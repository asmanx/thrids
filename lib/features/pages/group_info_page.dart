import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'widgets/chat_utils.dart';
import 'widgets/user_avatar.dart';

/// Hasil dari [PickPeoplePage]: username yang dipilih dan nama grup (boleh kosong).
class PickedPeople {
  final List<String> usernames;
  final String name;

  const PickedPeople(this.usernames, this.name);
}

/// Memilih beberapa orang. Dipakai untuk:
///   - membuat grup  : askName: true, minPick: 2
///   - tambah anggota: askName: false, minPick: 1, exclude: anggota sekarang
///
/// Mengembalikan [PickedPeople] lewat `Navigator.pop`, atau null bila dibatalkan.
class PickPeoplePage extends StatefulWidget {
  final String token;
  final String title;
  final String actionLabel;
  final int minPick;
  final int maxPick;
  final bool askName;

  /// Username yang tidak boleh ditampilkan (mis. yang sudah jadi anggota).
  final Set<String> exclude;

  const PickPeoplePage({
    super.key,
    required this.token,
    required this.title,
    required this.actionLabel,
    this.minPick = 1,
    this.maxPick = 31,
    this.askName = false,
    this.exclude = const {},
  });

  @override
  State<PickPeoplePage> createState() => _PickPeoplePageState();
}

class _PickPeoplePageState extends State<PickPeoplePage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kBorder = Color(0xFF2E2E2E);
  static const kField = Color(0xFF1E1E1E);
  static const kBlue = Color(0xFF0095F6);

  final _search = TextEditingController();
  final _name = TextEditingController();

  /// Urutan dipilih dipertahankan (Map literal Dart menjaga urutan sisip).
  final Map<String, Map<String, dynamic>> _picked = {};

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final query = _search.text.trim();

    try {
      final users = await ApiService.searchMessageUsers(
        token: widget.token,
        query: query,
      );

      if (!mounted || query != _search.text.trim()) return;

      setState(() {
        _users = users
            .where((u) => !widget.exclude.contains('${u['username']}'))
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _toggle(Map<String, dynamic> user) {
    final username = '${user['username']}';

    setState(() {
      if (_picked.remove(username) != null) return;

      if (_picked.length >= widget.maxPick) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Maksimal ${widget.maxPick} orang.')),
          );
        return;
      }

      _picked[username] = user;
    });
  }

  void _done() {
    Navigator.of(context).pop(
      PickedPeople(_picked.keys.toList(), _name.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _picked.length >= widget.minPick;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, size: 30),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: enabled ? _done : null,
            child: Text(
              widget.actionLabel,
              style: TextStyle(
                color: enabled ? kBlue : const Color(0xFF4A4A4A),
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: kBorder),
        ),
      ),
      body: Column(
        children: [
          if (widget.askName)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: TextField(
                controller: _name,
                maxLength: 50,
                style: const TextStyle(color: Colors.white, fontSize: 19),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: kField,
                  hintText: 'Nama grup (opsional)',
                  hintStyle: const TextStyle(color: kMuted, fontSize: 19),
                  prefixIcon:
                      const Icon(Icons.groups_rounded, color: kMuted, size: 26),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          if (_picked.isNotEmpty) _buildPickedStrip(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white, fontSize: 19),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                filled: true,
                fillColor: kField,
                hintText: 'Cari',
                hintStyle: const TextStyle(color: kMuted, fontSize: 19),
                prefixIcon: const Icon(Icons.search, color: kMuted, size: 26),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _picked.length < widget.minPick
                    ? 'Pilih minimal ${widget.minPick} orang'
                    : '${_picked.length} dipilih',
                style: const TextStyle(color: kMuted, fontSize: 16),
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildPickedStrip() {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: [
          for (final user in _picked.values)
            GestureDetector(
              onTap: () => _toggle(user),
              child: Container(
                width: 70,
                margin: const EdgeInsets.only(right: 6),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(
                          url: pictureOf(user['profile_picture']),
                          size: 52,
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              shape: BoxShape.circle,
                              border: Border.all(color: kBg, width: 2),
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${user['username']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: kMuted)),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('Akun tidak ditemukan.',
            style: TextStyle(color: kMuted, fontSize: 17)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final user = _users[i];
        final username = '${user['username']}';
        final name = '${user['display_name'] ?? ''}';
        final picked = _picked.containsKey(username);

        return InkWell(
          onTap: () => _toggle(user),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                UserAvatar(url: pictureOf(user['profile_picture']), size: 54),
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
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (name.isNotEmpty && name != username)
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 16),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: picked ? Colors.white : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: picked ? Colors.white : const Color(0xFF5A5A5A),
                      width: 2,
                    ),
                  ),
                  child: picked
                      ? const Icon(Icons.check_rounded,
                          size: 18, color: Colors.black)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


/// Halaman info grup, dibuka dari ikon info di obrolan grup.
///
/// Menutup halaman mengembalikan `{'muted': bool}` (atau `{'left': true}`
/// setelah keluar dari grup) supaya obrolan memuat ulang detailnya.
///
/// CATATAN: versi sementara. Tambah anggota, ganti nama, dan keluar grup
/// masih "Segera hadir" sampai fungsi API grup di backend disambungkan.
class GroupInfoPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;
  final Object conversationId;
  final String name;
  final bool muted;

  const GroupInfoPage({
    super.key,
    required this.token,
    required this.currentUser,
    required this.conversationId,
    required this.name,
    required this.muted,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kBorder = Color(0xFF2E2E2E);

  late bool _muted = widget.muted;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  String? _error;

  String get _me => '${widget.currentUser['username'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ApiService.getConversation(
        token: widget.token,
        conversationId: widget.conversationId,
      );

      final raw = detail['members'];

      if (!mounted) return;

      setState(() {
        _members = raw is List
            ? raw.map((m) => Map<String, dynamic>.from(m as Map)).toList()
            : [];
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _setMuted(bool value) async {
    setState(() => _muted = value);

    try {
      await ApiService.muteConversation(
        token: widget.token,
        conversationId: widget.conversationId,
        muted: value,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _muted = !value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _soon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Segera hadir.')));
  }

  bool _isAdmin(Map<String, dynamic> m) =>
      m['role'] == 'admin' || m['is_admin'] == true || m['is_owner'] == true;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(<String, dynamic>{'muted': _muted});
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 30),
            onPressed: () =>
                Navigator.of(context).pop(<String, dynamic>{'muted': _muted}),
          ),
          title: const Text(
            'Info grup',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: kBorder),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text(
                widget.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SwitchListTile(
              value: _muted,
              onChanged: _setMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: const Text(
                'Bisukan notifikasi',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(
                _loading ? 'Anggota' : 'Anggota (${_members.length})',
                style: const TextStyle(color: kMuted, fontSize: 16),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_error!, style: const TextStyle(color: kMuted)),
                    TextButton(onPressed: _load, child: const Text('Coba lagi')),
                  ],
                ),
              )
            else
              for (final m in _members) _memberRow(m),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.person_add_alt_1_outlined,
                  color: Colors.white, size: 28),
              title: const Text(
                'Tambah anggota',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              onTap: _soon,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.logout, color: Color(0xFFFF3040), size: 28),
              title: const Text(
                'Keluar dari grup',
                style: TextStyle(color: Color(0xFFFF3040), fontSize: 18),
              ),
              onTap: _soon,
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> m) {
    final username = '${m['username'] ?? ''}';
    final name = '${m['display_name'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          UserAvatar(url: pictureOf(m['profile_picture']), size: 50),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username == _me ? '$username (Anda)' : username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (name.isNotEmpty && name != username)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kMuted, fontSize: 15),
                  ),
              ],
            ),
          ),
          if (_isAdmin(m))
            const Text('Admin', style: TextStyle(color: kMuted, fontSize: 14)),
        ],
      ),
    );
  }
}