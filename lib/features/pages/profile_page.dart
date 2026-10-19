import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import 'activity_page.dart';
import 'edit_profile_page.dart';
import 'insight_page.dart';
import 'messages_page.dart';
import 'post_detail_page.dart';
import 'profile_search_page.dart';
import 'settings_page.dart';
import 'user_profile_page.dart';
import 'widgets/followers_summary.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/dashed_circle_button.dart';
import 'widgets/note_flow.dart';
import 'widgets/post_actions.dart';
import 'widgets/post_attachments.dart';
import 'widgets/post_events.dart';
import 'widgets/post_menu_sheet.dart';
import 'widgets/replies_tab.dart';
import 'widgets/logout_dialog.dart';
import 'widgets/user_avatar.dart';

/// Menyimpan data user terbaru selama aplikasi berjalan.
///
/// ProfilePage dibuat ulang setiap kali kamu pindah halaman, dan saat itu ia
/// menerima lagi data user lama dari luar (mis. dari login). Tanpa ini, foto
/// profil / nama / bio yang baru diubah akan "kembali" ke data lama.
/// Panggil [UserSession.clear] saat logout.
class UserSession {
  static final Map<String, Map<String, dynamic>> _latest = {};

  static String _key(Map<String, dynamic> user) =>
      (user['id'] ?? user['username'] ?? '').toString();

  /// Gabungkan data user dari luar dengan perubahan terbaru yang tersimpan.
  static Map<String, dynamic> merge(Map<String, dynamic> base) {
    final saved = _latest[_key(base)];
    return saved == null
        ? Map<String, dynamic>.from(base)
        : <String, dynamic>{...base, ...saved};
  }

  /// [original] = user awal (pembentuk kunci), [updated] = user terbaru.
  static void save(
    Map<String, dynamic> original,
    Map<String, dynamic> updated,
  ) {
    _latest[_key(original)] = Map<String, dynamic>.from(updated);
  }

  static void clear() => _latest.clear();
}

class ProfilePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  /// Dipanggil saat user menekan "Apa yang baru?" atau "Mulai utas pertama Anda".
  /// Isi dengan navigasi ke halaman buat postingan milikmu. Setelah selesai
  /// (Future selesai), daftar utas otomatis dimuat ulang.
  final FutureOr<void> Function()? onCreatePost;

  /// Dipanggil saat user menekan "Selesai" di Edit profil. Menerima hanya
  /// field yang berubah (display_name, username, bio, interests, links,
  /// podcast_url, show_instagram_badge, show_recent_views, is_private).
  /// Kirim ke backend, lalu kembalikan Map user terbaru (opsional).
  /// Lempar exception kalau gagal.
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> changes)?
      onUpdateProfile;

  /// Dipanggil saat user memilih Logout / Beralih akun di Pengaturan.
  /// Isi dengan navigasi ke halaman login. Kalau null, semua halaman ditutup
  /// sampai halaman pertama.
  final VoidCallback? onLogout;

  const ProfilePage({
    super.key,
    required this.token,
    required this.user,
    this.onCreatePost,
    this.onUpdateProfile,
    this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  // ── warna ──
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kTabMuted = Color(0xFF5E5E5E);
  static const kBorder = Color(0xFF2E2E2E);
  static const kCard = Color(0xFF181818);
  static const kAvatarBg = Color(0xFF383838);
  static const kIcon = Color(0xFFD6D6D6);

  late final TabController _tab;

  /// Postingan yang diposting ulang oleh akun ini (tab "Postingan ulang").
  List<Map<String, dynamic>> _reposts = [];

  /// Pengikut terbaru (avatar kecil di samping tombol pengikut).
  List<Map<String, dynamic>> _recentFollowers = [];
  bool _repostsLoading = true;
  String? _repostsError;

  final Set<String> _pendingTile = {};

  /// Kabar utas yang dihapus (dari Beranda, Detail, atau menu di sini).
  StreamSubscription<String>? _deletedSub;

  /// Untuk memuat ulang tab Balasan dari luar (mis. setelah komen di detail).
  final GlobalKey<RepliesTabState> _repliesKey = GlobalKey<RepliesTabState>();

  /// Semua postingan dari backend (dipakai untuk saran akun).
  List<Map<String, dynamic>> _allPosts = [];

  /// Hanya postingan milik akun yang login.
  List<Map<String, dynamic>> posts = [];

  /// Salinan user yang bisa berubah setelah edit profil.
  late Map<String, dynamic> _user = UserSession.merge(widget.user);

  bool isLoading = true;
  String? errorMessage;

  // Status lokal untuk kartu "Disarankan untuk Anda".
  final Set<String> _dismissed = {};
  final Set<String> _following = {};

  /// Akun privat yang permintaannya masih menunggu persetujuan.
  final Set<String> _requested = {};

  /// Akun yang sudah saya ikuti saat halaman dibuka (tidak ditampilkan lagi
  /// di "Disarankan untuk Anda").
  final Set<String> _followedAtLoad = {};

  // ───────────────────────── Data user ─────────────────────────

  String get username => (_user['username'] ?? 'user').toString();

  String get displayName =>
      (_user['display_name'] ?? username).toString();

  String get bio => (_user['bio'] ?? '').toString();

  bool get isPrivate => _user['is_private'] == true;

  /// URL foto profil (path server dilengkapi otomatis); null = pakai avatar bawaan.
  String? get avatarUrl {
    final raw =
        (_user['avatar_url'] ?? _user['profile_picture'] ?? '').toString();
    return raw.isEmpty ? null : ApiService.resolveUrl(raw);
  }

  int get followersCount =>
      int.tryParse('${_user['followers_count'] ?? 0}') ?? 0;

  String get initial => username.isEmpty ? 'U' : username[0].toUpperCase();

  String? _validUrl(dynamic v) {
    final s = (v ?? '').toString();
    return s.startsWith('http') ? s : null;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _deletedSub = PostEvents.onDeleted.listen(_onPostDeleted);
    _loadPosts();
    _loadReposts();
    _loadFollowInfo();
  }

  @override
  void dispose() {
    _deletedSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  // ───────────────────────── Hapus postingan ─────────────────────────

  /// Buang utas yang sudah dihapus dari semua daftar di profil.
  void _onPostDeleted(String id) {
    if (!mounted) return;

    bool keep(Map<String, dynamic> p) => '${p['id']}' != id;

    setState(() {
      posts = posts.where(keep).toList();
      _allPosts = _allPosts.where(keep).toList();
      _reposts = _reposts.where(keep).toList();
    });

    _repliesKey.currentState?.reload(silent: true);
  }

  /// Menu titik tiga di kartu postingan profil.
  Future<void> _openPostMenu(Map<String, dynamic> post) async {
    final author = '${post['username'] ?? username}';
    final isMine = author == username;

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
        if (isMine) {
          await PostActions.deleteWithConfirm(
            context,
            token: widget.token,
            post: post,
          );
        }
      default:
        _toast('Segera hadir.');
    }
  }

  // ───────────────────────── Backend ─────────────────────────

  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final result = await ApiService.getPosts(token: widget.token);

      if (!mounted) return;

      setState(() {
        _allPosts = result.toList();

        // Hanya tampilkan postingan milik akun yang login.
        posts = result.where((post) {
          return (post['username'] ?? '').toString() == username;
        }).toList();

        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      // Saat pull-to-refresh gagal tapi data lama masih ada, jangan hapus data.
      if (silent && posts.isNotEmpty) {
        _toast('Gagal memperbarui postingan.');
        return;
      }

      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadReposts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _repostsLoading = true;
        _repostsError = null;
      });
    }

    try {
      final result = await ApiService.getMyReposts(token: widget.token);

      if (!mounted) return;

      setState(() {
        _reposts = result;
        _repostsLoading = false;
        _repostsError = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (silent && _reposts.isNotEmpty) return;

      setState(() {
        _repostsLoading = false;
        _repostsError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Jumlah pengikut terbaru + daftar akun yang sudah saya ikuti (dari server).
  Future<void> _loadFollowInfo() async {
    try {
      final profile = await ApiService.getUserProfile(
        token: widget.token,
        username: username,
      );
      final state = await ApiService.getFollowState(token: widget.token);
      final following = state.following;

      if (!mounted) return;

      setState(() {
        _user['followers_count'] = profile['followers_count'];
        _recentFollowers = FollowersSummary.parse(profile['recent_followers']);
        _user['following_count'] = profile['following_count'];
        _followedAtLoad
          ..clear()
          ..addAll(following);
        _following
          ..clear()
          ..addAll(following);
        _requested
          ..clear()
          ..addAll(state.requested);
        FollowStore.usernames
          ..clear()
          ..addAll(following);
        FollowStore.requested
          ..clear()
          ..addAll(state.requested);
      });
    } catch (_) {
      // Gagal memuat info follow tidak boleh merusak halaman profil.
    }
  }

  /// Ikuti / berhenti mengikuti dari kartu "Disarankan untuk Anda".
  Future<void> _toggleSuggestion(String target) async {
    final key = 'follow:$target';
    if (!_pendingTile.add(key)) return;

    final unfollow =
        _following.contains(target) || _requested.contains(target);

    try {
      final result = await ApiService.setFollow(
        token: widget.token,
        username: target,
        follow: !unfollow,
      );

      if (!mounted) return;

      final nowFollowing = result['following'] == true;
      final nowRequested = result['requested'] == true;

      setState(() {
        nowFollowing ? _following.add(target) : _following.remove(target);
        nowRequested ? _requested.add(target) : _requested.remove(target);
      });

      nowFollowing
          ? FollowStore.usernames.add(target)
          : FollowStore.usernames.remove(target);
      nowRequested
          ? FollowStore.requested.add(target)
          : FollowStore.requested.remove(target);

      if (nowRequested) _toast('Permintaan mengikuti terkirim.');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pendingTile.remove(key);
    }
  }

  void _openOtherProfile(String target) {
    openUserProfile(
      context,
      token: widget.token,
      currentUser: _user,
      username: target,
    ).then((_) {
      if (mounted) _loadFollowInfo();
    });
  }

  Future<void> _openFollowList(bool followers) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FollowListPage(
          token: widget.token,
          currentUser: _user,
          username: username,
          initialTab: followers ? 0 : 1,
        ),
      ),
    );

    if (mounted) _loadFollowInfo();
  }

  /// Suka / posting ulang dari kartu postingan di profil.
  Future<void> _toggleTile(
    Map<String, dynamic> post, {
    required bool repost,
  }) async {
    final flag = repost ? 'reposted_by_me' : 'liked_by_me';
    final countKey = repost ? 'repost_count' : 'like_count';
    final key = '$flag:${post['id']}';

    if (!_pendingTile.add(key)) return;

    final was = post[flag] == true;
    final old = int.tryParse('${post[countKey] ?? 0}') ?? 0;

    setState(() {
      post[flag] = !was;
      post[countKey] = was ? (old - 1).clamp(0, 1 << 30) : old + 1;
    });

    try {
      final result = repost
          ? await ApiService.setRepost(
              token: widget.token,
              postId: post['id'],
              reposted: !was,
            )
          : await ApiService.setLike(
              token: widget.token,
              postId: post['id'],
              liked: !was,
            );

      if (!mounted) return;

      setState(() {
        post[flag] = result[repost ? 'reposted' : 'liked'] == true;
        post[countKey] = int.tryParse('${result[countKey] ?? 0}') ?? 0;
      });

      if (repost) _loadReposts(silent: true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        post[flag] = was;
        post[countKey] = old;
      });

      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _pendingTile.remove(key);
    }
  }

  Future<void> _openEditProfile() async {
    final oldUsername = username;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          token: widget.token,
          user: _user,
          onSave: widget.onUpdateProfile,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _user = Map<String, dynamic>.from(result));
    UserSession.save(widget.user, _user);

    _toast(
      widget.onUpdateProfile == null
          ? 'Perubahan hanya tersimpan di tampilan ini (belum terhubung ke server).'
          : 'Profil diperbarui.',
    );

    // Username berubah → muat ulang agar filter postingan ikut menyesuaikan.
    if (username != oldUsername) _loadPosts(silent: true);
  }

  Future<void> _createPost() async {
    final callback = widget.onCreatePost;
    if (callback == null) {
      _soon('buat utas');
      return;
    }

    await callback();
    if (!mounted) return;
    _loadPosts(silent: true);
  }

  // ───────────────────────── Catatan, pencarian, pengaturan ─────────────────────────

  /// Tombol + di foto profil: alur catatan yang sama seperti di beranda.
  Future<void> _addNote() async {
    final posted = await NoteFlow.start(
      context,
      token: widget.token,
      user: _user,
    );

    if (posted && mounted) _loadPosts(silent: true);
  }

  Future<void> _openInsight() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InsightPage(token: widget.token, posts: posts),
      ),
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProfileSearchPage(
          token: widget.token,
          currentUser: _user,
          myPosts: posts,
          allPosts: _allPosts,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          isPrivate: isPrivate,
          onPrivateChanged: _setPrivate,
          onLogout: _logout,
        ),
      ),
    );
  }

  Future<void> _setPrivate(bool value) async {
    final old = _user['is_private'];

    setState(() => _user['is_private'] = value);

    try {
      final save = widget.onUpdateProfile;

      if (save != null) {
        final updated = await save({'is_private': value});
        if (updated != null && mounted) {
          setState(() => _user = Map<String, dynamic>.from(updated));
        }
      }

      UserSession.save(widget.user, _user);
    } catch (e) {
      if (!mounted) return;

      setState(() => _user['is_private'] = old);
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Keluar dari akun. Kalau pemanggil memberi [ProfilePage.onLogout], itu yang
  /// dijalankan; kalau tidak, kembali ke halaman Pilih akun dan semua halaman
  /// sebelumnya ditutup.
  void _logout() {
    final callback = widget.onLogout;

    if (callback != null) {
      UserSession.clear();
      callback();
    } else {
      performLogout(context);
    }
  }

  // ───────────────────────── Navigasi ─────────────────────────

  /// Membuka halaman Pesan. Tombol navigasi di halaman Pesan diarahkan kembali
  /// ke alur Profil ini.
  Future<void> _openMessages() async {
    final here = ModalRoute.of(context); // rute Profil ini

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessagesPage(
          token: widget.token,
          currentUser: _user,
          onNavigate: (index) {
            switch (index) {
              case 0:
                // Tutup Pesan, lalu tutup Profil, sehingga kembali ke Home.
                Navigator.of(context).popUntil((route) => route == here);
                Navigator.of(context).maybePop();
                break;
              case 2:
                _createPost();
                break;
              case 3:
                // Tutup Pesan sampai tinggal Profil, lalu ganti Profil dengan
                // Aktivitas. popUntil aman walau Pesan sudah menutup dirinya
                // sendiri (pop() biasa bisa ikut menutup Home).
                Navigator.of(context).popUntil((route) => route == here);
                _onNavTap(3);
                break;
              case 4:
                // Kembali ke Profil (tutup Pesan saja).
                Navigator.of(context).popUntil((route) => route == here);
                break;
            }
          },
        ),
      ),
    );

    if (mounted) _loadPosts(silent: true);
  }

  /// 0 = home, 1 = pesan, 2 = buat postingan, 3 = aktivitas, 4 = profil (halaman ini).
  void _onNavTap(int index) {
    switch (index) {
      case 0:
        // Profil dibuka dari Home, jadi cukup kembali ke Home.
        Navigator.of(context).maybePop();
        break;
      case 1:
        _openMessages();
        break;
      case 2:
        _createPost();
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ActivityPage(
              token: widget.token,
              user: _user,
              onCreatePost: widget.onCreatePost,
              onUpdateProfile: widget.onUpdateProfile,
            ),
          ),
        );
        break;
    }
  }

  /// Membuka halaman penuh sebuah postingan beserta komentarnya.
  Future<void> _openPost(Map<String, dynamic> post) async {
    await Navigator.of(context).push<void>(
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

    if (!mounted) return;
    _repliesKey.currentState?.reload(silent: true);
    _loadReposts(silent: true);
  }

  // ───────────────────────── Helper ─────────────────────────

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _soon(String feature) => _toast('Fitur $feature belum tersedia.');

  String _formatTime(String raw) {
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return raw;

    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt';
    if (diff.inHours < 24) return '${diff.inHours} j';
    if (diff.inDays < 7) return '${diff.inDays} h';

    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return date.year == now.year ? '$mm/$dd' : '$mm/$dd/${date.year % 100}';
  }

  /// Index postingan paling lama (diberi label "Utas pertama").
  int get _firstPostIndex {
    if (posts.isEmpty) return -1;

    int? oldest;
    DateTime? oldestDate;
    for (var i = 0; i < posts.length; i++) {
      final d = DateTime.tryParse((posts[i]['created_at'] ?? '').toString());
      if (d == null) return posts.length - 1;
      if (oldestDate == null || d.isBefore(oldestDate)) {
        oldestDate = d;
        oldest = i;
      }
    }
    return oldest ?? posts.length - 1;
  }

  List<({String username, String name, String? avatar})> get _suggestions {
    final seen = <String>{};
    final list = <({String username, String name, String? avatar})>[];

    for (final p in _allPosts) {
      final u = (p['username'] ?? '').toString();
      if (u.isEmpty ||
          u == username ||
          _dismissed.contains(u) ||
          _followedAtLoad.contains(u)) {
        continue;
      }
      if (!seen.add(u)) continue;

      list.add((
        username: u,
        name: (p['display_name'] ?? u).toString(),
        avatar: (p['profile_picture'] ?? '').toString().isEmpty
            ? null
            : ApiService.resolveUrl(p['profile_picture'].toString()),
      ));
      if (list.length >= 10) break;
    }
    return list;
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onTap: _onNavTap,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          // Baris ikon atas: tetap menempel saat scroll (seperti screenshot).
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: kBg,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            toolbarHeight: 60,
            leadingWidth: 64,
            leading: IconButton(
              tooltip: 'Insight',
              icon: const Icon(Icons.bar_chart_rounded, size: 30),
              color: Colors.white,
              onPressed: _openInsight,
            ),
            actions: [
              IconButton(
                tooltip: 'Cari',
                icon: const Icon(Icons.search_rounded, size: 30),
                color: Colors.white,
                onPressed: _openSearch,
              ),
              IconButton(
                tooltip: 'Pengaturan',
                icon: const Icon(Icons.settings_outlined, size: 30),
                color: Colors.white,
                onPressed: _openSettings,
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tab,
                indicatorColor: Colors.white,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 1.5,
                labelColor: Colors.white,
                unselectedLabelColor: kTabMuted,
                dividerColor: kBorder,
                dividerHeight: 1,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(height: 56, text: 'Thrids'),
                  Tab(height: 56, text: 'Balasan'),
                  Tab(height: 56, text: 'Media'),
                  Tab(
                    height: 56,
                    child: Text('Postingan ulang', textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _buildThreadsTab(),
            RepliesTab(
              key: _repliesKey,
              token: widget.token,
              currentUser: _user,
              allPosts: _allPosts,
            ),
            _buildMediaTab(),
            _buildRepostsTab(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Header profil ─────────────────────────

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: kMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username,
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
                    FollowersSummary(
                      count: followersCount,
                      recent: _recentFollowers,
                      onTap: () => _openFollowList(true),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 112,
                height: 96,
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: _showAvatar,
                        child: _avatar(82, 34, url: avatarUrl),
                      ),
                    ),
                    // Tombol + (lingkaran putus-putus) di kiri bawah foto.
                    Positioned(
                      left: 14,
                      top: 58,
                      child: DashedCircleButton(size: 30, onTap: _addNote),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _outlinedButton('Edit profil', _openEditProfile),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _outlinedButton('Lihat insight', _openInsight),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 46,
                child: OutlinedButton(
                  style: _outlineStyle,
                  onPressed: _showShareSheet,
                  child: const Icon(Icons.ios_share_rounded, size: 24),
                ),
              ),
            ],
          ),
        ),
        _buildSuggestions(),
      ],
    );
  }

  ButtonStyle get _outlineStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: kBorder),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      );

  Widget _outlinedButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        style: _outlineStyle,
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _avatar(double size, double fontSize, {String? url, String? letter}) {
    return UserAvatar(url: url, size: size);
  }

  // ───────────────────────── Disarankan untuk Anda ─────────────────────────

  Widget _buildSuggestions() {
    final items = _suggestions;
    if (items.isEmpty) return const SizedBox(height: 16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Text(
            'Disarankan untuk Anda',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _suggestionCard(items[i]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _suggestionCard(({String username, String name, String? avatar}) s) {
    final following = _following.contains(s.username);
    final requested = _requested.contains(s.username);

    return Container(
      width: 148,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _dismissed.add(s.username)),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 16, color: kMuted),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openOtherProfile(s.username),
            child: _suggestionAvatar(s),
          ),
          const SizedBox(height: 8),
          Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: (following || requested)
                ? OutlinedButton(
                    style: _outlineStyle,
                    onPressed: () => _toggleSuggestion(s.username),
                    child: Text(
                      requested ? 'Diminta' : 'Mengikuti',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  )
                : FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF4F4F6),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _toggleSuggestion(s.username),
                    child: const Text(
                      'Ikuti',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionAvatar(({String username, String name, String? avatar}) s) {
    return UserAvatar(url: s.avatar, size: 68);
  }

  // ───────────────────────── Tab Thrids ─────────────────────────

  Widget _buildThreadsTab() {
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
              const Text(
                'Gagal memuat postingan.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _pillButton('Coba lagi', _loadPosts),
            ],
          ),
        ),
      );
    }

    // Belum ada utas → tombol "Mulai utas pertama Anda".
    if (posts.isEmpty) {
      return _refreshable(
        builder: (height) => SizedBox(
          height: height,
          child: Center(
            child: _pillButton('Mulai utas pertama Anda', _createPost),
          ),
        ),
      );
    }

    // Sudah ada utas → komposer + daftar utas.
    final firstIndex = _firstPostIndex;

    return RefreshIndicator(
      onRefresh: () => _loadPosts(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: ListView.builder(
        key: const PageStorageKey('threads'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: posts.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) return _buildComposer();
          final index = i - 1;
          return _buildPostTile(posts[index], isFirst: index == firstIndex);
        },
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF3A3A3A)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildComposer() {
    return InkWell(
      onTap: _createPost,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(
          children: [
            _avatar(42, 18, url: avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Apa yang baru?',
                    style: TextStyle(color: kMuted, fontSize: 17),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostTile(Map<String, dynamic> post, {required bool isFirst, bool reposted = false}) {
    final content = (post['content'] ?? '').toString();
    final time = _formatTime((post['created_at'] ?? '').toString());
    final imageUrl =
        _validUrl(post['image_url'] ?? post['image'] ?? post['media_url']);
    final likes = int.tryParse('${post['like_count'] ?? 0}') ?? 0;
    final liked = post['liked_by_me'] == true;
    final repostCount = int.tryParse('${post['repost_count'] ?? 0}') ?? 0;
    final isReposted = post['reposted_by_me'] == true;

    // Penulis postingan (di tab Postingan ulang bisa milik orang lain).
    final author = (post['username'] ?? username).toString();
    final authorLetter = author.isEmpty ? 'U' : author[0].toUpperCase();
    final authorPicture = (post['profile_picture'] ?? '').toString();
    final authorUrl = author == username
        ? avatarUrl
        : (authorPicture.isEmpty ? null : ApiService.resolveUrl(authorPicture));

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reposted)
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 14, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 20, color: kMuted),
                  SizedBox(width: 12),
                  Text(
                    'Anda memposting ulang',
                    style: TextStyle(color: kMuted, fontSize: 15),
                  ),
                ],
              ),
            ),
          if (isFirst)
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 14, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.star_border_rounded, size: 22, color: kMuted),
                  SizedBox(width: 12),
                  Text(
                    'Utas pertama',
                    style: TextStyle(color: kMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, (isFirst || reposted) ? 12 : 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(42, 18, url: authorUrl, letter: authorLetter),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _openPostMenu(post),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.more_horiz,
                                color: kMuted,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        time,
                        style: const TextStyle(color: kMuted, fontSize: 17),
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
                      // Foto/video, GIF, stiker, musik, polling, kutipan, lokasi.
                      PostAttachments(post: post, token: widget.token),
                      if (imageUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 220,
                                color: kCard,
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (_, _, _) => Container(
                              height: 120,
                              color: kCard,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: kMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _postAction(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: liked ? const Color(0xFFFF3040) : kIcon,
                            label: likes > 0 ? '$likes' : null,
                            onTap: () => _toggleTile(post, repost: false),
                          ),
                          const SizedBox(width: 20),
                          _postAction(
                            Icons.mode_comment_outlined,
                            label: (int.tryParse('${post['comment_count'] ?? 0}') ?? 0) > 0
                                ? '${post['comment_count']}'
                                : null,
                            onTap: () => _openPost(post),
                          ),
                          const SizedBox(width: 20),
                          _postAction(
                            Icons.repeat_rounded,
                            color: isReposted
                                ? const Color(0xFF3DDC84)
                                : kIcon,
                            label: repostCount > 0 ? '$repostCount' : null,
                            onTap: () => _toggleTile(post, repost: true),
                          ),
                          const SizedBox(width: 20),
                          _postAction(Icons.send_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postAction(
    IconData icon, {
    Color color = kIcon,
    String? label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap ?? () => _soon('interaksi postingan'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Tab Media ─────────────────────────

  /// Postingan milik akun ini yang membawa foto atau video.
  Widget _buildMediaTab() {
    final mediaPosts = posts.where((post) {
      final media = post['media'];
      return media is List && media.isNotEmpty;
    }).toList();

    if (mediaPosts.isEmpty) {
      return _buildEmptyTab('Anda belum memposting media apapun');
    }

    return RefreshIndicator(
      onRefresh: () => _loadPosts(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: ListView.builder(
        key: const PageStorageKey('media'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: mediaPosts.length,
        itemBuilder: (_, i) => _buildPostTile(mediaPosts[i], isFirst: false),
      ),
    );
  }

  // ───────────────────────── Tab Postingan ulang ─────────────────────────

  Widget _buildRepostsTab() {
    if (_repostsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_repostsError != null && _reposts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gagal memuat postingan ulang.',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                _repostsError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _pillButton('Coba lagi', _loadReposts),
            ],
          ),
        ),
      );
    }

    if (_reposts.isEmpty) {
      return _buildEmptyTab('Anda belum memposting ulang utas apapun');
    }

    return RefreshIndicator(
      onRefresh: () => _loadReposts(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: ListView.builder(
        key: const PageStorageKey('reposts'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _reposts.length,
        itemBuilder: (_, i) =>
            _buildPostTile(_reposts[i], isFirst: false, reposted: true),
      ),
    );
  }

  // ───────────────────────── Tab kosong lain ─────────────────────────

  Widget _buildEmptyTab(String text) {
    return _refreshable(
      builder: (height) => SizedBox(
        height: height,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 17),
            ),
          ),
        ),
      ),
    );
  }

  /// Konten yang selalu bisa di-pull-to-refresh walau pendek.
  Widget _refreshable({required Widget Function(double height) builder}) {
    return RefreshIndicator(
      onRefresh: () => _loadPosts(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [builder(constraints.maxHeight)],
        ),
      ),
    );
  }

  // ───────────────────────── Aksi ─────────────────────────

  void _showAvatar() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Center(child: _avatar(260, 110, url: avatarUrl)),
        ),
      ),
    );
  }

  void _showShareSheet() {
    final url = 'https://www.thrids.net/@$username';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF242424),
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 28),
                _avatar(96, 40, url: avatarUrl),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: const TextStyle(color: kMuted, fontSize: 15),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF303030),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ListTile(
                    title: const Text(
                      'Salin tautan',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: const Icon(
                      Icons.link_rounded,
                      color: Colors.white,
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!mounted) return;
                      _toast('Tautan profil disalin');
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
// ───────────────────────── Delegate TabBar (pinned) ─────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFF101010),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}