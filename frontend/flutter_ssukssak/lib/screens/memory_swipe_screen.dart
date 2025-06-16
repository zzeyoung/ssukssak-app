import 'dart:io';
import 'package:flutter/material.dart';
import '../globals.dart';


class MemorySwipeScreen extends StatefulWidget {
  final String folderName;
  final List<Map<String, dynamic>> photos;

  const MemorySwipeScreen({
    super.key,
    required this.folderName,
    required this.photos,
  });

  @override
  State<MemorySwipeScreen> createState() => _MemorySwipeScreenState();
}

class _MemorySwipeScreenState extends State<MemorySwipeScreen> {
  int currentIndex = 0;

  void _handleSwipe(String action) {
    final photo = widget.photos[currentIndex];
    final path = photo['photoId'];

    // 🔥 삭제된 이미지 경로를 휴지통에 저장
    if (action == '삭제') {
      trashBin.add(path);
    }

    print('✅ [$action] 처리됨: $path');

    setState(() {
      currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= widget.photos.length) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.folderName)),
        body: const Center(
          child: Text(
            '🎉 모든 사진 정리가 끝났어요!',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final photo = widget.photos[currentIndex];
    final date = photo['date'] ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: Text(widget.folderName)),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            '${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 12),

          // ✅ 이미지 영역 (스와이프 + 드래그)
          Expanded(
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  _handleSwipe('삭제');
                } else if (direction == DismissDirection.endToStart) {
                  _handleSwipe('보관');
                }
              },
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! > 0) {
                    _handleSwipe('보류');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(photo['photoId']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image, size: 60),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 📌 스와이프 방향 안내
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('👈 보관', style: TextStyle(fontSize: 14)),
              Text('👇 보류', style: TextStyle(fontSize: 14)),
              Text('삭제 👉', style: TextStyle(fontSize: 14)),
            ],
          ),

          const SizedBox(height: 20),

          // 📌 버튼 액션 (스와이프 대신)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => _handleSwipe('보관'),
                  child: const Text('보관'),
                ),
                ElevatedButton(
                  onPressed: () => _handleSwipe('보류'),
                  child: const Text('보류'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () => _handleSwipe('삭제'),
                  child: const Text('삭제'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 👋 종료 버튼
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('여기까지만 할게요'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
