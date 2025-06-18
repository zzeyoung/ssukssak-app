// lib/screens/gallery_list_screen.dart

import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

import '../globals.dart';
import 'trash_screen.dart';

class GalleryListScreen extends StatefulWidget {
  final String folderName; // UI 라벨
  final String type; // duplicate | similar | blurry | score
  final double minScore;

  const GalleryListScreen({
    Key? key,
    required this.folderName,
    required this.type,
    this.minScore = 0.85,
  }) : super(key: key);

  @override
  State<GalleryListScreen> createState() => _GalleryListScreenState();
}

class _GalleryListScreenState extends State<GalleryListScreen> {
  static const String _endpoint = 'http://172.31.81.175:3000';

  Map<String, List<Map<String, dynamic>>> _sections = {};
  final Set<String> _trashed = {};
  final Set<String> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final secs = await _fetchCandidates();
      await _attachLocalPaths(secs);
      await _loadTrashed();
      _filterTrashed(secs);

      if (!mounted) return;
      setState(() {
        _sections = secs;
        _loading = false;
      });
    } catch (e, st) {
      log('loadAll error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('데이터 로드 실패')));
        setState(() => _loading = false);
      }
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchCandidates() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id')!;
    final qp = <String, String>{'userId': uid};

    switch (widget.type) {
      case 'duplicate':
        qp['duplicate'] = '1';
        break;
      case 'similar':
        qp['similar'] = '1';
        break;
      case 'blurry':
        qp['blurry'] = '1';
        break;
      case 'score':
        qp['minScore'] = widget.minScore.toString();
        break;
    }

    final uri =
        Uri.parse('$_endpoint/photos/candidates').replace(queryParameters: qp);
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Status ${res.statusCode}');

    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    final secs = <String, List<Map<String, dynamic>>>{};

    if (widget.type == 'duplicate') {
      final groups = (jsonMap['duplicateGroups'] ?? {}) as Map<String, dynamic>;
      for (final g in groups.values) {
        for (final it in (g as List).cast<Map<String, dynamic>>()) {
          final dt = DateTime.parse(it['dateTaken']);
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          secs.putIfAbsent(key, () => []).add(it);
        }
      }
      return Map.fromEntries(
        secs.entries.toList()..sort((b, a) => a.key.compareTo(b.key)),
      );
    }

    if (widget.type == 'similar') {
      final groups = (jsonMap['similarGroups'] ?? {}) as Map<String, dynamic>;
      for (final entry in groups.entries) {
        secs[entry.key] = (entry.value as List).cast<Map<String, dynamic>>();
      }
      return secs;
    }

    final arr = (jsonMap['photos'] ??
        jsonMap['items'] ??
        jsonMap['Photos'] ??
        []) as List<dynamic>;
    for (final it in arr.cast<Map<String, dynamic>>()) {
      final dt = DateTime.parse(it['dateTaken']);
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      secs.putIfAbsent(key, () => []).add(it);
    }
    return Map.fromEntries(
      secs.entries.toList()..sort((b, a) => a.key.compareTo(b.key)),
    );
  }

  /// 최적화된 AssetEntity → 파일 경로 매핑
  Future<void> _attachLocalPaths(
      Map<String, List<Map<String, dynamic>>> data) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final root = albums.first;
    final assetCount = await root.assetCountAsync;
    final assets = await root.getAssetListRange(start: 0, end: assetCount);

    // 1. AssetEntity의 title(파일명) 기반으로 lookup 테이블 생성 (비동기 없음, 매우 빠름)
    final lookup = <String, AssetEntity>{};
    for (final a in assets) {
      final title = a.title?.toLowerCase();
      if (title != null) lookup[title] = a;
    }

    // 2. 서버에서 받은 photoId와 매핑
    for (final list in data.values) {
      for (final p in list) {
        final id = (p['photoId'] as String).toLowerCase();
        final a = lookup[id];
        if (a != null) {
          // originFile은 실제 파일 경로가 필요할 때만 await로 접근
          final file = await a.originFile;
          if (file != null) p['localPath'] = file.path;
        }
      }
    }

    // 만약 title이 photoId와 항상 일치하지 않는다면 아래 주석 참고
    /*
    // 병렬로 originFile을 가져와서 lookup 테이블 생성 (느릴 수 있으나, 병렬화로 개선)
    final pairs = await Future.wait(assets.map((a) async {
      final f = await a.originFile;
      return f != null
          ? MapEntry(f.uri.pathSegments.last.toLowerCase(), a)
          : null;
    }));
    final lookup = <String, AssetEntity>{
      for (final e in pairs)
        if (e != null) e.key: e.value,
    };
    */
  }

  Future<void> _loadTrashed() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id')!;
    final uri = Uri.parse('$_endpoint/trash/$uid');
    final res = await http.get(uri);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (body['items'] as List<dynamic>?) ?? [];
      _trashed
        ..clear()
        ..addAll(items.map((e) => e['photoId'] as String));
    } else {
      log('휴지통 조회 실패: ${res.statusCode}');
    }
  }

  void _filterTrashed(Map<String, List<Map<String, dynamic>>> secs) {
    for (final list in secs.values) {
      list.removeWhere((p) => _trashed.contains(p['photoId']));
    }
  }

  Future<void> _deleteSel() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId')!;

    for (final photoId in _selected) {
      try {
        final uri = Uri.parse('http://172.31.81.175:3000/trash');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': uid,
            'photoId': photoId,
          }),
        );
        if (res.statusCode == 200) {
          _trashed.add(photoId);
        } else {
          log('❌ 휴지통 추가 실패(${res.statusCode}): ${res.body}');
        }
      } catch (e) {
        log('🚨 HTTP 예외: $e');
      }
    }

    setState(() {
      for (final list in _sections.values) {
        list.removeWhere((p) => _selected.contains(p['photoId']));
      }
      _selected.clear();
    });
  }

  Future<void> _refreshTrashOnly() async {
    setState(() => _loading = true);
    await _loadTrashed();
    _filterTrashed(_sections);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
              await _refreshTrashOnly();
            },
          ),
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSel,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? const Center(child: Text('사진이 없습니다.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: _sections.length,
                  itemBuilder: (_, i) {
                    final header = _sections.keys.elementAt(i);
                    return _buildSection(header, _sections[header]!);
                  },
                ),
    );
  }

  Widget _buildSection(String header, List<Map<String, dynamic>> list) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(header,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (_, idx) {
              final p = list[idx];
              final id = p['photoId'] as String;
              final sel = _selected.contains(id);
              final path = p['localPath'] as String?;
              return GestureDetector(
                onTap: () => setState(
                    () => sel ? _selected.remove(id) : _selected.add(id)),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: path != null
                            ? Image.file(File(path), fit: BoxFit.cover)
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
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
