import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/material.dart';

class YoloResult {
  final double x;
  final double y;
  final double w;
  final double h;
  final double score;
  final int classId;

  YoloResult(this.x, this.y, this.w, this.h, this.score, this.classId);
}

class YoloService {
  // ---------- 싱글턴 ----------
  static final YoloService _instance = YoloService._internal();
  factory YoloService() => _instance;
  YoloService._internal();

  // ---------- 필드 ----------
  late Interpreter _interpreter;
  final int inputSize = 640;
  final double threshold = 0.05; // ← 0.05로 낮춰서 먼저 확인
  List<String> _labelList = [];

  // ---------- 모델 & 라벨 로드 ----------
  Future<void> loadModel() async {
    // CPU 전용 (delegate 미사용)
    _interpreter = await Interpreter.fromAsset(
      'assets/ai/yolo11n_float32.tflite',
      options: InterpreterOptions(), // 기본값 = CPU
    );

    try {
      final labels = await rootBundle.loadString('assets/labels/coco.txt');
      _labelList = labels
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      debugPrint('✅ 라벨 로딩 완료 (${_labelList.length}개)');
    } catch (e) {
      debugPrint('❌ 라벨 파일 로딩 실패: $e');
    }

    // 텐서 정보 로그
    debugPrint('▶︎ Indput  : ${_interpreter.getInputTensor(0).shape} '
        '${_interpreter.getInputTensor(0).type}');
    debugPrint('▶︎ Output : ${_interpreter.getOutputTensor(0).shape} '
        '${_interpreter.getOutputTensor(0).type}');
  }

  // ---------- 다중 라벨 감지 ----------
  Future<List<String>> detectLabels(img.Image image) async {
    final inputTensor = _preprocess(image);
    final output = List.filled(1 * 300 * 6, 0.0).reshape([1, 300, 6]);

    _interpreter.run(inputTensor, output);

    final Set<String> results = {};
    for (int i = 0; i < output[0].length; i++) {
      final det = output[0][i];
      final score = det[4];
      if (score > threshold) {
        final classId = det[5].round();
        final label = (classId >= 0 && classId < _labelList.length)
            ? _labelList[classId]
            : 'Unknown';
        debugPrint(
            '🔍 [$i] classId=$classId, score=${score.toStringAsFixed(2)}, label=$label');
        results.add(label);
      }
    }

    // maxScore 계산 시 타입 충돌 방지
    final maxScore =
        output[0].map((d) => d[4] as double).reduce((a, b) => a > b ? a : b);
    debugPrint('🧮 maxScore = ${maxScore.toStringAsFixed(3)}');

    return results.toList();
  }

  // ---------- 최고 신뢰도 결과 ----------
  Future<String?> detectTopResult(img.Image image) async {
    final inputTensor = _preprocess(image);
    final output = List.filled(1 * 300 * 6, 0.0).reshape([1, 300, 6]);

    _interpreter.run(inputTensor, output);

    List<double> bestDet = [];
    double maxScore = -1.0;

    for (final det in output[0]) {
      if (det[4] > maxScore) {
        maxScore = det[4];
        bestDet = det;
      }
    }

    if (bestDet.isNotEmpty && maxScore > threshold) {
      final classId = bestDet[5].round();
      final label = (classId >= 0 && classId < _labelList.length)
          ? _labelList[classId]
          : 'Unknown';

      return 'Class: $label ($classId) | '
          'Score: ${bestDet[4].toStringAsFixed(2)} | '
          'Box: ${bestDet.sublist(0, 4).map((v) => v.toStringAsFixed(1)).join(', ')}';
    }
    return null;
  }

  // ---------- Letterbox 전처리 (BGR·NHWC·float32) ----------
  List<List<List<List<double>>>> _preprocess(img.Image src) {
    // 0) EXIF 방향 보정
    final img.Image oriented = img.bakeOrientation(src);

    // 1) 비율 유지 축소
    final double scale =
        min(inputSize / oriented.width, inputSize / oriented.height);
    final int newW = (oriented.width * scale).round();
    final int newH = (oriented.height * scale).round();

    final img.Image resized = img.copyResize(
      oriented,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.linear,
    );

    // 2) 검은 Letterbox 캔버스 생성
    final img.Image canvas = img.Image.rgb(inputSize, inputSize);
    canvas.fill(0); // (0,0,0)

    final int dx = ((inputSize - newW) / 2).round();
    final int dy = ((inputSize - newH) / 2).round();
    img.copyInto(canvas, resized, dstX: dx, dstY: dy);

    // 3) NHWC float32, BGR 순서
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final p = canvas.getPixel(x, y);
            return [
              img.getBlue(p) / 255.0, // B
              img.getGreen(p) / 255.0, // G
              img.getRed(p) / 255.0, // R
            ];
          },
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );

    return input;
  }
}
