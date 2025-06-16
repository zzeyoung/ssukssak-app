import 'package:flutter/material.dart';

class EnvironmentReportScreen extends StatelessWidget {
  const EnvironmentReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 테스트용 데이터
    const deletedPhotos = 9426;
    const co2Saved = 4.8; // kg
    const storageSaved = 8.6; // GB
    const treesPlanted = 3.1;

    final ranking = [
      {'name': '숲지킴이삼촌', 'trees': 12.4, 'count': 37200},
      {'name': '초록빛정리요정', 'trees': 10.9, 'count': 31560},
      {'name': '사진털이집사', 'trees': 9.2, 'count': 27300},
      {'name': '용량다이어터', 'trees': 7.8, 'count': 23100},
      {'name': '나무나무열매', 'trees': 12.4, 'count': 9426},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('환경리포트'),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("지금까지", style: TextStyle(color: Colors.black54)),
            Text(
              "$deletedPhotos장을 삭제했어요",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("2025년 6월 3일 기준", style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),

            // 탄소절감 / 저장공간
            Row(
              children: [
                _statBox("누적 탄소 절감량", "$co2Saved kg CO₂"),
                const SizedBox(width: 12),
                _statBox("확보한 저장공간", "$storageSaved GB"),
              ],
            ),
            const SizedBox(height: 12),

            // 내가 살린 나무
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F9F4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("내가 살린 나무", style: TextStyle(color: Colors.black54)),
                        SizedBox(height: 4),
                        Text(
                          "$treesPlanted그루",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text("이쯤이면 작은 정원은 만들어졌어요!"),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset("assets/images/tree2.png", width: 80, height: 80),
                ],
              ),
            ),

            const SizedBox(height: 28),
            const Text("랭킹", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // 랭킹 리스트
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: ranking.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = ranking[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          radius: 18,
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(item['name'] as String? ?? ''),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${item['trees']}그루",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("${item['count']}장", style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text("전체보기"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _statBox(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F9F4), // 🌱 나무 배경색과 동일하게 수정
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
