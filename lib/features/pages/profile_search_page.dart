import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'post_detail_page.dart';
import 'user_profile_page.dart';
import 'widgets/date_wheel_sheet.dart';
import 'widgets/user_avatar.dart';

/// Pencarian dari halaman profil.
///
/// Kolom cari berisi chip "Dari `username`" (hapus dengan tombol x), kolom
/// teks, dan tombol filter di kanan. Tombol filter membuka popup:
/// Setelah tanggal / Sebelum tanggal / Dari profil (bertanda centang).
///
/// Saat mengetik: baris kata kunci + daftar akun yang cocok. Ketuk kata kunci
/// (atau tekan Enter) untuk mencari postingan.
class ProfileSearchPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;

  /// Postingan milik akun ini (dipakai saat filter "Dari profil" aktif).
  final List<Map<String, dynamic>> myPosts;

  /// Semua postingan (dipakai saat filter "Dari profil" dimatikan).
  final List<Map<String, dynamic>> allPosts;

  const ProfileSearchPage({
    super.key,
    required this.token,
    required this.currentUser,
    required this.myPosts,
    required this.allPosts,
  });

  @override
  State<ProfileSearchPage> createState() => _ProfileSearchPageState();
}

class _ProfileSearchPageState extends State<ProfileSearchPage> {
  static const _bg = Color(0xFF101010);
  static const _muted = Color(0xFF858585);
  static const _field = Color(0xFF1E1E1E);
  static const _chipBorder = Color(0xFF3A3A3A);

  /// Riwayat pencarian selama aplikasi berjalan.
  static final List<String> _recent = [];

  final _controller = TextEditingController();
  final _focus = FocusNode();

  List<Map<String, dynamic>> _users = [];
  bool _fromProfile = true;
  DateTime? _after;
  DateTime? _before;

  /// Kata kunci yang sedang dicari; null = belum menjalankan pencarian postingan.
  String? _submitted;

  String get _me => '${widget.currentUser['username'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await ApiService.getUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (_) {
      // Daftar akun gagal dimuat: pencarian postingan tetap jalan.
    }
  }

  // ───────────────────────── Aksi ─────────────────────────

  void _submit(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;

    _recent
      ..remove(q)
      ..insert(0, q);
    if (_recent.length > 8) _recent.removeLast();

    FocusScope.of(context).unfocus();
    setState(() => _submitted = q);
  }

  Future<void> _pickDate({required bool after}) async {
    final picked = await DateWheelSheet.show(
      context,
      title: after ? 'Setelah tanggal' : 'Sebelum tanggal',
      initial: after ? _after : _before,
    );

    if (picked == null || !mounted) return;

    setState(() => after ? _after = picked : _before = picked);
  }

  void _onFilter(String value) {
    switch (value) {
      case 'after':
        _pickDate(after: true);
        break;
      case 'before':
        _pickDate(after: false);
        break;
      case 'profile':
        setState(() => _fromProfile = !_fromProfile);
        break;
    }
  }

  void _openProfile(String username) {
    openUserProfile(
      context,
      token: widget.token,
      currentUser: widget.currentUser,
      username: username,
    );
  }

  void _openPost(Map<String, dynamic> post) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          token: widget.token,
          post: post,
          currentUser: widget.currentUser,
          onChanged: () {},
        ),
      ),
    );
  }

  // ───────────────────────── Data ─────────────────────────

  String _name(Map<String, dynamic> u) =>
      '${u['display_name'] ?? u['name'] ?? ''}';

  List<Map<String, dynamic>> get _matchedUsers {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return const [];

    return _users
        .where((u) => '${u['username']}' != _me)
        .where((u) => '${u['username'] ?? ''} ${_name(u)}'
            .toLowerCase()
            .contains(q))
        .take(12)
        .toList();
  }

  List<Map<String, dynamic>> get _postResults {
    final q = (_submitted ?? '').toLowerCase();
    final source = _fromProfile ? widget.myPosts : widget.allPosts;

    return source.where((p) {
      final content = '${p['content'] ?? ''}'.toLowerCase();
      if (q.isNotEmpty && !content.contains(q)) return false;

      final date = DateTime.tryParse('${p['created_at'] ?? ''}')?.toLocal();
      if (date == null) return _after == null && _before == null;

      if (_after != null && date.isBefore(_after!)) return false;

      if (_before != null &&
          !date.isBefore(_before!.add(const Duration(days: 1)))) {
        return false;
      }

      return true;
    }).toList();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_after != null || _before != null) _buildDateChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 22),
          ),
          Expanded(
            child: Container(
              height: 54,
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(27),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _muted, size: 26),
                  const SizedBox(width: 10),
                  if (_fromProfile) ...[
                    _fromChip(),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      cursorColor: Colors.white,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 19),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Cari',
                        hintStyle: TextStyle(color: _muted, fontSize: 19),
                      ),
                      onChanged: (_) => setState(() => _submitted = null),
                      onSubmitted: _submit,
                    ),
                  ),
                  _buildFilterButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fromChip() {
    final name = '${widget.currentUser['username'] ?? ''}';

    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Dari ',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: name, style: const TextStyle(color: _muted)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _fromProfile = false),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF3A3A3A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      tooltip: 'Filter',
      offset: const Offset(0, 52),
      color: _field,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 26),
      onSelected: _onFilter,
      itemBuilder: (_) => [
        _menuItem('after', Icons.update_rounded, 'Setelah tanggal',
            checked: _after != null),
        _menuItem('before', Icons.history_rounded, 'Sebelum tanggal',
            checked: _before != null),
        _menuItem('profile', Icons.person_outline_rounded, 'Dari profil',
            checked: _fromProfile),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    required bool checked,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 62,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          if (checked)
            const Icon(Icons.check_rounded, color: Colors.white, size: 26),
        ],
      ),
    );
  }

  Widget _buildDateChips() {
    Widget chip(String label, VoidCallback onRemove) => Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _chipBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Colors.white),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_after != null)
              chip('Setelah ${_fmtDate(_after!)}',
                  () => setState(() => _after = null)),
            if (_before != null)
              chip('Sebelum ${_fmtDate(_before!)}',
                  () => setState(() => _before = null)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_submitted != null) return _buildResults();

    final q = _controller.text.trim();

    // Belum mengetik: tampilkan riwayat.
    if (q.isEmpty) {
      if (_recent.isEmpty) {
        return const Center(
          child: Text('Cari postingan atau akun.',
              style: TextStyle(color: _muted, fontSize: 16)),
        );
      }

      return ListView(
        children: [
          for (final r in _recent)
            _queryRow(r, onTap: () {
              _controller.text = r;
              _controller.selection =
                  TextSelection.collapsed(offset: r.length);
              _submit(r);
            }),
        ],
      );
    }

    final users = _matchedUsers;

    return ListView(
      children: [
        _queryRow(q, onTap: () => _submit(q)),
        for (final u in users) _userRow(u),
      ],
    );
  }

  Widget _queryRow(String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: _field,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _userRow(Map<String, dynamic> u) {
    final username = '${u['username'] ?? ''}';
    final name = _name(u);

    return InkWell(
      onTap: () => _openProfile(username),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              url: (u['profile_picture'] ?? u['avatar_url'])?.toString(),
              size: 68,
            ),
            const SizedBox(width: 16),
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
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 18),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final list = _postResults;

    if (list.isEmpty) {
      return const Center(
        child: Text('Tidak ada hasil.',
            style: TextStyle(color: _muted, fontSize: 16)),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF292929)),
      itemBuilder: (_, i) {
        final p = list[i];
        final content = '${p['content'] ?? ''}';

        return InkWell(
          onTap: () => _openPost(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  url: p['profile_picture']?.toString(),
                  size: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['username'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (content.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          content,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.35,
                          ),
                        ),
                      ],
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
}