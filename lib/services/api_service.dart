import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

/// File yang dipilih pengguna dan siap diunggah (aman untuk web, desktop, mobile).
class UploadFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;

  const UploadFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });
}

class ApiService {
  static const String baseUrl =     'http://localhost:3000/api';

  /// Alamat server tanpa "/api" (dipakai untuk memuat foto/video/musik).
  static String get serverUrl => baseUrl.replaceFirst(RegExp(r'/api/?$'), '');

  /// Mengubah "/uploads/abc.jpg" menjadi URL penuh. URL penuh (mis. Giphy)
  /// dikembalikan apa adanya.
  static String resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$serverUrl$url';
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  // LOGIN MENGGUNAKAN USERNAME DAN PASSWORD
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username.trim(), 'password': password}),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Login gagal.');
  }

  // MENGAMBIL DAFTAR AKUN
  static Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/auth/users'));

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['users']);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil daftar akun.');
  }

  // REGISTER / MEMBUAT AKUN TANPA EMAIL
  static Future<Map<String, dynamic>> register({
    required String username,
    required String displayName,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'display_name': displayName.trim(),
        'password': password,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Registrasi gagal.');
  }

  // MENGAMBIL POSTINGAN
  // [token] opsional: bila diisi, server ikut mengirim pilihan polling milik user.
  static Future<List<Map<String, dynamic>>> getPosts({String? token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['posts']);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil postingan.');
  }

  // MEMBUAT POSTINGAN
  // Dikirim sebagai multipart/form-data agar bisa membawa foto, video, dan musik.
  //
  // Musik ada dua jenis (pilih salah satu):
  //  - musik online dari pemilih musik: [musicTrackId] + [musicCover] + [musicTitle]
  //  - file musik unggahan: [audio] + [musicTitle]
  static Future<Map<String, dynamic>> createPost({
    required String token,
    String content = '',
    List<UploadFile> media = const [],
    UploadFile? audio,
    String? musicTitle,
    String? musicTrackId,
    String? musicCover,
    String? gifUrl,
    String? stickerUrl,
    List<String>? pollOptions,
    Object? quotePostId,
    String? locationName,
    double? latitude,
    double? longitude,
    bool isTemporary = false,
    String replyAudience = 'anyone',
    bool approveReplies = false,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/posts'));

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['content'] = content;
    if (isTemporary) request.fields['is_temporary'] = 'true';
    request.fields['reply_audience'] = replyAudience;
    if (approveReplies) request.fields['approve_replies'] = 'true';

    if (gifUrl != null) request.fields['gif_url'] = gifUrl;
    if (stickerUrl != null) request.fields['sticker_url'] = stickerUrl;

    if (pollOptions != null && pollOptions.isNotEmpty) {
      request.fields['poll'] = jsonEncode(pollOptions);
    }

    if (quotePostId != null) {
      request.fields['quote_post_id'] = quotePostId.toString();
    }

    if (locationName != null && latitude != null && longitude != null) {
      request.fields['location_name'] = locationName;
      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
    }

    for (final file in media) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'media',
          file.bytes,
          filename: file.name,
          contentType: MediaType.parse(file.mimeType),
        ),
      );
    }

    if (audio != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audio.bytes,
          filename: audio.name,
          contentType: MediaType.parse(audio.mimeType),
        ),
      );
    }

    // Musik online: backend hanya menyimpan id lagu, judul, dan cover.
    if (musicTrackId != null && musicTrackId.isNotEmpty) {
      request.fields['music_track_id'] = musicTrackId;

      if (musicCover != null && musicCover.isNotEmpty) {
        request.fields['music_cover'] = musicCover;
      }
    }

    if ((audio != null || musicTrackId != null) &&
        musicTitle != null &&
        musicTitle.trim().isNotEmpty) {
      request.fields['music_title'] = musicTitle.trim();
    }

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal membuat postingan.');
  }

  // SUKA / BATAL SUKA
  // Mengembalikan {'liked': bool, 'like_count': int}
  static Future<Map<String, dynamic>> setLike({
    required String token,
    required Object postId,
    required bool liked,
  }) {
    return _toggle(token, '$baseUrl/posts/$postId/like', liked);
  }

  // POSTING ULANG / BATAL POSTING ULANG
  // Mengembalikan {'reposted': bool, 'repost_count': int}
  static Future<Map<String, dynamic>> setRepost({
    required String token,
    required Object postId,
    required bool reposted,
  }) {
    return _toggle(token, '$baseUrl/posts/$postId/repost', reposted);
  }

  static Future<Map<String, dynamic>> _toggle(
    String token,
    String url,
    bool add,
  ) async {
    final headers = {'Authorization': 'Bearer $token'};
    final uri = Uri.parse(url);

    final response =
        add ? await http.post(uri, headers: headers) : await http.delete(uri, headers: headers);

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal memproses permintaan.');
  }

  // MENGAMBIL KOMENTAR SEBUAH POSTINGAN
  // [token] opsional: bila diisi, server ikut mengirim liked_by_me tiap komentar.
  static Future<List<Map<String, dynamic>>> getComments({
    required Object postId,
    String? token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/$postId/comments'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['comments'] ?? const []);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil komentar.');
  }

  // MENGIRIM KOMENTAR
  // Mengembalikan {'comment': {...}, 'comment_count': int}
  static Future<Map<String, dynamic>> addComment({
    required String token,
    required Object postId,
    required String content,
    Object? parentId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/comments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'content': content,
        'parent_id': ?parentId,
      }),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal mengirim komentar.');
  }

  // SUKA / BATAL SUKA KOMENTAR
  // Mengembalikan {'liked': bool, 'like_count': int}
  static Future<Map<String, dynamic>> setCommentLike({
    required String token,
    required Object commentId,
    required bool liked,
  }) {
    return _toggle(token, '$baseUrl/posts/comments/$commentId/like', liked);
  }

  // MENCATAT POSTINGAN DILIHAT (dipanggil sekali saat halaman postingan dibuka)
  // Mengembalikan {'view_count': int}
  static Future<Map<String, dynamic>> registerView({
    required Object postId,
    String? token,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/view'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal mencatat tayangan.');
  }

  // BALASAN MILIK USER YANG LOGIN (untuk tab "Balasan" di profil)
  static Future<List<Map<String, dynamic>>> getMyReplies({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/me/replies'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['replies'] ?? const []);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil balasan.');
  }

  // INSIGHT AKUN (halaman Insight). [days] = 7, 14, 30, atau 90.
  // Mengembalikan {'profile': {...}, 'audience': {...}}
  static Future<Map<String, dynamic>> getInsights({
    required String token,
    int days = 30,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/me/insights?days=$days'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal mengambil insight.');
  }

  // POSTINGAN YANG DISUKAI OLEH USER YANG LOGIN
  static Future<List<Map<String, dynamic>>> getMyLikedPosts({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/me/liked'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(
        data['posts'] ?? const [],
      );
    }

    throw Exception(
      data['message'] ?? 'Gagal mengambil postingan yang disukai.',
    );
  }

  // POSTINGAN YANG DISIMPAN OLEH USER YANG LOGIN
  static Future<List<Map<String, dynamic>>> getMySavedPosts({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/me/saved'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(
        data['posts'] ?? const [],
      );
    }

    throw Exception(
      data['message'] ?? 'Gagal mengambil postingan yang disimpan.',
    );
  }

  // POSTINGAN YANG DIPOSTING ULANG OLEH USER YANG LOGIN (tab "Postingan ulang")
  static Future<List<Map<String, dynamic>>> getMyReposts({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/me/reposts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['posts'] ?? const []);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil postingan ulang.');
  }

  // POSTINGAN YANG DIPOSTING ULANG OLEH AKUN LAIN (tab "Postingan ulang" profil orang)
  static Future<List<Map<String, dynamic>>> getUserReposts({
    required String token,
    required String username,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/posts/user/${Uri.encodeComponent(username)}/reposts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['posts'] ?? const []);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil postingan ulang.');
  }

  // MEMBERI SUARA PADA POLLING
  // Mengembalikan {'poll_options': [...], 'my_vote': <id opsi>}
  static Future<Map<String, dynamic>> votePoll({
    required String token,
    required Object postId,
    required int optionId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/vote'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'option_id': optionId}),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal memberikan suara.');
  }

  // MEMPERBARUI PROFIL (hanya kirim field yang berubah)
  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required Map<String, dynamic> changes,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(changes),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data['user']);
    }

    throw Exception(data['message'] ?? 'Gagal memperbarui profil.');
  }

  // MENGUNGGAH FOTO PROFIL
  // Mengembalikan Map user terbaru (berisi avatar_url / profile_picture baru).
  static Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required UploadFile file,
  }) async {
    final request =
        http.MultipartRequest('PUT', Uri.parse('$baseUrl/auth/avatar'));

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'avatar',
        file.bytes,
        filename: file.name,
        contentType: MediaType.parse(file.mimeType),
      ),
    );

    final streamed = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);
    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data['user'] ?? const {});
    }

    throw Exception(
      data['message'] ??
          'Gagal mengunggah foto profil (HTTP ${response.statusCode}).',
    );
  }

  // ───────────────────────── PESAN (DM) ─────────────────────────

  static Future<Map<String, dynamic>> _messageCall(
    String method,
    String token,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/messages$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = method == 'POST'
        ? await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
        : await http.get(uri, headers: headers);

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message'] ?? 'Gagal memproses pesan.');
  }

  /// [box]: 'inbox' | 'requests' | 'hidden'.
  /// [filter]: 'all' | 'unread' | 'unanswered' | 'verified'.
  static Future<({List<Map<String, dynamic>> conversations, int requestCount})>
      getConversations({
    required String token,
    String box = 'inbox',
    String filter = 'all',
  }) async {
    final data = await _messageCall(
      'GET',
      token,
      '/conversations?box=$box&filter=$filter',
    );

    return (
      conversations: List<Map<String, dynamic>>.from(
        data['conversations'] ?? const [],
      ),
      requestCount: (data['request_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Membuka (atau membuat) percakapan dengan [username].
  /// Mengembalikan {'id': ..., 'user': {...}}.
  static Future<Map<String, dynamic>> openConversation({
    required String token,
    required String username,
  }) async {
    final data = await _messageCall(
      'POST',
      token,
      '/conversations',
      body: {'username': username},
    );

    return Map<String, dynamic>.from(data['conversation'] ?? const {});
  }

  static Future<Map<String, dynamic>> getConversation({
    required String token,
    required Object conversationId,
  }) async {
    final data = await _messageCall('GET', token, '/conversations/$conversationId');

    return Map<String, dynamic>.from(data['conversation'] ?? const {});
  }

  /// Tanpa [after]: 100 pesan terakhir. Dengan [after]: hanya pesan yang lebih baru.
  static Future<List<Map<String, dynamic>>> getMessages({
    required String token,
    required Object conversationId,
    int? after,
  }) async {
    final data = await _messageCall(
      'GET',
      token,
      '/conversations/$conversationId/messages${after != null ? '?after=$after' : ''}',
    );

    return List<Map<String, dynamic>>.from(data['messages'] ?? const []);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String token,
    required Object conversationId,
    required String content,

    /// Postingan yang dibagikan lewat pesan (dikirim sebagai `post_id`).
    Object? postId,
  }) async {
    final data = await _messageCall(
      'POST',
      token,
      '/conversations/$conversationId/messages',
      body: {'content': content, 'post_id': ?postId},
    );

    return Map<String, dynamic>.from(data['message'] ?? const {});
  }

  static Future<void> hideConversation({
    required String token,
    required Object conversationId,
    required bool hidden,
  }) async {
    await _messageCall(
      'POST',
      token,
      '/conversations/$conversationId/hide',
      body: {'hidden': hidden},
    );
  }

  static Future<void> muteConversation({
    required String token,
    required Object conversationId,
    required bool muted,
  }) async {
    await _messageCall(
      'POST',
      token,
      '/conversations/$conversationId/mute',
      body: {'muted': muted},
    );
  }

  // ── Obrolan grup ──

  /// Membuat grup (minimal 2 orang selain saya). Mengembalikan
  /// {'id': ..., 'user': {is_group: true, username: <nama grup>, ...}}.
  static Future<Map<String, dynamic>> createGroup({
    required String token,
    required List<String> usernames,
    String name = '',
  }) async {
    final data = await _messageCall(
      'POST',
      token,
      '/groups',
      body: {'name': name, 'usernames': usernames},
    );

    return Map<String, dynamic>.from(data['conversation'] ?? const {});
  }

  static Future<void> addGroupMembers({
    required String token,
    required Object conversationId,
    required List<String> usernames,
  }) async {
    await _messageCall(
      'POST',
      token,
      '/conversations/$conversationId/members',
      body: {'usernames': usernames},
    );
  }

  /// Hanya admin grup.
  static Future<void> removeGroupMember({
    required String token,
    required Object conversationId,
    required Object userId,
  }) async {
    await _messageCall(
      'POST',
      token,
      '/conversations/$conversationId/members/remove',
      body: {'user_id': '$userId'},
    );
  }

  static Future<void> leaveGroup({
    required String token,
    required Object conversationId,
  }) async {
    await _messageCall('POST', token, '/conversations/$conversationId/leave');
  }

  static Future<void> renameGroup({
    required String token,
    required Object conversationId,
    required String name,
  }) async {
    await _messageCall(
      'POST',
      token,
      '/conversations/$conversationId/rename',
      body: {'name': name},
    );
  }

  /// Orang yang bisa dikirimi pesan (yang saya ikuti tampil lebih dulu).
  static Future<List<Map<String, dynamic>>> searchMessageUsers({
    required String token,
    String query = '',
  }) async {
    final data = await _messageCall(
      'GET',
      token,
      '/users?q=${Uri.encodeQueryComponent(query)}',
    );

    return List<Map<String, dynamic>>.from(data['users'] ?? const []);
  }

  /// Jumlah percakapan belum dibaca di Kotak masuk + jumlah Permintaan.
  static Future<({int unread, int requests})> getMessageCounts({
    required String token,
  }) async {
    final data = await _messageCall('GET', token, '/unread-count');

    return (
      unread: (data['unread_count'] as num?)?.toInt() ?? 0,
      requests: (data['request_count'] as num?)?.toInt() ?? 0,
    );
  }

  // HAPUS POSTINGAN MILIK SENDIRI (DELETE /api/posts/:id)
  // Gagal dengan pesan dari server bila bukan pemilik atau postingan tidak ada.
  static Future<void> deletePost({
    required String token,
    required Object postId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/posts/$postId'),
      headers: _auth(token),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    final data = _decode(response);

    throw Exception(data['message'] ?? 'Gagal menghapus postingan.');
  }

  // ───────────────────── FOLLOW & PROFIL ORANG LAIN ─────────────────────

  static Map<String, String> _auth(String token) =>
      {'Authorization': 'Bearer $token'};

  static String _enc(String username) => Uri.encodeComponent(username);

  // PROFIL AKUN (sendiri / orang lain)
  // Mengembalikan user + followers_count, following_count, is_following,
  // follows_me, is_me.
  static Future<Map<String, dynamic>> getUserProfile({
    required String token,
    required String username,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/${_enc(username)}'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data['user'] ?? const {});
    }

    throw Exception(data['message'] ?? 'Gagal mengambil profil.');
  }

  // IKUTI / BERHENTI MENGIKUTI
  // Mengembalikan {'following': bool, 'followers_count': int}
  static Future<Map<String, dynamic>> setFollow({
    required String token,
    required String username,
    required bool follow,
  }) {
    return _toggle(token, '$baseUrl/users/${_enc(username)}/follow', follow);
  }

  // DAFTAR USERNAME YANG SAYA IKUTI + YANG PERMINTAANNYA MASIH MENUNGGU
  // (akun privat yang belum menyetujui).
  static Future<({Set<String> following, Set<String> requested})>
      getFollowState({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/following'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      Set<String> toSet(dynamic v) =>
          v is List ? v.map((e) => e.toString()).toSet() : <String>{};

      return (
        following: toSet(data['following']),
        requested: toSet(data['requested']),
      );
    }

    throw Exception(data['message'] ?? 'Gagal mengambil daftar yang diikuti.');
  }

  static Future<Set<String>> getFollowing({required String token}) async =>
      (await getFollowState(token: token)).following;

  // PERMINTAAN MENGIKUTI UNTUK AKUN SAYA (akun privat)
  static Future<List<Map<String, dynamic>>> getFollowRequests({
    required String token,
  }) =>
      _userList(token, '$baseUrl/users/requests');

  static Future<void> approveFollowRequest({
    required String token,
    required String username,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/requests/${_enc(username)}/approve'),
      headers: _auth(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          _decode(response)['message'] ?? 'Gagal menerima permintaan.');
    }
  }

  static Future<void> declineFollowRequest({
    required String token,
    required String username,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/requests/${_enc(username)}/decline'),
      headers: _auth(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          _decode(response)['message'] ?? 'Gagal menghapus permintaan.');
    }
  }

  // SARAN AKUN YANG BELUM DIIKUTI
  static Future<List<Map<String, dynamic>>> getSuggestions({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/suggestions'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['users'] ?? const []);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil saran akun.');
  }

  // DAFTAR FOLLOWER / FOLLOWING SEBUAH AKUN
  static Future<List<Map<String, dynamic>>> getFollowers({
    required String token,
    required String username,
  }) =>
      _userList(token, '$baseUrl/users/${_enc(username)}/followers');

  static Future<List<Map<String, dynamic>>> getFollowingOf({
    required String token,
    required String username,
  }) =>
      _userList(token, '$baseUrl/users/${_enc(username)}/following');

  static Future<List<Map<String, dynamic>>> getMutualFollowers({
    required String token,
    required String username,
  }) =>
      _userList(token, '$baseUrl/users/${_enc(username)}/mutual');

  static Future<List<Map<String, dynamic>>> _userList(
    String token,
    String url,
  ) async {
    final response = await http.get(Uri.parse(url), headers: _auth(token));
    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(data['users'] ?? const []);
    }

    throw Exception(data['message'] ?? 'Gagal mengambil daftar akun.');
  }

  // ───────────────────────── NOTIFIKASI ─────────────────────────

  static Future<List<Map<String, dynamic>>> getNotifications({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(
        data['notifications'] ?? const [],
      );
    }

    throw Exception(data['message'] ?? 'Gagal mengambil notifikasi.');
  }

  static Future<int> getUnreadCount({required String token}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: _auth(token),
    );

    final data = _decode(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return int.tryParse('${data['unread_count'] ?? 0}') ?? 0;
    }

    return 0;
  }

  static Future<void> markAllNotificationsRead({required String token}) async {
    await http.post(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: _auth(token),
    );
  }
}