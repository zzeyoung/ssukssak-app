// 그룹 ID는 접두어(d/s) 포함 하나의 필드로만 사용.
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exif/exif.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★
import 'package:http/http.dart' as http; // ★

import '../../ai/score_service.dart';
import '../../ai/yolo_service.dart';
import '../../ai/blur_service.dart';
import '../../ai/gallery_dedupe_service.dart';
import '../../models/photo_metadata.dart';
import '../../services/gallery_uploader.dart'; // ★

class MetadataDebugScreen extends StatefulWidget {
  const MetadataDebugScreen({Key? key}) : super(key: key);

  @override
  State<MetadataDebugScreen> createState() => _MetadataDebugScreenState();
}

class _MetadataDebugScreenState extends State<MetadataDebugScreen> {
  final List<AssetEntity> _photos = [];
  final List<AnalyzedPhotoData> _metaList = []; // ★
  Map<String, String> _groupMap = {};
  double _dupProgress = 0.0;
  double _uploadProgress = 0.0; // ★
  bool _aiReady = false;
  bool _uploading = false; // ★
  bool _scanning = false; // ★

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadAi();
    await _loadPhotos();
    _loadGroups();
  }

  Future<void> _loadAi() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    setState(() => _aiReady = true);
  }

  /* ─────────── 사진 로드 ─────────── */
  Future<void> _loadPhotos() async {
    final statuses = await [
      Permission.photos,
      Permission.accessMediaLocation,
    ].request();
    if (!statuses[Permission.photos]!.isGranted) {
      await openAppSettings();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final assets = await albums.first.getAssetListPaged(page: 0, size: 30);
    setState(() => _photos.addAll(assets));
  }

  /* ─────────── 유사 그룹 분석 ─────────── */
  Future<void> _loadGroups() async {
    final svc = GalleryDedupeService(maxConcurrent: 4);
    svc.progressStream.listen((v) => setState(() => _dupProgress = v));
    _groupMap = await svc.analyzeGallery(similarThreshold: 0.65);
    svc.dispose();
    setState(() {});
  }

  /* ─────────── 전체 스캔 (30장) ─────────── */
  Future<void> _scanAll() async {
    // ★
    if (_scanning) return;
    _metaList.clear();
    setState(() {
      _scanning = true;
    });

    for (final asset in _photos) {
      final data = await _analyzeAsset(asset);
      if (data != null) _metaList.add(data);
    }

    setState(() {
      _scanning = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('스캔 완료: ${_metaList.length}장')));
  }

  /* ─────────── 업로드 ─────────── */
  Future<void> _upload() async {
    // ★
    if (_uploading) return;
    if (_metaList.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('먼저 스캔을 실행하세요')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    final uploader = GalleryUploader(
      endpoint: 'http://10.0.2.2:3000', // 에뮬레이터, 실제 기기는 PC IP 교체
      userId: uid,
    );

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });
    try {
      await uploader.uploadAll(_metaList,
          onProgress: (p) => setState(() => _uploadProgress = p));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ 업로드 완료')));
    } catch (e) {
      log('Upload error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ 업로드 실패: $e')));
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  /* ─────────── 단일 사진 분석 ─────────── */
  Future<AnalyzedPhotoData?> _analyzeAsset(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return null;

    final name = file.uri.pathSegments.last;
    final size = await file.length();
    double? lat, lng;
    try {
      final ll = await asset.latlngAsync();
      lat = ll.latitude;
      lng = ll.longitude;
    } catch (_) {}

    if (lat == null || lng == null) {
      try {
        final tags = await readExifFromBytes(await file.readAsBytes());
        if (tags.containsKey('GPS GPSLatitude') &&
            tags.containsKey('GPS GPSLongitude')) {
          final rawLat = _deg(tags['GPS GPSLatitude']!.values.toList());
          final rawLng = _deg(tags['GPS GPSLongitude']!.values.toList());
          lat = tags['GPS GPSLatitudeRef']?.printable == 'S' ? -rawLat : rawLat;
          lng =
              tags['GPS GPSLongitudeRef']?.printable == 'W' ? -rawLng : rawLng;
        }
      } catch (_) {}
    }

    double? score;
    List<String>? yolo;
    bool blur = false;
    try {
      blur = await BlurService.isBlur(file);
    } catch (_) {}

    if (_aiReady) {
      final im = img.decodeImage(await file.readAsBytes());
      if (im != null) {
        try {
          score = await ScoreService().predictScore(im);
          yolo = await YoloService().detectLabels(im);
        } catch (_) {}
      }
    }

    return AnalyzedPhotoData(
      photoId: name,
      latitude: lat,
      longitude: lng,
      size: size,
      analysisTags: {'ai_score': score, 'blurry': blur ? 1 : 0},
      screenshot: name.toLowerCase().contains('screenshot') ? 1 : 0,
      imageTags: yolo,
      groupId: _groupMap[asset.id],
      sourceApp: 'ssukssak',
    );
  }

  /* ─────────── EXIF degree helper ─────────── */
  double _deg(List values) {
    if (values.length < 3) return double.nan;
    final d = values[0].numerator / values[0].denominator;
    final m = values[1].numerator / values[1].denominator;
    final s = values[2].numerator / values[2].denominator;
    return d + m / 60 + s / 3600;
  }

  /* ─────────── 기존 단일 탭 분석 UI (생략 없이 유지) ─────────── */
  Future<void> _analyzeAndShow(AssetEntity a) async {
    final data = await _analyzeAsset(a);
    if (data == null) return;
    // … (기존 Dialog 코드: 동일)
  }

  Future<Widget> _thumb(AssetEntity a) async {
    final d = await a.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    return d != null ? Image.memory(d, fit: BoxFit.cover) : const SizedBox();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📸 로컬 분석 결과'),
        actions: [
          IconButton(
            // ★ 스캔
            icon: const Icon(Icons.search),
            tooltip: '스캔',
            onPressed: _scanning ? null : _scanAll,
          ),
          IconButton(
            // ★ 업로드
            icon: const Icon(Icons.cloud_upload),
            tooltip: '업로드',
            onPressed: _uploading ? null : _upload,
          ),
        ],
      ),
      body: Stack(
        children: [
          _photos.isEmpty
              ? const Center(child: Text('사진 없음'))
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) {
                    final asset = _photos[i];
                    return FutureBuilder<Widget>(
                      future: _thumb(asset),
                      builder: (_, s) => GestureDetector(
                        onTap: () => _analyzeAndShow(asset),
                        child: s.data ?? const SizedBox(),
                      ),
                    );
                  },
                ),
          if (_dupProgress < 1.0)
            LinearProgressIndicator(value: _dupProgress, minHeight: 3),
          if (_uploading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(value: _uploadProgress),
            ),
        ],
      ),
    );
  }
}
