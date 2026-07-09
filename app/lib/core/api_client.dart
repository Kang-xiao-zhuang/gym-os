import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Thin client for the Spring Boot backend. Attaches the current Supabase
/// access token as a Bearer credential — that is exactly the JWT the backend
/// verifies against Supabase's JWKS.
class ApiClient {
  /// GET [path] (e.g. '/api/exercises') and return the decoded `data` field of
  /// the backend's uniform Result envelope. Throws [ApiException] on failure.
  static Future<dynamic> get(String path) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

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
  String toString() => 'ApiException($code, $message)';
}
