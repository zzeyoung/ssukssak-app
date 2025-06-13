import 'dart:typed_data';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

import '../../ai/score_service.dart';
import '../../ai/yolo_service.dart';
import '../../models/photo_metadata.dart';
import '../../ai/blur_service.dart';

class MetadataDebugScreen extends StatefulWidget {
  const MetadataDebugScreen({Key? key}) : super(key: key);

  @override
  State<MetadataDebugScreen> createState() => _MetadataDebugScreenState();
}

class _MetadataDebugScreenState extends State<MetadataDebugScreen> {
  List<AssetEntity> _photos = [];
  Map<String, AnalyzedPhotoData> _analyzedDataMap = {};
  bool _aiReady = false;

  @override
  void initState() {
    super.initState();
    _loadAiModels();
    _loadPhotos();
  }

  Future<void> _loadAiModels() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    setState(() => _aiReady = true);
  }

  Future<void> _loadPhotos() async {
    final photoStatus = await Permission.photos.request();
    final locStatus = await Permission.accessMediaLocation.request();
    if (!photoStatus.isGranted || !locStatus.isGranted) {
      await openAppSettings();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;

    final recent = albums.first;
    final assets = await recent.getAssetListPaged(page: 0, size: 30);

    setState(() => _photos = assets);
  }

  double _convertToDegree(List values) {
    final deg = values[0].numerator / values[0].denominator;
    final min = values[1].numerator / values[1].denominator;
    final sec = values[2].numerator / values[2].denominator;
    return deg + (min / 60.0) + (sec / 3600.0);
  }

  Future<void> _analyzeAndShow(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return;

    final filename = file.uri.pathSegments.last;
    final resolution = '${asset.width}×${asset.height}';
    final date = asset.createDateTime;
    final fileSize = await file.length();
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);

    double? lat, lng;
    try {
      final tags = await readExifFromBytes(bytes);
      if (tags.containsKey('GPS GPSLatitude') &&
          tags.containsKey('GPS GPSLongitude')) {
        lat = _convertToDegree(tags['GPS GPSLatitude']!.values.toList());
        lng = _convertToDegree(tags['GPS GPSLongitude']!.values.toList());
        if (tags['GPS GPSLatitudeRef']?.printable == 'S') lat = -lat!;
        if (tags['GPS GPSLongitudeRef']?.printable == 'W') lng = -lng!;
      }
    } catch (e) {
      log('❌ EXIF 파싱 실패: $e');
    }

    // --- AI 분석 ---
    double? score;
    List<String>? yoloTags;
    bool isBlur = false;

    try {
      isBlur = await BlurService.isBlur(file);
    } catch (e) {
      log('❌ BlurService 실패: $e');
    }

    if (_aiReady && decoded != null) {
      try {
        score = await ScoreService().predictScore(decoded);
        yoloTags = await YoloService().detectLabels(decoded);
      } catch (e) {
        log('❌ AI 분석 실패: $e');
      }
    }

    final result = AnalyzedPhotoData(
      photoId: filename,
      latitude: lat,
      longitude: lng,
      size: fileSize,
      analysisTags: {
        'ai_score': score,
        'blurry': isBlur ? 1 : 0,
      },
      screenshot: filename.toLowerCase().contains('screenshot') ? 1 : 0,
      screenshotTags: const [],
      imageTags: yoloTags,
      groupId: null,
      sourceApp: null,
    );

    _analyzedDataMap[filename] = result;

    // --- UI 출력 ---
    final aiInfo = '''
⭐️ 예쁨 점수: ${score?.toStringAsFixed(2) ?? '-'}
💧 흐릿함: ${isBlur ? '흐림' : '선명'}
📎 YOLO 태그: ${yoloTags?.join(', ') ?? '-'}
📱 스크린샷: ${result.screenshot == 1 ? '예' : '아님'}
📏 크기: ${(fileSize / 1000000).toStringAsFixed(2)} MB
''';

    final locationText =
        (lat != null && lng != null) ? '$lat, $lng' : '위치 정보 없음';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('📷 $filename'),
        content: SingleChildScrollView(
          child: Text(
            '📅 날짜: $date\n📐 해상도: $resolution\n🗺 위치: $locationText\n\n$aiInfo',
          ),
        ),
        actions: [
          if (lat != null && lng != null)
            TextButton(
              onPressed: () async {
                final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: const Text('지도에서 보기'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildThumbnail(AssetEntity asset) async {
    final data =
        await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    return data != null
        ? Image.memory(data, fit: BoxFit.cover)
        : const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📸 로컬 분석 결과 확인')),
      body: _photos.isEmpty
          ? const Center(child: Text("불러올 사진이 없습니다."))
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
                  future: _buildThumbnail(asset),
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return GestureDetector(
                      onTap: () => _analyzeAndShow(asset),
                      child: snap.data ?? const SizedBox(),
                    );
                  },
                );
              },
            ),
    );
  }
}
