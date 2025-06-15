// lib/routes.dart

import 'package:flutter/material.dart';
import 'screens/login_choice_screen.dart';
import 'screens/email_login_screen.dart'; // 이메일 로그인 화면
import 'screens/photo_analyzer.dart'; // 팀원 AI 화면 분리 파일
import 'screens/metadata_debug_screen.dart';
import 'screens/home_screen.dart'; // 홈 화면

/// 앱 내 모든 경로를 정의하는 Map.
/// 기존에 로그인/이메일 로그인 경로에 더해, AI 모델 화면 경로를 추가합니다.
Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const LoginChoiceScreen(),
  '/email-login': (context) => const EmailLoginScreen(),
  '/photoAnalyzer': (context) => const PhotoAnalyzer(),
  '/metadata-debug': (context) => const MetadataDebugScreen(),
  '/home': (_) => const HomeScreen(),
  // 필요시 다른 화면 경로를 여기에 추가
};
