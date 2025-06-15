import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/photo_metadata.dart';

/// DynamoDB 연동용 갤러리 업로더
class GalleryUploader {
  final String endpoint; // 'http://10.0.2.2:3000'
  final String userId; // 로그인된 Cognito UID
  final int batchSize;

  const GalleryUploader({
    required this.endpoint,
    required this.userId,
    this.batchSize = 25, // DynamoDB BatchWriteItem 최대 25
  });

  /// 모든 메타데이터를 /photo/gallery 로 전송
  Future<void> uploadAll(
    Iterable<AnalyzedPhotoData> photos, {
    void Function(double progress)? onProgress,
  }) async {
    final list = photos.toList();
    final total = list.length;
    for (var i = 0; i < total; i += batchSize) {
      final slice =
          list.sublist(i, i + batchSize > total ? total : i + batchSize);
      final body = jsonEncode({
        'userId': userId,
        'photos': slice.map((e) => e.toJson()).toList(),
      });

      final res = await http.post(
        Uri.parse('$endpoint/photos/metadata'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (res.statusCode != 200) {
        throw Exception('Upload failed (${res.statusCode}): ${res.body}');
      }
      onProgress?.call((i + slice.length) / total);
    }
  }
}
