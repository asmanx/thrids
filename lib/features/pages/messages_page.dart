import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'chat_page.dart';
import 'new_message_page.dart';
import 'widgets/app_bottom_nav.dart';
import 'widgets/chat_utils.dart';
import 'widgets/group_avatar.dart';
import 'widgets/user_avatar.dart';

const _kBg = Color(0xFF101010);
const _kMuted = Color(0xFF858585);
const _kField = Color(0xFF1C1C1C);
const _kBorder = Color(0xFF2E2E2E);

const _filterLabels = <String, String>{
  'all': 'Semua',
  'unread': 'Belum dibaca',
  'unanswered': 'Belum dijawab',
  'verified': 'Terverifikasi',
};

// ════════════════════════════════════════════════════════════════════
//  KOTAK MASUK
// ════════════════════════════════════════════════════════════════════

/// Halaman "Pesan": daftar percakapan, pencarian, filter, dan tombol Permintaan.
///
/// [onNavigate] dipanggil saat tombol navigasi bawah selain "Pesan" ditekan
/// (0 = home, 2 = buat utas, 3 = aktivitas, 4 = profil). Kalau null, halaman
/// ini cukup kembali ke Home.
class MessagesPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;
  final ValueChanged<int>? onNavigate;

  const MessagesPage({
    super.key,
    required this.token,
    required this.currentUser,
    this.onNavigate,
  });

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> _items = [];
  int _requestCount = 0;
  bool _loading = true;
  String? _error;

  String _filter = 'all';
  String _query = '';

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      final result = await ApiService.getConversations(
        token: widget.token,
        filter: _filter,
      );

      if (!mounted) return;

      setState(() {
        _items = result.conversations;
        _requestCount = result.requestCount;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || (silent && _items.isNotEmpty)) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items.where((item) {
      final user = Map<String, dynamic>.from(item['user'] as Map);
      return '${user['username']}'.toLowerCase().contains(q) ||
          '${user['display_name']}'.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openChat(Map<String, dynamic> item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          token: widget.token,
          currentUser: widget.currentUser,
          conversationId: item['id'],
          user: Map<String, dynamic>.from(item['user'] as Map),
        ),
      ),
    );

    if (mounted) _load(silent: true);
  }

  Future<void> _openNewMessage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => NewMessagePage(
          token: widget.token,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (mounted) _load(silent: true);
  }

  Future<void> _openRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessageRequestsPage(
          token: widget.token,
          currentUser: widget.currentUser,
        ),
      ),
    );

    if (mounted) _load(silent: true);
  }

  void _onNavTap(int index) {
    if (index == 1) return;

    final callback = widget.onNavigate;

    if (callback != null) {
      callback(index);
      return;
    }

    if (index == 2) {
      _toast('Buka dari beranda untuk membuat utas.');
      return;
    }

    // Tanpa callback: cukup tutup halaman Pesan (jangan sampai ke halaman login).
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      bottomNavigationBar: AppBottomNav(selectedIndex: 1, onTap: _onNavTap),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pesan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pesan baru',
                    onPressed: _openNewMessage,
                    icon: const Icon(Icons.edit_square, size: 30),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SearchField(onChanged: (value) => setState(() => _query = value)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                children: [
                  _FilterButton(
                    selected: _filter,
                    onSelected: (value) {
                      setState(() => _filter = value);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  const _PillChip(label: 'Kotak masuk', selected: true),
                  const SizedBox(width: 8),
                  _PillChip(
                    label: 'Permintaan',
                    badge: _requestCount,
                    onTap: _openRequests,
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null && _items.isEmpty) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final items = _visible;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: items.isEmpty
          ? LayoutBuilder(
              builder: (context, constraints) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: constraints.maxHeight,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _items.isEmpty
                                  ? 'Belum ada pesan'
                                  : 'Tidak ada hasil',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _items.isEmpty
                                  ? 'Kirim pesan pertamamu lewat tombol di kanan atas.'
                                  : 'Coba kata kunci atau filter lain.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _kMuted,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 6),
              itemCount: items.length,
              itemBuilder: (_, index) => ConversationTile(
                item: items[index],
                onTap: () => _openChat(items[index]),
              ),
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PERMINTAAN PESAN
// ════════════════════════════════════════════════════════════════════

/// Pesan dari orang yang tidak kamu ikuti. Tab "Disembunyikan" berisi
/// permintaan yang sudah kamu sembunyikan (tekan lama untuk menyembunyikan
/// atau memulihkan).
class MessageRequestsPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> currentUser;

  const MessageRequestsPage({
    super.key,
    required this.token,
    required this.currentUser,
  });

  @override
  State<MessageRequestsPage> createState() => _MessageRequestsPageState();
}

class _MessageRequestsPageState extends State<MessageRequestsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String _box = 'requests';
  String _filter = 'all';
  String _query = '';

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
      final result = await ApiService.getConversations(
        token: widget.token,
        box: _box,
        filter: _filter,
      );

      if (!mounted) return;

      setState(() {
        _items = result.conversations;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || (silent && _items.isNotEmpty)) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;

    return _items.where((item) {
      final user = Map<String, dynamic>.from(item['user'] as Map);
      return '${user['username']}'.toLowerCase().contains(q) ||
          '${user['display_name']}'.toLowerCase().contains(q);
    }).toList();
  }

  void _switchBox(String box) {
    if (_box == box) return;
    setState(() => _box = box);
    _load();
  }

  Future<void> _openChat(Map<String, dynamic> item) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          token: widget.token,
          currentUser: widget.currentUser,
          conversationId: item['id'],
          user: Map<String, dynamic>.from(item['user'] as Map),
        ),
      ),
    );

    if (mounted) _load(silent: true);
  }

  Future<void> _showActions(Map<String, dynamic> item) async {
    final hiding = _box == 'requests';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                hiding ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white,
              ),
              title: Text(
                hiding ? 'Sembunyikan permintaan' : 'Pulihkan ke Permintaan',
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.hideConversation(
        token: widget.token,
        conversationId: item['id'],
        hidden: hiding,
      );

      if (mounted) _load(silent: true);
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    icon: const Icon(Icons.arrow_back, size: 30),
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Permintaan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SearchField(onChanged: (value) => setState(() => _query = value)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                children: [
                  _FilterButton(
                    selected: _filter,
                    onSelected: (value) {
                      setState(() => _filter = value);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  _PillChip(
                    label: 'Permintaan',
                    selected: _box == 'requests',
                    onTap: () => _switchBox('requests'),
                  ),
                  const SizedBox(width: 8),
                  _PillChip(
                    label: 'Disembunyikan',
                    selected: _box == 'hidden',
                    onTap: () => _switchBox('hidden'),
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 8),
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

    if (_error != null && _items.isEmpty) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final items = _visible;

    if (items.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: Colors.white,
      backgroundColor: const Color(0xFF242424),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6),
        itemCount: items.length,
        itemBuilder: (_, index) => ConversationTile(
          item: items[index],
          onTap: () => _openChat(items[index]),
          onLongPress: () => _showActions(items[index]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final hidden = _box == 'hidden';

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: _kField,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_outlined, size: 56, color: _kMuted),
            ),
            const SizedBox(height: 28),
            Text(
              hidden
                  ? 'Tidak ada permintaan tersembunyi'
                  : 'Belum ada permintaan pesan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hidden
                  ? 'Permintaan yang kamu sembunyikan akan muncul di sini.'
                  : 'Pesan dari orang yang tidak Anda ikuti akan ditampilkan '
                      'di sini. Anda bisa menonaktifkannya kapan saja.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 18, height: 1.4),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () => _toast('Fitur pengaturan pesan belum tersedia.'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF3A3A3A)),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Kelola pengaturan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  KOMPONEN BERSAMA
// ════════════════════════════════════════════════════════════════════

/// Satu baris percakapan: avatar, nama, cuplikan pesan terakhir, dan waktu.
class ConversationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ConversationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final user = Map<String, dynamic>.from(item['user'] as Map);
    final last = item['last_message'] == null
        ? null
        : Map<String, dynamic>.from(item['last_message'] as Map);

    final unread = (item['unread_count'] as num?)?.toInt() ?? 0;
    final muted = item['is_muted'] == true;

    final isGroup = item['is_group'] == true;
    final preview = messagePreview(last, group: isGroup);
    final time = chatListTime(last?['created_at']);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            if (isGroup)
              GroupAvatar(
                pictures: [
                  for (final p in (item['preview_pictures'] as List? ?? const []))
                    pictureOf(p),
                ],
                size: 62,
              )
            else
              UserAvatar(url: pictureOf(user['profile_picture']), size: 62),
            const SizedBox(width: 16),
            Expanded(
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
                  const SizedBox(height: 3),
                  Text(
                    time.isEmpty ? preview : '$preview · $time',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0 ? Colors.white : _kMuted,
                      fontSize: 17,
                      fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (muted)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 18,
                  color: _kMuted,
                ),
              ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 10),
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  color: Color(0xFF0095F6),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          hintText: 'Cari',
          hintStyle: const TextStyle(color: _kMuted, fontSize: 20),
          prefixIcon: const Icon(Icons.search, color: _kMuted, size: 28),
          filled: true,
          fillColor: _kField,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon tiga garis yang membuka menu filter.
class _FilterButton extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterButton({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter',
      onSelected: onSelected,
      offset: const Offset(0, 54),
      color: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 236),
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          enabled: false,
          height: 40,
          child: Text(
            'Filter',
            style: TextStyle(color: _kMuted, fontSize: 15),
          ),
        ),
        for (final entry in _filterLabels.entries) ...[
          const PopupMenuDivider(height: 1),
          PopupMenuItem<String>(
            value: entry.key,
            height: 56,
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: selected == entry.key
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
                Text(
                  entry.value,
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        width: 50,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected == 'all' ? _kBorder : Colors.white54,
            width: 1.2,
          ),
        ),
        child: const Icon(Icons.filter_list_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback? onTap;

  const _PillChip({
    required this.label,
    this.selected = false,
    this.badge = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF242424) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _kBorder, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3040),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Gagal memuat pesan.',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
            TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}