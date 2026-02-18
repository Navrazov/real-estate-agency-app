import 'package:flutter/material.dart';
import '../api/api_client.dart';

class User {
  User({
    required this.id,
    required this.role,
    this.name,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatar,
    this.favorites = const [],
    this.phoneHidden = false,
    this.birthDate,
  });

  final String id;
  final String role;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? avatar;
  final List<String> favorites;
  final bool phoneHidden;
  final DateTime? birthDate;

  String get displayName => name ?? [firstName, lastName].where((s) => s != null && s.isNotEmpty).join(' ').nullIfEmpty ?? phone ?? 'Пользователь';
  bool get isAdmin => role == 'admin' || role == 'superadmin';
}

extension _StringExt on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

class AuthService extends ChangeNotifier {
  AuthService() {
    _loadUser();
  }

  final ApiClient _api = ApiClient();
  User? _user;
  bool _loading = true;
  String _plan = 'free'; // 'free' | 'pro' | 'premium'

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String get plan => _plan;
  bool get canCreate => _plan != 'free';

  Future<void> _loadUser() async {
    final token = await _api.getToken();
    if (token == null) {
      _user = null;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/users/me',
        (d) => d as Map<String, dynamic>,
      );
      if (data['blocked'] == true) {
        await _api.setToken(null);
        _user = null;
        _plan = 'free';
      } else {
        _user = User(
          id: data['id'] as String,
          role: data['role'] as String,
          name: data['name'] as String?,
          firstName: data['firstName'] as String?,
          lastName: data['lastName'] as String?,
          phone: data['phone'] as String?,
          avatar: data['avatar'] as String?,
          favorites: (data['favorites'] as List<dynamic>?)?.cast<String>() ?? [],
          phoneHidden: data['phoneHidden'] as bool? ?? false,
          birthDate: data['birthDate'] != null ? DateTime.tryParse(data['birthDate'] as String) : null,
        );
        // Load subscription plan
        try {
          final sub = await _api.get<Map<String, dynamic>>(
            '/subscriptions/me',
            (d) => d as Map<String, dynamic>,
          );
          _plan = sub['plan'] as String? ?? 'free';
        } catch (_) {
          _plan = (_user!.isAdmin) ? 'premium' : 'free';
        }
      }
    } catch (_) {
      await _api.setToken(null);
      _user = null;
      _plan = 'free';
    }
    _loading = false;
    notifyListeners();
  }

  /// Reload user data from the server.
  Future<void> reloadUser() async {
    await _loadUser();
  }

  /// Login with phone number and password.
  Future<void> login(String phone, String password) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      {'phone': phone, 'password': password},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
    await _api.setToken(data['token'] as String);
    await _loadUser();
  }

  /// Sends verification code to the given phone number.
  /// [method] can be 'call' (default) or 'telegram'.
  /// [checkExists] if true, server will check if phone is already registered.
  /// [mustExist] if true, server will check if phone is registered (for forgot password).
  Future<void> sendCode(String phone, {String method = 'call', bool checkExists = false, bool mustExist = false}) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/send-code',
      {'phone': phone, 'method': method, 'checkExists': checkExists, 'mustExist': mustExist},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
  }

  /// Verify SMS code without consuming it.
  Future<void> verifySmsCode(String phone, String code) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/verify-code',
      {'phone': phone, 'code': code},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
  }

  /// Register with phone, code, password, first/last name, and optional avatar.
  Future<void> register({
    required String phone,
    required String code,
    required String password,
    required String firstName,
    required String lastName,
    String? avatar,
    bool phoneHidden = false,
    DateTime? birthDate,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
      'code': code,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
    };
    if (avatar != null && avatar.isNotEmpty) {
      body['avatar'] = avatar;
    }
    body['phoneHidden'] = phoneHidden;
    if (birthDate != null) {
      body['birthDate'] = birthDate.toIso8601String();
    }
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      body,
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
    await _api.setToken(data['token'] as String);
    await _loadUser();
  }

  /// Send verification code for phone change (authenticated).
  /// [method] can be 'call' (default) or 'telegram'.
  Future<void> sendPhoneChangeCode(String phone, {String method = 'call'}) async {
    await _api.post<Map<String, dynamic>>(
      '/users/me/phone/send-code',
      {'phone': phone, 'method': method},
      (d) => d as Map<String, dynamic>,
    );
  }

  /// Verify phone change with code (authenticated), then refresh user.
  Future<void> verifyPhoneChange(String phone, String code) async {
    await _api.post<Map<String, dynamic>>(
      '/users/me/phone/verify',
      {'phone': phone, 'code': code},
      (d) => d as Map<String, dynamic>,
    );
    await _loadUser();
  }

  /// Change password (authenticated).
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _api.post<Map<String, dynamic>>(
      '/users/me/change-password',
      {'oldPassword': oldPassword, 'newPassword': newPassword},
      (d) => d as Map<String, dynamic>,
    );
  }

  /// Reset password via phone verification code (unauthenticated).
  Future<void> resetPassword(String phone, String code, String newPassword) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/reset-password',
      {'phone': phone, 'code': code, 'newPassword': newPassword},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
  }

  Future<void> logout() async {
    await _api.setToken(null);
    _user = null;
    _plan = 'free';
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _api.delete('/users/me/account');
    await _api.setToken(null);
    _user = null;
    _plan = 'free';
    notifyListeners();
  }

  /// Start Telegram auth flow. Returns bot URL and nonce for polling.
  Future<Map<String, String>> telegramInit() async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/telegram/init',
      {},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
    return {
      'nonce': data['nonce'] as String,
      'botUrl': data['botUrl'] as String,
    };
  }

  /// Poll for Telegram auth completion.
  /// Returns true if done, false if still pending.
  Future<bool> telegramCheck(String nonce) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/auth/telegram/check/$nonce',
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
    if (data['status'] == 'done') {
      final result = data['result'] as Map<String, dynamic>;
      await _api.setToken(result['token'] as String);
      await _loadUser();
      return true;
    }
    return false;
  }

  void updateFavorites(List<String> favorites) {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        role: _user!.role,
        name: _user!.name,
        firstName: _user!.firstName,
        lastName: _user!.lastName,
        phone: _user!.phone,
        avatar: _user!.avatar,
        favorites: favorites,
        phoneHidden: _user!.phoneHidden,
        birthDate: _user!.birthDate,
      );
      notifyListeners();
    }
  }
}

class AuthServiceScope extends InheritedNotifier<AuthService> {
  const AuthServiceScope({
    super.key,
    required AuthService auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthServiceScope>();
    assert(scope != null, 'AuthServiceScope not found');
    return scope!.notifier!;
  }
}
