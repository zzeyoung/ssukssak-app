import 'package:flutter/material.dart';

import 'delete_summary_dialog.dart'; // ✅ 요약 다이얼로그 위젯 import 필요

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final List<String> dummyTrash = List.generate(
    40,
    (i) => '/path/to/deleted_image_${i + 1}.jpg',
  );

  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("휴지통"),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: dummyTrash.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          final isSelected = _selectedIndices.contains(index);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedIndices.remove(index);
                } else {
                  _selectedIndices.add(index);
                }
              });
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.delete, color: Colors.grey),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.check, color: Colors.white, size: 26),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _selectedIndices.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 44, 164, 114),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    final deletedCount = _selectedIndices.length;
                    final savedStorage =
                        deletedCount * 0.1; // 예시: 0.1GB per image
                    final savedCO2 = deletedCount * 0.028;
                    final savedTrees = savedCO2 / 1.4;

                    setState(() {
                      _selectedIndices.toList()
                        ..sort((a, b) => b.compareTo(a))
                        ..forEach((i) => dummyTrash.removeAt(i));
                      _selectedIndices.clear();
                    });

                    showDialog(
                      context: context,
                      builder: (_) => DeleteSummaryDialog(
                        deletedCount: deletedCount,
                        savedStorage: savedStorage,
                        savedCO2: savedCO2,
                        savedTrees: savedTrees,
                      ),
                    );
                  },
                  label: const Text("영구 삭제"),
                ),
              ),
            )
          : null,
    );
  }
}
