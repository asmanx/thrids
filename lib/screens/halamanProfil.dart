// ignore_for_file: camel_case_types, non_constant_identifier_names

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../komponenBersama.dart';

// ───────────────────────── Halaman Profil ─────────────────────────

class halamanProfil extends StatefulWidget {
  const halamanProfil({super.key});

  @override
  State<halamanProfil> createState() => halamanProfilState();
}

class halamanProfilState extends State<halamanProfil>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final mine = app.mine;
          final media = mine.where((t) => t.hasMedia).toList();
          final reposts = app.thrids.where((t) => t.reposted).toList();
          return NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(child: _header(context)),
              SliverPersistentHeader(
                pinned: true,
                delegate: tabBarDelegate(
                  TabBar(
                    controller: _tab,
                    indicatorColor: Colors.white,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 1.5,
                    labelColor: Colors.white,
                    unselectedLabelColor: kMuted,
                    dividerColor: kBorder,
                    labelStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                    tabs: const [
                      Tab(text: 'Thrids'),
                      Tab(text: 'Balasan'),
                      Tab(text: 'Media'),
                      Tab(text: 'Postingan Ulang'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tab,
              children: [
                _postList(mine,
                    key: 'thrids',
                    emptyAction: true,
                    emptyText: 'Belum ada utas'),
                _repliesList(),
                _postList(media,
                    key: 'media',
                    emptyText: 'Anda belum memposting ulang media apapun'),
                _postList(reposts,
                    key: 'reposts',
                    emptyText: 'Anda belum memposting ulang utas apapun'),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── header ──

  Widget _header(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Insight',
                icon: const Icon(Icons.bar_chart_rounded, size: 30),
                onPressed: () => _push(const halamanInsights()),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Cari',
                icon: const Icon(Icons.search_rounded, size: 30),
                onPressed: () => _push(const halamanPencarian()),
              ),
              IconButton(
                tooltip: 'Pengaturan',
                icon: const Icon(Icons.settings_outlined, size: 30),
                onPressed: () => _push(const halamanPengaturan()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(app.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w700)),
                        ),
                        if (app.isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.lock_outline_rounded,
                                size: 18, color: kMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(app.username,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    if (app.bio.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(app.bio, style: const TextStyle(fontSize: 15)),
                    ],
                    if (app.link.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () =>
                            copyText(context, app.link, 'Tautan disalin'),
                        child: Text(app.link,
                            style: const TextStyle(fontSize: 14, color: kBlue)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _followersRow(context),
                  ],
                ),
              ),
              SizedBox(
                width: 168,
                height: 112,
                child: Stack(
                  children: [
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _showAvatar(context),
                        child: avatarFoto(
                            size: 88,
                            color: app.avatarColor,
                            foto: tambahan.fotoBytes),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 52,
                      width: 128,
                      child: _noteBubble(context),
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
                  child: _outlined(
                      'Edit profil', () => _push(const halamanEditProfil()))),
              const SizedBox(width: 10),
              Expanded(
                  child: _outlined(
                      'Lihat Insight', () => _push(const halamanInsights()))),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 46,
                child: OutlinedButton(
                  style: _outlineStyle,
                  onPressed: () => _shareSheet(context),
                  child: const Icon(Icons.ios_share_rounded, size: 24),
                ),
              ),
            ],
          ),
        ),
        _suggestions(context),
      ],
    );
  }

  ButtonStyle get _outlineStyle => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: kBorder),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _outlined(String label, VoidCallback onTap) => SizedBox(
        height: 46,
        child: OutlinedButton(
          style: _outlineStyle,
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _followersRow(BuildContext context) {
    final n = app.followers.length;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _push(const halamanPengikut()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (n > 0)
            SizedBox(
              width: n == 1 ? 24 : 40,
              height: 24,
              child: Stack(
                children: [
                  avatar(
                      size: 24,
                      color: avatarColors[3],
                      label: app.followers[0]),
                  if (n > 1)
                    Positioned(
                      left: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kBg, width: 2),
                        ),
                        child: avatar(
                            size: 24,
                            color: avatarColors[2],
                            label: app.followers[1]),
                      ),
                    ),
                ],
              ),
            ),
          if (n > 0) const SizedBox(width: 8),
          Text('$n pengikut',
              style: const TextStyle(fontSize: 16, color: kMuted)),
        ],
      ),
    );
  }

  Widget _noteBubble(BuildContext context) {
    final has = app.note.isNotEmpty;
    return GestureDetector(
      onTap: () => _editNote(context),
      child: CustomPaint(
        foregroundPainter:
            dashedBorderPainter(color: const Color(0xFF6A6A6A), radius: 24),
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF181818),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(has ? app.note : 'Catatan…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15, color: has ? Colors.white : kMuted)),
              ),
              Icon(has ? Icons.edit_outlined : Icons.add_rounded,
                  size: has ? 18 : 26, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestions(BuildContext context) {
    if (app.suggestions.isEmpty) return const SizedBox(height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
          child: Text('Disarankan untuk Anda',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: kMuted)),
        ),
        SizedBox(
          height: 180,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: ListView.separated(
              primary: false,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: app.suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final s = app.suggestions[i];
                return Container(
                  width: 144,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => app.dismissSuggestion(s),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: kMuted),
                          ),
                        ),
                      ),
                      Stack(
                        children: [
                          avatar(size: 56, color: s.color, label: s.name),
                          if (s.verified)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: kCard, shape: BoxShape.circle),
                                child: const verifiedBadge(size: 18),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(s.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: kMuted)),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: s.following
                            ? OutlinedButton(
                                style: _outlineStyle,
                                onPressed: () => app.toggleFollow(s),
                                child: const Text('Mengikuti',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                              )
                            : FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => app.toggleFollow(s),
                                child: const Text('Ikuti',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // ── isi tab ──

  Widget _postList(List<thridsPost> items,
      {required String key, bool emptyAction = false, String? emptyText}) {
    return Builder(
      builder: (context) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emptyText ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kMuted, fontSize: 17)),
                if (emptyAction) ...[
                  const SizedBox(height: 16),

                ],
              ],
            ),
          );
        }
        return ListView.builder(
          key: PageStorageKey(key),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (_, i) =>
              postTile(post: items[i], showRepostLabel: key == 'reposts'),
        );
      },
    );
  }

  Widget _repliesList() {
    if (app.replies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Anda belum memposting ulang balasan apapun',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMuted, fontSize: 17)),
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('replies'),
      padding: EdgeInsets.zero,
      itemCount: app.replies.length,
      itemBuilder: (_, i) {
        final r = app.replies[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatarFoto(
                  size: 40, color: app.avatarColor, foto: tambahan.fotoBytes),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Membalas @${r.toHandle} · ${timeAgo(r.time)}',
                        style: const TextStyle(color: kMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(r.text, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── aksi ──

  void _showAvatar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
              child: avatarFoto(
                  size: 260,
                  color: app.avatarColor,
                  foto: tambahan.fotoBytes)),
        ),
      ),
    );
  }

  void _editNote(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const halamanCatatanBaru(),
      ),
    );
  }

  
  void _shareSheet(BuildContext context) {
  final url = 'https://www.thrids.net/@${app.username}';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF242424),
    barrierColor: Colors.black.withOpacity(0.55),
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
              // Garis kecil di bagian atas
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 28),

              // QR Code profil
              QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: const Color(0xFF242424),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.white,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),

              // Username
              Text(
                app.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Download dan Scan
              Row(
                children: [
                  Expanded(
                    child: _aksiProfil(
                      icon: Icons.download_rounded,
                      label: 'Download',
                      onTap: () => toast(context, 'Fitur download belum tersedia'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _aksiProfil(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan',
                      onTap: () => toast(context, 'Fitur scan belum tersedia'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Menu Salin Tautan dan Bagikan
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF303030),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Salin tautan',
                          style: TextStyle(color: Colors.white)),
                      trailing:
                          const Icon(Icons.link_rounded, color: Colors.white),
                      onTap: () {
                        Navigator.pop(ctx);
                        copyText(context, url, 'Tautan profil disalin');
                      },
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    ListTile(
                      title: const Text('Bagikan ke',
                          style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.ios_share_rounded,
                          color: Colors.white),
                      onTap: () {
                        Navigator.pop(ctx);
                        copyText(context, url, 'Tautan profil disalin');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  // Widget tombol Download dan Scan
  Widget _aksiProfil({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF303030),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class tabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  tabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: kBg, child: tabBar);

  @override
  bool shouldRebuild(covariant tabBarDelegate old) => false;
}

// ───────────────────────── Pengikut & Mengikuti ─────────────────────────

// Urutan kapan seseorang mulai diikuti. Dicatat saat pertama kali terlihat
// di halaman ini (semakin besar angkanya = semakin baru diikuti).
final Map<String, int> _urutanIkuti = {};
int _hitunganIkuti = 0;

// Akun yang sudah diikuti sejak awal. Sengaja terpisah dari app.suggestions
// supaya daftar saran hanya berisi akun yang BELUM diikuti.
final List<suggested> _diikutiAwal = [
  suggested('Ros Blekping', 'Ros', false, avatarColors[1])..following = true,
  suggested('Jeni Blekping', 'Jeni', false, avatarColors[3])..following = true,
  suggested('Jisu Blekping', 'Jisu', true, avatarColors[4])..following = true,
  suggested('Lilis Blekping', 'GeuLis', true, avatarColors[2])..following = true,
];

class halamanPengikut extends StatefulWidget {
  final int tabAwal; // 0 = Pengikut, 1 = Mengikuti
  const halamanPengikut({super.key, this.tabAwal = 0});

  @override
  State<halamanPengikut> createState() => halamanPengikutState();
}

class halamanPengikutState extends State<halamanPengikut>
    with SingleTickerProviderStateMixin {
  late final TabController _tab =
      TabController(length: 2, vsync: this, initialIndex: widget.tabAwal);
  final _cari = TextEditingController();
  String _q = '';
  int _urut = 0; // 0 Default (terbaru dulu), 1 Terbaru dulu, 2 Paling awal dulu
  final List<dynamic> _batalIkuti = []; // akun yang di-unfollow di halaman ini

  @override
  void dispose() {
    for (final s in _batalIkuti) {
      if (!s.following) _urutanIkuti.remove(s.handle);
    }
    _tab.dispose();
    _cari.dispose();
    super.dispose();
  }

  // Default = terbaru dulu. Daftar pengikut diasumsikan tersimpan dari yang
  // paling lama ke yang paling baru; kalau di app urutannya terbalik,
  // tukar nilai ini.
  bool get _terbaruDulu => _urut != 2;

  Widget _tombolPesan() => SizedBox(
      height: 38,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const halamanKirimPesan(
                nama: 'Pengguna',
                username: 'pengguna',
                warnaAvatar: Colors.blue,
              ),
            ),
          );
        },
        child: const Text(
          'Kirim pesan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

  Widget _menuTitikTiga(String teks, VoidCallback aksi) =>
      PopupMenuButton<int>(
        icon: const Icon(Icons.more_horiz_rounded, color: kMuted),
        color: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (_) => aksi(),
        itemBuilder: (_) => [
          PopupMenuItem<int>(
            value: 0,
            child: Row(
              children: [
                Expanded(
                    child: Text(teks, style: const TextStyle(fontSize: 17))),
                const SizedBox(width: 24),
                const Icon(Icons.person_remove_outlined),
              ],
            ),
          ),
        ],
      );

  Widget _baris({
    required Widget foto,
    required String judul,
    String? sub,
    required List<Widget> aksi,
  }) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
        child: Row(
          children: [
            foto,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (sub != null)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, color: kMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ...aksi,
          ],
        ),
      );

  Widget _kosong(String teks) => Center(
        child: Text(teks, style: const TextStyle(color: kMuted, fontSize: 16)),
      );

  // ───────── tab Pengikut ─────────

  Widget _tabPengikut(List<String> semua) {
    var daftar = semua
        .where((f) => f.toLowerCase().contains(_q))
        .toList(); // urutan asli: paling lama -> paling baru
    if (_terbaruDulu) daftar = daftar.reversed.toList();
    if (daftar.isEmpty) {
      return _kosong(semua.isEmpty ? 'Belum ada pengikut' : 'Tidak ada hasil');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final f in daftar)
          _baris(
            foto: avatar(
                size: 48,
                color: avatarColors[f.length % avatarColors.length],
                label: f),
            judul: f,
            aksi: [_tombolPesan(), const SizedBox(width: 12)],
          ),
      ],
    );
  }

  // ───────── tab Mengikuti ─────────

  // Dialog konfirmasi sebelum berhenti mengikuti.
  Future<bool?> _konfirmasiBerhenti(dynamic s) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF2A2A2A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 32),
            avatar(size: 100, color: s.color, label: s.name),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 18),
                  children: [
                    const TextSpan(text: 'Berhenti mengikuti '),
                    TextSpan(
                        text: s.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(text: '?'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            const Divider(height: 1, thickness: 1, color: kBorder),
            InkWell(
              onTap: () => Navigator.pop(ctx, true),
              child: const SizedBox(
                height: 56,
                child: Center(
                  child: Text('Berhenti mengikuti',
                      style: TextStyle(
                          color: Color(0xFFFF3040),
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1, color: kBorder),
            InkWell(
              onTap: () => Navigator.pop(ctx, false),
              child: const SizedBox(
                height: 56,
                child: Center(
                  child: Text('Batal', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tombolIkuti(dynamic s) => SizedBox(
        height: 38,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            app.toggleFollow(s); // diikuti lagi -> jumlah Mengikuti bertambah
            setState(() => _batalIkuti.remove(s));
          },
          child: const Text('Ikuti',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _tabMengikuti(List<dynamic> semua) {
    // Akun yang baru saja di-unfollow tetap tampil, dengan tombol "Ikuti".
    final sisaBatal =
        _batalIkuti.where((s) => !s.following && !semua.contains(s)).toList();
    var daftar = [...semua, ...sisaBatal]
        .where((s) =>
            s.name.toLowerCase().contains(_q) ||
            s.handle.toLowerCase().contains(_q))
        .toList();
    daftar.sort((a, b) =>
        (_urutanIkuti[a.handle] ?? 0).compareTo(_urutanIkuti[b.handle] ?? 0));
    if (_terbaruDulu) daftar = daftar.reversed.toList();
    if (daftar.isEmpty) {
      return _kosong((semua.isEmpty && sisaBatal.isEmpty)
          ? 'Belum mengikuti siapa pun'
          : 'Tidak ada hasil');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final s in daftar)
          _baris(
            foto: avatar(size: 48, color: s.color, label: s.name),
            judul: s.name,
            sub: s.handle,
            aksi: s.following
                ? [
                    _tombolPesan(),
                    _menuTitikTiga('Berhenti mengikuti', () async {
                      final ya = await _konfirmasiBerhenti(s);
                      if (ya != true || !mounted) return;
                      setState(() => _batalIkuti.add(s));
                      app.toggleFollow(s);
                    }),
                  ]
                : [_tombolIkuti(s), const SizedBox(width: 12)],
          ),
      ],
    );
  }

  // ───────── urutkan ─────────

  void _lembarUrut() {
    const pilihan = ['Default', 'Terbaru dulu', 'Paling awal dulu'];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < pilihan.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, thickness: 1, color: kBorder),
                      InkWell(
                        onTap: () {
                          setState(() => _urut = i);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(pilihan[i],
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Icon(
                                _urut == i
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 30,
                                color: _urut == i ? Colors.white : kMuted,
                              ),
                            ],
                          ),
                        ),
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

  // ───────── tampilan ─────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final pengikut = List<String>.from(app.followers);
        final mengikuti = [
          ..._diikutiAwal.where((s) => s.following),
          ...app.suggestions.where((s) => s.following),
        ];
        for (final s in mengikuti) {
          _urutanIkuti.putIfAbsent(s.handle, () => _hitunganIkuti++);
        }

        Widget judulTab(String nama, int jumlah) => Tab(
              height: 60,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nama,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('$jumlah', style: const TextStyle(fontSize: 15)),
                ],
              ),
            );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
            titleSpacing: 0,
            title: Text(app.username,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            actions: [
              TextButton(
                onPressed: _lembarUrut,
                child: const Text('Urutkan',
                    style: TextStyle(color: Colors.white, fontSize: 17)),
              ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorWeight: 1.5,
              labelColor: Colors.white,
              unselectedLabelColor: kMuted,
              dividerColor: kBorder,
              tabs: [
                judulTab('Pengikut', pengikut.length),
                judulTab('Mengikuti', mengikuti.length),
              ],
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _cari,
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Cari',
                    hintStyle: const TextStyle(color: kMuted, fontSize: 17),
                    prefixIcon: const Icon(Icons.search_rounded, color: kMuted),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [_tabPengikut(pengikut), _tabMengikuti(mengikuti)],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── Edit profil ─────────────────────────

// Data tambahan khusus halaman Edit profil (minat, podcast, dua saklar).
// Disimpan di sini supaya komponenBersama.dart tidak perlu diubah.
class profilTambahan {
  String minat = '';
  String podcast = '';
  bool tampilkanLencanaInstagram = true;
  bool tampilkanTayanganTerbaru = true;
  Uint8List? fotoBytes; // foto profil dari galeri (null = pakai avatar bawaan)
}

final profilTambahan tambahan = profilTambahan();

// Menampilkan foto dari galeri kalau ada, kalau tidak pakai avatar bawaan.
class avatarFoto extends StatelessWidget {
  final double size;
  final Color color;
  final Uint8List? foto;
  const avatarFoto({
    super.key,
    required this.size,
    required this.color,
    required this.foto,
  });

  @override
  Widget build(BuildContext context) {
    if (foto == null) return avatar(size: size, color: color, label: null);
    return ClipOval(
      child: Image.memory(foto!, width: size, height: size, fit: BoxFit.cover),
    );
  }
}

// Latar "sheet" sedikit lebih terang dari kartu.
const _latarSheet = Color(0xFF181818);

class halamanEditProfil extends StatefulWidget {
  const halamanEditProfil({super.key});

  @override
  State<halamanEditProfil> createState() => halamanEditProfilState();
}

class halamanEditProfilState extends State<halamanEditProfil> {
  late final _nama = TextEditingController(text: app.name);
  late final _namaPengguna = TextEditingController(text: app.username);
  late final _bio = TextEditingController(text: app.bio);
  late final _podcast = TextEditingController(text: tambahan.podcast);
  late String _minat = tambahan.minat;
  late String _tautan = app.link;
  late int _indeksWarna = app.avatarColorIndex;
  late Uint8List? _foto = tambahan.fotoBytes;
  late bool _lencanaInstagram = tambahan.tampilkanLencanaInstagram;
  late bool _tayanganTerbaru = tambahan.tampilkanTayanganTerbaru;
  late bool _privat = app.isPrivate;

  @override
  void dispose() {
    _nama.dispose();
    _namaPengguna.dispose();
    _bio.dispose();
    _podcast.dispose();
    super.dispose();
  }

  void _simpan() {
    if (_nama.text.trim().isEmpty || _namaPengguna.text.trim().isEmpty) {
      toast(context, 'Nama dan nama pengguna tidak boleh kosong');
      return;
    }
    // Data tambahan disimpan lebih dulu, supaya saat app.updateProfile
    // memberi tahu pendengarnya, halaman profil sudah membaca foto terbaru.
    tambahan.minat = _minat.trim();
    tambahan.podcast = _podcast.text.trim();
    tambahan.tampilkanLencanaInstagram = _lencanaInstagram;
    tambahan.tampilkanTayanganTerbaru = _tayanganTerbaru;
    tambahan.fotoBytes = _foto;
    app.updateProfile(
      name: _nama.text.trim(),
      username: _namaPengguna.text.trim().replaceAll(' ', ''),
      bio: _bio.text.trim(),
      link: _tautan.trim(),
      colorIndex: _indeksWarna,
      isPrivate: _privat,
    );
    Navigator.pop(context);
    toast(context, 'Profil diperbarui');
  }

  // ───────── komponen kecil ─────────

  Widget _garis() => const Divider(height: 1, thickness: 1, color: kBorder);

  Widget _judul(String teks) =>
      Text(teks, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));

  Widget _padding(Widget isi) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: isi);

  Widget _kolomIsian({
    required String judul,
    required TextEditingController pengendali,
    required String petunjuk,
    bool banyakBaris = false,
    TextInputType? jenisKeyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _judul(judul),
        const SizedBox(height: 4),
        TextField(
          controller: pengendali,
          keyboardType: jenisKeyboard,
          maxLines: banyakBaris ? null : 1,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 4),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: petunjuk,
            hintStyle: const TextStyle(color: kMuted, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _barisSaklar({
    required String judul,
    String? keterangan,
    required bool nilai,
    required ValueChanged<bool> saatBerubah,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _judul(judul),
              if (keterangan != null) ...[
                const SizedBox(height: 4),
                Text(keterangan,
                    style: const TextStyle(fontSize: 14, color: kMuted, height: 1.3)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: nilai,
          onChanged: saatBerubah,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : const Color(0xFF3A3A3A),
          ),
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? const Color(0xFF1A1A1A) : Colors.white,
          ),
        ),
      ],
    );
  }

  // ───────── lembar edit ─────────

  void _lembarTeks({
    required String judul,
    required String awal,
    required String petunjuk,
    required ValueChanged<String> saatSimpan,
    TextInputType? jenisKeyboard,
  }) {
    final c = TextEditingController(text: awal);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(judul, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: jenisKeyboard,
              decoration: InputDecoration(
                hintText: petunjuk,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    saatSimpan('');
                    Navigator.pop(ctx);
                  },
                  child: const Text('Hapus', style: TextStyle(color: kRed)),
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: () {
                    saatSimpan(c.text.trim());
                    Navigator.pop(ctx);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _lembarPrivasi() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Privasi profil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final pilihan in const [
              ('Publik', false, 'Siapa saja bisa melihat utas dan balasan Anda.'),
              ('Privat', true, 'Hanya pengikut yang bisa melihat utas dan balasan Anda.'),
            ])
              ListTile(
                title: Text(pilihan.$1),
                subtitle: Text(pilihan.$3, style: const TextStyle(color: kMuted)),
                trailing: _privat == pilihan.$2
                    ? const Icon(Icons.check_rounded, color: kBlue)
                    : null,
                onTap: () {
                  setState(() => _privat = pilihan.$2);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pilihDariGaleri() async {
    try {
      final berkas = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (berkas == null) return;
      final bytes = await berkas.readAsBytes();
      if (!mounted) return;
      setState(() => _foto = bytes);
    } catch (_) {
      if (mounted) toast(context, 'Tidak bisa membuka galeri');
    }
  }

  Widget _barisLembar({
    required IconData ikon,
    required String teks,
    required VoidCallback saatDitekan,
    Color warna = Colors.white,
  }) {
    return InkWell(
      onTap: saatDitekan,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Row(
          children: [
            Icon(ikon, size: 28, color: warna),
            const SizedBox(width: 18),
            Text(teks,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600, color: warna)),
          ],
        ),
      ),
    );
  }

  // Lembar pilihan foto profil: "Pilih dari galeri" dan "Hapus".
  void _lembarAvatar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF555555),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    _barisLembar(
                      ikon: Icons.image_outlined,
                      teks: 'Pilih dari galeri',
                      saatDitekan: () {
                        Navigator.pop(ctx);
                        _pilihDariGaleri();
                      },
                    ),
                    const Divider(height: 1, thickness: 1, color: kBorder),
                    _barisLembar(
                      ikon: Icons.delete_outline_rounded,
                      teks: 'Hapus',
                      warna: kRed,
                      saatDitekan: () {
                        setState(() => _foto = null);
                        Navigator.pop(ctx);
                      },
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

  // ───────── tampilan ─────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _latarSheet,
      appBar: AppBar(
        backgroundColor: _latarSheet,
        centerTitle: true,
        leadingWidth: 90,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w400)),
          ),
        ),
        title: const Text('Edit profil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _simpan,
            child: const Text('Selesai',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: [
              // Nama + avatar (garis bawah berhenti sebelum avatar)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _padding(_kolomIsian(
                          judul: 'Nama',
                          pengendali: _nama,
                          petunjuk: 'Nama Anda',
                        )),
                        _garis(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: GestureDetector(
                      onTap: _lembarAvatar,
                      child: avatarFoto(
                          size: 70,
                          color: avatarColors[_indeksWarna],
                          foto: _foto),
                    ),
                  ),
                ],
              ),
              _padding(_kolomIsian(
                judul: 'Nama pengguna',
                pengendali: _namaPengguna,
                petunjuk: 'Nama pengguna',
              )),
              _garis(),
              _padding(_kolomIsian(
                judul: 'Bio',
                pengendali: _bio,
                petunjuk: '+ Tulis bio',
                banyakBaris: true,
              )),
              _garis(),
              // Minat
              InkWell(
                onTap: () => _lembarTeks(
                  judul: 'Minat',
                  awal: _minat,
                  petunjuk: 'Contoh: musik, kuliner, teknologi',
                  saatSimpan: (v) => setState(() => _minat = v),
                ),
                child: _padding(Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _judul('Minat'),
                      const SizedBox(height: 4),
                      Text(
                        _minat.isEmpty ? '+ Tambahkan minat' : _minat,
                        style: TextStyle(
                            fontSize: 16, color: _minat.isEmpty ? kMuted : Colors.white),
                      ),
                    ],
                  ),
                )),
              ),
              _garis(),
              // Tautan
              InkWell(
                onTap: () => _lembarTeks(
                  judul: 'Tautan',
                  awal: _tautan,
                  petunjuk: 'https://',
                  jenisKeyboard: TextInputType.url,
                  saatSimpan: (v) => setState(() => _tautan = v),
                ),
                child: _padding(Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _judul('Tautan'),
                          if (_tautan.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(_tautan,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, color: kBlue)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kMuted),
                  ],
                )),
              ),
              _garis(),
              _padding(_kolomIsian(
                judul: 'Podcast',
                pengendali: _podcast,
                petunjuk: '+ Tautan ke podcast Anda',
                jenisKeyboard: TextInputType.url,
              )),
              _garis(),
              _padding(_barisSaklar(
                judul: 'Tampilkan lencana Instagram',
                nilai: _lencanaInstagram,
                saatBerubah: (v) => setState(() => _lencanaInstagram = v),
              )),
              _garis(),
              _padding(_barisSaklar(
                judul: 'Tampilkan tayangan terbaru',
                keterangan:
                    'Ini akan menjadi publik di profil Anda saat Anda mendapatkan 1 rb+ tayangan terbaru.',
                nilai: _tayanganTerbaru,
                saatBerubah: (v) => setState(() => _tayanganTerbaru = v),
              )),
              _garis(),
              InkWell(
                onTap: _lembarPrivasi,
                child: _padding(Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _judul('Privasi profil'),
                          const SizedBox(height: 4),
                          const Text(
                            'Jika Anda mengubah ke publik, siapa saja bisa melihat utas dan balasan Anda.',
                            style: TextStyle(fontSize: 14, color: kMuted, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_privat ? 'Privat' : 'Publik',
                        style: const TextStyle(fontSize: 16, color: kMuted)),
                    const Icon(Icons.chevron_right_rounded, color: kMuted),
                  ],
                )),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Insight ─────────────────────────

class halamanInsights extends StatefulWidget {
  const halamanInsights({super.key});

  @override
  State<halamanInsights> createState() => halamanInsightsState();
}

class halamanInsightsState extends State<halamanInsights> {
  int _rentangProfil = 30;
  int _rentangPost = 90;
  int _metrik = 0; // 0 Dilihat, 1 Pemirsa, 2 Pengikut bersih, 3 Interaksi
  int _urut = 0; // 0 Terbaru, 1 Tayangan, 2 Balasan, 3 Suka
  int _filter = 1; // 0 Semua, 1 Thrids, 2 Balasan

  // ── SESUAIKAN dengan field di class thridsPost kamu ──
  DateTime _waktu(thridsPost t) => t.time;
  int _tayangan(thridsPost t) => t.likes * 8 + t.replyCount * 5; // data contoh
  int _balasan(thridsPost t) => t.replyCount;
  int _suka(thridsPost t) => t.likes;

  static const _metrikNama = ['Dilihat', 'Pemirsa', 'Pengikut bersih', 'Interaksi'];
  static const _urutNama = [
    'Terbaru',
    'Tayangan terbanyak',
    'Balasan terbanyak',
    'Suka terbanyak'
  ];

  static const _hariPilihan = [7, 14, 30, 90];

  // Pengali data contoh: angka dasar adalah untuk 30 hari.
  double _skala(int hari) {
    switch (hari) {
      case 7:
        return 0.3;
      case 14:
        return 0.6;
      case 90:
        return 2.4;
      default:
        return 1.0;
    }
  }

  int _nilaiMetrik(int i, int hari) {
    final int dasar;
    switch (i) {
      case 0:
        dasar = app.followers.length * 12 + app.mine.length * 30;
        break;
      case 1:
        dasar = app.followers.length * 8 + app.mine.length * 10;
        break;
      case 2:
        dasar = app.followers.length;
        break;
      default:
        dasar = app.totalLikes + app.replies.length;
    }
    return (dasar * _skala(hari)).round();
  }

  // Deret data contoh: bentuk, jumlah titik, dan tren berbeda tiap rentang.
  List<double> _deret(int total, int hari) {
    final n = const {7: 7, 14: 8, 30: 7, 90: 9}[hari] ?? 7;
    if (total <= 0) return List.filled(n, 0.0);
    final tren = const {7: 1.0, 14: -0.4, 30: 0.8, 90: 0.3}[hari] ?? 0.5;
    final fase = hari * 0.9;
    final w = List.generate(n, (i) {
      final t = n == 1 ? 1.0 : i / (n - 1);
      return 0.7 + tren * t + 0.15 * math.sin(t * math.pi * 2 + fase);
    });
    final jumlah = w.reduce((a, b) => a + b);
    return [for (final x in w) total * x / jumlah * (n / 7)];
  }

  String _fmt(int v, {bool plus = false}) => plus && v >= 0 ? '+$v' : '$v';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 130,
          leading: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 30),
            label: const Text('Kembali',
                style: TextStyle(color: Colors.white, fontSize: 17)),
          ),
          centerTitle: true,
          title: const Text('Insight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 1.5,
            labelColor: Colors.white,
            unselectedLabelColor: kMuted,
            dividerColor: kBorder,
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            tabs: [Tab(text: 'Gambaran Umum'), Tab(text: 'Audiens')],
          ),
        ),
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) => TabBarView(
            children: [_gambaranUmum(), _audiens()],
          ),
        ),
      ),
    );
  }

  // ───────── komponen umum ─────────

  Widget _rentang(int nilai, List<int> pilihan, ValueChanged<int> onPick) {
    return PopupMenuButton<int>(
      initialValue: nilai,
      onSelected: onPick,
      itemBuilder: (_) =>
          [for (final p in pilihan) PopupMenuItem(value: p, child: Text('$p hari'))],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$nilai hari',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: kMuted)),
          const Icon(Icons.keyboard_arrow_down_rounded, color: kMuted),
        ],
      ),
    );
  }

  Widget _judulBagian(String teks, Widget kanan) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          children: [
            Text(teks,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.info_outline_rounded, size: 18, color: kMuted),
            const Spacer(),
            kanan,
          ],
        ),
      );

  // ───────── tab Gambaran Umum ─────────

  Widget _gambaranUmum() {
    final total = _nilaiMetrik(_metrik, _rentangProfil);
    final hari = _rentangProfil;
    final deret = _deret(total, hari);

    final dari = DateTime.now().subtract(Duration(days: hari - 1));
    const bln = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    String tgl(DateTime d) => '${d.day} ${bln[d.month - 1]}';
    final akhir = DateTime.now();

    final postingan = _filter == 2 ? <thridsPost>[] : _postinganTerfilter();
    final balasan = _filter == 0 || _filter == 2 ? _balasanTerfilter() : [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _judulBagian('Profil',
            _rentang(_rentangProfil, _hariPilihan, (v) => setState(() => _rentangProfil = v))),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _metrikNama.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final aktif = _metrik == i;
              return GestureDetector(
                onTap: () => setState(() => _metrik = i),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: aktif ? const Color(0xFF1E1E1E) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_metrikNama[i],
                          style: const TextStyle(fontSize: 13, color: kMuted)),
                      const SizedBox(height: 4),
                      Text(_fmt(_nilaiMetrik(i, _rentangProfil), plus: i == 2),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                      const Text('+0,0%',
                          style: TextStyle(fontSize: 12, color: kMuted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: grafikInsightPainter(
                data: deret,
                labelKiri: tgl(dari),
                labelKanan: tgl(akhir),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _judulBagian('Postingan',
            _rentang(_rentangPost, const [7, 30, 90], (v) => setState(() => _rentangPost = v))),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _chipFilter(),
              for (int i = 0; i < _urutNama.length; i++)
                _chip(
                  label: _urutNama[i],
                  aktif: _urut == i,
                  onTap: () => setState(() => _urut = i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (postingan.isEmpty && balasan.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(_teksKosong(),
                  style: const TextStyle(color: kMuted, fontSize: 16)),
            ),
          )
        else ...[
          for (final p in postingan) postTile(post: p),
          for (final r in balasan) _balasanTile(r),
        ],
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool aktif,
    required VoidCallback onTap,
    IconData? ikon,
  }) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: aktif ? const Color(0xFF1E1E1E) : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Row(
              children: [
                if (ikon != null) ...[
                  Icon(ikon, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  List<thridsPost> _postinganTerfilter() {
    final batas = DateTime.now().subtract(Duration(days: _rentangPost));
    var list = app.mine.where((t) => _waktu(t).isAfter(batas)).toList();
    int Function(thridsPost) kunci;
    switch (_urut) {
      case 1:
        kunci = _tayangan;
        break;
      case 2:
        kunci = _balasan;
        break;
      case 3:
        kunci = _suka;
        break;
      default:
        list.sort((a, b) => _waktu(b).compareTo(_waktu(a)));
        return list;
    }
    list.sort((a, b) => kunci(b).compareTo(kunci(a)));
    return list;
  }

  // Teks kosong menyesuaikan chip yang sedang aktif.
  String _teksKosong() {
    const akhir = 'pada rentang tanggal ini';
    if (_filter == 2) return 'Tidak ada balasan $akhir';
    switch (_urut) {
      case 1:
        return 'Tidak ada tayangan $akhir';
      case 2:
        return 'Tidak ada balasan $akhir';
      case 3:
        return 'Tidak ada suka $akhir';
      default:
        return 'Tidak ada postingan $akhir';
    }
  }

  // Chip filter dengan menu popup: Semua / Thrids / Balasan.
  Widget _chipFilter() {
    const nama = ['Semua', 'Thrids', 'Balasan'];
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: PopupMenuButton<int>(
        onSelected: (v) => setState(() => _filter = v),
        offset: const Offset(0, 52),
        color: const Color(0xFF232323),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        itemBuilder: (_) => [
          for (int i = 0; i < nama.length; i++)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: _filter == i
                        ? const Icon(Icons.check_rounded, size: 22)
                        : null,
                  ),
                  Text(nama[i], style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 20),
              const SizedBox(width: 8),
              Text(nama[_filter],
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _balasanTerfilter() {
    final batas = DateTime.now().subtract(Duration(days: _rentangPost));
    final list = app.replies.where((r) => r.time.isAfter(batas)).toList();
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  Widget _balasanTile(dynamic r) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatarFoto(
                size: 40, color: app.avatarColor, foto: tambahan.fotoBytes),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Membalas @${r.toHandle} · ${timeAgo(r.time)}',
                      style: const TextStyle(color: kMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(r.text, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );

  // ───────── tab Audiens ─────────

  Widget _audiens() {
    final skala = _skala(_rentangProfil);
    final pengikut = (app.followers.length * skala).round();
    final nonPengikut = (app.mine.length * 3 * skala).round(); // data contoh
    final pemirsa = pengikut + nonPengikut;

    Widget kartu(String label, int v) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0B0B),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: kMuted)),
                const SizedBox(height: 4),
                Text('$v',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const Text('+0%',
                    style: TextStyle(fontSize: 13, color: kMuted)),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _judulBagian('Pemirsa',
            _rentang(_rentangProfil, _hariPilihan, (v) => setState(() => _rentangProfil = v))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$pemirsa',
                  style: const TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w700)),
              const Text('+0% vs. periode sebelumnya',
                  style: TextStyle(fontSize: 15, color: kMuted)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Jenis pemirsa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Icon(Icons.info_outline_rounded, size: 18, color: kMuted),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              kartu('Pengikut', pengikut),
              const SizedBox(width: 12),
              kartu('Non-pengikut', nonPengikut),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Grafik area ─────────────────────────

class grafikInsightPainter extends CustomPainter {
  final List<double> data;
  final String labelKiri, labelKanan;
  grafikInsightPainter({
    required this.data,
    required this.labelKiri,
    required this.labelKanan,
  });

  void _teks(Canvas c, String s, Offset o,
      {bool kanan = false, bool tengah = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s, style: const TextStyle(color: kMuted, fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = o.dx;
    if (kanan) dx -= tp.width;
    if (tengah) dx -= tp.width / 2;
    tp.paint(c, Offset(dx, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const kiri = 32.0, bawah = 28.0, atas = 8.0;
    final w = size.width - kiri;
    final h = size.height - bawah - atas;
    final maxV = data.isEmpty ? 0.0 : data.reduce(math.max);
    final puncak = maxV <= 0 ? 1 : maxV.ceil();

    // garis bantu + label sumbu Y
    final garis = Paint()
      ..color = const Color(0xFF242424)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = atas + h * i / 2;
      canvas.drawLine(Offset(kiri, y), Offset(size.width, y), garis);
    }
    _teks(canvas, '$puncak', Offset(0, atas));
    _teks(canvas, '${(puncak / 2).round()}', Offset(0, atas + h / 2));
    _teks(canvas, '0', Offset(0, atas + h));

    if (data.length > 1) {
      final pts = <Offset>[
        for (int i = 0; i < data.length; i++)
          Offset(kiri + w * i / (data.length - 1),
              atas + h - h * data[i] / puncak),
      ];

      // garis lurus antar titik
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }

      final area = Path.from(path)
        ..lineTo(pts.last.dx, atas + h)
        ..lineTo(pts.first.dx, atas + h)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x50FFFFFF), Color(0x00FFFFFF)],
          ).createShader(Rect.fromLTWH(kiri, atas, w, h)),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final yLabel = atas + h + 18;
    _teks(canvas, labelKiri, Offset(kiri, yLabel));
    _teks(canvas, labelKanan, Offset(size.width, yLabel), kanan: true);
  }

  @override
  bool shouldRepaint(covariant grafikInsightPainter old) =>
      old.data != data || old.labelKiri != labelKiri;
}

// ───────────────────────── Cari ─────────────────────────

class halamanPencarian extends StatefulWidget {
  const halamanPencarian({super.key});

  @override
  State<halamanPencarian> createState() => halamanPencarianState();
}

class halamanPencarianState extends State<halamanPencarian> {
  final _c = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _c,
          autofocus: true,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Cari akun atau utas',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _c.clear();
                      setState(() => _q = '');
                    },
                  ),
            filled: true,
            fillColor: kCard,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final users = app.suggestions
              .where((s) =>
                  s.name.toLowerCase().contains(_q) || s.handle.contains(_q))
              .toList();
          final posts = _q.isEmpty
              ? <thridsPost>[]
              : app.thrids
                  .where((t) => t.text.toLowerCase().contains(_q))
                  .toList();
          if (users.isEmpty && posts.isEmpty) {
            return const Center(
                child:
                    Text('Tidak ada hasil', style: TextStyle(color: kMuted)));
          }
          return ListView(
            children: [
              for (final s in users)
                ListTile(
                  leading: avatar(size: 44, color: s.color, label: s.name),
                  title: Row(children: [
                    Flexible(
                        child: Text(s.name, overflow: TextOverflow.ellipsis)),
                    if (s.verified) ...[
                      const SizedBox(width: 4),
                      const verifiedBadge()
                    ],
                  ]),
                  subtitle:
                      Text(s.handle, style: const TextStyle(color: kMuted)),
                  trailing: OutlinedButton(
                    onPressed: () => app.toggleFollow(s),
                    child: Text(s.following ? 'Mengikuti' : 'Ikuti'),
                  ),
                ),
              for (final p in posts) postTile(post: p),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── Pengaturan ─────────────────────────

class halamanPengaturan extends StatelessWidget {
  const halamanPengaturan({super.key});

  void _buka(BuildContext context, Widget halaman) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => halaman));

  void _belumAda(BuildContext context) =>
      toast(context, 'Fitur ini belum tersedia');

  Widget _menu(IconData ikon, String teks, VoidCallback saatDitekan) =>
      InkWell(
        onTap: saatDitekan,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(ikon, size: 28),
              const SizedBox(width: 22),
              Expanded(child: Text(teks, style: const TextStyle(fontSize: 18))),
            ],
          ),
        ),
      );

  Widget _teksSaja(String teks, Color warna, VoidCallback saatDitekan) =>
      InkWell(
        onTap: saatDitekan,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Text(teks, style: TextStyle(fontSize: 18, color: warna)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: const Text('Pengaturan',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Akun
          InkWell(
            onTap: () => _belumAda(context),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.all_inclusive_rounded, size: 28),
                  ),
                  SizedBox(width: 22),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Akun', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 6),
                        Text(
                          'Kata sandi, keamanan, detail pribadi, pengalaman lintas profil, preferensi iklan',
                          style:
                              TextStyle(fontSize: 16, color: kMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: kBorder),
          const SizedBox(height: 4),
          _menu(Icons.supervised_user_circle_outlined,
              'Pengawasan untuk Akun Remaja', () => _belumAda(context)),
          _menu(Icons.person_add_alt_outlined, 'Ikuti dan undang teman',
              () => _belumAda(context)),
          _menu(Icons.notifications_none_rounded, 'Notifikasi',
              () => _buka(context, const halamanPengaturanNotifikasi())),
          _menu(Icons.bookmark_border_rounded, 'Tersimpan',
              () => _belumAda(context)),
          _menu(Icons.favorite_border_rounded, 'Disukai',
              () => _belumAda(context)),
          _menu(Icons.history_rounded, 'Arsip', () => _belumAda(context)),
          _menu(Icons.lock_outline_rounded, 'Privasi',
              () => _buka(context, const halamanPengaturanPrivasi())),
          _menu(Icons.tune_rounded, 'Preferensi konten',
              () => _belumAda(context)),
          _menu(Icons.person_outline_rounded, 'Status profil',
              () => _belumAda(context)),
          _menu(Icons.ios_share_rounded, 'Berbagi lintas profil',
              () => _buka(context, const halamanPengaturanBerbagi())),
          _menu(Icons.settings_outlined, 'Pengaturan lainnya',
              () => _belumAda(context)),
          _menu(Icons.help_outline_rounded, 'Bantuan',
              () => _belumAda(context)),
          _menu(
            Icons.info_outline_rounded,
            'Tentang',
            () => showAboutDialog(
              context: context,
              applicationName: 'Thrids',
              applicationVersion: '1.0',
              children: const [
                Text('Aplikasi contoh untuk latihan UI Flutter.')
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, color: kBorder),
          _teksSaja(
              'Ganti akun',
              kBlue,
              () => toast(
                  context, 'Contoh saja: belum terhubung ke server')),
          _teksSaja('Keluar', kRed, () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Keluar dari akun?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Batal')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child:
                          const Text('Keluar', style: TextStyle(color: kRed))),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              toast(context, 'Contoh saja: keluar belum terhubung ke server');
            }
          }),
        ],
      ),
    );
  }
}

// ── Privasi: profil privat, sebutan, kata yang disembunyikan ──

class halamanPengaturanPrivasi extends StatelessWidget {
  const halamanPengaturanPrivasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Privasi',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.lock_outline_rounded),
              title: const Text('Profil privat'),
              value: app.isPrivate,
              onChanged: app.setPrivate,
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: const Text('Siapa yang bisa menyebut Anda'),
              subtitle:
                  Text(app.mentionWho, style: const TextStyle(color: kMuted)),
              onTap: () => _mentionDialog(context),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Kata yang disembunyikan'),
              subtitle: Text('${app.hiddenWords.length} kata',
                  style: const TextStyle(color: kMuted)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const halamanKataTersembunyi())),
            ),
          ],
        ),
      ),
    );
  }

  void _mentionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Siapa yang bisa menyebut Anda'),
        children: [
          for (final o in [
            'Semua orang',
            'Profil yang Anda ikuti',
            'Tidak ada'
          ])
            SimpleDialogOption(
              onPressed: () {
                app.setMentionWho(o);
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  Expanded(child: Text(o)),
                  if (app.mentionWho == o)
                    const Icon(Icons.check_rounded, color: kBlue),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Notifikasi ──

class halamanPengaturanNotifikasi extends StatelessWidget {
  const halamanPengaturanNotifikasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Notifikasi',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_none_rounded),
              title: const Text('Notifikasi'),
              value: app.notifications,
              onChanged: app.setNotifications,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Berbagi lintas profil: fediverse ──

class halamanPengaturanBerbagi extends StatelessWidget {
  const halamanPengaturanBerbagi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Berbagi lintas profil',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => ListView(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.public_rounded),
              title: const Text('Berbagi ke fediverse'),
              subtitle: const Text(
                  'Utas Anda bisa dilihat di platform seperti Mastodon',
                  style: TextStyle(color: kMuted)),
              value: app.fediverse,
              onChanged: app.setFediverse,
            ),
          ],
        ),
      ),
    );
  }
}

class halamanKataTersembunyi extends StatefulWidget {
  const halamanKataTersembunyi({super.key});

  @override
  State<halamanKataTersembunyi> createState() => halamanKataTersembunyiState();
}

class halamanKataTersembunyiState extends State<halamanKataTersembunyi> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    app.addHidden(_c.text.trim().toLowerCase());
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Kata yang disembunyikan',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _c,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: 'Tambah kata atau frasa',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.add_rounded), onPressed: _add),
                ),
              ),
              const SizedBox(height: 16),
              if (app.hiddenWords.isEmpty)
                const Text('Belum ada kata yang disembunyikan.',
                    style: TextStyle(color: kMuted))
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final w in app.hiddenWords)
                      InputChip(
                          label: Text(w), onDeleted: () => app.removeHidden(w)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Kirim Pesan ─────────────────────────

class halamanKirimPesan extends StatefulWidget {
  final String nama;
  final String username;
  final Color warnaAvatar;
  final bool terverifikasi;

  const halamanKirimPesan({
    super.key,
    required this.nama,
    required this.username,
    required this.warnaAvatar,
    this.terverifikasi = false,
  });

  @override
  State<halamanKirimPesan> createState() =>
      halamanKirimPesanState();
}

class halamanKirimPesanState extends State<halamanKirimPesan> {
  final TextEditingController _pesan = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<String> _daftarPesan = [];
  static const int _maksPesan = 3;

  @override
  void dispose() {
    _pesan.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _kirim() {
    final teks = _pesan.text.trim();

    if (teks.isEmpty) return;

    if (_daftarPesan.length >= _maksPesan) {
      toast(
        context,
        'Batas 3 pesan sebelum permintaan diterima sudah tercapai',
      );
      return;
    }

    setState(() {
      _daftarPesan.add(teks);
      _pesan.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sudahMaksimal =
        _daftarPesan.length >= _maksPesan;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            avatar(
              size: 42,
              color: widget.warnaAvatar,
              label: widget.nama,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.terverifikasi) ...[
                        const SizedBox(width: 5),
                        const verifiedBadge(size: 17),
                      ],
                    ],
                  ),
                  Text(
                    '@${widget.username.replaceAll('@', '')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(
                20, 36, 20, 20,
              ),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      avatar(
                        size: 112,
                        color: widget.warnaAvatar,
                        label: widget.nama,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.nama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (widget.terverifikasi) ...[
                            const SizedBox(width: 6),
                            const verifiedBadge(size: 23),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '@${widget.username.replaceAll('@', '')}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: kMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Kirim permintaan pesan untuk memulai percakapan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                for (int i = 0;
                    i < _daftarPesan.length;
                    i++)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width *
                                0.78,
                      ),
                      margin:
                          const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF303030),
                        borderRadius:
                            BorderRadius.circular(22),
                      ),
                      child: Text(
                        _daftarPesan[i],
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bagian bawah untuk mengirim pesan
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: kBorder),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!sudahMaksimal)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      4, 0, 4, 14,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Kirim permintaan pesan ke ${widget.nama}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Kamu bisa mengirim hingga '
                          '${_maksPesan - _daftarPesan.length} '
                          'pesan lagi sebelum permintaan diterima.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Batas 3 pesan tercapai. Tunggu sampai permintaan diterima.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pesan,
                        enabled: !sudahMaksimal,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization:
                            TextCapitalization.sentences,
                        onSubmitted: (_) => _kirim(),
                        decoration: InputDecoration(
                          hintText: sudahMaksimal
                              ? 'Pesan dibatasi'
                              : 'Pesan…',
                          hintStyle: const TextStyle(
                            color: kMuted,
                          ),
                          filled: true,
                          fillColor:
                              const Color(0xFF202020),
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          sudahMaksimal ? null : _kirim,
                      icon: const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            const Color(0xFF303030),
                        disabledForegroundColor: kMuted,
                        minimumSize: const Size(48, 48),
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
}

class halamanCatatanBaru extends StatefulWidget {
  const halamanCatatanBaru({super.key});

  @override
  State<halamanCatatanBaru> createState() =>
      _halamanCatatanBaruState();
}

class _halamanCatatanBaruState extends State<halamanCatatanBaru> {
  late final TextEditingController _catatan =
      TextEditingController(text: app.note);

  bool _balasanDiPostingan = true;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  void _bagikan() {
    final teks = _catatan.text.trim();

    if (teks.isEmpty) {
      toast(context, 'Tulis catatan terlebih dahulu');
      return;
    }

    app.setNote(teks);
    Navigator.pop(context);
    toast(context, 'Catatan dibagikan');
  }

  @override
  Widget build(BuildContext context) {
    final isi = _catatan.text.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, size: 30),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buat Catatan',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              toast(context, 'Draf belum tersedia');
            },
            icon: const Icon(
              Icons.description_outlined,
              size: 29,
            ),
          ),
          IconButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF202020),
                builder: (ctx) => SafeArea(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Hapus catatan'),
                    onTap: () {
                      _catatan.clear();

                      // Hapus juga catatan yang tersimpan di profil
                      app.setNote('');

                      setState(() {});

                      Navigator.pop(ctx);
                      Navigator.pop(context);

                      toast(context, 'Catatan berhasil dihapus');
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.more_horiz_rounded, size: 29),
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: Color(0xFF252525),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatarFoto(
                      size: 58,
                      color: app.avatarColor,
                      foto: tambahan.fotoBytes,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.username.isEmpty
                                ? app.name
                                : app.username,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CustomPaint(
                            foregroundPainter: dashedBorderPainter(
                              color: const Color(0xFF777777),
                              radius: 28,
                            ),
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: 54,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF101010),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: TextField(
                                controller: _catatan,
                                autofocus: true,
                                maxLength: 60,
                                maxLines: null,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Bagikan sesuatu...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF777777),
                                    fontSize: 16,
                                  ),
                                  counterText: '',
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                          if (isi.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 6,
                                  right: 8,
                                ),
                                child: Text(
                                  '${isi.length}/60',
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: kMuted,
                          size: 29,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Balasan muncul di postingan',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _balasanDiPostingan =
                            !_balasanDiPostingan;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 62,
                      height: 38,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _balasanDiPostingan
                            ? const Color(0xFFF4F4F6)
                            : const Color(0xFF303030),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Align(
                        alignment: _balasanDiPostingan
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pets_outlined,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: FilledButton(
                      onPressed: isi.isEmpty ? null : _bagikan,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF242424),
                        foregroundColor: Colors.black,
                        disabledForegroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Bagikan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}