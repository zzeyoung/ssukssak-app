// lib/screens/home_screen.dart
// 홈 화면: 로그인 완료 → 전체 갤러리 동기화 + AI 분석 + 업로드

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:exif/exif.dart';

import '../models/photo_metadata.dart';
import '../services/gallery_uploader.dart';
import '../services/auth_service.dart';

import '../../ai/score_service.dart';
import '../../ai/blur_service.dart';
import '../../ai/yolo_service.dart';
import '../../ai/gallery_dedupe_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _endpoint = 'http://172.31.81.175:3000';

  final List<AnalyzedPhotoData> _photos = []; // 신규 업로드 대상
  bool _scanning = false, _uploading = false;
  double _scanProgress = 0, _uploadProgress = 0;
  bool _aiReady = false;

  @override
  void initState() {
    super.initState();
    _loadAi().then((_) => _autoSync());
  }

  Future<void> _loadAi() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    setState(() => _aiReady = true);
  }

  Future<void> _autoSync() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('user_id') ??
        (await AuthService.fetchMe())?['userId'] as String?;
    if (uid == null) return;
    await prefs.setString('user_id', uid);

    final existingIds = await _fetchExistingIds(uid);
    await _scanGallery(skipIds: existingIds);
    await _uploadPhotos(uid);
  }

  Future<Set<String>> _fetchExistingIds(String uid) async {
    try {
      final res =
          await http.get(Uri.parse('$_endpoint/photos/metadata?userId=$uid'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>? ?? [];
        return items
            .cast<Map<String, dynamic>>()
            .map((e) => e['photoId'].toString().toLowerCase())
            .toSet();
      }
    } catch (e) {
      log('fetchExistingIds error: $e');
    }
    return {};
  }

  Future<void> _scanGallery({required Set<String> skipIds}) async {
    if (_scanning) return;
    _photos.clear();
    final lowerSkip = skipIds.map((e) => e.toLowerCase()).toSet();

    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });

    final perm = await Permission.photos.request();
    if (!perm.isGranted) {
      setState(() => _scanning = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) {
      setState(() => _scanning = false);
      return;
    }
    final path = albums.first;
    final allAssets =
        await path.getAssetListRange(start: 0, end: await path.assetCountAsync);

    // 신규 사진만 필터링
    final newAssets = <AssetEntity>[];
    for (final asset in allAssets) {
      final file = await asset.originFile;
      if (file == null) continue;
      final name = file.uri.pathSegments.last;
      if (!lowerSkip.contains(name.toLowerCase())) {
        newAssets.add(asset);
      }
    }

    // 중복/유사 그룹 계산 (신규 기준)
    final dedupeSvc = GalleryDedupeService(maxConcurrent: 4);
    final groupMap = await dedupeSvc.analyzeGallery(
      similarThreshold: 0.65,
    );
    dedupeSvc.dispose();

    int processed = 0;
    for (final asset in allAssets) {
      final file = await asset.originFile;
      if (file == null) continue;
      final name = file.uri.pathSegments.last;

      if (lowerSkip.contains(name.toLowerCase())) {
        processed++;
        setState(() => _scanProgress = processed / allAssets.length);
        continue;
      }

      final meta = await _analyzeAsset(asset, groupMap[asset.id]);
      if (meta != null) _photos.add(meta);

      processed++;
      setState(() => _scanProgress = processed / allAssets.length);
    }

    setState(() => _scanning = false);
  }

  Future<AnalyzedPhotoData?> _analyzeAsset(
      AssetEntity asset, String? groupId) async {
    final file = await asset.originFile;
    if (file == null) return null;
    final name = file.uri.pathSegments.last;
    final size = await file.length();

    double? lat, lng;
    try {
      final ll = await asset.latlngAsync();
      lat = ll.latitude;
      lng = ll.longitude;
    } catch (_) {
      try {
        final tags = await readExifFromBytes(await file.readAsBytes());
        if (tags.containsKey('GPS GPSLatitude') &&
            tags.containsKey('GPS GPSLongitude')) {
          lat = _deg(tags['GPS GPSLatitude']!.values.toList(),
              tags['GPS GPSLatitudeRef']?.printable);
          lng = _deg(tags['GPS GPSLongitude']!.values.toList(),
              tags['GPS GPSLongitudeRef']?.printable);
        }
      } catch (_) {}
    }

    bool blur = await BlurService.isBlur(file);
    double? score;
    List<String>? labels;
    if (_aiReady) {
      final raw = img.decodeImage(await file.readAsBytes());
      if (raw != null) {
        score = await ScoreService().predictScore(raw);
        labels = await YoloService().detectLabels(raw);
      }
    }

    return AnalyzedPhotoData(
      photoId: name,
      latitude: lat,
      longitude: lng,
      size: size,
      analysisTags: {'ai_score': score, 'blurry': blur ? 1 : 0},
      screenshot: name.toLowerCase().contains('screenshot') ? 1 : 0,
      imageTags: labels,
      groupId: groupId,
      sourceApp: _extractSourceApp(name),
      dateTaken: asset.createDateTime,
    );
  }

  String? _extractSourceApp(String fn) {
    if (!fn.toLowerCase().contains('screenshot')) return null;
    final us = fn.lastIndexOf('_');
    final dot = fn.lastIndexOf('.');
    if (us < 0 || dot < 0 || us >= dot) return null;
    return fn.substring(us + 1, dot);
  }

  double _deg(List values, String? ref) {
    final d = values[0].numerator / values[0].denominator;
    final m = values[1].numerator / values[1].denominator;
    final s = values[2].numerator / values[2].denominator;
    var dec = d + m / 60 + s / 3600;
    if (ref == 'S' || ref == 'W') dec = -dec;
    return dec;
  }

  Future<void> _uploadPhotos(String uid) async {
    if (_uploading || _photos.isEmpty) return;
    final uploader = GalleryUploader(endpoint: _endpoint, userId: uid);

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      await uploader.uploadAll(_photos,
          onProgress: (p) => setState(() => _uploadProgress = p));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('✅ 업로드 완료')));
      }
    } catch (e) {
      log('upload error: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Column(
        children: [
          if (_scanning) LinearProgressIndicator(value: _scanProgress),
          if (_uploading) LinearProgressIndicator(value: _uploadProgress),
          Expanded(
            child: Center(child: Text('신규 업로드: ${_photos.length}장')),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '수동 스캔',
        onPressed: () => _scanGallery(skipIds: {}),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
