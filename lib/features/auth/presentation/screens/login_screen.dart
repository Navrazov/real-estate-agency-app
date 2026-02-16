import 'dart:async';
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

  bool _isRegister = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureRegPassword = true;
  bool _codeSent = false;
  bool _sendingCode = false;
  int _regStep = 1; // 1 = phone verification, 2 = personal info
  String? _error;
  String? _codeMethod; // 'call' or 'telegram'
  int _cooldown = 0;
  Timer? _cooldownTimer;
  Uint8List? _avatarBytes;
  String? _avatarFileName;

  final _picker = ImagePicker();
  final _apiClient = ApiClient();

  static const _cooldownSeconds = 60;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _identifierCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  String _rawPhone() {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7')) return '+$digits';
    if (digits.startsWith('8')) return '+7${digits.substring(1)}';
    return '+7$digits';
  }

  String _rawLoginPhone() {
    final digits = _identifierCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('7')) return '+$digits';
    if (digits.startsWith('8')) return '+7${digits.substring(1)}';
    return '+7$digits';
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _cooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode(String method) async {
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
      await auth.sendCode(phone, method: method, checkExists: true);
      if (mounted) {
        setState(() {
          _codeSent = true;
          _sendingCode = false;
          _codeMethod = method;
        });
        _startCooldown();
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
    final file = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
          _avatarFileName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Ошибка выбора фото: ${e.toString().replaceFirst("Exception: ", "")}');
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_avatarBytes == null || _avatarFileName == null) return;
    final ext = _avatarFileName!.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'gif' => MediaType('image', 'gif'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
    final multipart = http.MultipartFile.fromBytes('images', _avatarBytes!,
        filename: _avatarFileName!, contentType: mimeType);
    final urls = await _apiClient.uploadImages([multipart]);
    if (urls.isNotEmpty) {
      await _apiClient.patch('/users/me', {'avatar': urls.first},
          (d) => d as Map<String, dynamic>);
    }
  }

  Future<void> _goToStep2() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = AuthServiceScope.of(context);
      await auth.verifySmsCode(_rawPhone(), _codeCtrl.text.trim());
      if (mounted) {
        setState(() {
          _regStep = 2;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _goBackToStep1() {
    setState(() {
      _regStep = 1;
      _error = null;
    });
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
        );
        // Upload avatar after registration (now we have a token)
        try {
          await _uploadAvatar();
        } catch (_) {
          // Avatar upload failed but registration succeeded
        }
      } else {
        await auth.login(_rawLoginPhone(), _passCtrl.text);
      }
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', ''));
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
                        gradient: LinearGradient(
                          colors: [context.appColors.primary, context.appColors.primary.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: context.appColors.primary.withValues(alpha: 0.3),
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
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister
                          ? (_regStep == 1
                              ? 'Шаг 1: Подтверждение телефона'
                              : 'Шаг 2: Личные данные')
                          : 'Войдите в аккаунт',
                      style: TextStyle(
                        color: context.appColors.textSecondary,
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
                          color: context.appColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: context.appColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: context.appColors.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style:
                                    TextStyle(color: context.appColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_isRegister)
                      ...(_regStep == 1
                          ? _buildRegisterStep1()
                          : _buildRegisterStep2())
                    else
                      ..._buildLoginFields(),

                    const SizedBox(height: 24),

                    // Submit / Next button
                    if (!_isRegister) ...[
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Войти'),
                      ),
                    ] else if (_regStep == 1) ...[
                      ElevatedButton(
                        onPressed:
                            (_loading || !_codeSent) ? null : _goToStep2,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Далее'),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Создать аккаунт'),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _loading ? null : _goBackToStep1,
                          child: const Text('Назад'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Toggle login/register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegister
                              ? 'Уже есть аккаунт?'
                              : 'Нет аккаунта?',
                          style:
                              TextStyle(color: context.appColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _isRegister = !_isRegister;
                                    _error = null;
                                    _codeSent = false;
                                    _regStep = 1;
                                    _codeMethod = null;
                                    _cooldown = 0;
                                    _cooldownTimer?.cancel();
                                  }),
                          child: Text(
                              _isRegister ? 'Войти' : 'Регистрация'),
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
      // Phone
      TextFormField(
        controller: _identifierCtrl,
        decoration: const InputDecoration(
          labelText: 'Телефон',
          prefixIcon: Icon(Icons.phone_outlined),
          hintText: '+7 (999) 123-45-67',
        ),
        keyboardType: TextInputType.phone,
        inputFormatters: [_PhoneInputFormatter()],
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите телефон';
          final digits = v.replaceAll(RegExp(r'[^\d]'), '');
          if (digits.length < 11) return 'Введите полный номер';
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
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
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

  /// Step 1: Phone number + verification code
  List<Widget> _buildRegisterStep1() {
    final cooldownDisabled = _cooldown > 0 || _sendingCode;

    return [
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
        enabled: !_loading && !_sendingCode && !_codeSent,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите телефон';
          final digits = v.replaceAll(RegExp(r'[^\d]'), '');
          if (digits.length < 11) return 'Введите полный номер';
          return null;
        },
      ),
      const SizedBox(height: 12),

      if (!_codeSent) ...[
        // Choose verification method
        Text(
          'Выберите способ получения кода',
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Call button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: cooldownDisabled ? null : () => _sendCode('call'),
                icon: _sendingCode
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.phone, size: 18),
                label: const Text('Звонок'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Telegram button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: cooldownDisabled ? null : () => _sendCode('telegram'),
                icon: _sendingCode
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.appColors.primary,
                        ),
                      )
                    : const Icon(Icons.telegram, size: 18),
                label: const Text('Telegram'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
        if (_cooldown > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Повторный запрос через $_cooldown сек.',
              style: TextStyle(
                color: context.appColors.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],

      if (_codeSent) ...[
        const SizedBox(height: 12),

        // Hint about the verification method
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.appColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.appColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _codeMethod == 'call' ? Icons.phone_callback : Icons.telegram,
                color: context.appColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _codeMethod == 'call'
                          ? 'Вам поступит звонок'
                          : 'Код отправлен в Telegram',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.appColors.primary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _codeMethod == 'call'
                          ? 'Введите последние 4 цифры номера, с которого поступит звонок. Если вы примете вызов, код будет озвучен.'
                          : 'Проверьте сообщения в Telegram и введите полученный 4-значный код.',
                      style: TextStyle(
                        color: context.appColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Code input
        TextFormField(
          controller: _codeCtrl,
          decoration: const InputDecoration(
            labelText: 'Код подтверждения',
            prefixIcon: Icon(Icons.pin_outlined),
            hintText: '0000',
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

        const SizedBox(height: 8),

        // Resend options
        Text(
          'Не получили код?',
          style: TextStyle(
            color: context.appColors.textSecondary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: cooldownDisabled ? null : () => _sendCode('call'),
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Позвонить снова'),
            ),
            Text(
              '|',
              style: TextStyle(
                color: context.appColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            TextButton(
              onPressed: cooldownDisabled ? null : () => _sendCode('telegram'),
              style: TextButton.styleFrom(
                textStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Отправить в Telegram'),
            ),
          ],
        ),
        if (_cooldown > 0)
          Text(
            'Повторный запрос через $_cooldown сек.',
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    ];
  }

  /// Step 2: Password, name, avatar
  List<Widget> _buildRegisterStep2() {
    return [
      // Password
      TextFormField(
        controller: _regPassCtrl,
        decoration: InputDecoration(
          labelText: 'Пароль',
          prefixIcon: const Icon(Icons.lock_outline),
          hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
          suffixIcon: IconButton(
            icon: Icon(
              _obscureRegPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () =>
                setState(() => _obscureRegPassword = !_obscureRegPassword),
          ),
        ),
        obscureText: _obscureRegPassword,
        enabled: !_loading,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Введите пароль';
          if (v.length < 4) return 'Минимум 4 символа';
          return null;
        },
      ),
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
      const SizedBox(height: 20),

      // Avatar upload (optional)
      Center(
        child: GestureDetector(
          onTap: _loading ? null : _pickAvatar,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: context.appColors.primary.withValues(alpha: 0.1),
            backgroundImage:
                _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
            child: _avatarBytes == null
                ? Icon(Icons.camera_alt_outlined,
                    size: 32, color: context.appColors.primary)
                : null,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Добавить фото (необязательно)',
          style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
        ),
      ),
    ];
  }
}
