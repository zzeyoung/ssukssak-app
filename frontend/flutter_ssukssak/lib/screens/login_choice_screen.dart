import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class LoginChoiceScreen extends StatefulWidget {
  const LoginChoiceScreen({super.key});

  @override
  State<LoginChoiceScreen> createState() => _LoginChoiceScreenState();
}

class _LoginChoiceScreenState extends State<LoginChoiceScreen> {
  final String backendBaseUrl = 'http://10.0.2.2:3000'; // ✅ 에뮬레이터 전용 IP

  final String cognitoLoginUrl =
      'https://ap-southeast-2cnp2bd9aj.auth.ap-southeast-2.amazoncognito.com/login'
      '?client_id=h2e9vnf4jcd26m4aapifu9dq1'
      '&response_type=code'
      '&scope=email+openid+phone+profile'
      '&redirect_uri=ssukssak://callback';

  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _listenForRedirect();
  }

  void _listenForRedirect() {
    _sub = uriLinkStream.listen((Uri? uri) async {
      if (uri != null && uri.scheme == 'ssukssak' && uri.host == 'callback') {
        final code = uri.queryParameters['code'];
        debugPrint('✅ 받은 code: $code');
        if (code != null) {
          final success = await _sendCodeToBackend(code);
          if (success) {
            debugPrint('🎉 로그인 성공');
            await _getUserInfo();
          } else {
            debugPrint('❌ 로그인 실패');
          }
        }
      }
    }, onError: (err) {
      debugPrint('❌ 딥링크 수신 오류: $err');
    });
  }

  Future<bool> _sendCodeToBackend(String code) async {
    try {
      final uri = Uri.parse('$backendBaseUrl/auth/callback?code=$code');
      final response = await http.get(uri);

      debugPrint('🌐 응답코드: ${response.statusCode}');
      debugPrint('🌐 응답본문: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final accessToken = json['access_token'];

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken);
          debugPrint('✅ access token 저장됨');
          return true;
        } else {
          debugPrint('❌ access_token 없음');
          return false;
        }
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('❌ 예외 발생: $e');
      return false;
    }
  }

  Future<void> _getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        debugPrint('❌ 저장된 토큰 없음');
        return;
      }

      final response = await http.get(
        Uri.parse('$backendBaseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('👤 사용자 정보: ${response.statusCode} / ${response.body}');
    } catch (e) {
      debugPrint('❌ 사용자 정보 요청 실패: $e');
    }
  }

  void _loginWithGoogle() async {
    final uri = Uri.parse(cognitoLoginUrl);
    debugPrint('🔗 로그인 URL: $uri');

    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      debugPrint('❌ launchUrl 실패: $e');
    }
  }

  void _goToEmailLogin(BuildContext context) {
    Navigator.pushNamed(context, '/email-login');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_background.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 5),
                    Image.asset('assets/images/logo.png', height: 150),
                    const SizedBox(height: 12),
                    const Text(
                      "사진을 정리하면, 지구가 가벼워져요",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00695C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: _loginWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      child: const Text(
                        "Google로 시작하기",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _goToEmailLogin(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF009688),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "이메일로 시작하기",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
