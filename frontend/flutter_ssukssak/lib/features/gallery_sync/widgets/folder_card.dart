// 📂 lib/features/gallery_sync/widgets/folder_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../screens/photo_list_screen.dart';

class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.title, required this.photos});
  final String title;
  final List<Map<String, dynamic>> photos;

  String get _type {
    switch (title) {
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

  @override
  Widget build(BuildContext context) {
    final minScore = _type == 'score' ? 0.4 : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryListScreen(
            folderName: title,
            type: _type,
            minScore: minScore,
          ),
        ),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: photos.isNotEmpty
                ? Image.file(File(photos.first['photoId']),
                    width: double.infinity, height: 120, fit: BoxFit.cover)
                : Container(
                    width: double.infinity,
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image),
                  ),
          ),
          const SizedBox(height: 8),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text('${photos.length}장',
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
