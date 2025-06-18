import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import 'memory_swipe_screen.dart';

class MemoryScreen extends StatelessWidget {
  // ✅ AI 태그 → 화면에 표시할 카테고리 매핑
  final Map<String, List<String>> tagMap = {
    '동물': [
      'dog',
      'cat',
    ],
    '음식': ['cup', 'spoon', 'bowl'],
    '스크린샷': ['screenshot'],
    '풍경': ['landscape'],
    '셀카/인물사진': ['selfie', 'person'],
    '문서/영수증': ['document', 'receipt'],
  };

  MemoryScreen({super.key});

  /* ────────── 로컬 파일 경로 붙이기 ────────── */
  Future<void> _attachLocal(List<Map<String, dynamic>> items) async {
    // 1) 사진 권한 요청
    if (!await Permission.photos.request().isGranted) {
      print('❌ 사진 권한 거부됨');
      return;
    }

    // 2) 모든 이미지 앨범 가져오기
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    final lookup = <String, AssetEntity>{};

    // 3) 페이징으로 앨범 순회하며 파일명 → AssetEntity 매핑
    const pageSize = 100;
    for (final album in albums) {
      final total = await album.assetCountAsync;
      for (int i = 0; i < total; i += pageSize) {
        final end = (i + pageSize > total) ? total : i + pageSize;
        final assets = await album.getAssetListRange(start: i, end: end);
        for (final a in assets) {
          final file = await a.originFile;
          if (file != null) {
            final name = file.uri.pathSegments.last.toLowerCase();
            lookup[name] = a;
          }
        }
      }
    }

    // 4) 서버에서 받아온 items 에 localPath 채우기
    for (final p in items) {
      final idName = (p['photoId'] as String).toLowerCase();
      final ae = lookup[idName];
      if (ae != null) {
        final file = await ae.originFile;
        if (file != null) {
          p['localPath'] = file.path;
        }
      }
    }
  }

  /* ────────── 서버에서 후보 사진 가져오기 & 이동 ────────── */
  Future<void> _loadAndNavigate(
      BuildContext context, String title, List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      print('❌ 사용자 ID 없음');
      return;
    }

    final tagParam = tags.join(',');
    final uri = Uri.parse(
      'http://172.31.81.175:3000/photos/candidates?userId=$userId&imgTag=$tagParam',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final photos = (data['photos'] as List).map((item) {
          return {
            'photoId': item['photoId'],
            'date': DateTime.tryParse(item['dateTaken'] ?? ''),
          };
        }).toList();

        await _attachLocal(photos);

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MemorySwipeScreen(
                folderName: title,
                photos: photos,
              ),
            ),
          );
        }
      } else {
        print('❌ 서버 에러: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 통신 실패: $e');
    }
  }

  /* ────────── UI ────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 전체 배경 흰색
      appBar: AppBar(
        title: const Text("메모리"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tagMap.length,
        separatorBuilder: (_, __) => Column(
          children: [
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 8),
          ],
        ),
        itemBuilder: (context, index) {
          final title = tagMap.keys.elementAt(index);
          final tags = tagMap[title]!;

          return GestureDetector(
            onTap: () => _loadAndNavigate(context, title, tags),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  /* 썸네일 자리 */
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                    child: const Icon(Icons.image, size: 40),
                  ),

                  /* 세로 구분선 */
                  Container(
                    width: 1,
                    height: 70,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 16),

                  /* 텍스트 */
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
