import 'package:flutter/material.dart';
import '../api/api_client.dart';

class SubscriptionInfo {
  const SubscriptionInfo({
    this.plan = 'free',
    this.maxListings = 3,
    this.maxConversations = 5,
    this.canSeePhones = false,
    this.priorityPlacement = false,
    this.advancedStats = false,
  });

  final String plan;
  final int maxListings;
  final int maxConversations;
  final bool canSeePhones;
  final bool priorityPlacement;
  final bool advancedStats;

  bool get isPro => plan == 'pro';
  bool get isFree => plan != 'pro';

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    final limits = json['limits'] as Map<String, dynamic>? ?? {};
    final maxListings = limits['maxListings'];
    return SubscriptionInfo(
      plan: json['plan'] as String? ?? 'free',
      maxListings: maxListings is num && maxListings.isFinite ? maxListings.toInt() : 999999,
      maxConversations: (limits['maxConversations'] as num?)?.toInt() ?? 5,
      canSeePhones: limits['canSeePhones'] as bool? ?? false,
      priorityPlacement: limits['priorityPlacement'] as bool? ?? false,
      advancedStats: limits['advancedStats'] as bool? ?? false,
    );
  }
}

class User {
  User({
    required this.id,
    required this.role,
    this.name,
    this.phone,
    this.avatar,
    this.favorites = const [],
    this.subscription = const SubscriptionInfo(),
  });

  final String id;
  final String role;
  final String? name;
  final String? phone;
  final String? avatar;
  final List<String> favorites;
  final SubscriptionInfo subscription;

  String get displayName => name ?? phone ?? 'Пользователь';
  bool get isAdmin => role == 'admin';
  bool get isPro => subscription.isPro;
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
        // Load subscription info in parallel
        SubscriptionInfo sub = const SubscriptionInfo();
        try {
          final subData = await _api.get<Map<String, dynamic>>(
            '/subscriptions/me',
            (d) => d as Map<String, dynamic>,
          );
          sub = SubscriptionInfo.fromJson(subData);
        } catch (_) {
          // Default to free plan on error
        }
        _user = User(
          id: data['id'] as String,
          role: data['role'] as String,
          name: data['name'] as String?,
          phone: data['phone'] as String?,
          avatar: data['avatar'] as String?,
          favorites: (data['favorites'] as List<dynamic>?)?.cast<String>() ?? [],
          subscription: sub,
        );
      }
    } catch (_) {
      await _api.setToken(null);
      _user = null;
    }
    _loading = false;
    notifyListeners();
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
  Future<void> sendCode(String phone, {String method = 'call', bool checkExists = false}) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/send-code',
      {'phone': phone, 'method': method, 'checkExists': checkExists},
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
  Future<void> sendPhoneChangeCode(String phone) async {
    await _api.post<Map<String, dynamic>>(
      '/users/me/phone/send-code',
      {'phone': phone},
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

  Future<void> logout() async {
    await _api.setToken(null);
    _user = null;
    notifyListeners();
  }

  void updateFavorites(List<String> favorites) {
    if (_user != null) {
      _user = User(
        id: _user!.id,
        role: _user!.role,
        name: _user!.name,
        phone: _user!.phone,
        avatar: _user!.avatar,
        favorites: favorites,
        subscription: _user!.subscription,
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
