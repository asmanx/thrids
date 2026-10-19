import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'reply_page.dart';
import 'user_profile_page.dart';
import 'widgets/linkified_text.dart';
import 'widgets/post_actions.dart';
import 'widgets/post_attachments.dart';
import 'widgets/post_menu_sheet.dart';
import 'widgets/share_sheet.dart';
import 'widgets/user_avatar.dart';

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? 0}') ?? 0;
}

/// Halaman penuh sebuah postingan beserta komentarnya (seperti Threads):
/// komentar bersarang, label "Pembuat", tombol "Tampilkan balasan", dan kolom
/// balas di bawah.
///
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => PostDetailPage(
///       token: token,
///       post: post,
///       currentUser: user,
///       onChanged: () => setState(() {}),
///     ),
///   ));
///
/// [post] dimodifikasi langsung (jumlah suka/komentar/posting ulang), lalu
/// [onChanged] dipanggil supaya halaman pemanggil bisa membangun ulang.
class PostDetailPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> post;
  final Map<String, dynamic> currentUser;
  final VoidCallback? onChanged;

  const PostDetailPage({
    super.key,
    required this.token,
    required this.post,
    required this.currentUser,
    this.onChanged,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  static const bg = Color(0xFF101010);
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);
  static const lineColor = Color(0xFF3A3A3A);
  static const redLike = Color(0xFFFF3040);
  static const greenRepost = Color(0xFF3DDC84);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<Map<String, dynamic>> _comments = [];

  /// Komentar (id) yang balasannya sudah dibuka. Komentar utama selalu terbuka.
  final Set<int> _expanded = {};

  final Set<String> _pending = {};

  /// Komentar yang sedang dibalas (null = membalas postingan itu sendiri).
  Map<String, dynamic>? _replyTo;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _sort = 'popular';

  late int _viewCount = _toInt(widget.post['view_count']);

  Map<String, dynamic> get post => widget.post;

  String get _myUsername => (widget.currentUser['username'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _load();
    _registerView();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<void> _registerView() async {
    try {
      final result = await ApiService.registerView(
        postId: post['id'],
        token: widget.token,
      );

      if (!mounted) return;

      setState(() => _viewCount = _toInt(result['view_count']));
    } catch (_) {
      // Jumlah dilihat tidak penting; abaikan bila gagal.
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final comments = await ApiService.getComments(
        postId: post['id'],
        token: widget.token,
      );

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      if (silent && _comments.isNotEmpty) {
        _toast(error.toString().replaceFirst('Exception: ', ''));
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    final target = _replyTo;

    setState(() => _sending = true);

    try {
      final result = await ApiService.addComment(
        token: widget.token,
        postId: post['id'],
        content: text,
        parentId: target?['id'],
      );

      if (!mounted) return;

      final comment = Map<String, dynamic>.from(result['comment'] as Map);

      setState(() {
        _comments = [..._comments, comment];
        if (target != null) _expandThread(target);
        _replyTo = null;
        _controller.clear();

        final count = _toInt(result['comment_count']);
        post['comment_count'] = count > 0 ? count : _comments.length;
      });

      widget.onChanged?.call();
      FocusScope.of(context).unfocus();
    } catch (error) {
      if (!mounted) return;

      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Membuka komentar [target] dan semua induknya supaya balasan baru terlihat.
  void _expandThread(Map<String, dynamic> target) {
    final byId = {for (final c in _comments) _toInt(c['id']): c};

    Map<String, dynamic>? current = target;

    while (current != null) {
      _expanded.add(_toInt(current['id']));

      final parent = current['parent_id'];
      current = parent == null ? null : byId[_toInt(parent)];
    }
  }

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
    final id = _toInt(comment['id']);

    if (!_pending.add('comment:$id')) return;

    final wasLiked = comment['liked_by_me'] == true;
    final oldCount = _toInt(comment['like_count']);

    setState(() {
      comment['liked_by_me'] = !wasLiked;
      comment['like_count'] = wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1;
    });

    try {
      final result = await ApiService.setCommentLike(
        token: widget.token,
        commentId: id,
        liked: !wasLiked,
      );

      if (!mounted) return;

      setState(() {
        comment['liked_by_me'] = result['liked'] == true;
        comment['like_count'] = _toInt(result['like_count']);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        comment['liked_by_me'] = wasLiked;
        comment['like_count'] = oldCount;
      });

      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pending.remove('comment:$id');
    }
  }

  /// Suka / posting ulang untuk postingan utama.
  Future<void> _togglePostInteraction({
    required String flag,
    required String countKey,
    required String resultFlag,
    required Future<Map<String, dynamic>> Function(bool next) call,
  }) async {
    if (!_pending.add(flag)) return;

    final was = post[flag] == true;
    final oldCount = _toInt(post[countKey]);

    setState(() {
      post[flag] = !was;
      post[countKey] = was ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1;
    });
    widget.onChanged?.call();

    try {
      final result = await call(!was);

      if (!mounted) return;

      setState(() {
        post[flag] = result[resultFlag] == true;
        post[countKey] = _toInt(result[countKey]);
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        post[flag] = was;
        post[countKey] = oldCount;
      });

      _toast(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pending.remove(flag);
      widget.onChanged?.call();
    }
  }

  Future<void> _sharePost() {
    return ShareSheet.show(context, token: widget.token, post: post);
  }

  /// Layar penuh "Balas". [target] = komentar yang dibalas (null = utasnya).
  Future<void> _openReplyPage(Map<String, dynamic>? target) async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReplyPage(
          token: widget.token,
          post: post,
          target: target,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (posted == true && mounted) {
      if (target != null) _expandThread(target);
      setState(() => _replyTo = null);
      widget.onChanged?.call();
      await _load(silent: true);
    }
  }

  void _startReply(Map<String, dynamic> comment) {
    setState(() => _replyTo = comment);
    _focus.requestFocus();
  }

  // ───────────────────────── Menu postingan ─────────────────────────

  /// Titik tiga di pojok kanan atas. Untuk postingan sendiri ada "Hapus";
  /// setelah terhapus, halaman ini ditutup.
  Future<void> _openPostMenu() async {
    final isMine = '${post['username']}' == _myUsername;

    final action = await PostMenuSheet.show(
      context,
      isNote: post['expires_at'] != null,
      isMine: isMine,
      isSaved: false,
    );

    if (action == null || !mounted) return;

    switch (action) {
      case PostMenuAction.copyLink:
        await Clipboard.setData(
          ClipboardData(text: '${ApiService.serverUrl}/post/${post['id']}'),
        );
        _toast('Tautan postingan disalin.');
      case PostMenuAction.delete:
        if (!isMine) return;

        final deleted = await PostActions.deleteWithConfirm(
          context,
          token: widget.token,
          post: post,
        );

        if (deleted && mounted) {
          widget.onChanged?.call();
          Navigator.of(context).pop();
        }
      default:
        _toast('Segera hadir.');
    }
  }

  // ───────────────────────── Helper ─────────────────────────

  void _toast(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _soon(String feature) => _toast('Fitur $feature belum tersedia.');

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

  DateTime _date(Map<String, dynamic> comment) {
    return DateTime.tryParse('${comment['created_at']}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// parent id -> daftar balasan (terlama di atas).
  Map<int, List<Map<String, dynamic>>> _childrenByParent() {
    final map = <int, List<Map<String, dynamic>>>{};

    for (final comment in _comments) {
      final parent = comment['parent_id'];
      if (parent == null) continue;

      map.putIfAbsent(_toInt(parent), () => []).add(comment);
    }

    for (final list in map.values) {
      list.sort((a, b) => _date(a).compareTo(_date(b)));
    }

    return map;
  }

  /// Komentar utama, diurutkan sesuai pilihan "Populer" / "Terbaru".
  List<Map<String, dynamic>> _topLevelComments() {
    final ids = _comments.map((c) => _toInt(c['id'])).toSet();

    final list = _comments.where((c) {
      final parent = c['parent_id'];
      return parent == null || !ids.contains(_toInt(parent));
    }).toList();

    if (_sort == 'newest') {
      list.sort((a, b) => _date(b).compareTo(_date(a)));
    } else {
      list.sort((a, b) {
        final likes = _toInt(b['like_count']).compareTo(_toInt(a['like_count']));
        return likes != 0 ? likes : _date(a).compareTo(_date(b));
      });
    }

    return list;
  }

  /// Membuka profil akun yang diketuk (foto / nama penulis dan komentator).
  void _openProfile(String username) {
    if (username.isEmpty || username == 'user') return;

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          token: widget.token,
          currentUser: widget.currentUser,
          username: username,
        ),
      ),
    );
  }

  Widget _avatar(dynamic picture, String username, double size) {
    return UserAvatar(url: picture?.toString(), size: size);
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thrids',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text(
              '$_viewCount kali dilihat',
              style: const TextStyle(color: muted, fontSize: 14),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
            onPressed: () => _soon('notifikasi utas'),
          ),
          IconButton(
            tooltip: 'Lainnya',
            icon: const Icon(Icons.more_horiz, size: 28),
            onPressed: _openPostMenu,
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: separator),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              color: Colors.white,
              backgroundColor: const Color(0xFF242424),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.zero,
                children: [
                  _buildPostHeader(),
                  const Divider(height: 1, color: separator),
                  _buildSortRow(),
                  const Divider(height: 1, color: separator),
                  _buildComments(),
                ],
              ),
            ),
          ),
          _buildReplyBar(),
        ],
      ),
    );
  }

  // ───────────────────────── Postingan utama ─────────────────────────

  Widget _buildPostHeader() {
    final username = (post['username'] ?? 'user').toString();
    final content = (post['content'] ?? '').toString();
    final isMine = username == _myUsername;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _openProfile(username),
                child: _avatar(post['profile_picture'], username, 46),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openProfile(username),
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
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(post['created_at']),
                      style: const TextStyle(color: muted, fontSize: 15),
                    ),
                  ],
                ),
              ),
              if (!isMine)
                OutlinedButton(
                  onPressed: () => _soon('pesan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3A3A)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Kirim Pesan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (content.isNotEmpty)
            LinkifiedText(
              text: content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                height: 1.4,
              ),
              onTapLink: (url) => openLink(
                context,
                url,
                token: widget.token,
                currentUser: widget.currentUser,
              ),
            ),
          PostAttachments(post: post, token: widget.token),
          const SizedBox(height: 16),
          Row(
            children: [
              _postAction(
                post['liked_by_me'] == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                _toInt(post['like_count']),
                color: post['liked_by_me'] == true ? redLike : null,
                onTap: () => _togglePostInteraction(
                  flag: 'liked_by_me',
                  countKey: 'like_count',
                  resultFlag: 'liked',
                  call: (next) => ApiService.setLike(
                    token: widget.token,
                    postId: post['id'],
                    liked: next,
                  ),
                ),
              ),
              const SizedBox(width: 22),
              _postAction(
                Icons.chat_bubble_outline,
                _toInt(post['comment_count']),
                onTap: () => _openReplyPage(null),
              ),
              const SizedBox(width: 22),
              _postAction(
                Icons.repeat,
                _toInt(post['repost_count']),
                color: post['reposted_by_me'] == true ? greenRepost : null,
                onTap: () => _togglePostInteraction(
                  flag: 'reposted_by_me',
                  countKey: 'repost_count',
                  resultFlag: 'reposted',
                  call: (next) => ApiService.setRepost(
                    token: widget.token,
                    postId: post['id'],
                    reposted: next,
                  ),
                ),
              ),
              const SizedBox(width: 22),
              _postAction(Icons.send_outlined, 0, onTap: _sharePost),
            ],
          ),
        ],
      ),
    );
  }

  Widget _postAction(
    IconData icon,
    int count, {
    required VoidCallback onTap,
    Color? color,
  }) {
    final tint = color ?? muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 24),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(color: tint, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────── "Populer" + "Lihat aktivitas" ─────────────────────────

  Widget _buildSortRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _sort = value),
            color: const Color(0xFF242424),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'popular', child: Text('Populer')),
              PopupMenuItem(value: 'newest', child: Text('Terbaru')),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _sort == 'popular' ? 'Populer' : 'Terbaru',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: muted),
              ],
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () => _soon('aktivitas postingan'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lihat aktivitas',
                  style: TextStyle(color: muted, fontSize: 16),
                ),
                Icon(Icons.chevron_right, color: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Komentar ─────────────────────────

  Widget _buildComments() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Text(
            'Belum ada balasan. Jadilah yang pertama!',
            style: TextStyle(color: muted, fontSize: 15),
          ),
        ),
      );
    }

    final children = _childrenByParent();

    return Column(
      children: [
        for (final comment in _topLevelComments()) ...[
          _buildNode(comment, 0, children),
          const Divider(height: 1, color: separator),
        ],
      ],
    );
  }

  /// Satu komentar + balasannya (rekursif).
  /// Komentar utama menampilkan balasan langsungnya; balasan yang punya balasan
  /// lagi menampilkan tombol "Tampilkan balasan".
  Widget _buildNode(
    Map<String, dynamic> comment,
    int depth,
    Map<int, List<Map<String, dynamic>>> children,
  ) {
    final id = _toInt(comment['id']);
    final replies = children[id] ?? const <Map<String, dynamic>>[];
    final isOpen = depth == 0 || _expanded.contains(id);
    final avatarSize = depth == 0 ? 38.0 : 32.0;
    final username = (comment['username'] ?? 'user').toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        depth == 0 ? 16 : 0,
        depth == 0 ? 14 : 6,
        depth == 0 ? 16 : 0,
        depth == 0 ? 8 : 0,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: avatarSize,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _openProfile(username),
                    child: _avatar(
                      comment['profile_picture'],
                      username,
                      avatarSize,
                    ),
                  ),
                  if (replies.isNotEmpty)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.only(top: 6, bottom: 4),
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
                  _buildCommentContent(comment, replies.length),
                  if (replies.isNotEmpty && isOpen)
                    for (final reply in replies)
                      _buildNode(reply, depth + 1, children),
                  if (replies.isNotEmpty && !isOpen)
                    _buildShowRepliesRow(comment, replies),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentContent(Map<String, dynamic> comment, int replyCount) {
    final username = (comment['username'] ?? 'user').toString();
    final isCreator = '${comment['user_id']}' == '${post['user_id']}';
    final liked = comment['liked_by_me'] == true;
    final likes = _toInt(comment['like_count']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: GestureDetector(
                onTap: () => _openProfile(username),
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatTime(comment['created_at']),
              style: const TextStyle(color: muted, fontSize: 15),
            ),
            if (isCreator)
              const Text(
                ' • Pembuat',
                style: TextStyle(color: muted, fontSize: 15),
              ),
            const Spacer(),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _soon('menu komentar'),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.more_horiz, color: muted, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LinkifiedText(
          text: (comment['content'] ?? '').toString(),
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.35),
          onTapLink: (url) => openLink(
            context,
            url,
            token: widget.token,
            currentUser: widget.currentUser,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _commentAction(
              liked ? Icons.favorite : Icons.favorite_border,
              likes,
              color: liked ? redLike : null,
              onTap: () => _toggleCommentLike(comment),
            ),
            const SizedBox(width: 20),
            _commentAction(
              Icons.chat_bubble_outline,
              replyCount,
              onTap: () => _startReply(comment),
            ),
            const SizedBox(width: 20),
            _commentAction(
              Icons.repeat,
              0,
              onTap: () => _soon('posting ulang komentar'),
            ),
            const SizedBox(width: 20),
            _commentAction(
              Icons.send_outlined,
              0,
              onTap: () => _soon('bagikan komentar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _commentAction(
    IconData icon,
    int count, {
    required VoidCallback onTap,
    Color? color,
  }) {
    final tint = color ?? muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 22),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text('$count', style: TextStyle(color: tint, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShowRepliesRow(
    Map<String, dynamic> comment,
    List<Map<String, dynamic>> replies,
  ) {
    final firstUser = (replies.first['username'] ?? 'user').toString();

    return InkWell(
      onTap: () => setState(() => _expanded.add(_toInt(comment['id']))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 22,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: GestureDetector(
                      onTap: () => _openProfile(firstUser),
                      child: _avatar(replies.first['profile_picture'], firstUser, 22),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 2),
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Tampilkan balasan',
              style: TextStyle(color: muted, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Kolom balas ─────────────────────────

  Widget _buildReplyBar() {
    final target = _replyTo;
    final targetName =
        (target?['username'] ?? post['username'] ?? 'user').toString();

    return Container(
      decoration: const BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: separator)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (target != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 0, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Membalas @$targetName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _replyTo = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 18, color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  children: [
                    _avatar(
                      widget.currentUser['profile_picture'] ??
                          widget.currentUser['avatar_url'],
                      _myUsername,
                      34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Balas $targetName...',
                          hintStyle: const TextStyle(color: muted),
                          counterText: '',
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_sending)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_controller.text.trim().isNotEmpty)
                      IconButton(
                        tooltip: 'Kirim',
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                      )
                    else ...[
                      IconButton(
                        tooltip: 'Foto',
                        onPressed: () => _toast('Segera hadir.'),
                        icon: const Icon(Icons.image_outlined,
                            color: Colors.white, size: 28),
                      ),
                      IconButton(
                        tooltip: 'GIF',
                        onPressed: () => _toast('Segera hadir.'),
                        icon: Container(
                          width: 30,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'GIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Perluas',
                        onPressed: () => _openReplyPage(_replyTo),
                        icon: const Icon(Icons.open_in_full_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}