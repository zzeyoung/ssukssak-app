// lib/ai/yolo_service.dart

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class YoloResult {
  final double x;
  final double y;
  final double w;
  final double h;
  final int classId;
  final double confidence;
  final String label;

  YoloResult({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.classId,
    required this.confidence,
    required this.label,
  });
}

class YoloService {
  // 싱글턴으로 바꾸고 싶으면 아래 패턴 추가
  static final YoloService _instance = YoloService._internal();
  factory YoloService() => _instance;
  YoloService._internal();

  Interpreter? _interpreter;
  bool _isLoaded = false;
  Future<void>? _loadingFuture;

  // COCO 클래스 레이블 리스트 (필요에 따라 수정)
  final List<String> labels = [
    'person',
    'bicycle',
    'car',
    'motorbike',
    'aeroplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'sofa',
    'pottedplant',
    'bed',
    'diningtable',
    'toilet',
    'tvmonitor',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush'
  ];

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
      // pubspec.yaml에 'assets/ai/yolo11_float32.tflite' 로 등록했다면:
      _interpreter =
          await Interpreter.fromAsset('assets/ai/yolo11_float32.tflite');
      _isLoaded = true;
      print('✅ YOLO 모델 로드 완료');
      // 입력/출력 텐서 정보 로그
      final inputT = _interpreter!.getInputTensor(0);
      final outputT = _interpreter!.getOutputTensor(0);
      print('📐 YOLO input shape: ${inputT.shape}, type: ${inputT.type}');
      print('📐 YOLO output shape: ${outputT.shape}, type: ${outputT.type}');
    } catch (e) {
      print('❌ YOLO 모델 로딩 실패: $e');
      _loadingFuture = null;
      _isLoaded = false;
      _interpreter = null;
      rethrow;
    }
  }

  bool get isLoaded => _isLoaded;

  /// detectLabels: 단순 라벨 목록 반환
  Future<List<String>> detectLabels(img.Image image,
      {double threshold = 0.25}) async {
    final objs = await detectObjects(image, threshold: threshold);
    final tags = objs.map((r) => r.label).toSet().toList();
    print('🎯 YOLO 탐지 라벨: $tags');
    return tags;
  }

  /// detectObjects: 후처리(NMS 등) 포함
  Future<List<YoloResult>> detectObjects(img.Image image,
      {double threshold = 0.25}) async {
    if (!_isLoaded) {
      await loadModel();
    }
    if (_interpreter == null) {
      throw Exception('YoloService: Interpreter가 초기화되지 않았습니다.');
    }

    // 입력 이미지 리사이즈: 모델 입력 크기에 맞게 설정
    const int inputSize = 640; // 예: 640x640 YOLO 모델
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
            // image 패키지 버전 문제 시 getRed 등 함수가 없다면 비트 연산으로 대체:
            int r = (pixel >> 16) & 0xFF;
            int g = (pixel >> 8) & 0xFF;
            int b = pixel & 0xFF;
            return [r / 255.0, g / 255.0, b / 255.0];
          },
        ),
      ),
    );

    // 출력 텐서 형태 파악
    final shape = _interpreter!.getOutputTensor(0).shape;
    // shape 예: [1, 8400, 85] 등, 모델마다 다름
    final batch = shape[0];
    final numBoxes = shape[1];
    final channels = shape[2];
    // 출력 버퍼 생성
    var output = List.generate(
      batch,
      (_) => List.generate(
        numBoxes,
        (_) => List<double>.filled(channels, 0.0),
      ),
    );

    // 모델 실행
    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('❌ YOLO run 오류: $e');
      rethrow;
    }

    // 후처리: objectness, class score, NMS 등
    final List<YoloResult> results = [];
    final b0 = output[0]; // [numBoxes][channels]
    for (int i = 0; i < numBoxes; i++) {
      final cx = b0[i][0];
      final cy = b0[i][1];
      final w = b0[i][2];
      final h = b0[i][3];
      final objectness = b0[i][4];
      if (objectness <= 0) continue;
      // class scores 중 최대값 찾기
      double maxScore = 0.0;
      int classId = -1;
      for (int c = 0; c < labels.length && 5 + c < channels; c++) {
        final score = b0[i][5 + c];
        if (score > maxScore) {
          maxScore = score;
          classId = c;
        }
      }
      if (classId < 0) continue;
      final confidence = objectness * maxScore;
      if (confidence < threshold) continue;

      final label = (classId < labels.length) ? labels[classId] : 'unknown';
      results.add(YoloResult(
        x: cx,
        y: cy,
        w: w,
        h: h,
        classId: classId,
        confidence: confidence,
        label: label,
      ));
    }

    return results;
  }
}
