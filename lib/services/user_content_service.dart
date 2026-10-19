import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Balasan dan postingan ulang milik akun LAIN (untuk tab di profil orang lain).
/// Butuh route baru di posts.js (lihat backend/posts_user_routes.js).
class UserContentService {
  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<List<Map<String, dynamic>>> _list(
    String token,
    String username,
    String kind,
    String key,
    String fallbackMessage,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiService.baseUrl}/posts/user/${Uri.encodeComponent(username)}/$kind',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data[key] ?? const []);
    }

    throw Exception(data['message'] ?? fallbackMessage);
  }

  /// Item: kolom komentar + post (utas asli) + parent + first_reply.
  static Future<List<Map<String, dynamic>>> getReplies({
    required String token,
    required String username,
  }) =>
      _list(token, username, 'replies', 'replies', 'Gagal mengambil balasan.');

  /// Item: postingan lengkap (sama seperti GET /api/posts).
  static Future<List<Map<String, dynamic>>> getReposts({
    required String token,
    required String username,
  }) =>
      _list(token, username, 'reposts', 'posts',
          'Gagal mengambil postingan ulang.');
}