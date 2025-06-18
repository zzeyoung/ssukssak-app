import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThumbnailCacheService {
  static Database? _db;

  static Future<Database> _openDB() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'thumbnail_cache.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE thumbs (
            photoId TEXT PRIMARY KEY,
            path TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// 썸네일 경로 캐시 조회
  static Future<String?> get(String photoId) async {
    final db = await _openDB();
    final result = await db.query(
      'thumbs',
      where: 'photoId = ?',
      whereArgs: [photoId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      final path = result.first['path'] as String;
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  /// 캐시 저장
  static Future<void> save(String photoId, String path) async {
    final db = await _openDB();
    await db.insert(
      'thumbs',
      {'photoId': photoId, 'path': path},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 썸네일 없으면 생성해서 경로 반환
  static Future<String?> getOrCreate(String photoId) async {
    final cached = await get(photoId);
    if (cached != null) return cached;

    // asset 탐색
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    for (final album in albums) {
      final assets = await album.getAssetListRange(
          start: 0, end: await album.assetCountAsync);
      for (final a in assets) {
        final f = await a.originFile;
        if (f != null &&
            f.uri.pathSegments.last.toLowerCase() == photoId.toLowerCase()) {
          final thumbData =
              await a.thumbnailDataWithSize(const ThumbnailSize(300, 300));
          if (thumbData != null) {
            final savedPath = await _saveThumbnail(photoId, thumbData);
            await save(photoId, savedPath);
            return savedPath;
          }
        }
      }
    }
    return null;
  }

  /// 실제 썸네일 파일 저장
  static Future<String> _saveThumbnail(String photoId, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final thumbDir = Directory(p.join(dir.path, 'ssukssak_thumbnails'));
    if (!thumbDir.existsSync()) thumbDir.createSync(recursive: true);
    final filePath =
        p.join(thumbDir.path, photoId.replaceAll('/', '_') + '.jpg');
    final f = File(filePath);
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// 전체 캐시 초기화 (선택)
  static Future<void> clear() async {
    final db = await _openDB();
    await db.delete('thumbs');
    final dir = await getTemporaryDirectory();
    final thumbDir = Directory(p.join(dir.path, 'ssukssak_thumbnails'));
    if (thumbDir.existsSync()) await thumbDir.delete(recursive: true);
  }
}
