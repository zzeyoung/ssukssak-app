// lib/screens/screenshot_tab.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScreenshotTab extends StatefulWidget {
  final String? userId;
  const ScreenshotTab({Key? key, this.userId}) : super(key: key);

  @override
  State<ScreenshotTab> createState() => _ScreenshotTabState();
}

class _ScreenshotTabState extends State<ScreenshotTab> {
  static const _endpoint = 'http://172.31.81.175:3000';

  static const Map<String, List<String>> _map = {
    '전체': [],
    '브라우저': ['Chrome', 'Samsung Internet'],
    '카카오톡': ['KakaoTalk'],
    '네이버맵': ['NAVER Map'],
    'Instagram': ['Instagram'],
    'OTT': ['Netflix'],
    '상품캡쳐': ['Karrot'],
    '게임': ['FIFA Online 4 M', 'TFT'],
    '음악': ['Melon', 'Samsung Music'],
    '홈화면': [
      'One UI Home',
    ],
  };

  final _cats = _map.keys.toList();
  String _selCat = '전체';

  bool _loading = true;
  final _photos = <Map<String, dynamic>>[];
  final _selected = <String>{};
  final Map<String, List<Map<String, dynamic>>> _cachedPhotos = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get hasSelection => _selected.isNotEmpty;

  void deleteSelected() {
    _photos.removeWhere((p) => _selected.contains(p['photoId'] as String));
    _selected.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('선택된 스크린샷이 휴지통으로 이동되었습니다.')),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    try {
      if (_cachedPhotos.containsKey(_selCat)) {
        _photos
          ..clear()
          ..addAll(_cachedPhotos[_selCat]!);
        setState(() => _loading = false);
        return;
      }

      final uid = await _resolveUid();
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }

      final list = await _fetch(uid);
      await _attachLocal(list);
      _cachedPhotos[_selCat] = list;

      if (mounted) {
        setState(() {
          _photos
            ..clear()
            ..addAll(list);
          _loading = false;
        });
      }
    } catch (e, st) {
      log('ScreenshotTab load error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스크린샷 로드 실패')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _resolveUid() async {
    if (widget.userId != null) return widget.userId;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  Future<List<Map<String, dynamic>>> _fetch(String uid) async {
    final sources = _map[_selCat]!;
    final list = <Map<String, dynamic>>[];

    if (sources.isEmpty) {
      list.addAll(await _callApi(uid, null));
    } else {
      for (final s in sources) {
        list.addAll(await _callApi(uid, s));
      }
    }

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

  /// 최적화: AssetEntity.title(파일명) 기반으로 빠르게 매칭
  Future<void> _attachLocal(List<Map<String, dynamic>> items) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    final screenshotAlbums = albums.where((album) =>
        album.name.toLowerCase().contains('screenshot') ||
        album.name.contains('스크린샷'));

    final lookup = <String, AssetEntity>{};
    for (final album in screenshotAlbums) {
      final assetCount = await album.assetCountAsync;
      final assets = await album.getAssetListRange(start: 0, end: assetCount);
      final pairs = await Future.wait(assets.map((a) async {
        final f = await a.originFile;
        return f != null
            ? MapEntry(f.uri.pathSegments.last.toLowerCase(), a)
            : null;
      }));
      for (final e in pairs) {
        if (e != null) lookup[e.key] = e.value;
      }
    }
    for (final p in items) {
      final id = (p['photoId'] as String).toLowerCase();
      final ae = lookup[id];
      if (ae != null) {
        p['asset'] = ae;
      }
    }

    // 만약 title이 photoId와 항상 일치하지 않는다면 아래 병렬화 주석 참고
    /*
    final lookup = <String, AssetEntity>{};
    for (final album in screenshotAlbums) {
      final assetCount = await album.assetCountAsync;
      final assets = await album.getAssetListRange(start: 0, end: assetCount);
      final pairs = await Future.wait(assets.map((a) async {
        final f = await a.originFile;
        return f != null
            ? MapEntry(f.uri.pathSegments.last.toLowerCase(), a)
            : null;
      }));
      for (final e in pairs) {
        if (e != null) lookup[e.key] = e.value;
      }
    }
    for (final p in items) {
      final id = (p['photoId'] as String).toLowerCase();
      final ae = lookup[id];
      if (ae != null) {
        p['asset'] = ae;
      }
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    const categoryBarHeight = 60.0;

    return Column(
      children: [
        SizedBox(
          height: categoryBarHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: _cats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = _cats[i];
              final sel = c == _selCat;

              return GestureDetector(
                onTap: () {
                  if (sel) return;
                  setState(() => _selCat = c);
                  _load();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: sel
                      ? BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(22),
                        )
                      : null,
                  child: Center(
                    child: Text(
                      c,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? Colors.black : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 16),
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
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (_, idx) {
                        final p = _photos[idx];
                        final id = p['photoId'] as String;
                        final asset = p['asset'] as AssetEntity?;
                        final sel = _selected.contains(id);

                        return GestureDetector(
                          onTap: () => setState(() =>
                              sel ? _selected.remove(id) : _selected.add(id)),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: asset != null
                                      ? FutureBuilder<Uint8List?>(
                                          future: asset.thumbnailDataWithSize(
                                              const ThumbnailSize(300, 300)),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                    ConnectionState.done &&
                                                snapshot.hasData) {
                                              return Image.memory(
                                                snapshot.data!,
                                                fit: BoxFit.cover,
                                              );
                                            } else {
                                              return Container(
                                                color: Colors.grey[300],
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 1),
                                                ),
                                              );
                                            }
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.broken_image),
                                        ),
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
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
