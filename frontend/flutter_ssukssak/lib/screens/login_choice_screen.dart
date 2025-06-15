import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uni_links/uni_links.dart';
import '../../services/auth_service.dart';

class LoginChoiceScreen extends StatefulWidget {
  const LoginChoiceScreen({Key? key}) : super(key: key);

  @override
  State<LoginChoiceScreen> createState() => _LoginChoiceScreenState();
}

class _LoginChoiceScreenState extends State<LoginChoiceScreen> {
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

  /* ─────────── 딥링크 수신 ─────────── */
  void _listenForRedirect() {
    _sub = uriLinkStream.listen((Uri? uri) async {
      if (uri?.scheme == 'ssukssak' && uri?.host == 'callback') {
        final code = uri?.queryParameters['code'];
        if (code == null) return;

        final ok = await AuthService.handleCognitoCode(code);
        if (!ok) {
          debugPrint('❌ 토큰 저장 실패');
          return;
        }
        final me = await AuthService.fetchMe();
        if (me == null) {
          debugPrint('❌ /auth/me 실패');
          return;
        }
        debugPrint('🎉 로그인 완료 userId=${me['userId']}');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }, onError: (err) {
      debugPrint('❌ 딥링크 오류: $err');
    });
  }

  /* ─────────── Google 로그인 버튼 ─────────── */
  void _loginWithGoogle() async {
    final uri = Uri.parse(cognitoLoginUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      debugPrint('❌ launchUrl 실패: $e');
    }
  }

  void _goToEmailLogin() => Navigator.pushNamed(context, '/email-login');

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
                      onPressed: _goToEmailLogin,
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
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/photoAnalyzer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "AI 모델 결과 확인하기",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "※ 테스트용: 로그인 없이 AI 분석 페이지로 이동합니다.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/metadata-debug'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "📷 갤럭시 메타데이터 확인",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "※ 테스트용: 갤러리 사진 메타데이터 확인 페이지로 이동합니다.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
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
