import 'dart:io';
import 'package:flutter/material.dart';
import 'memory_swipe_screen.dart'; // ✅ 한 장씩 스와이프 정리용

class RemindScreen extends StatelessWidget {
  const RemindScreen({super.key, required List screenshotPhotos});

  @override
  Widget build(BuildContext context) {
    final threshold = DateTime.now().subtract(const Duration(days: 180));

    // ✅ 더미 JSON 데이터 (직접 지정한 이미지 경로로 바꿔야 함!)
    final List<Map<String, dynamic>> screenshotPhotos = [
      {
        'photoId': '/path/to/sample.jpg', // ← 여기 본인 로컬 이미지 경로로 교체
        'date': DateTime.now().subtract(const Duration(days: 200)),
        'tags': {'screenshot': true},
      },
      {
        'photoId': '/path/to/another.jpg',
        'date': DateTime.now().subtract(const Duration(days: 190)),
        'tags': {'screenshot': true},
      },
    ];

    final oldPhotos = screenshotPhotos.where((photo) {
      final date = photo['date'];
      final isScreenshot = photo['tags']?['screenshot'] == true;
      return date != null && date.isBefore(threshold) && isScreenshot;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("리마인드"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemorySwipeScreen(
                  folderName: "6개월 지난 스크린샷",
                  photos: oldPhotos,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: oldPhotos.isNotEmpty
                      ? Image.file(
                          File(oldPhotos.first['photoId']),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          ),
                        )
                      : Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "6개월 지난 스크린샷",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "${oldPhotos.length}장",
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
