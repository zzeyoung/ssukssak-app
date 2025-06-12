// lib/ai/clip_service.dart

import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ClipService {
  static final ClipService _instance = ClipService._internal();
  factory ClipService() => _instance;
  ClipService._internal();

  Interpreter? _interpreter;
  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  /// (예시) 사전계산된 텍스트 임베딩 맵 (태그 → 512차원 벡터)
  static const Map<String, List<double>> _textEmbeddings = {
    // 실제 사용 시, 512개 double 값을 채워넣어야 함
    'person': [/* 512 values */],
    'dog': [/* 512 values */],
    'cat': [/* 512 values */],
    'cup': [/* 512 values */],
    'bottle': [/* 512 values */],
    'book': [/* 512 values */],
    'laptop': [/* 512 values */],
    'tree': [/* 512 values */],
    'car': [/* 512 values */],
    'food': [/* 512 values */],
    // 추가 태그 ...
  };

  Future<void> loadModel() {
    if (_isLoaded) return Future.value();
    if (_loadingFuture != null) return _loadingFuture!;
    _loadingFuture = _loadInterpreter();
    return _loadingFuture!;
  }

  Future<void> _loadInterpreter() async {
    try {
      // pubspec.yaml에 'assets/ai/mobileclip_image_nhwc.tflite' 로 등록했다면:
      _interpreter =
          await Interpreter.fromAsset('assets/ai/mobileclip_image_nhwc.tflite');
      _isLoaded = true;
      print('✅ CLIP 모델 로드 완료');
    } catch (e) {
      print('❌ CLIP 모델 로딩 실패: $e');
      _loadingFuture = null;
      _isLoaded = false;
      _interpreter = null;
      rethrow;
    }
  }

  bool get isLoaded => _isLoaded;

  /// 이미지 → 512차원 벡터 추출
  Future<List<double>> predictFeatures(img.Image image) async {
    if (!_isLoaded) {
      await loadModel();
    }
    if (_interpreter == null) {
      throw Exception('ClipService: Interpreter가 초기화되지 않았습니다.');
    }

    const int inputSize = 224; // CLIP 모델 입력 크기에 맞춰 수정
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // 입력 텐서 구성: [1][inputSize][inputSize][3]
    var input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            int pixel = resized.getPixel(x, y);
            int r = (pixel >> 16) & 0xFF;
            int g = (pixel >> 8) & 0xFF;
            int b = pixel & 0xFF;
            return [r / 255.0, g / 255.0, b / 255.0];
          },
        ),
      ),
    );

    // 출력 텐서: [1][512]
    const int featureDim = 512; // 실제 CLIP 모델 출력 차원
    var output = List.generate(1, (_) => List<double>.filled(featureDim, 0.0));

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('❌ CLIP run 오류: $e');
      rethrow;
    }

    return List<double>.from(output[0]);
  }

  /// 이미지 임베딩 ↔ 텍스트 임베딩 비교하여 topK 태그 반환
  Future<List<String>> predictLabels(img.Image image, {int topK = 5}) async {
    // 1) 이미지 벡터 얻고 L2 정규화
    final imgVec = await predictFeatures(image);
    final norm = sqrt(imgVec.map((e) => e * e).reduce((a, b) => a + b));
    final normedImg = imgVec.map((e) => e / norm).toList();

    // 2) 텍스트 임베딩과 cosine similarity 계산
    final sims = <MapEntry<String, double>>[];
    _textEmbeddings.forEach((tag, txtVec) {
      // txtVec 역시 L2 정규화 되어 있다고 가정. 아니라면 정규화 필요.
      double dot = 0.0;
      for (int i = 0; i < txtVec.length && i < normedImg.length; i++) {
        dot += normedImg[i] * txtVec[i];
      }
      sims.add(MapEntry(tag, dot));
    });

    // 3) 내림차순 정렬 후 topK
    sims.sort((a, b) => b.value.compareTo(a.value));
    return sims.take(topK).map((e) => e.key).toList();
  }
}
