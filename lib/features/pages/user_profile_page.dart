import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/user_content_service.dart';
import 'chat_page.dart' show openChatWithUser;
import 'messages_page.dart';
import 'activity_page.dart' show FollowStore;
import 'widgets/app_nav.dart';
import 'post_detail_page.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/post_attachments.dart';
import 'widgets/user_avatar.dart';

/// Membuka profil sebuah akun (milik orang lain maupun sendiri).
///
///   onTap: () => openUserProfile(
///     context,
///     token: widget.token,
///     currentUser: widget.user,
///     username: post['username'].toString(),
///   ),
Future<void> openUserProfile(
  BuildContext context, {
  required String token,
  required Map<String, dynamic> currentUser,
  required String username,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => UserProfilePage(
        token: token,
        currentUser: currentUser,
        username: username,
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  PROFIL AKUN ORANG LAIN
// ════════════════════════════════════════════════════════════════════

/// Satu balasan milik akun yang sedang dilihat, beserta utas yang dibalas.
class _ReplyItem {
  final Map<String, dynamic> comment;
  final Map<String, dynamic> post;

  const _ReplyItem(this.comment, this.post);
}

class UserProfilePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;
  final String username;

  /// Tombol navigasi bawah yang disorot (3 = Aktivitas, seperti saat dibuka
  /// dari halaman Aktivitas).
  final int navIndex;

  const UserProfilePage({
    super.key,
    required this.token,
    required this.currentUser,
    required this.username,
    this.navIndex = 3,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kTabMuted = Color(0xFF5E5E5E);
  static const kBorder = Color(0xFF2E2E2E);
  static const kIcon = Color(0xFFD6D6D6);

  static const List<String> _tabLabels = [
    'Thrids',
    'Balasan',
    'Media',
    'Postingan ulang',
  ];

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _posts = [];

  /// Semua utas dari server (dipakai untuk mencari balasan akun ini).
  List<Map<String, dynamic>> _allPosts = [];

  List<_ReplyItem> _replies = [];
  bool _repliesLoading = false;
  bool _repliesLoaded = false;

  List<Map<String, dynamic>> _reposts = [];
  bool _repostsLoading = false;
  bool _repostsLoaded = false;
  String? _repostsError;

  bool _loading = true;
  String? _error;
  bool _followBusy = false;
  int _tab = 0;

  final Set<String> _pendingLike = {};

  // ───────────────────────── Helper ─────────────────────────

  String _str(dynamic v) => (v ?? '').toString();

  int _int(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  bool get _isMe => _profile?['is_me'] == true;

  bool get _isFollowing => _profile?['is_following'] == true;

  bool get _followsMe => _profile?['follows_me'] == true;

  /// Permintaan mengikuti sudah dikirim, menunggu persetujuan (akun privat).
  bool get _isRequested => _profile?['is_requested'] == true;

  bool get _locked =>
      _profile?['is_private'] == true && !_isMe && !_isFollowing;

  String get _username => _str(_profile?['username']).isEmpty
      ? widget.username
      : _str(_profile?['username']);

  String get _displayName => _str(_profile?['display_name']).isEmpty
      ? _username
      : _str(_profile?['display_name']);

  String? _avatarOf(dynamic raw) {
    final s = _str(raw);
    return s.isEmpty ? null : ApiService.resolveUrl(s);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _soon(String feature) => _toast('Fitur $feature belum tersedia.');

  String _ago(String raw) {
    final t = DateTime.tryParse(raw)?.toLocal();
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt';
    if (d.inHours < 24) return '${d.inHours} jam';
    if (d.inDays < 7) return '${d.inDays} hari';
    if (d.inDays < 30) return '${d.inDays ~/ 7} mg';
    if (d.inDays < 365) return '${d.inDays ~/ 30} bln';
    return '${d.inDays ~/ 365} thn';
  }

  /// URL gambar tunggal lama (post['image_url']). Foto/video, GIF, stiker,
  /// musik, polling, kutipan, dan lokasi ditampilkan oleh [PostAttachments].
  String? _legacyImage(Map<String, dynamic> post) {
    final v = _str(post['image_url'] ?? post['image'] ?? post['media_url']);
    return v.startsWith('http') ? v : null;
  }

  /// Index postingan paling lama (diberi label "Utas pertama").
  int get _firstPostIndex {
    if (_posts.isEmpty) return -1;

    int? oldest;
    DateTime? oldestDate;
    for (var i = 0; i < _posts.length; i++) {
      final d = DateTime.tryParse(_str(_posts[i]['created_at']));
      if (d == null) return _posts.length - 1;
      if (oldestDate == null || d.isBefore(oldestDate)) {
        oldestDate = d;
        oldest = i;
      }
    }
    return oldest ?? _posts.length - 1;
  }

  // ───────────────────────── Data ─────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final profile = await ApiService.getUserProfile(
        token: widget.token,
        username: widget.username,
      );

      var posts = <Map<String, dynamic>>[];
      var allPosts = <Map<String, dynamic>>[];
      final locked = profile['is_private'] == true &&
          profile['is_me'] != true &&
          profile['is_following'] != true;

      if (!locked) {
        final all = await ApiService.getPosts(token: widget.token);
        allPosts = all;
        final name = _str(profile['username']).toLowerCase();
        posts = all
            .where((p) => _str(p['username']).toLowerCase() == name)
            .toList();
      }

      if (!mounted) return;

      final uname = _str(profile['username']);

      profile['is_following'] == true
          ? FollowStore.usernames.add(uname)
          : FollowStore.usernames.remove(uname);
      profile['is_requested'] == true
          ? FollowStore.requested.add(uname)
          : FollowStore.requested.remove(uname);

      setState(() {
        _profile = profile;
        _posts = posts;
        _allPosts = allPosts;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (silent && _profile != null) {
        _toast('Gagal memperbarui profil.');
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Balasan milik akun ini. Utama: GET /api/posts/user/:username/replies.
  /// Kalau route itu belum dipasang di server, jatuh ke cara lama (ambil
  /// komentar dari 40 utas terbaru lalu disaring berdasarkan username).
  Future<void> _loadReplies({bool force = false}) async {
    if (_repliesLoading || (_repliesLoaded && !force)) return;

    setState(() => _repliesLoading = true);

    try {
      final rows = await UserContentService.getReplies(
        token: widget.token,
        username: _username,
      );

      final items = <_ReplyItem>[];
      for (final row in rows) {
        final post = row['post'];
        if (post is! Map) continue;
        items.add(_ReplyItem(
          Map<String, dynamic>.from(row),
          Map<String, dynamic>.from(post),
        ));
      }

      if (!mounted) return;

      setState(() {
        _replies = items;
        _repliesLoaded = true;
        _repliesLoading = false;
      });
      return;
    } catch (_) {
      // lanjut ke cara lama di bawah
    }

    try {
      final name = _username.toLowerCase();

      final candidates = _allPosts
          .where((p) => _int(p['comment_count']) > 0)
          .toList()
        ..sort((a, b) => _str(b['created_at']).compareTo(_str(a['created_at'])));

      final batch = candidates.take(40).toList();
      final found = <_ReplyItem>[];

      for (var i = 0; i < batch.length; i += 8) {
        final lists = await Future.wait(
          batch.skip(i).take(8).map((p) async {
            try {
              final comments = await ApiService.getComments(
                postId: p['id'] as Object,
                token: widget.token,
              );

              return comments
                  .where((c) => _str(c['username']).toLowerCase() == name)
                  .map((c) => _ReplyItem(c, p))
                  .toList();
            } catch (_) {
              return <_ReplyItem>[];
            }
          }),
        );

        for (final l in lists) {
          found.addAll(l);
        }
      }

      found.sort((a, b) => _str(b.comment['created_at'])
          .compareTo(_str(a.comment['created_at'])));

      if (!mounted) return;

      setState(() {
        _replies = found;
        _repliesLoaded = true;
        _repliesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _repliesLoading = false);
    }
  }

  /// Postingan yang diposting ulang oleh akun ini.
  Future<void> _loadReposts({bool force = false}) async {
    if (_repostsLoading || (_repostsLoaded && !force)) return;

    setState(() {
      _repostsLoading = true;
      _repostsError = null;
    });

    try {
      final posts = await UserContentService.getReposts(
        token: widget.token,
        username: _username,
      );

      if (!mounted) return;

      setState(() {
        _reposts = posts;
        _repostsLoaded = true;
        _repostsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _repostsLoading = false;
        _repostsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Utas lengkap (dengan media, musik, dst.) untuk dibuka di halaman detail.
  Map<String, dynamic> _fullPost(Map<String, dynamic> p) {
    final id = _str(p['id']);

    for (final x in _allPosts) {
      if (_str(x['id']) == id) return x;
    }

    return p;
  }

  /// Ikuti / berhenti mengikuti / batalkan permintaan.
  /// Akun privat: "Ikuti" hanya mengirim permintaan ("Diminta").
  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _followBusy || _isMe) return;

    final unfollow = _isFollowing || _isRequested;

    setState(() => _followBusy = true);

    try {
      final result = await ApiService.setFollow(
        token: widget.token,
        username: _username,
        follow: !unfollow,
      );

      if (!mounted) return;

      final nowFollowing = result['following'] == true;
      final nowRequested = result['requested'] == true;

      nowFollowing
          ? FollowStore.usernames.add(_username)
          : FollowStore.usernames.remove(_username);
      nowRequested
          ? FollowStore.requested.add(_username)
          : FollowStore.requested.remove(_username);

      setState(() {
        profile['is_following'] = nowFollowing;
        profile['is_requested'] = nowRequested;
        profile['followers_count'] = _int(result['followers_count']);
      });

      if (nowRequested) _toast('Permintaan mengikuti terkirim.');

      // Utas akun privat & pengikut bersama berubah setelah ini.
      _load(silent: true);
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final key = _str(post['id']);
    if (!_pendingLike.add(key)) return;

    final was = post['liked_by_me'] == true;
    final old = _int(post['like_count']);

    setState(() {
      post['liked_by_me'] = !was;
      post['like_count'] = was ? (old - 1).clamp(0, 1 << 30) : old + 1;
    });

    try {
      await ApiService.setLike(
        token: widget.token,
        postId: post['id'] as Object,
        liked: !was,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          post['liked_by_me'] = was;
          post['like_count'] = old;
        });
        _toast(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _pendingLike.remove(key);
    }
  }

  Future<void> _openPost(Map<String, dynamic> post) async {
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

    if (mounted) _load(silent: true);
  }

  Future<void> _openList(int initialTab) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FollowListPage(
          token: widget.token,
          currentUser: widget.currentUser,
          username: _username,
          initialTab: initialTab,
        ),
      ),
    );

    if (mounted) _load(silent: true);
  }

  void _onNavTap(int index) {
    // Ikon pesan: buka halaman Pesan.
    if (index == 1) {
      _openMessages();
      return;
    }

    // Lainnya: kembali ke Home.
    AppNav.goHome(context);
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          token: widget.token,
          currentUser: widget.currentUser,
          onNavigate: (index) {
            if (index == 2) {
              _toast('Buka dari beranda untuk membuat utas.');
              return;
            }

            AppNav.goHome(context);
          },
        ),
      ),
    );
  }

  /// Tombol "Kirim Pesan": buka obrolan dengan akun ini.
  void _openChat() {
    openChatWithUser(
      context,
      token: widget.token,
      currentUser: widget.currentUser,
      username: _username,
    );
  }

  /// Membuka profil penulis sebuah utas (dipakai di tab Postingan ulang).
  void _openAuthor(String name) {
    if (name.isEmpty || name.toLowerCase() == _username.toLowerCase()) return;

    openUserProfile(
      context,
      token: widget.token,
      currentUser: widget.currentUser,
      username: name,
    );
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: widget.navIndex,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  /// Baris atas: panah kembali di kiri; cari, Instagram, lonceng, titik tiga di kanan.
  Widget _topBar() {
    Widget icon(IconData data, String tip, String feature, {double size = 30}) {
      return IconButton(
        tooltip: tip,
        icon: Icon(data, size: size),
        color: Colors.white,
        onPressed: () => _soon(feature),
      );
    }

    return SizedBox(
      height: 60,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back_rounded, size: 30),
            color: Colors.white,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          icon(Icons.search_rounded, 'Cari', 'pencarian'),
          icon(Icons.camera_alt_outlined, 'Instagram', 'Instagram', size: 28),
          icon(Icons.notifications_none_rounded, 'Notifikasi', 'notifikasi akun'),
          IconButton(
            tooltip: 'Lainnya',
            onPressed: () => _soon('menu lainnya'),
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.more_horiz_rounded,
                  size: 20, color: Colors.white),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null || _profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Akun tidak ditemukan.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3A3A3A)),
                ),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _load(silent: true);
        if (_tab == 1) await _loadReplies(force: true);
        if (_tab == 3) await _loadReposts(force: true);
      },
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _tabs()),
          ..._tabContent(),
        ],
      ),
    );
  }

  List<Widget> _tabContent() {
    Widget message(IconData? icon, String text) => SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 40, color: kMuted),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );

    if (_locked) {
      return [
        message(
          Icons.lock_outline_rounded,
          _isRequested
              ? 'Akun ini privat.\nPermintaan mengikuti terkirim, menunggu persetujuan.'
              : 'Akun ini privat.\nIkuti dan tunggu disetujui untuk melihat utasnya.',
        ),
      ];
    }

    // Balasan & Postingan ulang milik akun lain belum punya endpoint di server.
    if (_tab == 1) {
      if (_repliesLoading && !_repliesLoaded) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ];
      }

      if (_replies.isEmpty) return [message(null, 'Belum ada balasan.')];

      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _replyTile(_replies[i]),
            childCount: _replies.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ];
    }
    if (_tab == 3) {
      if (_repostsLoading && !_repostsLoaded) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ];
      }

      if (_repostsError != null) return [message(null, _repostsError!)];

      if (_reposts.isEmpty) {
        return [message(null, 'Belum ada postingan ulang.')];
      }

      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _postTile(_reposts[i], reposted: true),
            childCount: _reposts.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ];
    }

    if (_tab == 2) {
      final media = _posts.where((p) {
        final m = p['media'];
        return (m is List && m.isNotEmpty) || _legacyImage(p) != null;
      }).toList();

      if (media.isEmpty) return [message(null, 'Belum ada media.')];

      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _postTile(media[i]),
            childCount: media.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ];
    }

    if (_posts.isEmpty) return [message(null, 'Belum ada utas.')];

    final first = _firstPostIndex;

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _postTile(_posts[i], isFirst: i == first),
          childCount: _posts.length,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  // ───────────────────────── Header ─────────────────────────

  Widget _header() {
    final p = _profile!;
    final bio = _str(p['bio']);
    final mutual = (p['mutual_followers'] is List)
        ? List<Map<String, dynamic>>.from(
            (p['mutual_followers'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (p['is_private'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.lock_outline_rounded,
                                size: 20, color: kMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        bio,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _openList(0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (mutual.isNotEmpty) ...[
                            _mutualAvatars(mutual),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '${_int(p['followers_count'])} pengikut',
                            style: const TextStyle(fontSize: 17, color: kMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              UserAvatar(url: _avatarOf(p['profile_picture']), size: 66),
            ],
          ),
          if (!_isMe) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _followButton()),
                const SizedBox(width: 10),
                Expanded(
                  child: _outlined(
                    'Kirim Pesan',
                    Colors.white,
                    _openChat,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _mutualAvatars(List<Map<String, dynamic>> list) {
    final shown = list.take(3).toList();
    const size = 24.0;
    const step = 16.0;

    return SizedBox(
      width: size + (shown.length - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kBg, width: 1.5),
                ),
                child: UserAvatar(
                  url: _avatarOf(shown[i]['profile_picture']),
                  size: size - 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _outlined(String label, Color color, VoidCallback? onTap) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color,
          side: const BorderSide(color: kBorder),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Mengikuti / Diminta (abu-abu) / Ikuti balik (dia sudah mengikuti saya) / Ikuti.
  Widget _followButton() {
    if (_isFollowing) {
      return _outlined('Mengikuti', kMuted, _followBusy ? null : _toggleFollow);
    }

    if (_isRequested) {
      return _outlined('Diminta', kMuted, _followBusy ? null : _toggleFollow);
    }

    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: _followBusy ? null : _toggleFollow,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF3F5F7),
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          _followsMe ? 'Ikuti balik' : 'Ikuti',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ───────────────────────── Tab ─────────────────────────

  Widget _tabs() {
    return Row(
      children: [
        for (var i = 0; i < _tabLabels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _tab = i);
                if (i == 1) _loadReplies();
                if (i == 3) _loadReposts();
              },
              child: Container(
                height: 56,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tab == i ? Colors.white : kBorder,
                      width: _tab == i ? 1.5 : 1,
                    ),
                  ),
                ),
                child: Text(
                  _tabLabels[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: _tab == i ? Colors.white : kTabMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────── Kartu utas ─────────────────────────

  Widget _postTile(
    Map<String, dynamic> post, {
    bool isFirst = false,
    bool reposted = false,
  }) {
    final liked = post['liked_by_me'] == true;
    final legacy = _legacyImage(post);
    final author =
        _str(post['username']).isEmpty ? _username : _str(post['username']);

    return InkWell(
      onTap: () => _openPost(post),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reposted)
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.repeat_rounded, size: 20, color: kMuted),
                    const SizedBox(width: 10),
                    Text(
                      '$_username memposting ulang',
                      style: const TextStyle(color: kMuted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            if (isFirst)
              const Padding(
                padding: EdgeInsets.only(left: 24, bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.star_border_rounded, size: 22, color: kMuted),
                    SizedBox(width: 10),
                    Text(
                      'Utas pertama',
                      style: TextStyle(color: kMuted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openAuthor(author),
                  child: UserAvatar(
                    url: _avatarOf(post['profile_picture'] ??
                        (reposted ? null : _profile?['profile_picture'])),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: author,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: '  ${_ago(_str(post['created_at']))}',
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 17,
                                  ),
                                ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _soon('menu utas'),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.more_horiz_rounded,
                                  size: 22, color: kMuted),
                            ),
                          ),
                        ],
                      ),
                      if (_str(post['content']).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _str(post['content']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.3,
                          ),
                        ),
                      ],
                      // Foto/video, GIF, stiker, musik, polling, kutipan, lokasi.
                      PostAttachments(post: post, token: widget.token),
                      if (legacy != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            legacy,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _act(
                            liked
                                ? Icons.favorite
                                : Icons.favorite_border_rounded,
                            _int(post['like_count']),
                            () => _toggleLike(post),
                            color: liked ? const Color(0xFFFF3040) : kIcon,
                          ),
                          const SizedBox(width: 20),
                          _act(
                            Icons.chat_bubble_outline_rounded,
                            _int(post['comment_count']),
                            () => _openPost(post),
                          ),
                          const SizedBox(width: 20),
                          _act(
                            Icons.repeat_rounded,
                            _int(post['repost_count']),
                            () => _openPost(post),
                          ),
                          const SizedBox(width: 20),
                          _act(
                            Icons.send_outlined,
                            _int(post['share_count']),
                            () => _soon('bagikan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _replyTile(_ReplyItem r) {
    final c = r.comment;
    final parent = c['parent'];
    final parentAuthor = parent is Map && _str(parent['username']).isNotEmpty
        ? _str(parent['username'])
        : _str(r.post['username']);
    final likes = _int(c['like_count']);

    return InkWell(
      onTap: () => _openPost(_fullPost(r.post)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parentAuthor.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 52, bottom: 6),
                child: Text(
                  'Membalas $parentAuthor',
                  style: const TextStyle(color: kMuted, fontSize: 15),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(url: _avatarOf(_profile?['profile_picture']), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: _username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: '  ${_ago(_str(c['created_at']))}',
                            style: const TextStyle(color: kMuted, fontSize: 17),
                          ),
                        ]),
                      ),
                      if (_str(c['content']).isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _str(c['content']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (likes > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_border_rounded,
                                size: 22, color: kIcon),
                            const SizedBox(width: 6),
                            Text('$likes',
                                style: const TextStyle(
                                    color: kIcon, fontSize: 16)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _act(
    IconData icon,
    int count,
    VoidCallback onTap, {
    Color color = kIcon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text('$count',
                  style: const TextStyle(color: kIcon, fontSize: 17)),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PENGIKUT / MENGIKUTI / BERSAMA (akun orang lain)
//  PENGIKUT / MENGIKUTI / MENUNGGU PERSETUJUAN (akun sendiri)
// ════════════════════════════════════════════════════════════════════

class FollowListPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;
  final String username;

  /// 0 = Pengikut, 1 = Mengikuti, 2 = Bersama / Menunggu persetujuan.
  final int initialTab;

  const FollowListPage({
    super.key,
    required this.token,
    required this.currentUser,
    required this.username,
    this.initialTab = 0,
  });

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kBorder = Color(0xFF2E2E2E);
  static const kField = Color(0xFF262626);

  late final TabController _tab;
  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _mutual = [];
  List<Map<String, dynamic>> _requests = [];

  int _followersCount = 0;
  int _followingCount = 0;

  /// Status terbaru per username (dipakai bersama oleh ketiga tab supaya
  /// tombol selalu sinkron).
  final Map<String, bool> _iFollow = {};
  final Map<String, bool> _followsMe = {};
  final Map<String, bool> _requestedMap = {};

  final Set<String> _busy = {};

  bool _loading = true;
  String? _error;

  String get _me => (widget.currentUser['username'] ?? '').toString();

  bool get _isOwn =>
      widget.username.toLowerCase() == _me.toLowerCase();

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        ApiService.getUserProfile(
          token: widget.token,
          username: widget.username,
        ),
        ApiService.getFollowers(token: widget.token, username: widget.username),
        ApiService.getFollowingOf(
          token: widget.token,
          username: widget.username,
        ),
        // Akun sendiri: permintaan yang menunggu. Akun lain: pengikut bersama.
        _isOwn
            ? ApiService.getFollowRequests(token: widget.token)
            : ApiService.getMutualFollowers(
                token: widget.token,
                username: widget.username,
              ),
      ]);

      if (!mounted) return;

      final profile = results[0] as Map<String, dynamic>;
      final followers = results[1] as List<Map<String, dynamic>>;
      final following = results[2] as List<Map<String, dynamic>>;
      final third = results[3] as List<Map<String, dynamic>>;
      final mutual = _isOwn ? <Map<String, dynamic>>[] : third;
      final requests = _isOwn ? third : <Map<String, dynamic>>[];

      for (final row in [...followers, ...following, ...mutual, ...requests]) {
        final name = (row['username'] ?? '').toString();
        _iFollow[name] = row['is_following'] == true;
        _followsMe[name] = row['follows_me'] == true;
        _requestedMap[name] = row['is_requested'] == true;
      }

      setState(() {
        _followers = followers;
        _following = following;
        _mutual = mutual;
        _requests = requests;
        _followersCount =
            int.tryParse('${profile['followers_count'] ?? 0}') ??
                followers.length;
        _followingCount =
            int.tryParse('${profile['following_count'] ?? 0}') ??
                following.length;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (silent && _followers.isNotEmpty) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ikuti / berhenti mengikuti / batalkan permintaan (akun privat).
  Future<void> _toggle(String name) async {
    if (name.isEmpty || !_busy.add(name)) return;

    final unfollow = _iFollow[name] == true || _requestedMap[name] == true;

    try {
      final result = await ApiService.setFollow(
        token: widget.token,
        username: name,
        follow: !unfollow,
      );

      if (!mounted) return;

      final nowFollowing = result['following'] == true;
      final nowRequested = result['requested'] == true;

      setState(() {
        _iFollow[name] = nowFollowing;
        _requestedMap[name] = nowRequested;
      });

      nowFollowing
          ? FollowStore.usernames.add(name)
          : FollowStore.usernames.remove(name);
      nowRequested
          ? FollowStore.requested.add(name)
          : FollowStore.requested.remove(name);

      if (nowRequested) _toast('Permintaan mengikuti terkirim.');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy.remove(name);
    }
  }

  /// Buka obrolan dengan [name].
  void _openChat(String name) {
    openChatWithUser(
      context,
      token: widget.token,
      currentUser: widget.currentUser,
      username: name,
    );
  }

  /// Terima / hapus permintaan mengikuti ke akun saya.
  Future<void> _respond(String name, {required bool approve}) async {
    final key = 'req:$name';
    if (name.isEmpty || !_busy.add(key)) return;

    try {
      if (approve) {
        await ApiService.approveFollowRequest(
          token: widget.token,
          username: name,
        );
      } else {
        await ApiService.declineFollowRequest(
          token: widget.token,
          username: name,
        );
      }

      if (!mounted) return;

      setState(() => _requests.removeWhere((u) => u['username'] == name));
      _toast(approve ? '$name sekarang mengikuti Anda.' : 'Permintaan dihapus.');

      if (approve) _load(silent: true);
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy.remove(key);
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final thirdLabel = _isOwn ? 'Menunggu persetujuan' : 'Bersama';
    final thirdCount = _isOwn ? _requests.length : _mutual.length;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 1.5,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF5E5E5E),
            dividerColor: kBorder,
            dividerHeight: 1,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            tabs: [
              _tabItem('Pengikut', _followersCount),
              _tabItem('Mengikuti', _followingCount),
              _tabItem(thirdLabel, thirdCount),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _searchField(),
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Tab _tabItem(String label, int count) {
    return Tab(
      height: 66,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _search,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          hintText: 'Cari',
          hintStyle: TextStyle(color: kMuted, fontSize: 17),
          prefixIcon: Icon(Icons.search_rounded, color: kMuted, size: 24),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _content() {
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
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF3A3A3A)),
                ),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tab,
      children: [
        _list(
          _followers,
          tab: 0,
          empty: 'Belum ada pengikut.',
        ),
        _list(
          _following,
          tab: 1,
          empty: 'Belum mengikuti siapa pun.',
        ),
        _isOwn
            ? _list(
                _requests,
                tab: 2,
                empty: 'Tidak ada permintaan yang menunggu persetujuan.',
              )
            : _list(
                _mutual,
                tab: 2,
                empty: 'Belum ada pengikut bersama.',
              ),
      ],
    );
  }

  Widget _list(
    List<Map<String, dynamic>> all, {
    required int tab,
    required String empty,
  }) {
    final q = _search.text.trim().toLowerCase();

    final rows = q.isEmpty
        ? all
        : all.where((u) {
            final name = (u['username'] ?? '').toString().toLowerCase();
            final display = (u['display_name'] ?? '').toString().toLowerCase();
            return name.contains(q) || display.contains(q);
          }).toList();

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: rows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 240,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        q.isEmpty ? empty : 'Tidak ditemukan.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMuted, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: rows.length,
              itemBuilder: (_, i) => _row(rows[i], tab),
            ),
    );
  }

  Widget _row(Map<String, dynamic> u, int tab) {
    final name = (u['username'] ?? '').toString();
    final display = (u['display_name'] ?? '').toString();
    final pic = (u['profile_picture'] ?? '').toString();

    return Column(
      children: [
        InkWell(
          onTap: () => openUserProfile(
            context,
            token: widget.token,
            currentUser: widget.currentUser,
            username: name,
          ).then((_) {
            if (mounted) _load(silent: true);
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                UserAvatar(
                  url: pic.isEmpty ? null : ApiService.resolveUrl(pic),
                  size: 50,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (display.isNotEmpty)
                        Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 17),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _trailing(name, tab) ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 80),
          child: Divider(height: 1, thickness: 1, color: kBorder),
        ),
      ],
    );
  }

  /// Aturan tombol:
  ///  - baris saya sendiri                  -> tanpa tombol
  ///  - akun sendiri, tab Menunggu          -> "Konfirmasi" + hapus
  ///  - akun sendiri, tab Pengikut,
  ///    sudah saya ikuti                    -> "Kirim Pesan"
  ///  - sudah saya ikuti                    -> "Mengikuti"
  ///  - permintaan saya belum disetujui     -> "Diminta"
  ///  - dia mengikuti saya                  -> "Ikuti balik"
  ///  - selain itu                          -> "Ikuti"
  Widget? _trailing(String name, int tab) {
    if (name.toLowerCase() == _me.toLowerCase()) return null;

    if (_isOwn && tab == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(
            'Konfirmasi',
            filled: true,
            color: Colors.black,
            width: 96,
            onTap: () => _respond(name, approve: true),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _respond(name, approve: false),
            child: Container(
              width: 34,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder, width: 1.2),
              ),
              child: const Icon(Icons.close_rounded, size: 20, color: kMuted),
            ),
          ),
        ],
      );
    }

    final following = _iFollow[name] == true;
    final requested = _requestedMap[name] == true;
    final followsMe = _followsMe[name] == true;

    if (_isOwn && tab == 0 && following) {
      return _pill(
        'Kirim Pesan',
        filled: false,
        color: Colors.white,
        onTap: () => _openChat(name),
      );
    }

    if (following) {
      return _pill(
        'Mengikuti',
        filled: false,
        color: kMuted,
        onTap: () => _toggle(name),
      );
    }

    if (requested) {
      return _pill(
        'Diminta',
        filled: false,
        color: kMuted,
        onTap: () => _toggle(name),
      );
    }

    return _pill(
      followsMe ? 'Ikuti balik' : 'Ikuti',
      filled: true,
      color: Colors.black,
      onTap: () => _toggle(name),
    );
  }

  Widget _pill(
    String label, {
    required bool filled,
    required Color color,
    required VoidCallback onTap,
    double width = 112,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFF3F5F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: filled ? null : Border.all(color: kBorder, width: 1.2),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}