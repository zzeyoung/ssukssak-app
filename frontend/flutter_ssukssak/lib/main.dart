import 'package:flutter/material.dart';
import 'screens/login_choice_screen.dart'; // ✅ 우리가 만든 로그인 화면 import
import 'routes.dart'; // ✅ 이거 추가

void main() {
  runApp(const SsukssakApp());
}

class SsukssakApp extends StatelessWidget {
  const SsukssakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '쓱싹',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Pretendard',
      ),
      initialRoute: '/',
      routes: appRoutes, // ← 여기!
    );
  }
}
// 이 파일은 Flutter 앱의 진입점입니다.
// 여기서 앱을 실행하고, 필요한 화면과 라우트를 설정합니다.
// 이 파일은 Flutter 앱의 진입점입니다.
// 여기서 앱을 실행하고, 필요한 화면과 라우트를 설정합니다.