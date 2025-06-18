// lib/screens/gallery_home_screen.dart
// -----------------------------------------------------------
// 📷 갤러리 동기화 + 폴더 UI 통합 화면  (배경 흰색, 휴지통 아이콘, 썸네일 정사각)
// -----------------------------------------------------------

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

import '../globals.dart';
import '../models/photo_metadata.dart';
import '../services/gallery_uploader.dart';
import '../services/auth_service.dart';

import '../../ai/score_service.dart';
import '../../ai/blur_service.dart';
import '../../ai/yolo_service.dart';
import '../../ai/gallery_dedupe_service.dart';

import 'photo_list_screen.dart';
import 'trash_screen.dart'; // 🆕 휴지통 화면
import 'remind_screen.dart';
import 'memory_screen.dart';
import 'environment_report_screen.dart';
import 'screenshot_tab.dart';

class GallerySyncHomeScreen extends StatefulWidget {
  const GallerySyncHomeScreen({Key? key}) : super(key: key);

  @override
  State<GallerySyncHomeScreen> createState() => _GallerySyncHomeScreenState();
}

class _GallerySyncHomeScreenState extends State<GallerySyncHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _endpoint = 'http://172.31.81.175:3000';

  /* ── 진행 상태 ── */
  bool _aiReady = false;
  bool _scanning = false;
  bool _uploading = false;
  double _scanProgress = 0;
  double _uploadProgress = 0;

  /* ── 분석/업로드 결과 ── */
  final List<AnalyzedPhotoData> _newPhotos = [];
  final List<Map<String, dynamic>> _analyzedPhotos = [];

  /* ── 탭 컨트롤 ── */
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // 🏷️ 폴더별 지정 썸네일(에셋) 경로
  final Map<String, String> _folderThumbnailMap = {
    '중복된 사진': 'assets/images/logo.png',
    '유사한 사진': 'assets/images/logo.png',
    '흐릿한 사진': 'assets/images/logo.png',
    '점수기반 사진': 'assets/images/logo.png',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  /* ── 부트스트랩 ── */
  Future<void> _bootstrap() async {
    await _loadAi();
    await _autoSync();
  }

  /* ── AI 모델 로드 ── */
  Future<void> _loadAi() async {
    await ScoreService().loadModel();
    await YoloService().loadModel();
    setState(() => _aiReady = true);
  }

  /* ── 자동 동기화 ── */
  Future<void> _autoSync() async {
    final prefs = await SharedPreferences.getInstance();
    String? uid = prefs.getString('user_id') ??
        (await AuthService.fetchMe())?['userId'] as String?;
    if (uid == null) return;
    await prefs.setString('user_id', uid);

    final existing = await _fetchExistingIds(uid);
    await _scanGallery(skipIds: existing);
    await _uploadPhotos(uid);
    if (mounted) setState(() {});
  }

  Future<Set<String>> _fetchExistingIds(String uid) async {
    try {
      final res =
          await http.get(Uri.parse('$_endpoint/photos/metadata?userId=$uid'));
      if (res.statusCode == 200) {
        final items = (jsonDecode(res.body)['items'] as List<dynamic>? ?? []);
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

  /* ── 갤러리 스캔 & 분석 ── */
  Future<void> _scanGallery({required Set<String> skipIds}) async {
    if (_scanning) return;
    _newPhotos.clear();
    _analyzedPhotos.clear();
    final lowerSkip = skipIds.map((s) => s.toLowerCase()).toSet();

    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });

    if (!await Permission.photos.request().isGranted) {
      setState(() => _scanning = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) {
      setState(() => _scanning = false);
      return;
    }
    final path = albums.first;
    final total = await path.assetCountAsync;
    const pageSize = 100;
    final allAssets = <AssetEntity>[];

    for (int p = 0; p * pageSize < total; p++) {
      allAssets.addAll(await path.getAssetListPaged(page: p, size: pageSize));
    }

    final dedupe = GalleryDedupeService(maxConcurrent: 4);
    final groupMap = await dedupe.analyzeGallery(similarThreshold: 0.65);
    dedupe.dispose();

    int processed = 0;
    for (final a in allAssets) {
      final f = await a.originFile;
      if (f == null) continue;
      final name = f.uri.pathSegments.last;

      if (lowerSkip.contains(name.toLowerCase())) {
        _analyzedPhotos.add({
          'photoId': f.path,
          'analysisTags': {},
          'groupId': groupMap[a.id],
        });
      } else {
        final meta = await _analyzeAsset(a, groupMap[a.id]);
        if (meta != null) {
          _analyzedPhotos.add(meta.toJson());
          _newPhotos.add(meta);
        }
      }
      processed++;
      setState(() => _scanProgress = processed / allAssets.length);
    }

    setState(() => _scanning = false);
  }

  Future<AnalyzedPhotoData?> _analyzeAsset(
      AssetEntity a, String? groupId) async {
    final file = await a.originFile;
    if (file == null) return null;
    final name = file.uri.pathSegments.last;
    final size = await file.length();

    double? lat, lng;
    try {
      final ll = await a.latlngAsync();
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

    final isScreenshot = name.toLowerCase().contains('screenshot');

    bool? blur;
    double? score;
    List<String>? labels;
    if (!isScreenshot && _aiReady) {
      blur = await BlurService.isBlur(file);
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
      analysisTags: isScreenshot
          ? {}
          : {
              'ai_score': score,
              'blurry': (blur ?? false) ? 1 : 0,
            },
      screenshot: isScreenshot ? 1 : 0,
      imageTags: isScreenshot ? null : labels,
      groupId: isScreenshot ? null : groupId,
      sourceApp: _extractSourceApp(name),
      dateTaken: a.createDateTime,
    );
  }

  /* ── 업로드 ── */
  Future<void> _uploadPhotos(String uid) async {
    if (_uploading || _newPhotos.isEmpty) return;
    setState(() => _uploading = true);
    final uploader = GalleryUploader(endpoint: _endpoint, userId: uid);
    await uploader.uploadAll(_newPhotos,
        onProgress: (p) => setState(() => _uploadProgress = p));
    setState(() => _uploading = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ 업로드 완료')));
    }
  }

  /* ── analysisTags 값 → double ── */
  double _num(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is Map && v.containsKey('N')) {
      // DynamoDB Number 타입
      return double.tryParse(v['N'].toString()) ?? 0.0;
    }
    return 0.0;
  }

  /* ── 폴더 분류 ── */
  Map<String, List<Map<String, dynamic>>> _folderMap() {
    final map = {
      '중복된 사진': <Map<String, dynamic>>[],
      '유사한 사진': <Map<String, dynamic>>[],
      '흐릿한 사진': <Map<String, dynamic>>[],
      '점수기반 사진': <Map<String, dynamic>>[],
    };

    for (final p in _analyzedPhotos) {
      final gid = p['groupId'] as String?;
      final tags = p['analysisTags'] ?? {};

      if (gid != null && gid.startsWith('d')) {
        map['중복된 사진']!.add(p);
      } else if (gid != null && gid.startsWith('s')) {
        map['유사한 사진']!.add(p);
      } else if (_num(tags['blurry']) == 1.0) {
        map['흐릿한 사진']!.add(p);
      } else if (_num(tags['ai_score']) >= 0.85) {
        map['점수기반 사진']!.add(p);
      }
    }
    return map;
  }

  /* ── 라벨→타입 ── */
  String _labelToType(String label) {
    switch (label) {
      case '중복된 사진':
        return 'duplicate';
      case '유사한 사진':
        return 'similar';
      case '흐릿한 사진':
        return 'blurry';
      case '점수기반 사진':
        return 'score';
      default:
        return 'duplicate';
    }
  }

  /* ── UI ── */
  @override
  Widget build(BuildContext context) {
    final folderMap = _folderMap();

    final List<Widget> screens = [
      // 0️⃣ 정리 탭
      Container(
        color: Colors.white,
        child: Column(
          children: [
            if (_scanning) LinearProgressIndicator(value: _scanProgress),
            if (_uploading) LinearProgressIndicator(value: _uploadProgress),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 촬영 사진
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.83,
                      children: folderMap.entries
                          .map((e) => _buildFolderCard(e.key, e.value))
                          .toList(),
                    ),
                  ),
                  // 스크린샷
                  const ScreenshotTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      // 1️⃣ 리마인드
      const RemindScreen(screenshotPhotos: []),
      // 2️⃣ 메모리
      MemoryScreen(),
      // 3️⃣ 리포트
      const EnvironmentReportScreen(),
    ];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          title: const Text(''),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '휴지통',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              ),
            ),
          ],
          bottom: _selectedTabIndex == 0
              ? TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF26C485),
                  tabs: const [
                    Tab(text: '촬영 사진'),
                    Tab(text: '스크린샷'),
                  ],
                )
              : null,
        ),
        body: screens[_selectedTabIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _selectedTabIndex,
          onTap: (i) => setState(() => _selectedTabIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF26C485),
          unselectedItemColor: Colors.black54,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.photo_library), label: '정리'),
            BottomNavigationBarItem(
                icon: Icon(Icons.notifications_none), label: '리마인드'),
            BottomNavigationBarItem(icon: Icon(Icons.refresh), label: '메모리'),
            BottomNavigationBarItem(
                icon: Icon(Icons.insert_chart_outlined), label: '리포트'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF26C485),
          onPressed: _autoSync,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }

  /* ── 폴더 카드 ── */
  Widget _buildFolderCard(String label, List<Map<String, dynamic>> photos) {
    return GestureDetector(
      onTap: () {
        final type = _labelToType(label);
        final minScore = type == 'score' ? 0.4 : 0.0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GalleryListScreen(
              folderName: label,
              type: type,
              minScore: minScore,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnail(label),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${photos.length}장',
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  /// 🏞️ 에셋 썸네일을 보여줍니다
  Widget _buildThumbnail(String label) {
    final assetPath = _folderThumbnailMap[label];

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
      );
    }

    // 매핑이 없으면 기본 박스
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.image),
    );
  }

  /* ── 기타 헬퍼 ── */

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
}

/* ── 로딩 다이얼로그 ── */
class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('잠시만 기다려주세요')
          ],
        ),
      ),
    );
  }
}
