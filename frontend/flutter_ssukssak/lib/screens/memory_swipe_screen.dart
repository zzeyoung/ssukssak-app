import 'dart:io';
import 'package:flutter/material.dart';
import '../globals.dart';

class MemorySwipeScreen extends StatefulWidget {
  final String folderName;
  final List<Map<String, dynamic>> photos; // photoId, date, localPath

  const MemorySwipeScreen({
    super.key,
    required this.folderName,
    required this.photos,
  });

  @override
  State<MemorySwipeScreen> createState() => _MemorySwipeScreenState();
}

class _MemorySwipeScreenState extends State<MemorySwipeScreen>
    with SingleTickerProviderStateMixin {
  int currentIndex = 0;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSwipe(String action) {
    final photo = widget.photos[currentIndex];
    final path = photo['localPath'] as String?;
    if (action == '삭제' && path != null) {
      trashBin.add(path);
    }
    print('✅ [$action] 처리됨: ${path ?? photo['photoId']}');

    setState(() {
      currentIndex++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentIndex >= widget.photos.length) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.folderName),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            '🎉 모든 사진 정리가 끝났어요!',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    final photo = widget.photos[currentIndex];
    final date = photo['date'] as DateTime? ?? DateTime.now();
    final path = photo['localPath'] as String?;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.folderName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            '${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 12),
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
                    _controller.forward(from: 0);
                    Future.delayed(const Duration(milliseconds: 200), () {
                      _handleSwipe('보류');
                      _controller.reset();
                    });
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: path != null && File(path).existsSync()
                          ? Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image,
                                size: 60,
                                color: Colors.white70,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 이모지 심플하게 변경
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              Column(
                children: [
                  Icon(Icons.arrow_back_ios_new, color: Colors.black),
                  SizedBox(height: 4),
                  Text('보관',
                      style: TextStyle(fontSize: 12, color: Colors.black)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.arrow_downward, color: Colors.black),
                  SizedBox(height: 4),
                  Text('보류',
                      style: TextStyle(fontSize: 12, color: Colors.black)),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.arrow_forward_ios, color: Colors.black),
                  SizedBox(height: 4),
                  Text('삭제',
                      style: TextStyle(fontSize: 12, color: Colors.black)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 10, 47, 39),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('여기까지만 할게요'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
