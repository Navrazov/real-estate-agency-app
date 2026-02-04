import 'package:flutter/material.dart';
import '../api/api_client.dart';

class User {
  User({
    required this.id,
    required this.email,
    required this.role,
    this.name,
    this.phone,
    this.avatar,
    this.favorites = const [],
  });

  final String id;
  final String email;
  final String role;
  final String? name;
  final String? phone;
  final String? avatar;
  final List<String> favorites;

  String get displayName => name ?? email.split('@').first;
  bool get isAdmin => role == 'admin';
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
      final data = await _api.get<Map<String, dynamic>>(
        '/users/me',
        (d) => d as Map<String, dynamic>,
      );
      if (data['blocked'] == true) {
        await _api.setToken(null);
        _user = null;
      } else {
        _user = User(
          id: data['id'] as String,
          email: data['email'] as String,
          role: data['role'] as String,
          name: data['name'] as String?,
          phone: data['phone'] as String?,
          avatar: data['avatar'] as String?,
          favorites: (data['favorites'] as List<dynamic>?)?.cast<String>() ?? [],
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
    await _loadUser();
  }

  Future<void> register(String email, String password, {String? name}) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (name != null && name.isNotEmpty) {
      body['name'] = name;
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

  Future<void> logout() async {
    await _api.setToken(null);
    _user = null;
    notifyListeners();
  }

  void updateFavorites(List<String> favorites) {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        email: _user!.email,
        role: _user!.role,
        name: _user!.name,
        phone: _user!.phone,
        avatar: _user!.avatar,
        favorites: favorites,
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
