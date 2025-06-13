class AnalyzedPhotoData {
  final String photoId;
  final double? latitude;
  final double? longitude;
  final int? size;
  final Map<String, dynamic>? analysisTags;
  final int? screenshot;
  final List<String>? screenshotTags;
  final List<String>? imageTags;
  final String? groupId;
  final String? sourceApp;

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
  });

  factory AnalyzedPhotoData.fromJson(Map<String, dynamic> json) {
    return AnalyzedPhotoData(
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
    );
  }
}
