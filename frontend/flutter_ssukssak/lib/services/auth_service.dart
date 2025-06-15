import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인·토큰·프로필 관리
class AuthService {
  /// 에뮬레이터: 10.0.2.2 / 실제 기기: PC IP 로 교체
  static const String _baseUrl = 'http://172.31.81.175:3000';

  /* ─────────── Cognito 코드 처리 ─────────── */

  /// `/auth/callback?code=` → 액세스 토큰 저장
  static Future<bool> handleCognitoCode(String code) async {
    final uri = Uri.parse('$_baseUrl/auth/callback?code=$code');
    final res = await http.get(uri);
    if (res.statusCode != 200) return false;

    final token = jsonDecode(res.body)['access_token'] as String?;
    if (token == null) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    return true;
  }

  /// `/auth/me` 호출 → userId / email 등 반환 & 로컬 저장
  static Future<Map<String, dynamic>?> fetchMe() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return null;

    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return null;

    final profile = jsonDecode(res.body) as Map<String, dynamic>;
    final uid =
        (profile['userId'] ?? profile['sub'] ?? profile['id'])?.toString();
    return profile;
  }

  /* ─────────── 이메일 회원가입 예시 ─────────── */

  static Future<bool> signup({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return res.statusCode == 200;
  }
}
