import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// UI 스레드를 막지 않으면서 Blur 여부만 판단하는 서비스
class BlurService {
  /// true  → 흐림,  false → 선명
  static Future<bool> isBlur(
    File file, {
    double threshold = 150.0, // 컷오프 분산값
    int sampleSize = 512, // 다운샘플 가로 크기
  }) {
    return compute<_Req, bool>(
      _isBlurIsolate,
      _Req(file.path, threshold, sampleSize),
    );
  }

  /* ---------- Isolate ---------- */

  static Future<bool> _isBlurIsolate(_Req r) async {
    final bytes = await File(r.path).readAsBytes();
    final score = _varianceOfLaplacian(bytes, r.sampleSize);
    return score < r.threshold;
  }

  /* ---------- 내부 헬퍼 ---------- */

  static double _varianceOfLaplacian(Uint8List bytes, int sampleSize) {
    final img.Image? src = img.decodeImage(bytes); // ← 수정: allowInvalid 제거
    if (src == null) throw Exception('이미지 디코딩 실패');

    // 1) 다운샘플
    final img.Image resized =
        img.copyResize(src, width: min(sampleSize, src.width));

    // 2) Grayscale → Laplacian
    final img.Image gray = img.grayscale(resized);
    final img.Image lap = img.convolution(gray, _kernel, div: 1, offset: 0);

    // 3) 정수 누적 방식 분산 계산
    int sum = 0, sumSq = 0;
    for (final p in lap.data) {
      final v = img.getRed(p); // 0-255
      sum += v;
      sumSq += v * v;
    }
    final n = lap.data.length; // ← 수정: data.length 사용
    final mean = sum / n;
    return (sumSq / n) - mean * mean;
  }

  static const _kernel = [0, 1, 0, 1, -4, 1, 0, 1, 0];
}

/* ---------- DTO ---------- */
class _Req {
  const _Req(this.path, this.threshold, this.sampleSize);
  final String path;
  final double threshold;
  final int sampleSize;
}
