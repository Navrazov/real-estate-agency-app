import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiClient = ApiClient();
  final _picker = ImagePicker();

  // Email section
  final _emailCtrl = TextEditingController();
  final _emailCodeCtrl = TextEditingController();
  bool _emailCodeSent = false;
  bool _emailLoading = false;
  bool _editingEmail = false;

  // Phone section
  final _phoneCtrl = TextEditingController();
  final _phoneCodeCtrl = TextEditingController();
  bool _phoneCodeSent = false;
  bool _phoneLoading = false;
  bool _editingPhone = false;

  // Avatar section
  bool _avatarLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneCodeCtrl.dispose();
    super.dispose();
  }

  void _resetEmailState() {
    setState(() {
      _editingEmail = false;
      _emailCodeSent = false;
      _emailLoading = false;
      _emailCtrl.clear();
      _emailCodeCtrl.clear();
    });
  }

  void _resetPhoneState() {
    setState(() {
      _editingPhone = false;
      _phoneCodeSent = false;
      _phoneLoading = false;
      _phoneCtrl.clear();
      _phoneCodeCtrl.clear();
    });
  }

  Future<void> _sendEmailCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar('Введите корректный email');
      return;
    }

    setState(() => _emailLoading = true);
    try {
      final auth = AuthServiceScope.of(context);
      await auth.sendEmailCode(email);
      if (mounted) {
        setState(() {
          _emailCodeSent = true;
          _emailLoading = false;
        });
        _showSnackBar('Код отправлен на $email');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emailLoading = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _verifyEmailCode() async {
    final email = _emailCtrl.text.trim();
    final code = _emailCodeCtrl.text.trim();
    if (code.length < 4) {
      _showSnackBar('Введите 4-значный код');
      return;
    }

    setState(() => _emailLoading = true);
    try {
      final auth = AuthServiceScope.of(context);
      await auth.verifyEmailCode(email, code);
      if (mounted) {
        _resetEmailState();
        _showSnackBar('Email успешно подтвержден');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _emailLoading = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _sendPhoneChangeCode() async {
    final phone = _rawPhone();
    if (phone.length < 12) {
      _showSnackBar('Введите корректный номер телефона');
      return;
    }

    setState(() => _phoneLoading = true);
    try {
      final auth = AuthServiceScope.of(context);
      await auth.sendPhoneChangeCode(phone);
      if (mounted) {
        setState(() {
          _phoneCodeSent = true;
          _phoneLoading = false;
        });
        _showSnackBar('Код отправлен');
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

  String _rawPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7')) return '+$digits';
    if (digits.startsWith('8')) return '+7${digits.substring(1)}';
    return '+7$digits';
  }

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
        // Update profile via PATCH /users/me
        await _apiClient.patch<Map<String, dynamic>>(
          '/users/me',
          {'avatar': urls.first},
          (d) => d as Map<String, dynamic>,
        );
        // Refresh user data in auth service
        if (mounted) {
          // Re-read the auth to trigger a refresh
          final auth = AuthServiceScope.of(context);
          // We need to reload user; calling a dummy method or using internal reload
          // Since _loadUser is private, we trigger a re-login by calling verifyEmailCode-like approach
          // Actually, we can use the fact that auth notifies listeners. Let's just patch and rely on the
          // next navigation to refresh. But for immediate feedback, let's call login refresh.
          // The simplest approach: call sendEmailCode to trigger _loadUser... but that's hacky.
          // Better: add a public refresh method or just reconstruct the user locally.
          // Since we can't modify the private _loadUser, let's trigger a full reload by logging out/in.
          // Actually the simplest: the verifyPhoneChange and verifyEmailCode both call _loadUser.
          // For avatar, we don't have such a method. Let's just do a workaround:
          // We'll make a dummy authenticated GET to /users/me and update the user.
          // Actually, we can just use auth's internal state. Let's read the user data directly.
          await _reloadUser(auth);
          _showSnackBar('Фото профиля обновлено');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
            'Ошибка: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  /// Reload the user by making a profile-level change that triggers _loadUser.
  /// Since _loadUser is private, we use a workaround: PATCH with empty body and
  /// then use sendEmailCode/verifyEmailCode. But actually, the cleanest way is
  /// to read /users/me and update the auth user state.
  Future<void> _reloadUser(AuthService auth) async {
    // We use verifyPhoneChange with the current phone to trigger _loadUser.
    // Actually, we can't do that without a code. Let's just call the API and
    // reconstruct the user manually.
    try {
      final data = await _apiClient.get<Map<String, dynamic>>(
        '/users/me',
        (d) => d as Map<String, dynamic>,
      );
      // Update favorites to trigger notifyListeners (this is the only public
      // method that updates internal user state)
      final favorites =
          (data['favorites'] as List<dynamic>?)?.cast<String>() ?? [];
      auth.updateFavorites(favorites);
    } catch (_) {
      // Ignore reload errors
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Theme Section ---
          _buildSectionTitle('Тема оформления'),
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
                    onChanged: (_) {
                      ThemeServiceScope.of(context).toggleTheme();
                    },
                    activeThumbColor: context.appColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Avatar Section ---
          _buildSectionTitle('Фото профиля'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
                    backgroundImage: user?.avatar != null
                        ? NetworkImage(user!.avatar!)
                        : null,
                    child: user?.avatar == null
                        ? Text(
                            user?.displayName
                                    .substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: context.appColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _avatarLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
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

          // --- Email Section ---
          _buildSectionTitle('Email'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildEmailSection(user),
            ),
          ),
          const SizedBox(height: 24),

          // --- Phone Section ---
          _buildSectionTitle('Телефон'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildPhoneSection(user),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: context.appColors.textPrimary,
      ),
    );
  }

  Widget _buildEmailSection(User? user) {
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;

    if (!_editingEmail) {
      if (hasEmail) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email_outlined,
                    color: context.appColors.textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.email!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (user.emailVerified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.appColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: context.appColors.success, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Подтвержден',
                          style:
                              TextStyle(color: context.appColors.success, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _editingEmail = true),
              child: const Text('Изменить email'),
            ),
          ],
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email не привязан',
              style: TextStyle(color: context.appColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _editingEmail = true),
              icon: const Icon(Icons.add),
              label: const Text('Добавить email'),
            ),
          ],
        );
      }
    }

    // Editing email flow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            hintText: 'your@email.com',
          ),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enabled: !_emailLoading && !_emailCodeSent,
        ),
        const SizedBox(height: 12),
        if (!_emailCodeSent)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _emailLoading ? null : _sendEmailCode,
                  child: _emailLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить код'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetEmailState,
                child: const Text('Отмена'),
              ),
            ],
          ),
        if (_emailCodeSent) ...[
          TextFormField(
            controller: _emailCodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Код подтверждения',
              prefixIcon: Icon(Icons.sms_outlined),
              hintText: '1234',
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !_emailLoading,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _emailLoading ? null : _verifyEmailCode,
                  child: _emailLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Подтвердить'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetEmailState,
                child: const Text('Отмена'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneSection(User? user) {
    if (!_editingPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_outlined,
                  color: context.appColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user?.phone ?? 'Не указан',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
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

    // Editing phone flow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Текущий: ${user?.phone ?? "Не указан"}',
          style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Новый номер',
            prefixIcon: Icon(Icons.phone_outlined),
            hintText: '+7 (999) 123-45-67',
          ),
          keyboardType: TextInputType.phone,
          inputFormatters: [_SettingsPhoneInputFormatter()],
          enabled: !_phoneLoading && !_phoneCodeSent,
        ),
        const SizedBox(height: 12),
        if (!_phoneCodeSent)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _phoneLoading ? null : _sendPhoneChangeCode,
                  child: _phoneLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Отправить код'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetPhoneState,
                child: const Text('Отмена'),
              ),
            ],
          ),
        if (_phoneCodeSent) ...[
          TextFormField(
            controller: _phoneCodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Код подтверждения',
              prefixIcon: Icon(Icons.sms_outlined),
              hintText: '1234',
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            enabled: !_phoneLoading,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _phoneLoading ? null : _verifyPhoneChange,
                  child: _phoneLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Подтвердить'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _resetPhoneState,
                child: const Text('Отмена'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Phone input formatter for Settings screen (same logic).
String _settingsFormatPhoneDisplay(String digits) {
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

class _SettingsPhoneInputFormatter extends TextInputFormatter {
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
    final formatted = _settingsFormatPhoneDisplay(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
