import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../ai/score_service.dart';
import '../ai/clip_service.dart';
import '../ai/yolo_service.dart';

class PhotoAnalyzer extends StatefulWidget {
  const PhotoAnalyzer({Key? key}) : super(key: key);

  @override
  State<PhotoAnalyzer> createState() => _PhotoAnalyzerState();
}

class _PhotoAnalyzerState extends State<PhotoAnalyzer> {
  double? score;
  List<double>? clipVector;
  List<String>? contentTags;
  File? photoFile;

  bool _isLoadingModels = false;
  bool _modelsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAllModels();
  }

  Future<void> _loadAllModels() async {
    setState(() {
      _isLoadingModels = true;
    });
    try {
      await ScoreService().loadModel();
      await ClipService().loadModel();
      await YoloService().loadModel(); // YOLO 모델도 로드
      setState(() {
        _modelsLoaded = true;
      });
    } catch (e) {
      debugPrint('❌ 모델 로딩 중 오류: $e');
    } finally {
      setState(() {
        _isLoadingModels = false;
      });
    }
  }

  Future<void> pickPhotoAndAnalyze() async {
    if (!_modelsLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모델 로딩이 아직 완료되지 않았습니다.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return;

    double resultScore = 0.0;
    List<double> resultVector = [];
    List<String> resultTags = [];

    try {
      resultScore = await ScoreService().predictScore(image);
    } catch (e) {
      debugPrint('❌ ScoreService 예측 오류: $e');
    }

    try {
      resultVector = await ClipService().predictFeatures(image);
    } catch (e) {
      debugPrint('❌ ClipService 예측 오류: $e');
    }

    try {
      resultTags = await YoloService().detectLabels(image);
    } catch (e) {
      debugPrint('❌ YoloService 예측 오류: $e');
    }

    setState(() {
      score = resultScore;
      clipVector = resultVector;
      contentTags = resultTags;
      photoFile = file;
    });

    debugPrint("📌 분석 결과 요약");
    debugPrint("- 예쁨 점수: $resultScore");
    debugPrint("- CLIP 벡터 길이: ${resultVector.length}");
    debugPrint("- YOLO 태그: $resultTags");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingModels) {
      return Scaffold(
        appBar: AppBar(title: const Text('모델 로딩 중')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_modelsLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('모델 로딩 실패')),
        body: Center(
          child: ElevatedButton(
            onPressed: _loadAllModels,
            child: const Text('모델 재로딩 시도'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('쓱싹 - AI 모델 결과')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (photoFile != null) ...[
                Image.file(photoFile!, height: 200),
                const SizedBox(height: 12),
              ],
              if (score != null) ...[
                Text(
                  '예쁨 점수dd: ${(score! * 100).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 12),
              ],
              if (clipVector != null) ...[
                Text(
                  'CLIP 벡터 길이: ${clipVector!.length}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
              ],
              if (contentTags != null && contentTags!.isNotEmpty) ...[
                const Text('탐지된 객체 태그:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: contentTags!
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton(
                onPressed: pickPhotoAndAnalyze,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('사진 선택하고 분석하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
