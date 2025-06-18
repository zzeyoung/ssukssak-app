// lib/ai/gallery_dedupe_service.dart
// -----------------------------------------------------------
// 완전 중복(dN): aHash 해밍 거리 <= dupMaxDist
// 유사(sN): pHash·dHash·히스토그램 3개 지표 중 2개 이상 통과하면 edge
//           → 연결 컴포넌트(transitive closure)를 한 그룹으로 취급
// 날짜별(YYYY-MM-DD)로만 그룹핑
// -----------------------------------------------------------

import 'dart:async';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:pool/pool.dart';

class GalleryDedupeService {
  GalleryDedupeService({
    this.hashSize = 8,
    this.maxConcurrent = 4,
  });

  final int hashSize;
  final int maxConcurrent;

  final int histBins = 16;
  final double histThreshold = 120.0;

  final _progress = StreamController<double>.broadcast();
  Stream<double> get progressStream => _progress.stream;
  void dispose() => _progress.close();

  // ───────────────────────────────────────────────────────────
  // public
  // ───────────────────────────────────────────────────────────
  Future<Map<String, String>> analyzeGallery({
    double similarThreshold = 0.88,
    int dupMaxDist = 0,
  }) async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) return {};
    final allAssets = await _collectAssets(paths.first);

    // 날짜별 묶기
    final byDate = <String, List<AssetEntity>>{};
    for (final a in allAssets) {
      final d = a.createDateTime;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';
      byDate.putIfAbsent(key, () => []).add(a);
    }

    final result = <String, String>{};
    int idx = 0;

    for (final entry in byDate.entries) {
      idx++;
      _progress.add(idx / byDate.length * 0.9);

      final dateKey = entry.key;
      final assets = entry.value;
      if (assets.length < 2) continue;

      final hashes = await _computeHashes(assets);

      // 1) 완전 중복
      final dups = _duplicates(hashes, dupMaxDist);
      for (final g in dups) {
        final id = 'd_${dateKey}_${g.first.aHash.toRadixString(16)}';
        for (final e in g) result[e.asset.id] = id;
      }

      // 2) 유사 (Connected Component)
      final maxDist = (hashSize * hashSize * (1 - similarThreshold)).round();
      final sims = _similarsConnected(hashes, dups, maxDist);
      for (final g in sims) {
        final id = 's_${dateKey}_${g.first.asset.id}';
        for (final e in g) result[e.asset.id] = id;
      }
    }

    _progress.add(1);
    return result;
  }

  // ───────────────────────────────────────────────────────────
  // helpers
  // ───────────────────────────────────────────────────────────
  Future<List<AssetEntity>> _collectAssets(AssetPathEntity root) async {
    const pageSize = 500;
    final list = <AssetEntity>[];
    for (int p = 0;; p++) {
      final chunk = await root.getAssetListPaged(page: p, size: pageSize);
      if (chunk.isEmpty) break;
      list.addAll(chunk);
    }
    return list;
  }

  Future<List<_HashEntry>> _computeHashes(List<AssetEntity> assets) async {
    final pool = Pool(maxConcurrent);
    final futures = assets.map((a) => pool.withResource(() async {
          final bytes =
              await a.thumbnailDataWithSize(const ThumbnailSize(200, 200));
          if (bytes == null) return null;
          final im = img.decodeImage(bytes);
          if (im == null) return null;
          return _HashEntry(
            asset: a,
            aHash: _aHash(im),
            dHash: _dHash(im),
            pHashes: _rotPHashes(im),
            hist: _histogram(im, histBins),
          );
        }));
    final list = (await Future.wait(futures)).whereType<_HashEntry>().toList();
    await pool.close();
    return list;
  }

  // ────────── 그룹핑 ──────────
  List<List<_HashEntry>> _duplicates(List<_HashEntry> all, int maxDist) {
    final res = <List<_HashEntry>>[];
    final visited = <_HashEntry>{};

    for (int i = 0; i < all.length; i++) {
      final a = all[i];
      if (visited.contains(a)) continue;

      final g = <_HashEntry>[a];
      for (int j = i + 1; j < all.length; j++) {
        final b = all[j];
        if (visited.contains(b)) continue;
        if (_ham(a.aHash, b.aHash) <= maxDist) {
          g.add(b);
          visited.add(b);
        }
      }
      if (g.length > 1) res.add(g);
      visited.addAll(g);
    }
    return res;
  }

  /// 전이적(Connected Component) 유사 그룹
  List<List<_HashEntry>> _similarsConnected(
      List<_HashEntry> all, List<List<_HashEntry>> dup, int maxDist) {
    final excluded = dup.expand((g) => g).toSet();
    final nodes = all.where((e) => !excluded.contains(e)).toList();
    if (nodes.length < 2) return [];

    // 1) adjacency list
    final adj = <_HashEntry, List<_HashEntry>>{};
    bool similar(_HashEntry a, _HashEntry b) {
      final p = _minHam(a.pHashes, b.pHashes) <= maxDist;
      final d = _ham(a.dHash, b.dHash) <= maxDist;
      final h = _chi2(a.hist, b.hist) <= histThreshold;
      return (p ? 1 : 0) + (d ? 1 : 0) + (h ? 1 : 0) >= 2;
    }

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final a = nodes[i], b = nodes[j];
        if (similar(a, b)) {
          adj.putIfAbsent(a, () => []).add(b);
          adj.putIfAbsent(b, () => []).add(a);
        }
      }
    }

    // 2) DFS/BFS to get connected components
    final groups = <List<_HashEntry>>[];
    final visited = <_HashEntry>{};

    for (final v in nodes) {
      if (visited.contains(v)) continue;
      final g = <_HashEntry>[];
      final stack = <_HashEntry>[v];
      visited.add(v);
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        g.add(cur);
        for (final nb in adj[cur] ?? const []) {
          if (!visited.contains(nb)) {
            visited.add(nb);
            stack.add(nb);
          }
        }
      }
      if (g.length > 1) groups.add(g);
    }
    return groups;
  }

  // ────────── 해시/통계 계산 ──────────
  BigInt _aHash(img.Image src) {
    final gray = img.grayscale(src);
    final small = img.copyResize(gray,
        width: hashSize,
        height: hashSize,
        interpolation: img.Interpolation.average);
    int sum = 0;
    final px = List<int>.generate(hashSize * hashSize, (i) {
      final v = small.getPixel(i % hashSize, i ~/ hashSize) & 0xFF;
      sum += v;
      return v;
    });
    final avg = sum ~/ px.length;
    BigInt bits = BigInt.zero;
    for (int i = 0; i < px.length; i++) {
      if (px[i] > avg) bits |= (BigInt.one << i);
    }
    return bits;
  }

  BigInt _dHash(img.Image src) {
    final gray = img.grayscale(src);
    final w = hashSize + 1;
    final small = img.copyResize(gray,
        width: w, height: hashSize, interpolation: img.Interpolation.average);
    BigInt bits = BigInt.zero;
    for (int y = 0; y < hashSize; y++) {
      for (int x = 0; x < hashSize; x++) {
        final l = small.getPixel(x, y) & 0xFF;
        final r = small.getPixel(x + 1, y) & 0xFF;
        if (l > r) bits |= (BigInt.one << (y * hashSize + x));
      }
    }
    return bits;
  }

  List<BigInt> _rotPHashes(img.Image src) =>
      [0, 90, 180, 270].map((a) => _pHash(img.copyRotate(src, a))).toList();

  BigInt _pHash(img.Image src) {
    const N = 32;
    final gray = img.grayscale(src);
    final resized = img.copyResize(gray,
        width: N, height: N, interpolation: img.Interpolation.average);

    final F = List.generate(N, (_) => List<double>.filled(N, 0));
    for (int u = 0; u < N; u++) {
      for (int v = 0; v < N; v++) {
        double sum = 0;
        for (int i = 0; i < N; i++) {
          for (int j = 0; j < N; j++) {
            final f = resized.getPixel(j, i) & 0xFF;
            sum += f *
                math.cos(((2 * i + 1) * u * math.pi) / (2 * N)) *
                math.cos(((2 * j + 1) * v * math.pi) / (2 * N));
          }
        }
        final cu = u == 0 ? 1 / math.sqrt(2) : 1;
        final cv = v == 0 ? 1 / math.sqrt(2) : 1;
        F[u][v] = 0.25 * cu * cv * sum;
      }
    }

    final coeffs = <double>[];
    for (int y = 0; y < hashSize; y++) {
      for (int x = 0; x < hashSize; x++) {
        if (y == 0 && x == 0) continue;
        coeffs.add(F[y][x]);
      }
    }
    final median = (List<double>.from(coeffs)..sort())[coeffs.length ~/ 2];

    BigInt bits = BigInt.zero;
    for (int i = 0; i < coeffs.length; i++) {
      if (coeffs[i] > median) bits |= (BigInt.one << i);
    }
    return bits;
  }

  List<int> _histogram(img.Image src, int bins) {
    final gray = img.grayscale(src);
    final hist = List<int>.filled(bins, 0);
    final step = 256 / bins;
    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        final v = gray.getPixel(x, y) & 0xFF;
        hist[(v / step).floor().clamp(0, bins - 1)]++;
      }
    }
    return hist;
  }

  double _chi2(List<int> a, List<int> b) {
    double s = 0;
    for (int i = 0; i < a.length; i++) {
      final x = a[i].toDouble(), y = b[i].toDouble();
      if (x + y > 0) s += ((x - y) * (x - y)) / (x + y);
    }
    return s;
  }

  int _ham(BigInt a, BigInt b) {
    var d = a ^ b;
    int c = 0;
    while (d > BigInt.zero) {
      c += (d & BigInt.one) == BigInt.one ? 1 : 0;
      d >>= 1;
    }
    return c;
  }

  int _minHam(List<BigInt> a, List<BigInt> b) {
    int best = 1 << 30;
    for (final x in a) {
      for (final y in b) {
        final d = _ham(x, y);
        if (d < best) best = d;
      }
    }
    return best;
  }
}

class _HashEntry {
  final AssetEntity asset;
  final BigInt aHash;
  final BigInt dHash;
  final List<BigInt> pHashes;
  final List<int> hist;

  _HashEntry({
    required this.asset,
    required this.aHash,
    required this.dHash,
    required this.pHashes,
    required this.hist,
  });

  @override
  bool operator ==(Object other) =>
      other is _HashEntry && other.asset.id == asset.id;
  @override
  int get hashCode => asset.id.hashCode;
}
