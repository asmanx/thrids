import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'chat_page.dart';
import 'pick_people_page.dart';
import 'widgets/chat_utils.dart';
import 'widgets/user_avatar.dart';

/// Halaman "Pesan baru": pilih orang yang akan dikirimi pesan.
/// Akun yang kamu ikuti atau yang mengikutimu tampil lebih dulu.
class NewMessagePage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;

  const NewMessagePage({
    super.key,
    required this.token,
    required this.currentUser,
  });

  @override
  State<NewMessagePage> createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF858585);
  static const kBorder = Color(0xFF2E2E2E);

  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _opening = false;
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
        _users = users;
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

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _choose(Map<String, dynamic> user) async {
    if (_opening) return;

    setState(() => _opening = true);

    try {
      final conversation = await ApiService.openConversation(
        token: widget.token,
        username: '${user['username']}',
      );

      if (!mounted) return;

      // Ganti halaman ini dengan obrolan, supaya "kembali" langsung ke daftar pesan.
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            token: widget.token,
            currentUser: widget.currentUser,
            conversationId: conversation['id'],
            user: user,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// "Buat obrolan grup": pilih minimal 2 orang (nama grup opsional), lalu
  /// buka obrolan grupnya.
  Future<void> _createGroup() async {
    if (_opening) return;

    final picked = await Navigator.of(context).push<PickedPeople>(
      MaterialPageRoute(
        builder: (_) => PickPeoplePage(
          token: widget.token,
          title: 'Grup baru',
          actionLabel: 'Buat',
          minPick: 2,
          maxPick: 31,
          askName: true,
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _opening = true);

    try {
      final conversation = await ApiService.createGroup(
        token: widget.token,
        name: picked.name,
        usernames: picked.usernames,
      );

      if (!mounted) return;

      final user = conversation['user'] is Map
          ? Map<String, dynamic>.from(conversation['user'] as Map)
          : <String, dynamic>{
              'is_group': true,
              'username': picked.name.isEmpty ? 'Grup' : picked.name,
            };

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            token: widget.token,
            currentUser: widget.currentUser,
            conversationId: conversation['id'],
            user: user,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _opening = false);
      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _search.text.trim().isNotEmpty;

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
        title: const Text(
          'Pesan baru',
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 16, 6),
            child: Row(
              children: [
                const Text(
                  'Kepada:',
                  style: TextStyle(color: kMuted, fontSize: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _search,
                    autofocus: false,
                    onChanged: (value) {
                      setState(() {});
                      _onChanged(value);
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 19),
                    decoration: const InputDecoration(
                      hintText: 'Cari',
                      hintStyle: TextStyle(color: Color(0xFF5E5E5E)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (!searching) ...[
                  InkWell(
                    onTap: _createGroup,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1C1C1C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Buat obrolan grup',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: kMuted),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 18, 20, 10),
                    child: Text(
                      'Disarankan',
                      style: TextStyle(color: kMuted, fontSize: 19),
                    ),
                  ),
                ],
                ..._buildUsers(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildUsers() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ];
    }

    if (_error != null) {
      return [
        Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kMuted),
              ),
              TextButton(onPressed: _load, child: const Text('Coba lagi')),
            ],
          ),
        ),
      ];
    }

    if (_users.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Text(
              'Akun tidak ditemukan.',
              style: TextStyle(color: kMuted, fontSize: 17),
            ),
          ),
        ),
      ];
    }

    return [
      for (final user in _users)
        InkWell(
          onTap: () => _choose(user),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                UserAvatar(url: pictureOf(user['profile_picture']), size: 58),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: kBorder)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user['username']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user['display_name']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}