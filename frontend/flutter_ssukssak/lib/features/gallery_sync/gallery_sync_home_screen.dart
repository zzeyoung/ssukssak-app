// 📂 lib/features/gallery_sync/screens/gallery_sync_home_screen.dart
import 'package:flutter/material.dart';
import 'controllers/gallery_sync_controller.dart';
import 'widgets/folder_card.dart';
import '../../screens/environment_report_screen.dart'; // 기존 위치 유지

class GallerySyncHomeScreen extends StatefulWidget {
  const GallerySyncHomeScreen({super.key});

  @override
  State<GallerySyncHomeScreen> createState() => _GallerySyncHomeScreenState();
}

class _GallerySyncHomeScreenState extends State<GallerySyncHomeScreen>
    with SingleTickerProviderStateMixin {
  late final GallerySyncController _c;
  late final TabController _tabs;
  int _bottomIndex = 0;

  @override
  void initState() {
    super.initState();
    _c = GallerySyncController()..addListener(() => setState(() {}));
    _c.bootstrap();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _c.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          automaticallyImplyLeading: false,
          bottom: _bottomIndex == 0
              ? TabBar(
                  controller: _tabs,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF26C485),
                  tabs: const [Tab(text: '촬영 사진'), Tab(text: '스크린샷')],
                )
              : null,
        ),
        body: Column(
          children: [
            if (_c.scanning)
              LinearProgressIndicator(
                  value: _c.scanProgress, color: Colors.blue),
            if (_c.uploading)
              LinearProgressIndicator(
                  value: _c.uploadProgress, color: Colors.green),
            Expanded(
              child: _bottomIndex == 0
                  ? TabBarView(
                      controller: _tabs,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.85,
                            children: _c.folders.entries
                                .map((e) =>
                                    FolderCard(title: e.key, photos: e.value))
                                .toList(),
                          ),
                        ),
                        const Center(child: Text('스크린샷 탭 준비 중')),
                      ],
                    )
                  : const EnvironmentReportScreen(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _bottomIndex,
          onTap: (i) => setState(() => _bottomIndex = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF26C485),
          unselectedItemColor: Colors.black54,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.photo_library), label: '정리'),
            BottomNavigationBarItem(
                icon: Icon(Icons.insert_chart_outlined), label: '리포트'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF26C485),
          onPressed: _c.autoSync,
          child: const Icon(Icons.refresh),
        ),
      );
}
