import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://your-api.com';

  static Future<bool> signup(
      {required String email, required String password}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('회원가입 실패: ${response.body}');
        return false;
      }
    } catch (e) {
      print('회원가입 예외: $e');
      return false;
    }
  }
}
