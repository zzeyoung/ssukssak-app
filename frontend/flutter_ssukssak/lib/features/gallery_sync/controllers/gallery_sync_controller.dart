// 📂 lib/features/gallery_sync/controllers/gallery_sync_controller.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img_pkg; // ← alias
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:exif/exif.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/photo_metadata.dart';
import '../../../services/gallery_uploader.dart';
import '../../../services/auth_service.dart';

// AI & dedupe
import '../../../../ai/score_service.dart';
import '../../../../ai/blur_service.dart';
import '../../../../ai/yolo_service.dart';
import '../../../../ai/gallery_dedupe_service.dart';

class GallerySyncController extends ChangeNotifier {
  static const _endpoint = 'http://172.31.81.175:3000';

  /* 상태 ------------------------------------------------------------------ */
  bool get scanning => _scanning;
  bool get uploading => _uploading;
  double get scanProgress => _scanProgress;
  double get uploadProgress => _uploadProgress;
  Map<String, List<Map<String, dynamic>>> get folders => _folderMap();

  bool _aiReady = false;
  bool _scanning = false, _uploading = false;
  double _scanProgress = 0, _uploadProgress = 0;

  final List<AnalyzedPhotoData> _newPhotos = [];
  final List<Map<String, dynamic>> _analyzed = [];

  /* 부트스트랩 ------------------------------------------------------------ */
  Future<void> bootstrap() async {
    await _loadAi();
    await autoSync();
  }

  /* AI 모델 --------------------------------------------------------------- */
  Future<void> _loadAi() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    _aiReady = true;
  }

  /* 자동 동기화 ----------------------------------------------------------- */
  Future<void> autoSync() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('user_id') ??
        (await AuthService.fetchMe())?['userId'] as String?;
    if (uid == null) return;
    await prefs.setString('user_id', uid);

    final existing = await _fetchExistingIds(uid);
    await _scanGallery(skipIds: existing);
    await _uploadPhotos(uid);
  }

  Future<Set<String>> _fetchExistingIds(String uid) async {
    try {
      final res =
          await http.get(Uri.parse('$_endpoint/photos/metadata?userId=$uid'));
      if (res.statusCode == 200) {
        final items = (jsonDecode(res.body)['items'] as List? ?? []);
        return {for (final e in items) (e['photoId'] as String).toLowerCase()};
      }
    } catch (e) {
      log('fetchExistingIds error: $e');
    }
    return {};
  }

  /* 갤러리 스캔 & AI 분석 -------------------------------------------------- */
  Future<void> _scanGallery({required Set<String> skipIds}) async {
    if (_scanning) return;
    _scanning = true;
    _scanProgress = 0;
    notifyListeners();

    _newPhotos.clear();
    _analyzed.clear();
    final lowerSkip = skipIds;

    if (!await Permission.photos.request().isGranted) {
      _scanning = false;
      notifyListeners();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) {
      _scanning = false;
      notifyListeners();
      return;
    }

    final path = albums.first;
    final total = await path.assetCountAsync;
    const pageSz = 100;
    final assets = <AssetEntity>[];

    for (var p = 0; p * pageSz < total; p++) {
      assets.addAll(await path.getAssetListPaged(page: p, size: pageSz));
    }

    final newAssets = [
      for (final a in assets)
        if (!lowerSkip.contains(
            (await a.originFile)?.uri.pathSegments.last.toLowerCase() ?? ''))
          a
    ];

    final dedupe = GalleryDedupeService(maxConcurrent: 4);
    final group = await dedupe.analyzeGallery();
    dedupe.dispose();

    var done = 0;
    for (final a in assets) {
      final file = await a.originFile;
      if (file == null) continue;
      final name = file.uri.pathSegments.last;

      if (lowerSkip.contains(name.toLowerCase())) {
        _analyzed.add(
            {'photoId': file.path, 'analysisTags': {}, 'groupId': group[a.id]});
      } else {
        final meta = await _analyzeAsset(a, group[a.id]);
        if (meta != null) {
          _analyzed.add(meta.toJson());
          _newPhotos.add(meta);
        }
      }
      _scanProgress = ++done / assets.length;
      notifyListeners();
    }

    _scanning = false;
    notifyListeners();
  }

  Future<AnalyzedPhotoData?> _analyzeAsset(AssetEntity a, String? gid) async {
    final file = await a.originFile;
    if (file == null) return null;
    final name = file.uri.pathSegments.last;

    /* 위치 ---------------------------------------------------------------- */
    double? lat, lng;
    try {
      final ll = await a.latlngAsync();
      lat = ll.latitude;
      lng = ll.longitude;
    } catch (_) {
      try {
        final exif = await readExifFromBytes(await file.readAsBytes());
        lat = _degIfExist(exif, 'GPS GPSLatitude', 'GPS GPSLatitudeRef');
        lng = _degIfExist(exif, 'GPS GPSLongitude', 'GPS GPSLongitudeRef');
      } catch (_) {}
    }

    /* AI ------------------------------------------------------------------ */
    final blurry = await BlurService.isBlur(file);
    double? score;
    List<String>? yolo;
    if (_aiReady) {
      final imgRaw = img_pkg.decodeImage(await file.readAsBytes());
      if (imgRaw != null) {
        score = await ScoreService().predictScore(imgRaw);
        yolo = await YoloService().detectLabels(imgRaw);
      }
    }

    return AnalyzedPhotoData(
      photoId: name,
      latitude: lat,
      longitude: lng,
      size: await file.length(),
      analysisTags: {'ai_score': score, 'blurry': blurry ? 1 : 0},
      screenshot: name.toLowerCase().contains('screenshot') ? 1 : 0,
      imageTags: yolo,
      groupId: gid,
      sourceApp: _srcApp(name),
      dateTaken: a.createDateTime,
    );
  }

  /* 업로드 ---------------------------------------------------------------- */
  Future<void> _uploadPhotos(String uid) async {
    if (_uploading || _newPhotos.isEmpty) return;
    _uploading = true;
    _uploadProgress = 0;
    notifyListeners();

    final up = GalleryUploader(endpoint: _endpoint, userId: uid);
    await up.uploadAll(_newPhotos, onProgress: (p) {
      _uploadProgress = p;
      notifyListeners();
    });

    _uploading = false;
    notifyListeners();
  }

  /* 폴더 분류 ------------------------------------------------------------- */
  Map<String, List<Map<String, dynamic>>> _folderMap() {
    double n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is Map && v.containsKey('N')) return double.tryParse(v['N']) ?? 0;
      return 0;
    }

    final m = {
      '중복된 사진': <Map<String, dynamic>>[],
      '유사한 사진': <Map<String, dynamic>>[],
      '흐릿한 사진': <Map<String, dynamic>>[],
      '점수기반 사진': <Map<String, dynamic>>[],
    };

    for (final p in _analyzed) {
      final gid = p['groupId'] as String?;
      final tags = p['analysisTags'] ?? {};

      if (gid?.startsWith('d') ?? false) {
        m['중복된 사진']!.add(p);
      } else if (gid?.startsWith('s') ?? false) {
        m['유사한 사진']!.add(p);
      } else if (n(tags['blurry']) == 1) {
        m['흐릿한 사진']!.add(p);
      } else if (n(tags['ai_score']) >= 0.85) {
        m['점수기반 사진']!.add(p);
      }
    }
    return m;
  }

  /* 유틸 ------------------------------------------------------------------ */
  double? _degIfExist(Map<String, IfdTag> t, String key, String refKey) {
    if (!t.containsKey(key)) return null;
    final v = t[key]!.values.toList();
    final r = t[refKey]?.printable;
    final d = v[0].numerator / v[0].denominator;
    final m = v[1].numerator / v[1].denominator;
    final s = v[2].numerator / v[2].denominator;
    var dec = d + m / 60 + s / 3600;
    if (r == 'S' || r == 'W') dec = -dec;
    return dec;
  }

  String? _srcApp(String fn) {
    if (!fn.toLowerCase().contains('screenshot')) return null;
    final us = fn.lastIndexOf('_'), dot = fn.lastIndexOf('.');
    return (us < 0 || dot < 0 || us >= dot) ? null : fn.substring(us + 1, dot);
  }
}
