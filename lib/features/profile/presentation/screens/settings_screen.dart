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
    _phoneCtrl.dispose();
    _phoneCodeCtrl.dispose();
    super.dispose();
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
          final auth = AuthServiceScope.of(context);
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

  Future<void> _reloadUser(AuthService auth) async {
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
