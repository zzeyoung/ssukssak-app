// lib/ui/photo_analyzer.dart
// -----------------------------------------------------------
// PhotoAnalyzer 화면
//  • ScoreService → 예쁨 점수
//  • YoloService   → YOLO 객체 태그
// -----------------------------------------------------------

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../ai/score_service.dart';
import '../ai/yolo_service.dart';

class PhotoAnalyzer extends StatefulWidget {
  const PhotoAnalyzer({Key? key}) : super(key: key);

  @override
  State<PhotoAnalyzer> createState() => _PhotoAnalyzerState();
}

class _PhotoAnalyzerState extends State<PhotoAnalyzer> {
  // ── 예측 결과 ──
  double? _score;
  List<String>? _yoloTags;
  File? _photoFile;

  // ── 모델 로딩 상태 ──
  bool _loading = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  // ─────────────────────────────────────────────
  // 모든 모델 로드
  // ─────────────────────────────────────────────
  Future<void> _loadModels() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        ScoreService().loadModel(),
        YoloService().loadModel(),
      ]);
      _loaded = true;
    } catch (e) {
      debugPrint('❌ 모델 로딩 오류: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────
  // 사진 선택 & 분석
  // ─────────────────────────────────────────────
  Future<void> _pickAndAnalyze() async {
    if (!_loaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델이 아직 준비되지 않았습니다.')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return;

    // 예측
    double? sc;
    List<String>? yolo;

    try {
      sc = await ScoreService().predictScore(image);
    } catch (e) {
      debugPrint('❌ ScoreService 오류: $e');
    }

    try {
      yolo = await YoloService().detectLabels(image);
    } catch (e) {
      debugPrint('❌ YoloService 오류: $e');
    }

    setState(() {
      _photoFile = file;
      _score = sc;
      _yoloTags = yolo;
    });

    debugPrint('📌 분석 완료 — Score=$_score  YOLO=$_yoloTags');
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('모델 로딩 중')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 로딩 실패
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('모델 로딩 실패')),
        body: Center(
          child: ElevatedButton(
            onPressed: _loadModels,
            child: const Text('다시 시도'),
          ),
        ),
      );
    }

    // 메인 화면
    return Scaffold(
      appBar: AppBar(title: const Text('쓱싹 – AI 분석')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_photoFile != null) ...[
                Image.file(_photoFile!, height: 220),
                const SizedBox(height: 12),
              ],
              if (_score != null) ...[
                Text('예쁨 점수: ${(_score! * 100).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
              ],
              if (_yoloTags != null && _yoloTags!.isNotEmpty) ...[
                const Text('YOLO 객체:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children:
                      _yoloTags!.map((t) => Chip(label: Text(t))).toList(),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: _pickAndAnalyze,
                child: const Text('사진 선택 → 분석'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
