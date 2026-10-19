import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'activity_page.dart';
import 'messages_page.dart';
import 'create_post_page.dart';
import 'profile_page.dart';
import 'user_profile_page.dart';
import 'post_detail_page.dart';
import 'reply_page.dart';
import 'search_users_page.dart';
import 'widgets/app_nav.dart';
import 'widgets/dashed_bubble.dart';
import 'widgets/follow_avatar.dart';
import 'widgets/linkified_text.dart';
import 'widgets/nav_badges.dart';
import 'widgets/note_flow.dart';
import 'widgets/post_actions.dart';
import 'widgets/post_events.dart';
import 'widgets/post_menu_sheet.dart';
import 'widgets/post_attachments.dart';
import 'widgets/share_sheet.dart';
import 'widgets/user_avatar.dart';

class HomePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const HomePage({super.key, required this.token, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  /// Salinan user yang ikut diperbarui setelah edit profil.
  late Map<String, dynamic> _user = Map<String, dynamic>.from(widget.user);

  static const background = Color(0xFF101010);
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);

  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;
  String? errorMessage;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Username yang saya ikuti / yang permintaannya masih menunggu.
  Set<String> _following = {};
  Set<String> _requested = {};

  /// Filter feed dari panel kiri: for_you | following | ghost
  String _feed = 'for_you';

  /// false saat daftar di-scroll ke bawah: navigasi disembunyikan dan
  /// tombol "+" melayang muncul di kanan bawah.
  bool _showNav = true;

  bool _onScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;

    if (n.direction == ScrollDirection.reverse && _showNav) {
      setState(() => _showNav = false);
    } else if (n.direction == ScrollDirection.forward && !_showNav) {
      setState(() => _showNav = true);
    }

    return false;
  }

  /// Disimpan di perangkat saja (belum ada endpoint di backend).
  final Set<String> _saved = {};
  final Set<String> _hiddenIds = {};
  final Set<String> _mutedUsers = {};

  /// Kabar utas yang dihapus (dari Profil, Detail, atau menu di sini).
  StreamSubscription<String>? _deletedSub;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadFollowState();
    _deletedSub = PostEvents.onDeleted.listen(_removePost);

    // Tanda merah di ikon Pesan & Aktivitas (diperiksa berkala).
    NavBadges.start(widget.token);

    // Daftarkan rute Home supaya tombol navigasi di halaman lain bisa kembali
    // ke Home (bukan ke halaman login).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppNav.registerHome(context);
    });
  }

  @override
  void dispose() {
    _deletedSub?.cancel();
    NavBadges.stop();
    super.dispose();
  }

  Future<void> _loadFollowState() async {
    try {
      final state = await ApiService.getFollowState(token: widget.token);

      if (!mounted) return;

      setState(() {
        _following = state.following;
        _requested = state.requested;
      });
    } catch (_) {
      // Tanpa status ikuti, badge tetap tampil sebagai "+".
    }
  }

  /// Data akun terbaru (foto/nama yang diubah lewat Edit profil ikut masuk).
  Map<String, dynamic> get _me => UserSession.merge(_user);

  String get _myUsername => '${_me['username'] ?? ''}';

  List<Map<String, dynamic>> get _visiblePosts {
    final base = posts.where((p) {
      return !_hiddenIds.contains('${p['id']}') &&
          !_mutedUsers.contains('${p['username']}');
    });

    switch (_feed) {
      case 'following':
        return base.where((p) {
          final name = '${p['username']}';
          return name == _myUsername || _following.contains(name);
        }).toList();
      case 'ghost':
        return base.where((p) => p['expires_at'] != null).toList();
      default:
        return base.toList();
    }
  }

  Future<void> _toggleFollow(String username) async {
    final wasFollowing = _following.contains(username);
    final wasRequested = _requested.contains(username);
    final undo = wasFollowing || wasRequested;

    setState(() {
      if (undo) {
        _following.remove(username);
        _requested.remove(username);
      } else {
        _following.add(username);
      }
    });

    try {
      final result = await ApiService.setFollow(
        token: widget.token,
        username: username,
        follow: !undo,
      );

      if (!mounted) return;

      setState(() {
        _following.remove(username);
        _requested.remove(username);

        if (result['requested'] == true) {
          _requested.add(username);
        } else if (result['following'] == true) {
          _following.add(username);
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _following.remove(username);
        _requested.remove(username);
        if (wasFollowing) _following.add(username);
        if (wasRequested) _requested.add(username);
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// [intro] true: tampilkan sheet "Coba" dulu (dari ikon catatan di feed).
  Future<void> _openNote({bool intro = true}) async {
    final posted = await NoteFlow.start(
      context,
      token: widget.token,
      user: _me,
      showIntro: intro,
    );

    if (posted && mounted) {
      _showMessage('Postingan dibagikan.');
      await _loadPosts();
    }
  }

  /// Buang utas yang sudah dihapus dari daftar beranda.
  void _removePost(String id) {
    if (!mounted) return;

    setState(() {
      posts = posts.where((p) => '${p['id']}' != id).toList();
    });
  }

  /// Menu titik tiga. Isinya beda untuk postingan biasa dan catatan.
  Future<void> _openPostMenu(Map<String, dynamic> post) async {
    final id = '${post['id']}';
    final username = '${post['username']}';

    final action = await PostMenuSheet.show(
      context,
      isNote: post['expires_at'] != null,
      isMine: username == _myUsername,
      isSaved: _saved.contains(id),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case PostMenuAction.copyLink:
        await _copyLink(post);
      case PostMenuAction.save:
        final wasSaved = _saved.contains(id);
        setState(() => wasSaved ? _saved.remove(id) : _saved.add(id));
        _showMessage(wasSaved ? 'Dihapus dari simpanan.' : 'Postingan disimpan.');
      case PostMenuAction.notInterested:
        setState(() => _hiddenIds.add(id));
        _showMessage('Postingan disembunyikan.');
      case PostMenuAction.mute:
        setState(() => _mutedUsers.add(username));
        _showMessage('@$username disenyapkan.');
      case PostMenuAction.delete:
        // Hanya muncul di menu postingan sendiri; PostEvents memperbarui daftar.
        await PostActions.deleteWithConfirm(
          context,
          token: widget.token,
          post: post,
        );
      case PostMenuAction.askAi:
      case PostMenuAction.createWithTag:
      case PostMenuAction.pin:
      case PostMenuAction.archive:
      case PostMenuAction.hideCounts:
      case PostMenuAction.postOptions:
      case PostMenuAction.interested:
      case PostMenuAction.restrict:
      case PostMenuAction.block:
      case PostMenuAction.report:
        _showMessage('Segera hadir.');
    }
  }

  /// Titik tiga di pojok kanan setiap postingan.
  Widget _moreButton(Map<String, dynamic> post) {
    // Digeser ke kanan agar menempel di pojok (melewati padding kartu).
    return Transform.translate(
      offset: const Offset(10, 0),
      child: InkWell(
        onTap: () => _openPostMenu(post),
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Icon(Icons.more_horiz, color: muted),
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchUsersPage(token: widget.token, currentUser: _user),
      ),
    );

    if (mounted) _loadFollowState();
  }

  Widget _postAvatar(Map<String, dynamic> post, String username, {double size = 46}) {
    return FollowAvatar(
      url: post['profile_picture']?.toString(),
      size: size,
      showBadge: username != _myUsername,
      isFollowing: _following.contains(username),
      isRequested: _requested.contains(username),
      onAvatarTap: () => _openProfile(username),
      onOpenProfile: () => _openProfile(username),
      onToggleFollow: () => _toggleFollow(username),
    );
  }

  Future<void> _loadPosts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getPosts(token: widget.token);

      if (!mounted) return;

      setState(() {
        posts = result;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _openCreatePost() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          token: widget.token,
          user: _me,
        ),
      ),
    );

    if (!mounted) return;

    setState(() => _user = _me);

    if (result == true) {
      await _loadPosts();
    }
  }

  /// Membuka profil akun yang diketuk (avatar / nama di postingan).
  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          token: widget.token,
          currentUser: _user,
          username: username,
          navIndex: 0, // sorot ikon Home
        ),
      ),
    );
  }

  Future<void> _openMyProfile() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          token: widget.token,
          user: _me,
          onCreatePost: _openCreatePost,
          onUpdateProfile: _updateProfile,
        ),
      ),
    );

    if (!mounted) return;

    // Foto/nama yang baru diganti langsung tampil di beranda.
    setState(() => _user = _me);
    _loadPosts();
  }

  /// Membuka halaman Pesan (ikon kirim di navigasi bawah).
  Future<void> _openMessages() async {
    // Rute Home ini: dipakai untuk menutup Pesan tanpa terlempar ke login.
    final homeRoute = ModalRoute.of(context);

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          token: widget.token,
          currentUser: _me,
          onNavigate: (index) {
            if (index == 2) {
              _openCreatePost();
              return;
            }

            // Tutup Pesan saja (kembali ke Home), lalu buka halaman yang dipilih.
            Navigator.of(context).popUntil((route) => route == homeRoute);

            if (index == 3) _openActivity();
            if (index == 4) _openMyProfile();
          },
        ),
      ),
    );

    // Pesan yang baru dibaca: perbarui tanda merah.
    NavBadges.refresh();
  }

  /// Membuka halaman Aktivitas (ikon hati di navigasi bawah).
  Future<void> _openActivity() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityPage(
          token: widget.token,
          user: _me,
          onCreatePost: _openCreatePost,
          onUpdateProfile: _updateProfile,
        ),
      ),
    );

    // Notifikasi yang baru dibuka: perbarui tanda merah.
    NavBadges.refresh();
  }

  Future<Map<String, dynamic>?> _updateProfile(
    Map<String, dynamic> changes,
  ) async {
    final updated = await ApiService.updateProfile(
      token: widget.token,
      changes: changes,
    );

    if (mounted) {
      setState(() => _user = {..._user, ...updated});
      _loadPosts(); // nama/username di daftar postingan ikut diperbarui
    }

    return updated;
  }

  // ---------------------------------------------------------------------------
  // Interaksi: suka, komentar, posting ulang, bagikan
  // ---------------------------------------------------------------------------

  /// Kunci "jenis:id postingan" yang permintaannya masih berjalan, supaya
  /// ketukan beruntun tidak mengirim permintaan ganda.
  final Set<String> _pending = {};

  int _count(Map<String, dynamic> post, String key) =>
      (post[key] as num?)?.toInt() ?? 0;

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final key = 'like:${post['id']}';

    if (!_pending.add(key)) return;

    final wasLiked = post['liked_by_me'] == true;
    final oldCount = _count(post, 'like_count');

    // Tampilan langsung berubah; dikembalikan bila server menolak.
    setState(() {
      post['liked_by_me'] = !wasLiked;
      post['like_count'] = wasLiked ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1;
    });

    try {
      final result = await ApiService.setLike(
        token: widget.token,
        postId: post['id'],
        liked: !wasLiked,
      );

      if (!mounted) return;

      setState(() {
        post['liked_by_me'] = result['liked'] == true;
        post['like_count'] = _count(result, 'like_count');
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        post['liked_by_me'] = wasLiked;
        post['like_count'] = oldCount;
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _toggleRepost(Map<String, dynamic> post) async {
    final key = 'repost:${post['id']}';

    if (!_pending.add(key)) return;

    final wasReposted = post['reposted_by_me'] == true;
    final oldCount = _count(post, 'repost_count');

    setState(() {
      post['reposted_by_me'] = !wasReposted;
      post['repost_count'] =
          wasReposted ? (oldCount - 1).clamp(0, 1 << 30) : oldCount + 1;
    });

    try {
      final result = await ApiService.setRepost(
        token: widget.token,
        postId: post['id'],
        reposted: !wasReposted,
      );

      if (!mounted) return;

      setState(() {
        post['reposted_by_me'] = result['reposted'] == true;
        post['repost_count'] = _count(result, 'repost_count');
      });

      _showMessage(wasReposted ? 'Posting ulang dibatalkan.' : 'Diposting ulang.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        post['reposted_by_me'] = wasReposted;
        post['repost_count'] = oldCount;
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _openComments(Map<String, dynamic> post) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          token: widget.token,
          post: post,
          currentUser: _user,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  /// Ikon pesawat kertas: lembar share (kirim ke pesan / salin tautan).
  Future<void> _sharePost(Map<String, dynamic> post) {
    return ShareSheet.show(context, token: widget.token, post: post);
  }

  /// Ikon komentar: layar "Balas" untuk membalas utas langsung.
  Future<void> _openReply(Map<String, dynamic> post) async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReplyPage(
          token: widget.token,
          post: post,
          currentUser: _me,
        ),
      ),
    );

    if (posted == true && mounted) {
      setState(() {}); // jumlah komentar sudah diperbarui di `post`
      _showMessage('Balasan dikirim.');
    }
  }

  Future<void> _copyLink(Map<String, dynamic> post) async {
    // Tautan postingan. Ganti alamatnya bila nanti ada halaman web publik.
    final link = '${ApiService.serverUrl}/post/${post['id']}';

    await Clipboard.setData(ClipboardData(text: link));

    _showMessage('Tautan postingan disalin.');
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inSeconds < 60) return 'Baru saja';

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} j';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} h';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: background,
      drawer: _buildDrawer(),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                _buildComposer(),
                Expanded(child: _buildPostList()),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _showNav
                      ? _buildBottomNavigation()
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: IgnorePointer(
                ignoring: _showNav,
                child: AnimatedScale(
                  scale: _showNav ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Material(
                    color: const Color(0xFF303030),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: _openCreatePost,
                      borderRadius: BorderRadius.circular(22),
                      child: const SizedBox(
                        width: 66,
                        height: 62,
                        child: Icon(Icons.add, color: muted, size: 36),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            padding: const EdgeInsets.all(14),
            icon: const _TwoLineMenuIcon(color: muted),
          ),
          const Spacer(),
          const Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '@',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(width: 4),
              Text(
                'thrids',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _openSearch,
            icon: const Icon(Icons.search, color: muted, size: 32),
          ),
        ],
      ),
    );
  }

  /// Panel kiri "Kabar": pilihan feed.
  Widget _buildDrawer() {
    final width = (MediaQuery.of(context).size.width * 0.82).clamp(0.0, 360.0);

    Widget square(IconData icon, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF3A3A3A)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      );
    }

    Widget item(String key, String label, {Widget? trailing, bool last = false}) {
      final selected = _feed == key;

      return InkWell(
        onTap: () {
          setState(() {
            _feed = key;
            _showNav = true;
          });
          Navigator.pop(context);
        },
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: Color(0xFF3A3A3A))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFB5B5B5),
                    fontSize: 19,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      );
    }

    return Drawer(
      width: width,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kabar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showMessage('Segera hadir.'),
                    icon: const Icon(Icons.add_circle_outline,
                        color: muted, size: 30),
                  ),
                  IconButton(
                    onPressed: () => _showMessage('Segera hadir.'),
                    icon: const Icon(Icons.edit_outlined, color: muted, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  square(Icons.favorite_border, () {
                    Navigator.pop(context);
                    _openActivity();
                  }),
                  const SizedBox(width: 14),
                  square(Icons.bookmark_border, () => _showMessage('Segera hadir.')),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: const Color(0xFF3A3A3A)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    item('for_you', 'Untuk Anda'),
                    item('following', 'Mengikuti'),
                    item(
                      'ghost',
                      'Postingan hantu',
                      last: true,
                      trailing: const Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final username = (_user['username'] ?? 'user').toString();
    final initial = username.isEmpty
        ? 'U'
        : username.substring(0, 1).toUpperCase();

    return InkWell(
      onTap: _openCreatePost,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: separator)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(
              initial,
              size: 52,
              picture: _me['avatar_url'] ?? _me['profile_picture'],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Apa yang baru?',
                    style: TextStyle(color: muted, fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: muted, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Gagal memuat postingan.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadPosts,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_visiblePosts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.forum_outlined, color: muted, size: 45),
            SizedBox(height: 12),
            Center(
              child: Text(
                'Belum ada postingan.',
                style: TextStyle(color: muted, fontSize: 16),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Jadilah yang pertama untuk memposting!',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _visiblePosts.length,
        separatorBuilder: (_, _) => const Divider(color: separator, height: 1),
        itemBuilder: (context, index) {
          final post = _visiblePosts[index];

          // Ketuk bagian mana pun di kartu untuk membuka utas + komentarnya.
          // Avatar, nama, titik tiga, ikon aksi, dan video tetap punya
          // ketukan sendiri.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openComments(post),
            child: _buildPost(post),
          );
        },
      ),
      ),
    );
  }

  Widget _buildPost(Map<String, dynamic> post) {
    // Postingan sementara (catatan) tampil sebagai gelembung putus-putus.
    if (post['expires_at'] != null) return _buildTemporaryPost(post);

    final username = (post['username'] ?? 'user').toString();
    final content = (post['content'] ?? '').toString();
    final time = _formatTime(post['created_at']);

    final initial = username.isEmpty
        ? 'U'
        : username.substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _postAvatar(post, username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openProfile(username),
                        child: Text(
                          username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      time,
                      style: const TextStyle(color: muted, fontSize: 13),
                    ),
                    const Spacer(),
                    _moreButton(post),
                  ],
                ),
                const SizedBox(height: 7),
                if (content.isNotEmpty)
                  LinkifiedText(
                    text: content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.45,
                    ),
                    onTapLink: (url) => openLink(
                      context,
                      url,
                      token: widget.token,
                      currentUser: _me,
                    ),
                  ),
                // Foto/video, GIF, stiker, musik, polling, kutipan, lokasi.
                PostAttachments(post: post, token: widget.token),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _action(
                      post['liked_by_me'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      '${_count(post, 'like_count')}',
                      onTap: () => _toggleLike(post),
                      color: post['liked_by_me'] == true
                          ? const Color(0xFFFF3040)
                          : null,
                    ),
                    _action(
                      Icons.chat_bubble_outline,
                      '${_count(post, 'comment_count')}',
                      onTap: () => _openReply(post),
                    ),
                    _action(
                      Icons.repeat,
                      '${_count(post, 'repost_count')}',
                      onTap: () => _toggleRepost(post),
                      color: post['reposted_by_me'] == true
                          ? const Color(0xFF3DDC84)
                          : null,
                    ),
                    _action(
                      Icons.send_outlined,
                      '',
                      onTap: () => _sharePost(post),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _remaining(dynamic value) {
    final end = DateTime.tryParse('$value')?.toLocal();
    if (end == null) return '';

    final left = end.difference(DateTime.now());

    if (left.inSeconds <= 0) return 'Berakhir';
    if (left.inHours >= 1) return '${left.inHours} jam lagi';

    return '${left.inMinutes.clamp(1, 59)} mnt lagi';
  }

  /// Dua wajah kecil di samping ikon suka / balasan (pengganti angka).
  Widget _faces() {
    const face = Icon(
      Icons.sentiment_satisfied_alt_outlined,
      color: Color(0xFF6E6E6E),
      size: 22,
    );

    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [face, SizedBox(width: 2), face],
    );
  }

  /// Postingan sementara (postingan hantu): avatar, gelembung putus-putus,
  /// suka & balasan versi wajah, dan sisa waktu.
  Widget _buildTemporaryPost(Map<String, dynamic> post) {
    final username = (post['username'] ?? 'user').toString();
    final content = (post['content'] ?? '').toString();
    final liked = post['liked_by_me'] == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _postAvatar(post, username),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: () => _openProfile(username),
                        child: Text(
                          username,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _moreButton(post),
                  ],
                ),
                const SizedBox(height: 6),
                DashedBubble(
                  child: LinkifiedText(
                    text: content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.35,
                    ),
                    onTapLink: (url) => openLink(
                      context,
                      url,
                      token: widget.token,
                      currentUser: _me,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _toggleLike(post),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: liked ? const Color(0xFFFF3040) : muted,
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _faces(),
                    const SizedBox(width: 22),
                    InkWell(
                      onTap: () => _openReply(post),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.chat_bubble_outline,
                            color: muted, size: 25),
                      ),
                    ),
                    const SizedBox(width: 4),
                    _faces(),
                    const Spacer(),
                    InkWell(
                      onTap: _openNote,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.sentiment_satisfied_alt_outlined,
                              color: muted,
                              size: 24,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _remaining(post['expires_at']),
                              style: const TextStyle(color: muted, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String letter, {double size = 46, dynamic picture}) {
    return UserAvatar(url: picture?.toString(), size: size);
  }

  Widget _action(
    IconData icon,
    String count, {
    required VoidCallback onTap,
    Color? color,
  }) {
    final tint = color ?? muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 23),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 5),
              Text(count, style: TextStyle(color: tint, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    final icons = [
      Icons.home_filled,
      Icons.send_outlined,
      Icons.add,
      Icons.favorite_border,
      Icons.person_outline,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: separator)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(icons.length, (index) {
          final isSelected = selectedIndex == index;

          return IconButton(
            onPressed: () {
              if (index == 1) {
                _openMessages();
              } else if (index == 2) {
                _openCreatePost();
              } else if (index == 3) {
                _openActivity();
              } else if (index == 4) {
                _openMyProfile();
              } else {
                setState(() {
                  selectedIndex = index;
                });
              }
            },
            icon: NavBadgeIcon(
              index: index,
              child: Icon(
                icons[index],
                size: index == 2 ? 35 : 29,
                color: isSelected ? Colors.white : muted,
              ),
            ),
            style: index == 2
                ? IconButton.styleFrom(
                    backgroundColor: const Color(0xFF303030),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    fixedSize: const Size(58, 52),
                  )
                : null,
          );
        }),
      ),
    );
  }
}

/// Ikon menu dua garis: atas panjang, bawah lebih pendek (rata kiri).
class _TwoLineMenuIcon extends StatelessWidget {
  final Color color;

  const _TwoLineMenuIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    Widget line(double width) => Container(
          width: width,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return SizedBox(
      width: 30,
      height: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [line(30), const SizedBox(height: 8), line(19)],
      ),
    );
  }
}