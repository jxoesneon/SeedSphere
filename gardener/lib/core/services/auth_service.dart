import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _prodUrl = 'https://seedsphere.fly.dev';

  String get _apiBase =>
      (kDebugMode && !kIsWeb) ? 'http://localhost:8080' : _prodUrl;

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userId = prefs.getString('user_id');

    // 1. Clear local session immediately
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');

    // 2. Notify backend to invalidate session (fire-and-forget)
    if (token != null && userId != null) {
      try {
        final uri = Uri.parse('$_apiBase/api/auth/logout');
        await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (e) {
        debugPrint('Logout cleanup failed: $e');
      }
    }
  }
}
