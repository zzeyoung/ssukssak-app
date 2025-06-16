import 'package:flutter/material.dart';

class PromptSelectScreen extends StatefulWidget {
  const PromptSelectScreen({super.key});

  @override
  State<PromptSelectScreen> createState() => _PromptSelectScreenState();
}

class _PromptSelectScreenState extends State<PromptSelectScreen> {
  final Set<String> _selected = {};

  final List<String> prompts = [
    '동물', '음식', '스크린샷', '풍경',
    '셀카/인물사진', '문서/영수증', '여행',
  ];

  void _toggleSelect(String label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  void _goNext() {
    debugPrint("✅ 선택된 태그: $_selected");
    Navigator.pushReplacementNamed(context, '/gallery');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ 전체 배경색 설정
      appBar: AppBar(
        title: const Text(''),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white, // ✅ 앱바도 배경과 맞춤
        foregroundColor: Colors.black, // 아이콘 색 보정
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "어떤 사진을 정리할까요?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "정리하고 싶은 사진 유형을 선택해주세요",
              style: TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 32),

            Wrap(
              spacing: 12,
              runSpacing: 16,
              children: prompts.map((label) {
                final selected = _selected.contains(label);
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => _toggleSelect(label),
                  selectedColor: const Color(0xFF26C485),
                  backgroundColor: Colors.white, // ✅ 배경색과 동일하게
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.grey.shade300, // ✅ 선택 안 됐을 때 외곽선
                    ),
                  ),
                );
              }).toList(),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty ? null : _goNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "다음",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
