import 'package:flutter/material.dart';
import '../api/api_client.dart';

class User {
  User({required this.id, required this.email, required this.role});
  final String id;
  final String email;
  final String role;
}

class AuthService extends ChangeNotifier {
  AuthService() {
    _loadUser();
  }

  final ApiClient _api = ApiClient();
  User? _user;
  bool _loading = true;

  User? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;

  Future<void> _loadUser() async {
    final token = await _api.getToken();
    if (token == null) {
      _user = null;
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.get<Map<String, dynamic>>('/users/me', (d) => d as Map<String, dynamic>);
      if (data['blocked'] == true) {
        await _api.setToken(null);
        _user = null;
      } else {
        _user = User(
          id: data['id'] as String,
          email: data['email'] as String,
          role: data['role'] as String,
        );
      }
    } catch (_) {
      await _api.setToken(null);
      _user = null;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      {'email': email, 'password': password},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
    await _api.setToken(data['token'] as String);
    final u = data['user'] as Map<String, dynamic>;
    _user = User(
      id: u['id'] as String,
      email: u['email'] as String,
      role: u['role'] as String,
    );
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      {'email': email, 'password': password},
      (d) => d as Map<String, dynamic>,
      withAuth: false,
    );
    await _api.setToken(data['token'] as String);
    final u = data['user'] as Map<String, dynamic>;
    _user = User(
      id: u['id'] as String,
      email: u['email'] as String,
      role: u['role'] as String,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.setToken(null);
    _user = null;
    notifyListeners();
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
