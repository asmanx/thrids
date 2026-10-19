import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Memeriksa ke server apakah sebuah username sudah dipakai.
class UsernameService {
  /// [valid] = sesuai aturan, [available] = belum dipakai orang lain,
  /// [suggestions] = usulan username lain kalau yang diminta sudah dipakai.
  static Future<({bool valid, bool available, String message, List<String> suggestions})>
      check(
    String username,
  ) async {
    final uri = Uri.parse('${ApiService.baseUrl}/auth/username-available')
        .replace(queryParameters: {'username': username});

    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'Gagal memeriksa username.');
    }

    return (
      valid: data['valid'] == true,
      available: data['available'] == true,
      message: (data['message'] ?? '').toString(),
      suggestions: data['suggestions'] is List
          ? (data['suggestions'] as List).map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}