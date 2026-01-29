import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient({String baseUrl = 'http://localhost:3000/api'}) : _baseUrl = baseUrl;

  final String _baseUrl;

  static const _tokenKey = 'token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<T> get<T>(String path, T Function(dynamic) fromJson, {bool withAuth = true, Map<String, String>? queryParams}) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final res = await http.get(uri, headers: await _headers(withAuth: withAuth));
    return _handleResponse(res, fromJson);
  }

  Future<List<String>> uploadImages(List<http.MultipartFile> files) async {
    final uri = Uri.parse('$_baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    for (final f in files) request.files.add(f);
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode >= 400) {
      throw Exception(data?['error'] ?? res.body);
    }
    final urls = data?['urls'] as List<dynamic>?;
    return urls?.map((e) => e as String).toList() ?? [];
  }

  Future<T> post<T>(String path, Map<String, dynamic>? body, T Function(dynamic) fromJson, {bool withAuth = true}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final res = await http.post(
      uri,
      headers: await _headers(withAuth: withAuth),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res, fromJson);
  }

  Future<T> patch<T>(String path, Map<String, dynamic>? body, T Function(dynamic) fromJson) async {
    final uri = Uri.parse('$_baseUrl$path');
    final res = await http.patch(
      uri,
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(res, fromJson);
  }

  Future<void> delete(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final res = await http.delete(uri, headers: await _headers());
    if (res.statusCode >= 400) {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      throw Exception(data?['error'] ?? res.body);
    }
  }

  T _handleResponse<T>(http.Response res, T Function(dynamic) fromJson) {
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final msg = data is Map ? data['error'] : res.body;
      throw Exception(msg ?? 'Request failed');
    }
    return fromJson(data);
  }
}
