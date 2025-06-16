// lib/screens/screenshot_tab.dart
// -----------------------------------------------------------------------------
// 📲 스크린샷 탭 화면 (userId 선택적) – 2025‑06‑16 fix
//   • ChoiceChip 으로 카테고리 선택 → sourceApp 매핑별 API 호출
//   • GET /photos/candidates?userId=<uid>[&sourceApp=<name>]
//   • photoId ↔︎ 로컬 파일 매핑 → 썸네일(Image.file) 표시
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenshotTab extends StatefulWidget {
  /// userId 가 null 이면 내부에서 SharedPreferences → AuthService 순으로 조회
  final String? userId;
  const ScreenshotTab({Key? key, this.userId}) : super(key: key);

  @override
  State<ScreenshotTab> createState() => _ScreenshotTabState();
}

class _ScreenshotTabState extends State<ScreenshotTab> {
  static const _endpoint = 'http://172.31.81.175:3000';

  // 카테고리 ↔︎ sourceApp 매핑
  static const Map<String, List<String>> _map = {
    '전체': [],
    '카카오톡': ['KakaoTalk'],
    '네이버맵': ['NAVER Map'],
    'Instagram': ['Instagram'],
    'OTT': ['Netflix'],
    '상품캡쳐': ['Karrot'],
    '게임': ['FIFA Online 4 M', 'TFT'],
    '음악': ['Melon', 'Samsung Music'],
  };
  final _cats = _map.keys.toList();

  String _selCat = '전체';
  bool _loading = true;
  final _photos = <Map<String, dynamic>>[]; // {photoId, localPath, dateTaken}
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /* ─── 메인 로드 ─── */
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = await _resolveUid();
      if (uid == null) return;
      final list = await _fetch(uid);
      await _attachLocal(list);
      if (mounted)
        setState(() {
          _photos
            ..clear()
            ..addAll(list);
        });
    } catch (e, st) {
      log('ScreenshotTab load error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('스크린샷 로드 실패')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _resolveUid() async {
    if (widget.userId != null) return widget.userId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id'); // null → UI 에러 처리
  }

  /* ─── 1. 서버 호출 ─── */
  Future<List<Map<String, dynamic>>> _fetch(String uid) async {
    final sources = _map[_selCat]!;
    final list = <Map<String, dynamic>>[];

    // "전체" → sourceApp 파라미터 없이 한 번만 호출
    if (sources.isEmpty) {
      list.addAll(await _callApi(uid, null));
    } else {
      for (final s in sources) {
        list.addAll(await _callApi(uid, s));
      }
    }
    // dateTaken DESC 정렬
    list.sort((b, a) => a['dateTaken'].compareTo(b['dateTaken']));
    return list;
  }

  Future<List<Map<String, dynamic>>> _callApi(String uid, String? src) async {
    final qp = {'userId': uid, if (src != null) 'sourceApp': src};
    final uri =
        Uri.parse('$_endpoint/photos/candidates').replace(queryParameters: qp);
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception(res.statusCode);
    final arr = (jsonDecode(res.body)['photos'] as List<dynamic>? ?? []);
    return arr.cast<Map<String, dynamic>>();
  }

  /* ─── 2. 로컬 경로 매핑 ─── */
  Future<void> _attachLocal(List<Map<String, dynamic>> items) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final assets = await albums.first
        .getAssetListRange(start: 0, end: await albums.first.assetCountAsync);
    final lookup = <String, AssetEntity>{};
    for (final a in assets) {
      final f = await a.originFile;
      if (f != null) lookup[f.uri.pathSegments.last.toLowerCase()] = a;
    }
    for (final p in items) {
      final ae = lookup[(p['photoId'] as String).toLowerCase()];
      if (ae != null) p['localPath'] = (await ae.originFile)?.path;
    }
  }

  /* ─── UI ─── */
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (_, i) {
              final c = _cats[i];
              final sel = c == _selCat;
              return ChoiceChip(
                label: Text(c),
                selected: sel,
                onSelected: (_) {
                  setState(() => _selCat = c);
                  _load();
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: _cats.length,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _photos.isEmpty
                  ? const Center(child: Text('해당 카테고리의 스크린샷이 없습니다.'))
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (_, idx) {
                        final p = _photos[idx];
                        final id = p['photoId'] as String;
                        final path = p['localPath'] as String?;
                        final sel = _selected.contains(id);
                        return GestureDetector(
                          onTap: () => setState(() =>
                              sel ? _selected.remove(id) : _selected.add(id)),
                          child: Stack(children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: path != null
                                    ? Image.file(File(path), fit: BoxFit.cover)
                                    : Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image)),
                              ),
                            ),
                            if (sel)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                      child: Icon(Icons.check_circle,
                                          color: Colors.white)),
                                ),
                              ),
                          ]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
