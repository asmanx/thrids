import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Mengelola utas milik sendiri (saat ini: hapus).
/// Butuh route DELETE /api/posts/:id di backend (backend/posts_delete_route.js).
class PostManageService {
  static Future<void> deletePost({
    required String token,
    required Object postId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/posts/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = 'Gagal menghapus utas.';

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}

    throw Exception(message);
  }
}