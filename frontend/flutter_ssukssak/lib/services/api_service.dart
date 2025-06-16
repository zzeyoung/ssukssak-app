import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://172.31.105.35:3000'; // ← 실기기용 IP 주소 수정

  /// ---------------- AUTH ----------------

  static Future<bool> signup(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return res.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getMe(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(res.body);
  }

  /// ---------------- USER ----------------

  static Future<void> createUser(Map<String, dynamic> user) async {
    await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(user),
    );
  }

  static Future<Map<String, dynamic>?> getUser(String userId) async {
    final res = await http.get(Uri.parse('$baseUrl/users/$userId'));
    return res.statusCode == 200 ? jsonDecode(res.body) : null;
  }

  /// ---------------- PROMPTS ----------------

  static Future<List<String>> fetchInitialPrompts() async {
    final res = await http.get(Uri.parse('$baseUrl/user/prompts/init'));
    return List<String>.from(jsonDecode(res.body)['data']);
  }

  static Future<void> saveUserPreferences(
      String userId, List<String> promptTags) async {
    await http.post(
      Uri.parse('$baseUrl/user/preferences'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'promptTags': promptTags}),
    );
  }

  /// ---------------- PHOTO ----------------

  static Future<bool> uploadGalleryMetadata(
      String userId, List<Map<String, dynamic>> photos) async {
    final uri = Uri.parse('$baseUrl/photo/metadata');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'photos': photos}),
      );

      print('📤 [Gallery Upload] status: ${res.statusCode}');
      print('📤 [Gallery Upload] response: ${res.body}');

      return res.statusCode == 200;
    } catch (e) {
      print('❌ [Gallery Upload] error: $e');
      return false;
    }
  }

  /// ---------------- CLASSIFY ----------------

  static Future<void> classifyAndSaveAll(
      String userId, List<Map<String, dynamic>> classifiedPhotos) async {
    await http.post(
      Uri.parse('$baseUrl/classify/save-all'),
      headers: {'Content-Type': 'application/json'},
      body:
          jsonEncode({'userId': userId, 'classifiedPhotos': classifiedPhotos}),
    );
  }

  static Future<Map<String, dynamic>> getFolderSummary(String userId) async {
    final res =
        await http.get(Uri.parse('$baseUrl/classify/folder-summary/$userId'));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getPhotosByFolder(
      String userId, String folderName) async {
    final encoded = Uri.encodeComponent(folderName);
    final res =
        await http.get(Uri.parse('$baseUrl/classify/folder/$userId/$encoded'));
    return jsonDecode(res.body)['data'];
  }

  static Future<Map<String, dynamic>> getScreenshotSubfolders(
      String userId) async {
    final res =
        await http.get(Uri.parse('$baseUrl/classify/screenshots/$userId'));
    return jsonDecode(res.body)['data'];
  }

  /// ---------------- HIGHLIGHT ----------------

  static Future<void> saveHighlightAction(
      String userId, String photoId, String action) async {
    await http.post(
      Uri.parse('$baseUrl/highlight/action'),
      headers: {'Content-Type': 'application/json'},
      body:
          jsonEncode({'userId': userId, 'photoId': photoId, 'action': action}),
    );
  }

  static Future<List<dynamic>> getHighlightHistory(String userId) async {
    final res =
        await http.get(Uri.parse('$baseUrl/highlight/history?userId=$userId'));
    return jsonDecode(res.body)['data'];
  }

  static Future<List<Map<String, dynamic>>> getHighlightFolders(
      String userId) async {
    final res = await http.get(Uri.parse('$baseUrl/highlight/folders/$userId'));
    return List<Map<String, dynamic>>.from(jsonDecode(res.body)['data']);
  }

  static Future<List<Map<String, dynamic>>> getPhotosInHighlightFolder(
      String userId, String folderName) async {
    final encoded = Uri.encodeComponent(folderName);
    final res = await http
        .get(Uri.parse('$baseUrl/highlight/folders/$userId/photos/$encoded'));
    return List<Map<String, dynamic>>.from(jsonDecode(res.body)['data']);
  }

  /// ---------------- TRASH ----------------

  static Future<void> addToTrash({
    required String userId,
    required String photoId,
    required String source,
    List<String> tags = const [],
    double score = 0,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/trash'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'photoId': photoId,
        'source': source,
        'tags': tags,
        'score': score,
      }),
    );
  }

  static Future<List<dynamic>> getTrash(String userId) async {
    final res = await http.get(Uri.parse('$baseUrl/trash/$userId'));
    return jsonDecode(res.body)['items'];
  }

  static Future<void> restorePhotos(
      String userId, List<String> photoIds) async {
    await http.delete(
      Uri.parse('$baseUrl/trash/restore'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'photoIds': photoIds}),
    );
  }

  static Future<void> deletePhotos(
      String userId, List<Map<String, dynamic>> photos) async {
    await http.delete(
      Uri.parse('$baseUrl/trash/permanent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'photos': photos}),
    );
  }

  /// ---------------- REPORT ----------------

  static Future<Map<String, dynamic>> getReport(String userId) async {
    final res = await http.get(Uri.parse('$baseUrl/report/$userId'));
    return jsonDecode(res.body);
  }

  static Future fetchClassifiedPhotos(String userId) async {}

  static Future<void> sendTrashList(String userId, List<String> list) async {}

  static Future fetchOldScreenshots(globalUserId) async {}
}
