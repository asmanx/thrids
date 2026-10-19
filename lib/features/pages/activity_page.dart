import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'messages_page.dart';
import 'widgets/nav_badges.dart';
import 'post_detail_page.dart';
import 'profile_page.dart';
import 'user_profile_page.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/user_avatar.dart';

/// Menyimpan akun yang sudah di-"Ikuti" selama aplikasi berjalan.
///
/// Cache lokal dari daftar akun yang saya ikuti. Sumber kebenarannya ada di
/// server (tabel follows); cache ini diisi ulang setiap Aktivitas dimuat dan
/// diperbarui setiap kali tombol Ikuti ditekan.
class FollowStore {
  static final Set<String> usernames = {};

  /// Akun privat yang permintaannya masih menunggu persetujuan ("Diminta").
  static final Set<String> requested = {};
}

enum ActivityKind { post, follow, request, like, reply, mention, repost }

class ActivityItem {
  final String id;
  final ActivityKind kind;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final DateTime time;

  /// Baris abu-abu di bawah nama (mis. "Saran mengikuti").
  final String subtitle;

  /// Isi teks putih (isi postingan / balasan).
  final String content;
  final String? thumbUrl;

  /// Postingan yang dibuka saat baris ditekan.
  final Map<String, dynamic>? post;

  /// Map yang menyimpan status suka (postingan atau komentar).
  final Map<String, dynamic>? target;

  /// true kalau [target] adalah komentar (bukan postingan).
  final bool commentTarget;

  /// true kalau notifikasi ini belum pernah dibuka.
  final bool unread;

  /// true kalau orang ini mengikuti saya (tombolnya jadi "Ikuti balik").
  final bool followsMe;

  const ActivityItem({
    required this.id,
    required this.kind,
    required this.username,
    required this.displayName,
    required this.time,
    this.avatarUrl,
    this.subtitle = '',
    this.content = '',
    this.thumbUrl,
    this.post,
    this.target,
    this.commentTarget = false,
    this.unread = false,
    this.followsMe = false,
  });
}

/// Halaman Aktivitas.
///
/// Dibuka dari Home lewat tombol navigasi ke-4 (ikon hati). Notifikasi (follow,
/// suka, balasan, penyebutan, posting ulang) diambil dari GET /api/notifications.
class ActivityPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;
  final FutureOr<void> Function()? onCreatePost;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> changes)?
      onUpdateProfile;

  const ActivityPage({
    super.key,
    required this.token,
    required this.user,
    this.onCreatePost,
    this.onUpdateProfile,
  });

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  static const kBg = Color(0xFF101010);
  static const kCard = Color(0xFF1A1A1A);
  static const kMuted = Color(0xFF777777);
  static const kBorder = Color(0xFF3A3A3A);
  static const kDivider = Color(0xFF2A2A2A);
  static const kIcon = Color(0xFFD6D6D6);

  static const List<String> _filters = [
    'Semua',
    'Mengikuti',
    'Percakapan',
    'Penyebutan',
    'Orang yang Anda ikuti',
    'Postingan ulang',
  ];

  static const List<String> _emptyTexts = [
    'Belum ada aktivitas.',
    'Belum ada saran akun untuk diikuti.',
    'Belum ada balasan untuk utas Anda.',
    'Belum ada yang menyebut Anda.',
    'Ikuti beberapa akun untuk melihat aktivitas mereka di sini.',
    'Belum ada yang memposting ulang utas Anda.',
  ];

  final ScrollController _scroll = ScrollController();

  int _filter = 0;
  bool _loading = true;
  String? _error;
  List<ActivityItem> _items = [];

  final Set<String> _pending = {};

  // ───────────────────────── Helper ─────────────────────────

  String get _me => (widget.user['username'] ?? '').toString();

  String _str(dynamic v) => (v ?? '').toString();

  int _int(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  DateTime _timeOf(Map<String, dynamic> m) =>
      DateTime.tryParse(_str(m['created_at']))?.toLocal() ?? DateTime.now();

  String? _avatarOf(dynamic v) {
    final s = _str(v);
    return s.isEmpty ? null : ApiService.resolveUrl(s);
  }

  bool _isFollowed(String username) => FollowStore.usernames.contains(username);

  String _snippet(String text, [int max = 90]) {
    final t = text.replaceAll('\n', ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  String? _thumbOf(Map<String, dynamic> post) {
    String? pick(dynamic v) {
      if (v is String && v.isNotEmpty) return v;
      if (v is Map) {
        for (final k in ['url', 'media_url', 'path', 'file']) {
          final s = _str(v[k]);
          if (s.isNotEmpty) return s;
        }
      }
      return null;
    }

    bool isVideo(String u) {
      final l = u.toLowerCase();
      return l.endsWith('.mp4') ||
          l.endsWith('.mov') ||
          l.endsWith('.webm') ||
          l.endsWith('.mkv');
    }

    final media = post['media'];
    if (media is List) {
      for (final m in media) {
        final u = pick(m);
        if (u != null && !isVideo(u)) return ApiService.resolveUrl(u);
      }
    }

    final single = pick(post['image_url'] ?? post['image'] ?? post['media_url']);
    if (single != null && !isVideo(single)) return ApiService.resolveUrl(single);

    return null;
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt';
    if (d.inHours < 24) return '${d.inHours} jam';
    if (d.inDays < 7) return '${d.inDays} hari';
    if (d.inDays < 30) return '${d.inDays ~/ 7} mg';
    if (d.inDays < 365) return '${d.inDays ~/ 30} bln';
    return '${d.inDays ~/ 365} thn';
  }

  String _sectionOf(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;

    if (diff <= 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '7 hari terakhir';
    if (diff < 30) return '30 hari terakhir';
    return 'Lebih lama';
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _soon(String feature) => _toast('Fitur $feature belum tersedia.');

  // ───────────────────────── Data ─────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _markedRead = false;

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Dua permintaan dijalankan bersamaan.
      final postsFuture = ApiService.getPosts(token: widget.token)
          .catchError((_) => <Map<String, dynamic>>[]);
      final notifs = await ApiService.getNotifications(token: widget.token);
      final posts = await postsFuture;

      // Daftar yang saya ikuti (sumber: server).
      try {
        final state = await ApiService.getFollowState(token: widget.token);
        FollowStore.usernames
          ..clear()
          ..addAll(state.following);
        FollowStore.requested
          ..clear()
          ..addAll(state.requested);
      } catch (_) {}

      // Saran akun untuk diikuti (hanya yang belum diikuti).
      var suggestions = <Map<String, dynamic>>[];
      try {
        suggestions = await ApiService.getSuggestions(token: widget.token);
      } catch (_) {}

      final postById = <String, Map<String, dynamic>>{
        for (final p in posts) _str(p['id']): p,
      };

      final items = <ActivityItem>[];

      // 1) Notifikasi dari server.
      for (final n in notifs) {
        final type = _str(n['type']);
        final actor = _str(n['actor_username']);
        if (actor.isEmpty) continue;

        final post = postById[_str(n['post_id'])];
        final postContent = _str(n['post_content']);
        final commentContent = _str(n['comment_content']);
        final hasComment = _str(n['comment_id']).isNotEmpty;

        late final ActivityKind kind;
        var followsMe = false;
        var subtitle = '';
        var content = '';
        Map<String, dynamic>? target;

        switch (type) {
          case 'follow':
            kind = ActivityKind.follow;
            followsMe = true;
            subtitle = 'Mulai mengikuti Anda';
            break;
          case 'follow_request':
            kind = ActivityKind.request;
            subtitle = 'Meminta untuk mengikuti Anda';
            break;
          case 'follow_accept':
            kind = ActivityKind.follow;
            subtitle = 'Menerima permintaan mengikuti Anda';
            break;
          case 'like':
            kind = ActivityKind.like;
            subtitle = 'Menyukai utas Anda';
            content = _snippet(postContent);
            break;
          case 'comment_like':
            kind = ActivityKind.like;
            subtitle = 'Menyukai balasan Anda';
            content = _snippet(commentContent);
            break;
          case 'repost':
            kind = ActivityKind.repost;
            subtitle = 'Memposting ulang utas Anda';
            content = _snippet(postContent);
            break;
          case 'reply':
            kind = ActivityKind.reply;
            subtitle = _snippet(postContent);
            content = commentContent;
            break;
          case 'mention':
            kind = ActivityKind.mention;
            subtitle = 'Menyebut Anda';
            content = hasComment ? commentContent : postContent;
            // Penyebutan di postingan: tombol suka/komentar bisa dipakai.
            if (!hasComment) target = post;
            break;
          default:
            continue;
        }

        items.add(ActivityItem(
          id: 'n:${_str(n['id'])}',
          kind: kind,
          username: actor,
          displayName: _str(n['actor_display_name']).isEmpty
              ? actor
              : _str(n['actor_display_name']),
          avatarUrl: _avatarOf(n['actor_profile_picture']),
          time: _timeOf(n),
          subtitle: subtitle,
          content: content,
          thumbUrl: post == null ? null : _thumbOf(post),
          post: post,
          target: target,
          unread: n['is_read'] != true,
          followsMe: followsMe,
        ));
      }

      // 2) Utas terbaru dari orang yang saya ikuti.
      final me = _me;
      final followedPosts = posts
          .where((p) =>
              _str(p['username']) != me &&
              FollowStore.usernames.contains(_str(p['username'])))
          .toList()
        ..sort((a, b) => _timeOf(b).compareTo(_timeOf(a)));

      for (final p in followedPosts.take(30)) {
        items.add(ActivityItem(
          id: 'post:${_str(p['id'])}',
          kind: ActivityKind.post,
          username: _str(p['username']),
          displayName: _str(p['display_name']).isEmpty
              ? _str(p['username'])
              : _str(p['display_name']),
          avatarUrl: _avatarOf(p['profile_picture']),
          time: _timeOf(p),
          content: _str(p['content']),
          thumbUrl: _thumbOf(p),
          post: p,
          target: p,
        ));
      }

      // 3) Saran mengikuti.
      var i = 0;
      for (final u in suggestions) {
        final name = _str(u['username']);
        if (name.isEmpty || name == me) continue;

        items.add(ActivityItem(
          id: 'suggest:$name',
          kind: ActivityKind.follow,
          username: name,
          displayName:
              _str(u['display_name']).isEmpty ? name : _str(u['display_name']),
          avatarUrl: _avatarOf(u['profile_picture']),
          time: DateTime.tryParse(_str(u['created_at']))?.toLocal() ??
              DateTime.now().subtract(Duration(hours: i + 1)),
          subtitle: 'Saran mengikuti',
        ));

        i++;
        if (i >= 10) break;
      }

      items.sort((a, b) => b.time.compareTo(a.time));

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });

      // Tandai semua notifikasi sudah dibaca (sorotan "baru" tetap tampil
      // untuk tampilan pertama ini).
      if (!_markedRead) {
        _markedRead = true;
        unawaited(
          ApiService.markAllNotificationsRead(token: widget.token)
              .then<void>((_) => NavBadges.refresh())
              .catchError((_) {}),
        );
      }
    } catch (e) {
      if (!mounted) return;

      if (silent && _items.isNotEmpty) {
        _toast('Gagal memperbarui aktivitas.');
        return;
      }

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ───────────────────────── Filter ─────────────────────────

  List<ActivityItem> get _filtered {
    switch (_filter) {
      case 1:
        return _items
            .where((e) =>
                e.kind == ActivityKind.follow || e.kind == ActivityKind.request)
            .toList();
      case 2:
        return _items.where((e) => e.kind == ActivityKind.reply).toList();
      case 3:
        return _items.where((e) => e.kind == ActivityKind.mention).toList();
      case 4:
        return _items
            .where((e) => e.kind == ActivityKind.post && _isFollowed(e.username))
            .toList();
      case 5:
        return _items.where((e) => e.kind == ActivityKind.repost).toList();
      default:
        return _items;
    }
  }

  List<Object> _rows() {
    final rows = <Object>[];
    String? last;
    for (final it in _filtered) {
      final section = _sectionOf(it.time);
      if (section != last) {
        rows.add(section);
        last = section;
      }
      rows.add(it);
    }
    return rows;
  }

  // ───────────────────────── Aksi ─────────────────────────

  Future<void> _openPost(Map<String, dynamic>? post) async {
    if (post == null) {
      _toast('Utas ini sudah tidak tersedia.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          token: widget.token,
          post: post,
          currentUser: widget.user,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );

    if (!mounted) return;
    _load(silent: true);
  }

  Future<void> _openProfile(String username) async {
    await openUserProfile(
      context,
      token: widget.token,
      currentUser: widget.user,
      username: username,
    );

    // Status ikuti mungkin berubah di halaman profil.
    if (mounted) setState(() {});
  }

  /// Ikuti / berhenti mengikuti / batalkan permintaan (akun privat).
  Future<void> _toggleFollow(String username) async {
    final key = 'follow:$username';
    if (!_pending.add(key)) return;

    final unfollow = FollowStore.usernames.contains(username) ||
        FollowStore.requested.contains(username);

    try {
      final result = await ApiService.setFollow(
        token: widget.token,
        username: username,
        follow: !unfollow,
      );

      if (!mounted) return;

      setState(() {
        if (result['following'] == true) {
          FollowStore.usernames.add(username);
        } else {
          FollowStore.usernames.remove(username);
        }

        if (result['requested'] == true) {
          FollowStore.requested.add(username);
        } else {
          FollowStore.requested.remove(username);
        }
      });

      if (result['requested'] == true) {
        _toast('Permintaan mengikuti terkirim.');
      }
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pending.remove(key);
    }
  }

  /// Menerima / menghapus permintaan mengikuti dari akun lain.
  Future<void> _respondRequest(ActivityItem it, {required bool approve}) async {
    final key = 'req:${it.id}';
    if (!_pending.add(key)) return;

    try {
      if (approve) {
        await ApiService.approveFollowRequest(
          token: widget.token,
          username: it.username,
        );
      } else {
        await ApiService.declineFollowRequest(
          token: widget.token,
          username: it.username,
        );
      }

      if (!mounted) return;

      setState(() => _items.removeWhere((e) => e.id == it.id));
      _toast(approve
          ? '${it.username} sekarang mengikuti Anda.'
          : 'Permintaan dihapus.');

      if (approve) _load(silent: true);
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _toggleLike(ActivityItem it) async {
    final t = it.target;
    if (t == null || t['id'] == null) return;

    final key = 'like:${it.id}';
    if (!_pending.add(key)) return;

    final was = t['liked_by_me'] == true;
    final old = _int(t['like_count']);

    setState(() {
      t['liked_by_me'] = !was;
      t['like_count'] = was ? (old > 0 ? old - 1 : 0) : old + 1;
    });

    try {
      if (it.commentTarget) {
        await ApiService.setCommentLike(
          token: widget.token,
          commentId: t['id'] as Object,
          liked: !was,
        );
      } else {
        await ApiService.setLike(
          token: widget.token,
          postId: t['id'] as Object,
          liked: !was,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          t['liked_by_me'] = was;
          t['like_count'] = old;
        });
        _toast(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _toggleRepost(ActivityItem it) async {
    final t = it.target;
    if (t == null || it.commentTarget || t['id'] == null) {
      _soon('posting ulang');
      return;
    }

    final key = 'repost:${it.id}';
    if (!_pending.add(key)) return;

    final was = t['reposted_by_me'] == true;
    final old = _int(t['repost_count']);

    setState(() {
      t['reposted_by_me'] = !was;
      t['repost_count'] = was ? (old > 0 ? old - 1 : 0) : old + 1;
    });

    try {
      await ApiService.setRepost(
        token: widget.token,
        postId: t['id'] as Object,
        reposted: !was,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          t['reposted_by_me'] = was;
          t['repost_count'] = old;
        });
        _toast(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _createPost() async {
    final callback = widget.onCreatePost;
    if (callback == null) {
      _soon('buat utas');
      return;
    }

    await callback();
    if (!mounted) return;
    _load(silent: true);
  }

  /// Membuka halaman Pesan. Tombol navigasi di halaman Pesan diarahkan kembali
  /// ke alur Aktivitas ini.
  Future<void> _openMessages() async {
    final here = ModalRoute.of(context); // rute Aktivitas ini

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          token: widget.token,
          currentUser: widget.user,
          onNavigate: (index) {
            switch (index) {
              case 0:
                // Tutup Pesan, lalu tutup Aktivitas, sehingga kembali ke Home.
                Navigator.of(context).popUntil((route) => route == here);
                Navigator.of(context).maybePop();
                break;
              case 2:
                _createPost();
                break;
              case 3:
                // Kembali ke Aktivitas (tutup Pesan saja).
                Navigator.of(context).popUntil((route) => route == here);
                break;
              case 4:
                // Tutup Pesan sampai tinggal Aktivitas, lalu ganti dengan Profil.
                // popUntil aman walau Pesan sudah menutup dirinya sendiri
                // (pop() biasa bisa ikut menutup Home).
                Navigator.of(context).popUntil((route) => route == here);
                _onNavTap(4);
                break;
            }
          },
        ),
      ),
    );

    if (mounted) _load(silent: true);
  }

  /// 0 = home, 1 = pesan, 2 = buat postingan, 3 = aktivitas (halaman ini), 4 = profil.
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        // Aktivitas dibuka dari Home, jadi cukup kembali ke Home.
        Navigator.of(context).maybePop();
        break;
      case 1:
        _openMessages();
        break;
      case 2:
        _createPost();
        break;
      case 3:
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        break;
      case 4:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfilePage(
              token: widget.token,
              user: widget.user,
              onCreatePost: widget.onCreatePost,
              onUpdateProfile: widget.onUpdateProfile,
            ),
          ),
        );
        break;
    }
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 3,
        onTap: _onNavTap,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(silent: true),
          color: Colors.white,
          backgroundColor: const Color(0xFF242424),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    'Aktivitas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterBarDelegate(
                  labels: _filters,
                  selected: _filter,
                  onSelect: (i) => setState(() => _filter = i),
                ),
              ),
              ..._buildBody(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ];
    }

    if (_error != null && _items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gagal memuat aktivitas.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _pillButton('Coba lagi', _load),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final rows = _rows();

    if (rows.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _emptyTexts[_filter],
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted, fontSize: 17),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final row = rows[i];
            if (row is String) return _sectionHeader(row);
            return _buildTile(row as ActivityItem);
          },
          childCount: rows.length,
        ),
      ),
    ];
  }

  Widget _pillButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ───────────────────────── Baris aktivitas ─────────────────────────

  Widget _typeIcon(ActivityItem it) {
    switch (it.kind) {
      case ActivityKind.post:
        return const Icon(Icons.lightbulb, size: 21, color: Color(0xFF0A84FF));
      case ActivityKind.follow:
        return const Icon(Icons.person, size: 25, color: Color(0xFF7B3FF2));
      case ActivityKind.request:
        return const Icon(
          Icons.person_add_alt_1_rounded,
          size: 24,
          color: Color(0xFF7B3FF2),
        );
      case ActivityKind.like:
        return const Icon(
          Icons.favorite,
          size: 23,
          color: Color(0xFFFF3040),
        );
      case ActivityKind.reply:
        return const Icon(
          Icons.chat_bubble,
          size: 23,
          color: Color(0xFF1CB0F6),
        );
      case ActivityKind.mention:
        return const Icon(
          Icons.alternate_email_rounded,
          size: 23,
          color: Color(0xFFFF8A1F),
        );
      case ActivityKind.repost:
        return const Icon(
          Icons.repeat_rounded,
          size: 24,
          color: Color(0xFF30C46B),
        );
    }
  }

  Widget _buildTile(ActivityItem it) {
    final followed = _isFollowed(it.username);

    var subtitle = it.subtitle;
    if (it.kind == ActivityKind.post) {
      subtitle = followed ? 'Karena Anda mengikuti' : 'Saran utas';
    }

    // Tombol suka / komentar hanya muncul kalau ada postingan yang bisa disuka.
    final hasActions = it.target != null;

    Widget? trailing;
    if (it.kind == ActivityKind.follow) {
      trailing = _followButton(it.username, followed, followBack: it.followsMe);
    } else if (it.kind == ActivityKind.request) {
      trailing = _requestButtons(it);
    } else if (it.thumbUrl != null) {
      trailing = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          it.thumbUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Container(width: 44, height: 44, color: kCard),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: it.unread ? const Color(0xFF15202B) : Colors.transparent,
          child: InkWell(
          onTap: (it.kind == ActivityKind.follow ||
                  it.kind == ActivityKind.request)
              ? () => _openProfile(it.username)
              : () => _openPost(it.post),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 40,
                  child: Center(child: _typeIcon(it)),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _openProfile(it.username),
                  child: UserAvatar(url: it.avatarUrl, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: it.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '  ${_ago(it.time)}',
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 16),
                        ),
                      ],
                      if (it.content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          it.content,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (hasActions) _actions(it),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Padding(
                    padding: EdgeInsets.only(
                      top: (it.kind == ActivityKind.follow ||
                              it.kind == ActivityKind.request)
                          ? 4
                          : 0,
                    ),
                    child: trailing,
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 54),
          child: Divider(height: 1, thickness: 1, color: kDivider),
        ),
      ],
    );
  }

  /// Ikuti / Ikuti balik / Diminta (menunggu persetujuan) / Mengikuti.
  Widget _followButton(
    String username,
    bool followed, {
    bool followBack = false,
  }) {
    final requested = FollowStore.requested.contains(username);
    final outlined = followed || requested;

    final label = followed
        ? 'Mengikuti'
        : requested
            ? 'Diminta'
            : (followBack ? 'Ikuti balik' : 'Ikuti');

    return GestureDetector(
      onTap: () => _toggleFollow(username),
      child: Container(
        width: 104,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(10),
          border: outlined ? Border.all(color: kBorder) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: outlined ? kMuted : Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Tombol Konfirmasi / Hapus untuk permintaan mengikuti ke akun privat saya.
  Widget _requestButtons(ActivityItem it) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _respondRequest(it, approve: true),
          child: Container(
            width: 104,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Konfirmasi',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _respondRequest(it, approve: false),
          child: Container(
            width: 104,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: kMuted,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(ActivityItem it) {
    final t = it.target;
    final liked = t?['liked_by_me'] == true;
    final likes = _int(t?['like_count']);
    final comments = _int((it.commentTarget ? t : it.post)?['comment_count']);
    final reposts = it.commentTarget ? 0 : _int(t?['repost_count']);
    final reposted = !it.commentTarget && t?['reposted_by_me'] == true;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _act(
            liked ? Icons.favorite : Icons.favorite_border_rounded,
            likes,
            () => _toggleLike(it),
            color: liked ? const Color(0xFFFF3040) : kIcon,
          ),
          const SizedBox(width: 22),
          _act(
            Icons.chat_bubble_outline_rounded,
            comments,
            () => _openPost(it.post),
          ),
          const SizedBox(width: 22),
          _act(
            Icons.repeat_rounded,
            reposts,
            () => _toggleRepost(it),
            color: reposted ? const Color(0xFF30C46B) : kIcon,
          ),
          const SizedBox(width: 22),
          _act(Icons.send_outlined, 0, () => _soon('bagikan')),
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(color: kMuted, fontSize: 15),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Baris filter (Semua, Mengikuti, ...) yang tetap menempel di atas saat scroll.
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  const _FilterBarDelegate({
    required this.labels,
    required this.selected,
    required this.onSelect,
  });

  @override
  double get minExtent => 60;

  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFF101010),
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final active = i == selected;

          return GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF262626) : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active
                      ? const Color(0xFF4A4A4A)
                      : const Color(0xFF3A3A3A),
                ),
              ),
              child: Text(
                labels[i],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) =>
      oldDelegate.selected != selected || oldDelegate.labels != labels;
}