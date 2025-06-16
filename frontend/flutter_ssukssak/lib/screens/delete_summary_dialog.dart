import 'package:flutter/material.dart';

class DeleteSummaryDialog extends StatelessWidget {
  final int deletedCount;
  final double savedStorage;
  final double savedCO2;
  final double savedTrees;

  const DeleteSummaryDialog({
    super.key,
    required this.deletedCount,
    required this.savedStorage,
    required this.savedCO2,
    required this.savedTrees,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("사진 정리 완료!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("작은 정리 하나가 지구에 큰 도움이 됩니다 💚"),
            const SizedBox(height: 24),
            Image.asset('assets/images/tree.png', height: 80),
            const SizedBox(height: 24),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("삭제한 사진", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("$deletedCount장"),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("확보한 용량", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${savedStorage.toStringAsFixed(1)}GB"),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text("🌲 나무 ${savedTrees.toStringAsFixed(1)}그루를 살린 효과예요",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("절감된 탄소", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${savedCO2.toStringAsFixed(1)} kg CO₂eq"),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // 공유 기능 추가 가능
              },
              icon: const Icon(Icons.share),
              label: const Text("공유하기"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("닫기"),
            ),
          ],
        ),
      ),
    );
  }
}
