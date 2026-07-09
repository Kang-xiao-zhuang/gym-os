import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Thin client for the Spring Boot backend. Attaches the current Supabase
/// access token as a Bearer credential — that is exactly the JWT the backend
/// verifies against Supabase's JWKS.
class ApiClient {
  static Map<String, String> _headers() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      if (token != null) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('${AppConfig.apiBaseUrl}$path'), headers: _headers());
    return _unwrap(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: _headers(), body: jsonEncode(body));
    return _unwrap(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: _headers(), body: jsonEncode(body));
    return _unwrap(res);
  }

  /// Unwrap the backend's uniform Result envelope; throw [ApiException] unless code == 200.
  static dynamic _unwrap(http.Response res) {
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final code = body['code'] as int?;
    if (code != 200) {
      throw ApiException(code ?? res.statusCode, body['message']?.toString() ?? '请求失败');
    }
    return body['data'];
  }
}

class ApiException implements Exception {
  ApiException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => message;
}
