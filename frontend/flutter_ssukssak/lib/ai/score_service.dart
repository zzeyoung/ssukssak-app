// lib/ai/score_service.dart

import 'package:flutter/services.dart'; // rootBundle 사용 시 필요 (fromAsset 대신 fromBuffer 등을 쓸 때)
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ScoreService {
  // 싱글턴 패턴
  static final ScoreService _instance = ScoreService._internal();
  factory ScoreService() => _instance;
  ScoreService._internal();

  Interpreter? _interpreter;
  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  /// 모델 로드: 한 번만 수행
  Future<void> loadModel() {
    if (_isLoaded) {
      return Future.value();
    }
    if (_loadingFuture != null) {
      return _loadingFuture!;
    }
    _loadingFuture = _loadInterpreter();
    return _loadingFuture!;
  }

  Future<void> _loadInterpreter() async {
    try {
      // fromAsset에 전달하는 경로는 pubspec.yaml에 등록된 asset 경로 중, assets/ 접두사 이후 상대경로
      // 예: pubspec.yaml에 '- assets/ai/meta_model_float32.tflite' 로 등록했다면:
      _interpreter =
          await Interpreter.fromAsset('assets/ai/meta_model_float32.tflite');
      _isLoaded = true;
      print('✅ ScoreService 모델 로드 완료');
    } catch (e) {
      print('❌ ScoreService 모델 로딩 실패: $e');
      // 실패 시 상태 초기화
      _loadingFuture = null;
      _isLoaded = false;
      _interpreter = null;
      rethrow;
    }
  }

  bool get isLoaded => _isLoaded;

  /// 이미지 예측: 예쁨 점수 등
  Future<double> predictScore(img.Image image) async {
    if (!_isLoaded) {
      await loadModel();
    }
    if (_interpreter == null) {
      throw Exception('ScoreService: Interpreter가 초기화되지 않았습니다.');
    }

    // 모델 스펙에 맞춰 입력/출력 텐서 구성
    // 예: 모델이 [1,224,224,3] float32 입력, [1,1] float32 출력이라고 가정
    const int inputSize = 224; // 실제 모델 입력 크기에 맞게 수정

    // 1) 이미지 리사이즈
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // 2) 입력 텐서 생성: [1][inputSize][inputSize][3]
    // Dart List 구조: List<List<List<List<double>>>>
    var input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (_) => List.generate(
          inputSize,
          (_) => List<double>.filled(3, 0.0),
        ),
      ),
    );
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        int pixel = resized.getPixel(x, y);
        int r = (pixel >> 16) & 0xFF;
        int g = (pixel >> 8) & 0xFF;
        int b = pixel & 0xFF;
        input[0][y][x] = [r / 255.0, g / 255.0, b / 255.0];
      }
    }

    // 3) 출력 텐서 생성: [1][1]
    var output = List.generate(1, (_) => List<double>.filled(1, 0.0));

    // 4) 인터프리터 실행
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('❌ ScoreService 예측 실행 오류: $e');
      rethrow;
    }

    return output[0][0];
  }
}
