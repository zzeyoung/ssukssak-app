// lib/ai/gallery_dedupe_service.dart
// -----------------------------------------------------------
// • 완전 중복(dN): aHash 동일
// • 유사(sN): pHash, dHash, 또는 색상 히스토그램 χ² 거리 기준
// • 같은 날짜별(YYYY-MM-DD)로만 그룹핑
// -----------------------------------------------------------

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:pool/pool.dart';

class GalleryDedupeService {
  GalleryDedupeService({
    this.hashSize = 8,
    this.maxConcurrent = 4,
  });

  /// pHash 해상도 (기본 8×8)
  final int hashSize;

  /// 동시 처리할 최대 스레드 수
  final int maxConcurrent;

  /// 색상 히스토그램 bin 수
  final int histBins = 16;

  /// 색상 히스토그램 χ² 거리 임계값
  /// 작을수록 더 엄격, 클수록 더 느슨
  final double histThreshold = 200.0;

  // 진행률 스트림 (0.0 ~ 1.0)
  final _progress = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progress.stream;
  void dispose() => _progress.close();

  /// 같은 날짜별로만 해시 계산 → 중복/유사 판단
  Future<Map<String, String>> analyzeGallery({
    double similarThreshold = 0.6, // 0.0 ~ 1.0, 낮을수록 더 느슨
    int dupMaxDist = 2, // aHash 완전 중복 최대 허밍 거리
  }) async {
    // 1) 전체 이미지 수집
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return {};
    final allAssets = await _collectAssets(paths.first);

    // 2) 날짜별(YYYY-MM-DD)로 묶기
    final byDate = <String, List<AssetEntity>>{};
    for (final asset in allAssets) {
      final d = asset.createDateTime;
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      byDate.putIfAbsent(key, () => []).add(asset);
    }

    final result = <String, String>{};
    int dIndex = 1, sIndex = 1;
    final totalDates = byDate.length;
    int dateCount = 0;

    // 3) 날짜별로만 해시 계산 및 그룹핑
    for (final assets in byDate.values) {
      dateCount++;
      _progress.add((dateCount / totalDates) * 0.9);

      if (assets.length < 2) continue;
      final entries = await _computeHashes(assets, (_) {});

      // 3-1) 완전 중복 (aHash)
      final dups = _duplicates(entries, dupMaxDist);
      for (final group in dups) {
        final id = 'd${dIndex++}';
        for (final e in group) result[e.asset.id] = id;
      }

      // 3-2) 유사 (pHash OR dHash OR histogram)
      final maxDist = (hashSize * hashSize * (1 - similarThreshold)).round();
      final sims = _similars(entries, dups, maxDist);
      for (final group in sims) {
        final id = 's${sIndex++}';
        for (final e in group) result[e.asset.id] = id;
      }
    }

    _progress.add(1.0);
    return result;
  }

  /// 전체 AssetEntity 수집 (페이징)
  Future<List<AssetEntity>> _collectAssets(AssetPathEntity root) async {
    const pageSize = 500;
    final list = <AssetEntity>[];
    for (int page = 0;; page++) {
      final chunk = await root.getAssetListPaged(page: page, size: pageSize);
      if (chunk.isEmpty) break;
      list.addAll(chunk);
    }
    return list;
  }

  /// aHash, dHash, pHashes, histogram 계산
  Future<List<_HashEntry>> _computeHashes(
      List<AssetEntity> assets, void Function(int) onDone) async {
    final pool = Pool(maxConcurrent);
    int done = 0;

    final tasks = assets.map((asset) => pool.withResource(() async {
          try {
            final bytes = await asset
                .thumbnailDataWithSize(const ThumbnailSize(200, 200));
            if (bytes == null) return null;
            final im = img.decodeImage(bytes);
            if (im == null) return null;

            return _HashEntry(
              asset: asset,
              aHash: _aHash(im),
              dHash: _dHash(im),
              pHashes: _rotationInvariantPHashes(im),
              histogram: _histogram(im, histBins),
            );
          } finally {
            onDone(++done);
          }
        }));

    final list = (await Future.wait(tasks)).whereType<_HashEntry>().toList();
    await pool.close();
    return list;
  }

  // ── 그룹핑 ──

  /// aHash 기반 완전 중복 그룹
  List<List<_HashEntry>> _duplicates(List<_HashEntry> all, int dupMaxDist) {
    final buckets = <BigInt, List<_HashEntry>>{};
    for (final e in all) {
      // exact match 만 묶음 (dupMaxDist는 무시)
      buckets.putIfAbsent(e.aHash, () => []).add(e);
    }
    return buckets.values.where((g) => g.length > 1).toList();
  }

  /// pHash, dHash, histogram 기준 느슨한 유사 그룹
  List<List<_HashEntry>> _similars(
      List<_HashEntry> all, List<List<_HashEntry>> dupGroups, int maxDist) {
    final dupSet = dupGroups.expand((g) => g).toSet();
    final left = all.where((e) => !dupSet.contains(e)).toList();
    final visited = <_HashEntry>{};
    final res = <List<_HashEntry>>[];

    for (int i = 0; i < left.length; i++) {
      final a = left[i];
      if (visited.contains(a)) continue;

      final group = <_HashEntry>[a];
      for (int j = i + 1; j < left.length; j++) {
        final b = left[j];
        if (visited.contains(b)) continue;

        final pDist = _minHamming(a.pHashes, b.pHashes);
        final dDist = _ham(a.dHash, b.dHash);
        final hDist = _chiSquare(a.histogram, b.histogram);

        if (pDist <= maxDist || dDist <= maxDist || hDist <= histThreshold) {
          group.add(b);
          visited.add(b);
        }
      }
      if (group.length > 1) res.add(group);
      visited.addAll(group);
    }
    return res;
  }

  // ── 해시 함수 ──

  /// average hash
  BigInt _aHash(img.Image src) {
    final gray = img.grayscale(src);
    final small = img.copyResize(gray,
        width: hashSize,
        height: hashSize,
        interpolation: img.Interpolation.average);

    int sum = 0;
    final pixels = List<int>.generate(hashSize * hashSize, (i) {
      final p = small.getPixel(i % hashSize, i ~/ hashSize) & 0xFF;
      sum += p;
      return p;
    });

    final avg = sum ~/ pixels.length;
    BigInt bits = BigInt.zero;
    for (int i = 0; i < pixels.length; i++) {
      if (pixels[i] > avg) bits |= (BigInt.one << i);
    }
    return bits;
  }

  /// difference hash (horizontal)
  BigInt _dHash(img.Image src) {
    final gray = img.grayscale(src);
    final w = hashSize + 1, h = hashSize;
    final small = img.copyResize(gray,
        width: w, height: h, interpolation: img.Interpolation.average);

    BigInt bits = BigInt.zero;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < hashSize; x++) {
        final left = small.getPixel(x, y) & 0xFF;
        final right = small.getPixel(x + 1, y) & 0xFF;
        if (left > right) bits |= (BigInt.one << (y * hashSize + x));
      }
    }
    return bits;
  }

  /// rotation-invariant pHashes (0°,90°,180°,270°)
  List<BigInt> _rotationInvariantPHashes(img.Image src) {
    const angles = [0, 90, 180, 270];
    return angles.map((a) {
      final rot = img.copyRotate(src, a);
      return _pHash(rot);
    }).toList();
  }

  /// perceptual hash (DCT 기반)
  BigInt _pHash(img.Image src) {
    const N = 32;
    final gray = img.grayscale(src);
    final resized = img.copyResize(gray,
        width: N, height: N, interpolation: img.Interpolation.average);

    // 2D 배열로 변환
    final f = List.generate(
        N,
        (y) => List<double>.generate(
            N, (x) => (resized.getPixel(x, y) & 0xFF).toDouble()));

    // DCT 변환
    final F = List.generate(N, (_) => List<double>.filled(N, 0.0));
    for (int u = 0; u < N; u++) {
      for (int v = 0; v < N; v++) {
        double sum = 0;
        for (int i = 0; i < N; i++) {
          for (int j = 0; j < N; j++) {
            sum += f[i][j] *
                math.cos(((2 * i + 1) * u * math.pi) / (2 * N)) *
                math.cos(((2 * j + 1) * v * math.pi) / (2 * N));
          }
        }
        final cu = u == 0 ? 1 / math.sqrt(2) : 1.0;
        final cv = v == 0 ? 1 / math.sqrt(2) : 1.0;
        F[u][v] = 0.25 * cu * cv * sum;
      }
    }

    // 상위 hashSize×hashSize 영역에서 평균 기준 비트화
    final vals = <double>[];
    for (int y = 0; y < hashSize; y++) {
      for (int x = 0; x < hashSize; x++) {
        if (y == 0 && x == 0) continue;
        vals.add(F[y][x]);
      }
    }
    final sorted = List<double>.from(vals)..sort();
    final med = sorted[sorted.length ~/ 2];

    BigInt bits = BigInt.zero;
    for (int i = 0; i < vals.length; i++) {
      if (vals[i] > med) bits |= (BigInt.one << i);
    }
    return bits;
  }

  // ── 히스토그램 함수 ──

  /// 그레이스케일 히스토그램
  List<int> _histogram(img.Image src, int bins) {
    final gray = img.grayscale(src);
    final hist = List<int>.filled(bins, 0);
    final step = 256 / bins;
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y) & 0xFF;
        final idx = (v / step).floor().clamp(0, bins - 1);
        hist[idx]++;
      }
    }
    return hist;
  }

  /// χ² 거리 계산
  double _chiSquare(List<int> h1, List<int> h2) {
    var sum = 0.0;
    for (int i = 0; i < h1.length; i++) {
      final a = h1[i].toDouble(), b = h2[i].toDouble();
      if (a + b > 0) sum += ((a - b) * (a - b)) / (a + b);
    }
    return sum;
  }

  // ── 공통 유틸 ──

  /// 해밍 거리 계산
  int _ham(BigInt a, BigInt b) {
    BigInt d = a ^ b;
    int c = 0;
    while (d > BigInt.zero) {
      if ((d & BigInt.one) == BigInt.one) c++;
      d >>= 1;
    }
    return c;
  }

  /// 리스트 간 최소 해밍 거리
  int _minHamming(List<BigInt> a, List<BigInt> b) {
    int minDist = 1 << 30;
    for (final ah in a) {
      for (final bh in b) {
        final d = _ham(ah, bh);
        if (d < minDist) minDist = d;
      }
    }
    return minDist;
  }
}

/// 하나의 이미지 해시 & 히스토그램 엔트리
class _HashEntry {
  final AssetEntity asset;
  final BigInt aHash;
  final BigInt dHash;
  final List<BigInt> pHashes;
  final List<int> histogram;

  _HashEntry({
    required this.asset,
    required this.aHash,
    required this.dHash,
    required this.pHashes,
    required this.histogram,
  });

  @override
  bool operator ==(Object other) =>
      other is _HashEntry && other.asset.id == asset.id;
  @override
  int get hashCode => asset.id.hashCode;
}
