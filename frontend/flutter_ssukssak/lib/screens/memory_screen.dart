import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math';
import 'memory_swipe_screen.dart'; // 📌 꼭 추가!

class MemoryScreen extends StatelessWidget {
  final Set<String> selectedPrompts = {'풍경', '문서/영수증', '여행'};

  final List<Map<String, dynamic>> allPromptFolders = [
    {'title': '동물', 'photos': [{'photoId': '/path/to/animal.jpg'}]},
    {'title': '음식', 'photos': [{'photoId': '/path/to/food.jpg'}]},
    {'title': '스크린샷', 'photos': [{'photoId': '/path/to/screenshot.jpg'}]},
    {'title': '풍경', 'photos': [{'photoId': '/path/to/scenery.jpg'}]},
    {'title': '셀카/인물사진', 'photos': [{'photoId': '/path/to/selfie.jpg'}]},
    {'title': '문서/영수증', 'photos': [{'photoId': '/path/to/document.jpg'}]},
  ];

  final List<Map<String, dynamic>> travelPhotos = [
    {
      'photoId': '/path/to/photo1.jpg',
      'date': DateTime(2025, 5, 9),
      'lat': 33.45,
      'lon': 126.55
    },
    {
      'photoId': '/path/to/photo2.jpg',
      'date': DateTime(2025, 5, 10),
      'lat': 33.46,
      'lon': 126.56
    },
    {
      'photoId': '/path/to/photo3.jpg',
      'date': DateTime(2025, 5, 12),
      'lat': 37.57,
      'lon': 126.98
    },
    {
      'photoId': '/path/to/photo4.jpg',
      'date': DateTime(2025, 5, 13),
      'lat': 37.56,
      'lon': 126.99
    },
  ];

  MemoryScreen({super.key, required List promptFolders});

  double _distance(double lat1, double lon1, double lat2, double lon2) {
    return sqrt(pow(lat1 - lat2, 2) + pow(lon1 - lon2, 2));
  }

  List<Map<String, dynamic>> groupTravelPhotos(List<Map<String, dynamic>> photos) {
    final List<List<Map<String, dynamic>>> groups = [];

    for (final photo in photos) {
      bool added = false;
      for (final group in groups) {
        final sample = group.first;
        final d = photo['date'].difference(sample['date']).inDays.abs();
        final dist = _distance(photo['lat'], photo['lon'], sample['lat'], sample['lon']);
        if (d <= 1 && dist < 0.05) {
          group.add(photo);
          added = true;
          break;
        }
      }
      if (!added) groups.add([photo]);
    }

    return groups.asMap().entries.map((entry) {
      final index = entry.key + 1;
      return {
        'title': '여행$index',
        'photos': entry.value,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groupedTravel = groupTravelPhotos(travelPhotos);

    final orderedFolders = [
      ...groupedTravel,
      ...allPromptFolders.where((f) => selectedPrompts.contains(f['title'])),
      ...allPromptFolders.where((f) => !selectedPrompts.contains(f['title'])),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("메모리"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: orderedFolders.isEmpty
          ? const Center(child: Text("추천된 메모리가 아직 없어요 📂", style: TextStyle(fontSize: 16)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orderedFolders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final folder = orderedFolders[index];
                final title = folder['title'] as String;
                final photos = folder['photos'] as List<Map<String, dynamic>>;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemorySwipeScreen(
                          folderName: title,
                          photos: photos,
                        ),
                      ),
                    );
                  },
                  child: Container(
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
                          child: photos.isNotEmpty
                              ? Image.file(
                                  File(photos.first['photoId']),
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
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("${photos.length}장",
                                  style: const TextStyle(color: Colors.black54)),
                            ],
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
