import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ClipService {
  ClipService._();
  static final ClipService _inst = ClipService._();
  factory ClipService() => _inst;

  late final Interpreter _interpreter;
  late final Map<String, List<double>> _textEmb; // 이미 L2 정규화
  bool _ready = false;

  // ── 모델만 따로 로드 ──
  Future<void> loadModel() async {
    _interpreter =
        await Interpreter.fromAsset('assets/ai/mobileclip_image_nhwc.tflite');
    final inShape = _interpreter.getInputTensor(0).shape;
    final outShape = _interpreter.getOutputTensor(0).shape;
    assert(inShape[1] == 224 && outShape.last == 512,
        'CLIP 모델 입·출력 크기가 예상과 다릅니다.');
  }

  // ── 전체 초기화 ──
  Future<void> init() async {
    if (_ready) return;

    // 1) 모델 로드
    await loadModel();

    // 2) 텍스트 임베딩 로드
    final js = await rootBundle.loadString('assets/labels/tb512.json');
    final raw = json.decode(js) as Map<String, dynamic>;
    _textEmb = raw.map((tag, v) {
      final vec = (v as List).cast<num>().map((e) => e.toDouble()).toList();
      final n = sqrt(vec.fold(0.0, (s, e) => s + e * e));
      return MapEntry(tag, vec.map((e) => e / n).toList());
    });

    _ready = true;
    print('✅ ClipService ready (labels: ${_textEmb.length})');
  }

  // ── 이미지 224×224 → 512차 벡터 ──
  Future<List<double>> _encode(img.Image image) async {
    if (!_ready) await init();
    final resized = img.copyResize(image, width: 224, height: 224);

    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(
          224,
          (x) {
            final p = resized.getPixel(x, y);
            return [
              img.getRed(p) / 255.0,
              img.getGreen(p) / 255.0,
              img.getBlue(p) / 255.0,
            ];
          },
        ),
      ),
    );

    final output = List.generate(1, (_) => List.filled(512, 0.0));
    _interpreter.run(input, output);

    print('[CLIP] raw first5: '
        '${output[0].take(5).map((e) => e.toStringAsFixed(4)).toList()}');
    return output[0];
  }

  // ── Top-K 라벨 예측 ──
  Future<List<String>> predictLabels(
    img.Image image, {
    int topK = 3,
  }) async {
    final vec = await _encode(image);

    final n = sqrt(vec.fold(0.0, (s, e) => s + e * e));
    if (n == 0) {
      print('[CLIP] ⚠️ 이미지 벡터 norm==0 (전처리·모델 확인 필요)');
      return [];
    }
    print('[CLIP] img norm = ${n.toStringAsFixed(5)}');

    final imgNorm = vec.map((e) => e / n).toList();

    final sims = <MapEntry<String, double>>[];
    _textEmb.forEach((tag, txt) {
      double dot = 0;
      for (int i = 0; i < 512; i++) {
        dot += imgNorm[i] * txt[i];
      }
      sims.add(MapEntry(tag, dot));
    });
    sims.sort((a, b) => b.value.compareTo(a.value));

    print('[CLIP] dot TOP10');
    for (var e in sims.take(10)) {
      print('  • ${e.key.padRight(15)}  ${e.value.toStringAsFixed(4)}');
    }

    return sims.take(topK).map((e) => e.key).toList();
  }

  // ── 이미지 벡터 직접 얻기 ──
  Future<List<double>> predictFeatures(img.Image image) => _encode(image);
}
