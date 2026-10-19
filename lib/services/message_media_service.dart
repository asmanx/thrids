import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import 'api_service.dart';

/// Mengirim foto, GIF, dan stiker di obrolan (DM).
/// Butuh route pesan terbaru di backend (routes/messages.js).
class MessageMediaService {
  static Uri _uri(Object conversationId) => Uri.parse(
        '${ApiService.baseUrl}/messages/conversations/$conversationId/messages',
      );

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _result(http.Response response, String fallback) {
    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data['message'] ?? const {});
    }

    throw Exception(data['message'] ?? fallback);
  }

  /// Kirim satu foto (multipart, field "media").
  static Future<Map<String, dynamic>> sendImage({
    required String token,
    required Object conversationId,
    required UploadFile file,
  }) async {
    final request = http.MultipartRequest('POST', _uri(conversationId));

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'media',
        file.bytes,
        filename: file.name,
        contentType: MediaType.parse(file.mimeType),
      ),
    );

    final streamed = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);

    return _result(response, 'Gagal mengirim foto.');
  }

  /// Kirim GIF atau stiker dari Giphy (cukup alamatnya).
  static Future<Map<String, dynamic>> sendGiphy({
    required String token,
    required Object conversationId,
    required String url,
    required bool sticker,
  }) async {
    final response = await http.post(
      _uri(conversationId),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'type': sticker ? 'sticker' : 'gif',
        'media_url': url,
      }),
    );

    return _result(
      response,
      sticker ? 'Gagal mengirim stiker.' : 'Gagal mengirim GIF.',
    );
  }
}