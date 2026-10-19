import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'user_profile_page.dart';
import 'widgets/user_avatar.dart';

/// Halaman "Cari": daftar akun lain + kolom pencarian + tombol Ikuti.
class SearchUsersPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;

  const SearchUsersPage({
    super.key,
    required this.token,
    required this.currentUser,
  });

  @override
  State<SearchUsersPage> createState() => _SearchUsersPageState();
}

class _SearchUsersPageState extends State<SearchUsersPage> {
  static const _bg = Color(0xFF101010);
  static const _muted = Color(0xFF858585);
  static const _field = Color(0xFF1E1E1E);

  final _search = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  Set<String> _following = {};
  Set<String> _requested = {};
  bool _loading = true;
  String? _error;
  String _query = '';

  String get _me => '${widget.currentUser['username'] ?? ''}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await ApiService.getUsers();

      try {
        final state = await ApiService.getFollowState(token: widget.token);
        _following = state.following;
        _requested = state.requested;
      } catch (_) {
        // Status ikuti gagal dimuat: daftar tetap tampil.
      }

      if (!mounted) return;

      setState(() {
        _users = users.where((u) => '${u['username']}' != _me).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _users;

    return _users.where((u) {
      final name = '${u['username'] ?? ''} ${_displayName(u)}'.toLowerCase();
      return name.contains(q);
    }).toList();
  }

  String _displayName(Map<String, dynamic> u) =>
      '${u['display_name'] ?? u['name'] ?? ''}';

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _openProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          token: widget.token,
          currentUser: widget.currentUser,
          username: username,
          navIndex: 0,
        ),
      ),
    );
  }

  /// 4015 -> "4.015", 14700 -> "14,7RB", 1100000 -> "1,1JT"
  String _formatCount(dynamic raw) {
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? 0}') ?? 0;

    String short(double v, String unit) {
      final s = v.toStringAsFixed(1).replaceAll('.', ',');
      return '${s.endsWith(',0') ? s.substring(0, s.length - 2) : s}$unit';
    }

    if (n >= 1000000) return short(n / 1000000, 'JT');
    if (n >= 10000) return short(n / 1000, 'RB');

    return n.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (_) => '.',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const Text(
                    'Cari',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white, fontSize: 17),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _field,
                  hintText: 'Cari',
                  hintStyle: const TextStyle(color: _muted, fontSize: 17),
                  prefixIcon: const Icon(Icons.search, color: _muted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gagal memuat akun.',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: _muted, fontSize: 12)),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    final list = _filtered;

    if (list.isEmpty) {
      return const Center(
        child: Text('Akun tidak ditemukan.',
            style: TextStyle(color: _muted, fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: 80,
          color: Color(0xFF292929),
        ),
        itemBuilder: (_, i) => _row(list[i]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> u) {
    final username = '${u['username'] ?? ''}';
    final name = _displayName(u);
    final followed = _following.contains(username);
    final requested = _requested.contains(username);
    final active = followed || requested;

    return InkWell(
      onTap: () => _openProfile(username),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            UserAvatar(
              url: (u['profile_picture'] ?? u['avatar_url'])?.toString(),
              size: 48,
            ),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 17),
                    ),
                  if (u['followers_count'] != null)
                    Text(
                      '${_formatCount(u['followers_count'])} pengikut',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 128,
              height: 44,
              child: active
                  ? OutlinedButton(
                      onPressed: () => _toggleFollow(username),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF3A3A3A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        requested ? 'Diminta' : 'Mengikuti',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _toggleFollow(username),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F5F7),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Ikuti',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}