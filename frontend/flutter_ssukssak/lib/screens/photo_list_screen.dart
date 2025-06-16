// lib/screens/gallery_list_screen.dart
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';

import '../globals.dart';

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
  static const _endpoint = 'http://172.31.81.175:3000';

  /// key → list<photo>
  Map<String, List<Map<String, dynamic>>> _sections = {};
  bool _loading = true;
  final _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /* ────────── 메인 로드 ────────── */
  Future<void> _load() async {
    try {
      final secs = await _fetchCandidates();
      await _attachLocalPaths(secs);
      if (mounted) {
        setState(() {
          _sections = secs;
          _loading = false;
        });
      }
    } catch (e, st) {
      log('load error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('데이터 로드 실패')));
        setState(() => _loading = false);
      }
    }
  }

  /* ────────── 1. 서버 호출 ────────── */
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
    if (res.statusCode != 200) throw Exception(res.statusCode);

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final secs = <String, List<Map<String, dynamic>>>{};

    /* ── duplicate → 날짜별 ── */
    if (widget.type == 'duplicate') {
      final groups = (json['duplicateGroups'] ?? {}) as Map<String, dynamic>;
      for (final g in groups.values) {
        for (final it in (g as List).cast<Map<String, dynamic>>()) {
          final dt = DateTime.parse(it['dateTaken']);
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          secs.putIfAbsent(key, () => []).add(it);
        }
      }
      return Map.fromEntries(
          secs.entries.toList()..sort((b, a) => a.key.compareTo(b.key)));
    }

    /* ── similar → 그룹 ID별 ── */
    if (widget.type == 'similar') {
      final groups = (json['similarGroups'] ?? {}) as Map<String, dynamic>;
      int idx = 1;
      for (final entry in groups.entries) {
        secs['그룹 $idx'] = (entry.value as List).cast<Map<String, dynamic>>();
        idx++;
      }
      return secs;
    }

    /* ── blurry / score → json['photos'] or json['items'] ── */
    final arr = (json['photos'] ??
        json['items'] ??
        json['Photos'] ?? // 혹시 대문자
        []) as List<dynamic>;

    for (final it in arr.cast<Map<String, dynamic>>()) {
      final dt = DateTime.parse(it['dateTaken']);
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      secs.putIfAbsent(key, () => []).add(it);
    }

    return Map.fromEntries(
        secs.entries.toList()..sort((b, a) => a.key.compareTo(b.key)));
  }

  /* ────────── 2. 로컬 경로 매핑 ────────── */
  Future<void> _attachLocalPaths(
      Map<String, List<Map<String, dynamic>>> data) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return;
    final root = albums.first;
    final assets =
        await root.getAssetListRange(start: 0, end: await root.assetCountAsync);

    final lookup = <String, AssetEntity>{};
    for (final a in assets) {
      final f = await a.originFile;
      if (f != null) lookup[f.uri.pathSegments.last.toLowerCase()] = a;
    }

    for (final list in data.values) {
      for (final p in list) {
        final a = lookup[(p['photoId'] as String).toLowerCase()];
        if (a != null) {
          final file = await a.originFile;
          if (file != null) p['localPath'] = file.path;
        }
      }
    }
  }

  /* ────────── 삭제 → 휴지통 ────────── */
  void _deleteSel() {
    trashBin.addAll(_selected);
    setState(() {
      for (final l in _sections.values) {
        l.removeWhere((p) => _selected.contains(p['photoId']));
      }
      _selected.clear();
    });
  }

  /* ────────── UI ────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folderName),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteSel),
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
