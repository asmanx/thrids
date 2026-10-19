import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../post_detail_page.dart';
import 'post_attachments.dart';
import 'user_avatar.dart';

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

/// Isi tab "Balasan" di profil: semua komentar/balasan yang pernah kamu tulis.
///
/// Tiap item tampil sebagai satu rangkaian yang dihubungkan garis vertikal,
/// dari atas ke bawah:
///  1. label "Utas pertama" (bila ada),
///  2. postingan asli yang kamu komentari,
///  3. komentar yang kamu balas (bila balasanmu ditujukan ke komentar),
///  4. komentarmu sendiri ("Membalas @username"),
///  5. balasan pertama dari orang lain (bila ada).
///
/// Ketuk sebuah blok untuk membuka postingannya di [PostDetailPage].
///
/// Gunakan [GlobalKey<RepliesTabState>] lalu `currentState?.reload()` untuk
/// memuat ulang dari luar.
class RepliesTab extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;

  /// Semua postingan (dari feed), dipakai untuk membuka halaman detail.
  final List<Map<String, dynamic>> allPosts;

  const RepliesTab({
    super.key,
    required this.token,
    required this.currentUser,
    required this.allPosts,
  });

  @override
  State<RepliesTab> createState() => RepliesTabState();
}

class RepliesTabState extends State<RepliesTab>
    with AutomaticKeepAliveClientMixin {
  static const muted = Color(0xFF858585);
  static const border = Color(0xFF2E2E2E);
  static const lineColor = Color(0xFF3A3A3A);

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await ApiService.getMyReplies(token: widget.token);

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      if (silent && _items.isNotEmpty) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openPost(Object postId) async {
    final post = widget.allPosts.cast<Map<String, dynamic>?>().firstWhere(
          (p) => '${p?['id']}' == '$postId',
          orElse: () => null,
        );

    if (post == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Postingan tidak ditemukan.')),
        );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          token: widget.token,
          post: post,
          currentUser: widget.currentUser,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );

    if (mounted) reload(silent: true);
  }

  /// Gabungkan postingan induk dari server dengan data lengkap di feed
  /// (foto/video, GIF, musik, polling, dll.) bila tersedia.
  Map<String, dynamic> _fullPost(Map<String, dynamic> post) {
    for (final p in widget.allPosts) {
      if ('${p['id']}' == '${post['id']}') {
        return <String, dynamic>{...p, ...post, 'media': p['media'] ?? post['media']};
      }
    }
    return post;
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return '';

    final diff = DateTime.now().difference(date.toLocal());

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
    if (diff.inHours < 24) return '${diff.inHours} jam';
    if (diff.inDays < 7) return '${diff.inDays} hari';

    return '${date.day}/${date.month}/${date.year}';
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gagal memuat balasan.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              TextButton(onPressed: reload, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => reload(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: _items.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Anda belum memposting balasan apapun',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 17),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              key: const PageStorageKey('replies'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _items.length,
              itemBuilder: (_, i) => _buildItem(_items[i]),
            ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final post = _fullPost(Map<String, dynamic>.from(item['post'] as Map));
    final parent = item['parent'] == null
        ? null
        : Map<String, dynamic>.from(item['parent'] as Map);
    final firstReply = item['first_reply'] == null
        ? null
        : Map<String, dynamic>.from(item['first_reply'] as Map);

    final replyingTo = (parent ?? post)['username'];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: InkWell(
        onTap: () => _openPost(item['post_id']),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) Label "Utas pertama".
            if (post['is_first_post'] == true)
              const Padding(
                padding: EdgeInsets.fromLTRB(28, 14, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.star_border_rounded, size: 22, color: muted),
                    SizedBox(width: 12),
                    Text(
                      'Utas pertama',
                      style: TextStyle(color: muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            // 2) Postingan asli yang kamu komentari (selalu di atas).
            _threadRow(
              data: post,
              lineBelow: true,
              firstInChain: true,
              likes: _toInt(post['like_count']),
              comments: _toInt(post['comment_count']),
              reposts: _toInt(post['repost_count']),
              attachments: PostAttachments(post: post, token: widget.token),
            ),
            // 3) Komentar yang kamu balas (bila ada).
            if (parent != null)
              _threadRow(
                data: parent,
                lineBelow: true,
                likes: _toInt(parent['like_count']),
                comments: _toInt(parent['reply_count']),
              ),
            // 4) Komentarmu sendiri, di bawahnya.
            _threadRow(
              data: item,
              replyingTo: '$replyingTo',
              lineBelow: firstReply != null,
              likes: _toInt(item['like_count']),
              comments: _toInt(item['reply_count']),
            ),
            // 5) Balasan pertama dari orang lain terhadap komentarmu.
            if (firstReply != null)
              _threadRow(
                data: firstReply,
                likes: _toInt(firstReply['like_count']),
                comments: _toInt(firstReply['reply_count']),
              ),
          ],
        ),
      ),
    );
  }

  /// Satu baris (avatar, nama, waktu, isi, ikon aksi). Jika [lineBelow], garis
  /// vertikal digambar di bawah avatar untuk menyambung ke baris berikutnya.
  Widget _threadRow({
    required Map<String, dynamic> data,
    String? replyingTo,
    bool lineBelow = false,
    bool firstInChain = false,
    int likes = 0,
    int comments = 0,
    int reposts = 0,
    Widget? attachments,
  }) {
    final username = (data['username'] ?? 'user').toString();
    final content = (data['content'] ?? '').toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, firstInChain ? 14 : 6, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  _avatar(data['profile_picture'], username, 42),
                  if (lineBelow)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: lineColor,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(data['created_at']),
                        style: const TextStyle(color: muted, fontSize: 16),
                      ),
                      const Spacer(),
                      const Icon(Icons.more_horiz, color: muted, size: 22),
                    ],
                  ),
                  if (replyingTo != null)
                    Text(
                      'Membalas @$replyingTo',
                      style: const TextStyle(color: muted, fontSize: 16),
                    ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.35,
                      ),
                    ),
                  ],
                  ?attachments,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat(Icons.favorite_border, likes),
                      const SizedBox(width: 20),
                      _stat(Icons.chat_bubble_outline, comments),
                      const SizedBox(width: 20),
                      _stat(Icons.repeat, reposts),
                      const SizedBox(width: 20),
                      _stat(Icons.send_outlined, 0),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFD6D6D6), size: 23),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Text(
            '$count',
            style: const TextStyle(color: Color(0xFFD6D6D6), fontSize: 15),
          ),
        ],
      ],
    );
  }

  Widget _avatar(dynamic picture, String username, double size) {
    return UserAvatar(url: picture?.toString(), size: size);
  }
}