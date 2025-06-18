// screens/metadata_debug_screen.dart
// 그룹 ID는 접두어(d/s) 포함 하나의 필드로만 사용.

import 'dart:developer';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exif/exif.dart';

import '../../ai/score_service.dart';
import '../../ai/yolo_service.dart';
import '../../ai/blur_service.dart';
import '../../ai/gallery_dedupe_service.dart';
import '../../models/photo_metadata.dart';

class MetadataDebugScreen extends StatefulWidget {
  const MetadataDebugScreen({Key? key}) : super(key: key);

  @override
  State<MetadataDebugScreen> createState() => _MetadataDebugScreenState();
}

class _MetadataDebugScreenState extends State<MetadataDebugScreen> {
  final List<AssetEntity> _photos = [];
  final Map<String, AnalyzedPhotoData> _analyzed = {};
  Map<String, String> _groupMap = {}; // asset.id → d1 / s3
  double _dupProgress = 0.0;
  bool _aiReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadAi();
    await _loadPhotos();
    _loadGroups(); // 비동기
  }

  Future<void> _loadAi() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    setState(() => _aiReady = true);
  }

  Future<void> _loadPhotos() async {
    // 사진 및 위치메타 권한 요청
    final statuses = await [
      Permission.photos,
      Permission.accessMediaLocation,
    ].request();
    if (statuses[Permission.photos] != PermissionStatus.granted ||
        statuses[Permission.accessMediaLocation] != PermissionStatus.granted) {
      log('⚠️ 권한 거부됨: $statuses');
      await openAppSettings();
      return;
    }

    // 사진 로드
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final assets = await albums.first.getAssetListPaged(page: 0, size: 30);
    setState(() => _photos.addAll(assets));
  }

  Future<void> _loadGroups() async {
    final svc = GalleryDedupeService(maxConcurrent: 4);
    svc.progressStream.listen((v) => setState(() => _dupProgress = v));
    _groupMap = await svc.analyzeGallery();
    svc.dispose();
    setState(() {});
  }

  // EXIF degree helper
  double _deg(List values) {
    if (values.length < 3) return double.nan;
    final d = values[0].numerator / values[0].denominator;
    final m = values[1].numerator / values[1].denominator;
    final s = values[2].numerator / values[2].denominator;
    return d + m / 60 + s / 3600;
  }

  Future<void> _analyzeAndShow(AssetEntity asset) async {
    log('🔔 _analyzeAndShow 시작: ${asset.id}');

    final file = await asset.originFile;
    if (file == null) return;

    final name = file.uri.pathSegments.last;
    final size = await file.length();
    final reso = '${asset.width}×${asset.height}';
    final date = asset.createDateTime;

    // 위치 메타데이터 우선
    double? lat, lng;
    try {
      log('1️⃣ latlngAsync 시도 전');
      final latLng = await asset.latlngAsync();
      log('2️⃣ latlngAsync 결과: $latLng');
      lat = latLng.latitude;
      lng = latLng.longitude;
      log('3️⃣ lat, lng 할당: $lat, $lng');
    } catch (e) {
      log('❌ latlngAsync 실패: $e');
    }

    // 보조 EXIF 파싱
    if (lat == null || lng == null) {
      try {
        final tags = await readExifFromBytes(await file.readAsBytes());
        if (tags.containsKey('GPS GPSLatitude') &&
            tags.containsKey('GPS GPSLongitude')) {
          log('🔍 EXIF GPS raw: lat=${tags['GPS GPSLatitude']!.values}, lng=${tags['GPS GPSLongitude']!.values}');
          final rawLat = _deg(tags['GPS GPSLatitude']!.values.toList());
          final rawLng = _deg(tags['GPS GPSLongitude']!.values.toList());
          if (rawLat.isFinite && rawLng.isFinite) {
            lat =
                tags['GPS GPSLatitudeRef']?.printable == 'S' ? -rawLat : rawLat;
            lng = tags['GPS GPSLongitudeRef']?.printable == 'W'
                ? -rawLng
                : rawLng;
            log('→ EXIF 최종 lat=$lat, lng=$lng');
          }
        }
      } catch (e) {
        log('EXIF 파싱 실패: $e');
      }
    }

    // AI 분석
    double? score;
    List<String>? yolo;
    bool isBlur = false;
    try {
      isBlur = await BlurService.isBlur(file);
    } catch (_) {}
    if (_aiReady) {
      final im = img.decodeImage(await file.readAsBytes());
      if (im != null) {
        try {
          score = await ScoreService().predictScore(im);
          yolo = await YoloService().detectLabels(im);
        } catch (e) {
          log('AI 분석 실패: $e');
        }
      }
    }

    // 그룹
    final gid = _groupMap[asset.id];

    // 결과 저장
    _analyzed[name] = AnalyzedPhotoData(
      photoId: name,
      latitude: lat,
      longitude: lng,
      size: size,
      analysisTags: {'ai_score': score, 'blurry': isBlur ? 1 : 0},
      screenshot: name.toLowerCase().contains('screenshot') ? 1 : 0,
      imageTags: yolo,
      groupId: gid,
    );

    // 다이얼로그 표시
    final hasLoc = lat != null && lng != null;
    final locTxt = hasLoc
        ? '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}'
        : '위치 정보 없음';
    final grpTxt = gid != null ? '🔗 그룹: $gid' : '🔗 그룹 없음';
    final aiTxt = '''
⭐️ 예쁨 점수: ${score?.toStringAsFixed(2) ?? '-'}
💧 흐릿함: ${isBlur ? '흐림' : '선명'}
📎 YOLO 태그: ${yolo?.join(', ') ?? '-'}
📱 스크린샷: ${name.toLowerCase().contains('screenshot') ? '예' : '아님'}
$grpTxt
📏 크기: ${(size / 1e6).toStringAsFixed(2)} MB
''';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('📷 $name'),
        content: SingleChildScrollView(
          child: Text('📅 날짜: $date\n📐 해상도: $reso\n🗺 위치: $locTxt\n\n$aiTxt'),
        ),
        actions: [
          if (hasLoc)
            TextButton(
              onPressed: () async {
                final uri = Uri.parse('geo:${lat},${lng}?q=${lat},${lng}');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              child: const Text('지도에서 보기'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('닫기'))
        ],
      ),
    );
  }

  Future<Widget> _thumb(AssetEntity a) async {
    final d = await a.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    return d != null ? Image.memory(d, fit: BoxFit.cover) : const SizedBox();
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(title: const Text('📸 로컬 분석 결과 확인')),
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
            Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(value: _dupProgress)),
        ],
      ),
    );
  }
}
