/// lib/screens/home_screen.dart
/// 홈 화면: 갤러리 스캔 → /photo/gallery 업로드
/// • PK = USER#<userId>, SK = PHOTO#<photoId>
/// • API: POST /photo/gallery { userId, photos:[...AnalyzedPhotoData] }

import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final List<AnalyzedPhotoData> _photos = [];
  double _scanProgress = 0, _uploadProgress = 0;
  bool _scanning = false, _uploading = false;
  bool _aiReady = false;

  @override
  void initState() {
    super.initState();
    _loadAi();
  }

  Future<void> _loadAi() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    setState(() => _aiReady = true);
  }

  Future<void> _scanGallery() async {
    if (_scanning) return;
    _photos.clear();
    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });

    // 권한 요청
    final statuses = await [
      Permission.photos,
      Permission.accessMediaLocation,
    ].request();
    if (!statuses[Permission.photos]!.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('📷 권한 필요')));
      }
      setState(() => _scanning = false);
      return;
    }

    // 최근 30장 로드
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) {
      setState(() => _scanning = false);
      return;
    }
    final assets = await albums.first.getAssetListPaged(page: 0, size: 30);

    // 중복/유사 그룹 분석
    final dedupe = GalleryDedupeService(maxConcurrent: 4);
    final groupMap = await dedupe.analyzeGallery(similarThreshold: 0.65);
    dedupe.dispose();

    // 개별 사진 분석
    for (var i = 0; i < assets.length; i++) {
      final data = await _analyzeAsset(assets[i], groupMap[assets[i].id]);
      if (data != null) _photos.add(data);
      setState(() => _scanProgress = (i + 1) / assets.length);
    }

    setState(() => _scanning = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스캔 완료: ${_photos.length}장')),
      );
    }
  }

  Future<AnalyzedPhotoData?> _analyzeAsset(
      AssetEntity asset, String? groupId) async {
    final file = await asset.originFile;
    if (file == null) return null;

    final name = file.uri.pathSegments.last;
    final size = await file.length();

    // 위치 메타
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
          lat = _deg(tags['GPS GPSLatitude']!.values.toList(),
              tags['GPS GPSLatitudeRef']?.printable);
          lng = _deg(tags['GPS GPSLongitude']!.values.toList(),
              tags['GPS GPSLongitudeRef']?.printable);
        }
      } catch (_) {}
    }

    // 블러·YOLO·스코어
    bool blur = false;
    double? score;
    List<String>? yolo;
    try {
      blur = await BlurService.isBlur(file);
    } catch (_) {}
    if (_aiReady) {
      final image = img.decodeImage(await file.readAsBytes());
      if (image != null) {
        try {
          score = await ScoreService().predictScore(image);
          yolo = await YoloService().detectLabels(image);
        } catch (e) {
          log('AI 분석 실패: $e');
        }
      }
    }

    return AnalyzedPhotoData(
      photoId: name,
      latitude: lat,
      longitude: lng,
      size: size,
      analysisTags: {'ai_score': score, 'blurry': blur ? 1 : 0},
      screenshot: name.toLowerCase().contains('screenshot') ? 1 : 0,
      screenshotTags: null,
      imageTags: yolo,
      groupId: groupId,
      sourceApp: _extractSourceApp(name),
      dateTaken: asset.createDateTime,
    );
  }

  String? _extractSourceApp(String filename) {
    final fn = filename.toLowerCase();
    if (!fn.contains('screenshot')) return null;
    final us = filename.lastIndexOf('_');
    final dot = filename.lastIndexOf('.');
    if (us < 0 || dot < 0 || us >= dot) return null;
    final app = filename.substring(us + 1, dot);
    return app.isNotEmpty ? app : null;
  }

  double? _deg(List values, String? ref) {
    if (values.length < 3) return null;
    final d = values[0].numerator / values[0].denominator;
    final m = values[1].numerator / values[1].denominator;
    final s = values[2].numerator / values[2].denominator;
    final dec = d + m / 60 + s / 3600;
    return (ref == 'S' || ref == 'W') ? -dec : dec;
  }

  Future<void> _upload() async {
    if (_uploading) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('먼저 스캔을 실행하세요')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('user_id');
    if (uid == null) {
      final profile = await AuthService.fetchMe();
      uid = profile?['userId'] as String?;
      if (uid != null) {
        await prefs.setString('user_id', uid);
      }
    }
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('로그인 정보 없음')));
      return;
    }

    final uploader = GalleryUploader(
      endpoint: 'http://172.31.81.175:3000', // PC IP로 변경
      userId: uid,
    );

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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ 업로드 실패: $e')));
      }
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
            child: Center(child: Text('스캔된 사진: ${_photos.length}장')),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            icon: const Icon(Icons.photo_library),
            label: const Text('갤러리 스캔'),
            onPressed: _scanning ? null : _scanGallery,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'upload',
            icon: const Icon(Icons.cloud_upload),
            label: const Text('업로드'),
            onPressed: (_uploading || _photos.isEmpty) ? null : _upload,
          ),
        ],
      ),
    );
  }
}
