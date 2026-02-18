import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/theme_service.dart';

/// Formats a raw digit string as +7 (XXX) XXX-XX-XX.
/// Returns empty string when no digits are present.
String _formatPhoneDisplay(String digits) {
  if (digits.isEmpty) return '';
  final d = digits;
  final buf = StringBuffer('+7');
  if (d.isNotEmpty) {
    buf.write(' (');
    buf.write(d.substring(0, d.length.clamp(0, 3)));
  }
  if (d.length >= 3) buf.write(') ');
  if (d.length > 3) buf.write(d.substring(3, d.length.clamp(3, 6)));
  if (d.length > 6) {
    buf.write('-');
    buf.write(d.substring(6, d.length.clamp(6, 8)));
  }
  if (d.length > 8) {
    buf.write('-');
    buf.write(d.substring(8, d.length.clamp(8, 10)));
  }
  return buf.toString();
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7') || digits.startsWith('8')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    final formatted = _formatPhoneDisplay(digits);
    if (formatted.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final cursorPos = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    int subDigitsBefore = _countSubscriberDigitsBefore(newValue.text, cursorPos);
    subDigitsBefore = subDigitsBefore.clamp(0, digits.length);
    final newCursorPos = _findCursorPosition(formatted, subDigitsBefore);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  int _countSubscriberDigitsBefore(String text, int pos) {
    int count = 0;
    bool firstDigitSeen = false;
    for (int i = 0; i < pos; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 48 && c <= 57) {
        if (!firstDigitSeen) {
          firstDigitSeen = true;
          if (text[i] == '7' || text[i] == '8') continue;
        }
        count++;
      }
    }
    return count;
  }

  int _findCursorPosition(String formatted, int n) {
    if (n <= 0) {
      final idx = formatted.indexOf('(');
      return idx >= 0 ? idx + 1 : formatted.length;
    }
    int count = 0;
    bool prefixSkipped = false;
    for (int i = 0; i < formatted.length; i++) {
      final c = formatted.codeUnitAt(i);
      if (c >= 48 && c <= 57) {
        if (!prefixSkipped) { prefixSkipped = true; continue; }
        count++;
        if (count == n) return i + 1;
      }
    }
    return formatted.length;
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiClient = ApiClient();
  final _picker = ImagePicker();

  // Name section
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  bool _editingName = false;
  bool _nameLoading = false;

  // Phone section
  final _phoneCtrl = TextEditingController();
  final _phoneCodeCtrl = TextEditingController();
  bool _phoneCodeSent = false;
  bool _phoneLoading = false;
  bool _editingPhone = false;
  String? _phoneCodeMethod;
  int _phoneCooldown = 0;
  Timer? _phoneCooldownTimer;

  // Password section
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _editingPassword = false;
  bool _passwordLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Avatar section
  bool _avatarLoading = false;

  static const _cooldownSeconds = 60;

  @override
  void dispose() {
    _phoneCooldownTimer?.cancel();
    _phoneCtrl.dispose();
    _phoneCodeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──

  String _rawPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7')) return '+$digits';
    if (digits.startsWith('8')) return '+7${digits.substring(1)}';
    return '+7$digits';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _startPhoneCooldown() {
    _phoneCooldownTimer?.cancel();
    setState(() => _phoneCooldown = _cooldownSeconds);
    _phoneCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _phoneCooldown--;
        if (_phoneCooldown <= 0) timer.cancel();
      });
    });
  }

  // ── Name ──

  void _startEditName() {
    final auth = AuthServiceScope.of(context);
    final user = auth.user;
    _firstNameCtrl.text = user?.firstName ?? '';
    _lastNameCtrl.text = user?.lastName ?? '';
    if (_firstNameCtrl.text.isEmpty && _lastNameCtrl.text.isEmpty && user?.name != null) {
      final parts = user!.name!.split(' ');
      _firstNameCtrl.text = parts.first;
      _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    setState(() {
      _editingName = true;
    });
  }

  Future<void> _saveName() async {
    final fn = _firstNameCtrl.text.trim();
    final ln = _lastNameCtrl.text.trim();
    if (fn.isEmpty || ln.isEmpty) {
      _showSnackBar('Заполните имя и фамилию');
      return;
    }
    setState(() => _nameLoading = true);
    try {
      await _apiClient.patch<Map<String, dynamic>>(
        '/users/me',
        {'firstName': fn, 'lastName': ln},
        (d) => d as Map<String, dynamic>,
      );
      if (mounted) {
        final auth = AuthServiceScope.of(context);
        await auth.reloadUser();
        setState(() {
          _editingName = false;
          _nameLoading = false;
        });
        _showSnackBar('Имя обновлено');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _nameLoading = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ── Phone ──

  void _resetPhoneState() {
    _phoneCooldownTimer?.cancel();
    setState(() {
      _editingPhone = false;
      _phoneCodeSent = false;
      _phoneLoading = false;
      _phoneCodeMethod = null;
      _phoneCooldown = 0;
      _phoneCtrl.clear();
      _phoneCodeCtrl.clear();
    });
  }

  Future<void> _sendPhoneChangeCode(String method) async {
    final phone = _rawPhone();
    if (phone.length < 12) {
      _showSnackBar('Введите корректный номер телефона');
      return;
    }
    setState(() => _phoneLoading = true);
    try {
      final auth = AuthServiceScope.of(context);
      await auth.sendPhoneChangeCode(phone, method: method);
      if (mounted) {
        setState(() {
          _phoneCodeSent = true;
          _phoneLoading = false;
          _phoneCodeMethod = method;
        });
        _startPhoneCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _phoneLoading = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _verifyPhoneChange() async {
    final phone = _rawPhone();
    final code = _phoneCodeCtrl.text.trim();
    if (code.length < 4) {
      _showSnackBar('Введите 4-значный код');
      return;
    }
    setState(() => _phoneLoading = true);
    try {
      final auth = AuthServiceScope.of(context);
      await auth.verifyPhoneChange(phone, code);
      if (mounted) {
        _resetPhoneState();
        _showSnackBar('Номер телефона успешно изменен');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _phoneLoading = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ── Password ──

  void _resetPasswordState() {
    setState(() {
      _editingPassword = false;
      _passwordLoading = false;
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _obscureOld = true;
      _obscureNew = true;
      _obscureConfirm = true;
    });
  }

  Future<void> _changePassword() async {
    final oldPass = _oldPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (oldPass.isEmpty) {
      _showSnackBar('Введите текущий пароль');
      return;
    }
    if (newPass.length < 6) {
      _showSnackBar('Новый пароль должен быть не менее 6 символов');
      return;
    }
    if (newPass != confirm) {
      _showSnackBar('Пароли не совпадают');
      return;
    }
    setState(() => _passwordLoading = true);
    try {
      final auth = AuthServiceScope.of(context);
      await auth.changePassword(oldPass, newPass);
      if (mounted) {
        _resetPasswordState();
        _showSnackBar('Пароль изменен');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _passwordLoading = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ── Avatar ──

  Future<void> _changeAvatar() async {
    final file = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;

    setState(() => _avatarLoading = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
        'png' => MediaType('image', 'png'),
        'gif' => MediaType('image', 'gif'),
        'webp' => MediaType('image', 'webp'),
        _ => MediaType('image', 'jpeg'),
      };
      final multipart = http.MultipartFile.fromBytes('images', bytes,
          filename: file.name, contentType: mimeType);
      final urls = await _apiClient.uploadImages([multipart]);
      if (urls.isNotEmpty) {
        await _apiClient.patch<Map<String, dynamic>>(
          '/users/me',
          {'avatar': urls.first},
          (d) => d as Map<String, dynamic>,
        );
        if (mounted) {
          final auth = AuthServiceScope.of(context);
          await auth.reloadUser();
          _showSnackBar('Фото профиля обновлено');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Ошибка: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Theme ---
          _sectionTitle('Тема оформления'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    context.isDark ? Icons.dark_mode : Icons.light_mode,
                    color: context.appColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.isDark ? 'Тёмная тема' : 'Светлая тема',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Switch(
                    value: context.isDark,
                    onChanged: (_) => ThemeServiceScope.of(context).toggleTheme(),
                    activeThumbColor: context.appColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Avatar ---
          _sectionTitle('Фото профиля'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                    backgroundImage: user?.avatar != null ? NetworkImage(user!.avatar!) : null,
                    child: user?.avatar == null
                        ? Text(
                            user?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: context.appColors.primary),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _avatarLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : OutlinedButton.icon(
                          onPressed: _changeAvatar,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Изменить фото'),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Name ---
          _sectionTitle('Имя'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildNameSection(user),
            ),
          ),
          const SizedBox(height: 24),

          // --- Birth Date ---
          _sectionTitle('Дата рождения'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildBirthDateSection(user),
            ),
          ),
          const SizedBox(height: 24),

          // --- Phone ---
          _sectionTitle('Телефон'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildPhoneSection(user),
            ),
          ),
          const SizedBox(height: 24),

          // --- Phone Visibility ---
          _sectionTitle('Скрыть номер'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    user?.phoneHidden == true ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: context.appColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Скрыть номер',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Другие пользователи не смогут видеть ваш номер телефона',
                          style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: user?.phoneHidden == true,
                    onChanged: (val) async {
                      try {
                        await _apiClient.patch<Map<String, dynamic>>(
                          '/users/me',
                          {'phoneHidden': val},
                          (d) => d as Map<String, dynamic>,
                        );
                        if (mounted) {
                          await AuthServiceScope.of(context).reloadUser();
                        }
                      } catch (e) {
                        if (mounted) _showSnackBar('Ошибка: $e');
                      }
                    },
                    activeThumbColor: context.appColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Password ---
          _sectionTitle('Пароль'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildPasswordSection(),
            ),
          ),

          const SizedBox(height: 32),

          // --- Delete Account ---
          _buildDeleteAccountSection(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.appColors.textPrimary),
    );
  }

  // ── Name section ──

  Widget _buildNameSection(User? user) {
    if (!_editingName) {
      final displayName = user?.name ?? [user?.firstName, user?.lastName].where((s) => s != null && s.isNotEmpty).join(' ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: context.appColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayName.isNotEmpty ? displayName : 'Не указано',
                  style: TextStyle(fontSize: 16, color: displayName.isNotEmpty ? null : context.appColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _startEditName,
            child: const Text('Изменить имя'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _firstNameCtrl,
          decoration: const InputDecoration(labelText: 'Имя', prefixIcon: Icon(Icons.person_outline), hintText: 'Иван'),
          textCapitalization: TextCapitalization.words,
          enabled: !_nameLoading,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastNameCtrl,
          decoration: const InputDecoration(labelText: 'Фамилия', prefixIcon: Icon(Icons.person_outline), hintText: 'Иванов'),
          textCapitalization: TextCapitalization.words,
          enabled: !_nameLoading,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _nameLoading ? null : _saveName,
                child: _nameLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Сохранить'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _editingName = false),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ],
    );
  }

  // ── Birth Date section ──

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _buildBirthDateSection(User? user) {
    final birthDate = user?.birthDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cake_outlined, color: context.appColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                birthDate != null ? _formatDate(birthDate) : 'Не указана',
                style: TextStyle(fontSize: 16, color: birthDate != null ? null : context.appColors.textSecondary),
              ),
            ),
            if (birthDate != null)
              IconButton(
                icon: Icon(Icons.clear, size: 18, color: context.appColors.textMuted),
                onPressed: () async {
                  try {
                    await _apiClient.patch<Map<String, dynamic>>(
                      '/users/me',
                      {'birthDate': null},
                      (d) => d as Map<String, dynamic>,
                    );
                    if (mounted) await AuthServiceScope.of(context).reloadUser();
                  } catch (e) {
                    if (mounted) _showSnackBar('Ошибка: $e');
                  }
                },
                tooltip: 'Удалить дату рождения',
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: birthDate ?? DateTime(now.year - 25),
              firstDate: DateTime(1920),
              lastDate: now,
              locale: const Locale('ru'),
            );
            if (picked == null) return;
            try {
              await _apiClient.patch<Map<String, dynamic>>(
                '/users/me',
                {'birthDate': picked.toIso8601String()},
                (d) => d as Map<String, dynamic>,
              );
              if (mounted) {
                await AuthServiceScope.of(context).reloadUser();
                _showSnackBar('Дата рождения обновлена');
              }
            } catch (e) {
              if (mounted) _showSnackBar('Ошибка: $e');
            }
          },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(birthDate != null ? 'Изменить' : 'Указать дату рождения'),
        ),
      ],
    );
  }

  // ── Phone section ──

  Widget _buildPhoneSection(User? user) {
    final cooldownDisabled = _phoneCooldown > 0 || _phoneLoading;

    if (!_editingPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_outlined, color: context.appColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(user?.phone ?? 'Не указан', style: const TextStyle(fontSize: 16))),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _editingPhone = true),
            child: const Text('Изменить номер'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Текущий: ${user?.phone ?? "Не указан"}', style: TextStyle(color: context.appColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Новый номер', prefixIcon: Icon(Icons.phone_outlined), hintText: '+7 (999) 123-45-67'),
          keyboardType: TextInputType.phone,
          inputFormatters: [_PhoneInputFormatter()],
          enabled: !_phoneLoading && !_phoneCodeSent,
        ),
        const SizedBox(height: 12),

        if (!_phoneCodeSent) ...[
          Text('Выберите способ получения кода', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: cooldownDisabled ? null : () => _sendPhoneChangeCode('call'),
                  icon: _phoneLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.phone, size: 18),
                  label: const Text('Звонок'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cooldownDisabled ? null : () => _sendPhoneChangeCode('telegram'),
                  icon: _phoneLoading
                      ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.appColors.primary))
                      : const Icon(Icons.telegram, size: 18),
                  label: const Text('Telegram'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ),
            ],
          ),
          if (_phoneCooldown > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Повторный запрос через $_phoneCooldown сек.', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
            ),
          const SizedBox(height: 8),
          TextButton(onPressed: _resetPhoneState, child: const Text('Отмена')),
        ],

        if (_phoneCodeSent) ...[
          // Hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_phoneCodeMethod == 'call' ? Icons.phone_callback : Icons.telegram, color: context.appColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _phoneCodeMethod == 'call' ? 'Вам поступит звонок' : 'Код отправлен в Telegram',
                        style: TextStyle(fontWeight: FontWeight.w600, color: context.appColors.primary, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _phoneCodeMethod == 'call'
                            ? 'Введите последние 4 цифры номера, с которого поступит звонок.'
                            : 'Проверьте сообщения в Telegram и введите полученный 4-значный код.',
                        style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCodeCtrl,
            decoration: const InputDecoration(labelText: 'Код подтверждения', prefixIcon: Icon(Icons.sms_outlined), hintText: '0000'),
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !_phoneLoading,
          ),
          const SizedBox(height: 8),
          // Resend
          Text('Не получили код?', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: cooldownDisabled ? null : () => _sendPhoneChangeCode('call'),
                style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 12), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Позвонить снова'),
              ),
              Text('|', style: TextStyle(color: context.appColors.textSecondary.withValues(alpha: 0.5))),
              TextButton(
                onPressed: cooldownDisabled ? null : () => _sendPhoneChangeCode('telegram'),
                style: TextButton.styleFrom(textStyle: const TextStyle(fontSize: 12), padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Отправить в Telegram'),
              ),
            ],
          ),
          if (_phoneCooldown > 0)
            Text('Повторный запрос через $_phoneCooldown сек.', style: TextStyle(color: context.appColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _phoneLoading ? null : _verifyPhoneChange,
                  child: _phoneLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Подтвердить'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _resetPhoneState, child: const Text('Отмена')),
            ],
          ),
        ],
      ],
    );
  }

  // ── Password section ──

  Widget _buildPasswordSection() {
    if (!_editingPassword) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: context.appColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              const Text('••••••••', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _editingPassword = true),
            child: const Text('Изменить пароль'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _oldPassCtrl,
          decoration: InputDecoration(
            labelText: 'Текущий пароль',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureOld = !_obscureOld),
            ),
          ),
          obscureText: _obscureOld,
          enabled: !_passwordLoading,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _newPassCtrl,
          decoration: InputDecoration(
            labelText: 'Новый пароль',
            prefixIcon: const Icon(Icons.lock_outline),
            hintText: 'Минимум 6 символов',
            suffixIcon: IconButton(
              icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
          ),
          obscureText: _obscureNew,
          enabled: !_passwordLoading,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPassCtrl,
          decoration: InputDecoration(
            labelText: 'Повторите пароль',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          obscureText: _obscureConfirm,
          enabled: !_passwordLoading,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _passwordLoading ? null : _changePassword,
                child: _passwordLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Сохранить'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _resetPasswordState, child: const Text('Отмена')),
          ],
        ),
      ],
    );
  }

  // ── Delete account section ──

  Widget _buildDeleteAccountSection() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.appColors.error.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Удаление аккаунта',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.appColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              'Это действие нельзя отменить. Все ваши данные и объявления будут удалены навсегда.',
              style: TextStyle(fontSize: 13, color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _confirmDeleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appColors.error,
                  side: BorderSide(color: context.appColors.error),
                ),
                child: const Text('Удалить аккаунт'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text('Это действие нельзя отменить. Все ваши данные и объявления будут удалены навсегда.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Удалить', style: TextStyle(color: context.appColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await AuthServiceScope.of(context).deleteAccount();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) _showSnackBar('Ошибка: $e');
    }
  }
}
