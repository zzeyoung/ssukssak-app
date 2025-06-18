// models/photo_metadata.dart
// 그룹 ID는 d1, s3 처럼 접두어로 중복/유사 타입까지 포함.
class AnalyzedPhotoData {
  final String photoId;
  final double? latitude;
  final double? longitude;
  final int? size;
  final Map<String, dynamic>? analysisTags;
  final int? screenshot; // 스크린샷 여부 (1 or 0)
  final List<String>? screenshotTags;

  final List<String>? imageTags;
  final String? groupId; // dN / sN
  final String? sourceApp; // 추출된 앱 이름 or null
  final DateTime? dateTaken; // 촬영일자

  const AnalyzedPhotoData({
    required this.photoId,
    this.latitude,
    this.longitude,
    this.size,
    this.analysisTags,
    this.screenshot,
    this.screenshotTags,
    this.imageTags,
    this.groupId,
    this.sourceApp,
    this.dateTaken,
  });

  factory AnalyzedPhotoData.fromJson(Map<String, dynamic> json) =>
      AnalyzedPhotoData(
        photoId: json['photoId'] ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        size: json['size'] as int?,
        analysisTags: json['analysisTags'] as Map<String, dynamic>?,
        screenshot: json['screenshot'] as int?,
        screenshotTags: (json['screenshotTags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        imageTags: (json['imageTags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        groupId: json['groupId'] as String?,
        sourceApp: json['sourceApp'] as String?,
        dateTaken: json['dateTaken'] != null
            ? DateTime.tryParse(json['dateTaken'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'photoId': photoId,
        'latitude': latitude,
        'longitude': longitude,
        'size': size,
        'analysisTags': analysisTags,
        'screenshot': screenshot,
        'screenshotTags': screenshotTags,
        'imageTags': imageTags,
        'groupId': groupId,
        'sourceApp': sourceApp,
        'dateTaken': dateTaken?.toIso8601String(),
      };
}
