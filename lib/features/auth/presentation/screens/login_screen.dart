import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:real_estate_app/app/theme/app_theme.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/api/api_client.dart';

/// Formats a raw digit string as +7 (XXX) XXX-XX-XX.
String _formatPhoneDisplay(String digits) {
  // digits should not include the leading 7
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
    // Extract only digits, strip leading 7/8
    var digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7') || digits.startsWith('8')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) digits = digits.substring(0, 10);
    final formatted = _formatPhoneDisplay(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Login fields
  final _identifierCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Register fields
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _codeSent = false;
  bool _sendingCode = false;
  String? _error;
  String? _avatarUrl;

  final _picker = ImagePicker();
  final _apiClient = ApiClient();

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _regPassCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _rawPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7')) return '+$digits';
    if (digits.startsWith('8')) return '+7${digits.substring(1)}';
    return '+7$digits';
  }

  Future<void> _sendCode() async {
    final phone = _rawPhone();
    if (phone.length < 12) {
      setState(() => _error = 'Введите корректный номер телефона');
      return;
    }

    setState(() {
      _sendingCode = true;
      _error = null;
    });

    try {
      final auth = AuthServiceScope.of(context);
      await auth.sendCode(phone);
      if (mounted) {
        setState(() {
          _codeSent = true;
          _sendingCode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _sendingCode = false;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;

    setState(() => _loading = true);
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
      final multipart = http.MultipartFile.fromBytes('images', bytes, filename: file.name, contentType: mimeType);
      final urls = await _apiClient.uploadImages([multipart]);
      if (urls.isNotEmpty && mounted) {
        setState(() => _avatarUrl = urls.first);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Ошибка загрузки аватара: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = AuthServiceScope.of(context);
      if (_isRegister) {
        await auth.register(
          phone: _rawPhone(),
          code: _codeCtrl.text.trim(),
          password: _regPassCtrl.text,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          avatar: _avatarUrl,
        );
      } else {
        await auth.login(_identifierCtrl.text.trim(), _passCtrl.text);
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'EstateHub',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister ? 'Создайте аккаунт' : 'Войдите в аккаунт',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Error
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isRegister) ..._buildRegisterFields() else ..._buildLoginFields(),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isRegister ? 'Создать аккаунт' : 'Войти'),
                    ),
                    const SizedBox(height: 16),

                    // Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegister ? 'Уже есть аккаунт?' : 'Нет аккаунта?',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _isRegister = !_isRegister;
                                    _error = null;
                                    _codeSent = false;
                                  }),
                          child: Text(_isRegister ? 'Войти' : 'Регистрация'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoginFields() {
    return [
      // Identifier (Phone or Email)
      TextFormField(
        controller: _identifierCtrl,
        decoration: const InputDecoration(
          labelText: 'Телефон или Email',
          prefixIcon: Icon(Icons.person_outline),
          hintText: '+7 (999) 123-45-67 или email',
        ),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите телефон или email';
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Password
      TextFormField(
        controller: _passCtrl,
        decoration: InputDecoration(
          labelText: 'Пароль',
          prefixIcon: const Icon(Icons.lock_outline),
          hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        obscureText: _obscurePassword,
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите пароль';
          if (v.length < 4) return 'Минимум 4 символа';
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildRegisterFields() {
    return [
      // Avatar
      Center(
        child: GestureDetector(
          onTap: _loading ? null : _pickAvatar,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
            child: _avatarUrl == null
                ? const Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.primary)
                : null,
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Center(
        child: Text(
          'Добавить фото',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
      const SizedBox(height: 16),

      // Phone
      TextFormField(
        controller: _phoneCtrl,
        decoration: const InputDecoration(
          labelText: 'Телефон',
          prefixIcon: Icon(Icons.phone_outlined),
          hintText: '+7 (999) 123-45-67',
        ),
        keyboardType: TextInputType.phone,
        inputFormatters: [_PhoneInputFormatter()],
        enabled: !_loading && !_sendingCode,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите телефон';
          final digits = v.replaceAll(RegExp(r'[^\d]'), '');
          if (digits.length < 11) return 'Введите полный номер';
          return null;
        },
      ),
      const SizedBox(height: 12),

      // Send code button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: (_loading || _sendingCode) ? null : _sendCode,
          child: _sendingCode
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_codeSent ? 'Отправить повторно' : 'Получить код'),
        ),
      ),

      if (_codeSent) ...[
        const SizedBox(height: 16),
        // Code input
        TextFormField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Код из СМС',
            prefixIcon: Icon(Icons.sms_outlined),
            hintText: '1234',
          ),
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_loading,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Введите код';
            if (v.length < 4) return 'Код — 4 цифры';
            return null;
          },
        ),
      ],
      const SizedBox(height: 16),

      // First name
      TextFormField(
        controller: _firstNameCtrl,
        decoration: const InputDecoration(
          labelText: 'Имя',
          prefixIcon: Icon(Icons.person_outline),
          hintText: 'Ваше имя',
        ),
        textCapitalization: TextCapitalization.words,
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Введите имя';
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Last name
      TextFormField(
        controller: _lastNameCtrl,
        decoration: const InputDecoration(
          labelText: 'Фамилия',
          prefixIcon: Icon(Icons.person_outline),
          hintText: 'Ваша фамилия',
        ),
        textCapitalization: TextCapitalization.words,
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Введите фамилию';
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Password
      TextFormField(
        controller: _regPassCtrl,
        decoration: InputDecoration(
          labelText: 'Пароль',
          prefixIcon: const Icon(Icons.lock_outline),
          hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        obscureText: _obscurePassword,
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите пароль';
          if (v.length < 4) return 'Минимум 4 символа';
          return null;
        },
      ),
      const SizedBox(height: 16),

      // Email (optional)
      TextFormField(
        controller: _emailCtrl,
        decoration: const InputDecoration(
          labelText: 'Email (необязательно)',
          prefixIcon: Icon(Icons.email_outlined),
          hintText: 'your@email.com',
        ),
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        enabled: !_loading,
      ),
    ];
  }
}
