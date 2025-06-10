import 'package:flutter/material.dart';
import 'screens/login_choice_screen.dart';
import 'screens/email_login_screen.dart'; // 이메일 로그인 화면 import

Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const LoginChoiceScreen(),
  '/email-login': (context) => const EmailLoginScreen(),
  // 필요한 경로 더 추가 가능
};
