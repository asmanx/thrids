import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import 'user_avatar.dart';

/// Lembar "bagikan" sebuah postingan (tombol pesawat kertas):
///  - kolom Cari + baris orang yang bisa dikirimi pesan (bisa pilih banyak)
///  - setelah ada yang dipilih: kolom "Kirim Pesan..." dan tombol Kirim
///  - belum ada yang dipilih: baris WhatsApp / cerita Instagram / Tautan /
///    Lainnya
///
///   await ShareSheet.show(context, token: token, post: post);
class ShareSheet extends StatefulWidget {
  final String token;
  final Map<String, dynamic> post;

  const ShareSheet({super.key, required this.token, required this.post});

  static Future<void> show(
    BuildContext context, {
    required String token,
    required Map<String, dynamic> post,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1B1B1B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ShareSheet(token: token, post: post),
    );
  }

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  static const _field = Color(0xFF262626);
  static const _muted = Color(0xFF858585);

  final _search = TextEditingController();
  final _message = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  final List<String> _selected = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int _loadId = 0;

  String get _link => '${ApiService.serverUrl}/post/${widget.post['id']}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_loadId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await ApiService.searchMessageUsers(
        token: widget.token,
        query: _search.text.trim(),
      );

      // Abaikan hasil lama bila pengguna sudah mengetik lagi.
      if (!mounted || id != _loadId) return;

      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || id != _loadId) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _toggle(String username) {
    setState(() {
      if (!_selected.remove(username)) _selected.add(username);
    });
  }

  Future<void> _copyLink(String hint) async {
    final messenger = ScaffoldMessenger.of(context);

    await Clipboard.setData(ClipboardData(text: _link));

    if (!mounted) return;

    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(hint)));
  }

  /// Buka WhatsApp dengan tautan postingan terisi; bila gagal, salin tautan.
  Future<void> _shareWhatsApp() async {
    final navigator = Navigator.of(context);
    final who = '${widget.post['username'] ?? ''}';
    final text = who.isEmpty
        ? _link
        : 'Lihat postingan @$who di Thrids: $_link';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (ok) {
        if (mounted) navigator.pop();
        return;
      }
    } catch (_) {}

    await _copyLink('WhatsApp tidak bisa dibuka. Tautan disalin.');
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final note = _message.text.trim();

    setState(() => _sending = true);

    var sent = 0;
    String? lastError;

    for (final username in _selected) {
      try {
        final conversation = await ApiService.openConversation(
          token: widget.token,
          username: username,
        );

        final id = conversation['id'];
        if (id == null) throw Exception('Percakapan tidak dapat dibuka.');

        await ApiService.sendMessage(
          token: widget.token,
          conversationId: id,
          // Tautan ikut dikirim supaya postingan tetap bisa dibuka.
          content: note.isEmpty ? _link : '$note\n$_link',
          postId: widget.post['id'],
        );

        sent++;
      } catch (error) {
        lastError = error.toString().replaceFirst('Exception: ', '');
      }
    }

    if (!mounted) return;

    if (sent == 0) {
      setState(() {
        _sending = false;
        _error = lastError ?? 'Gagal mengirim pesan.';
      });
      return;
    }

    navigator.pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sent == _selected.length
              ? 'Terkirim ke $sent orang.'
              : 'Terkirim ke $sent dari ${_selected.length} orang.',
        ),
      ),
    );
  }

  // ───────────────────────── UI ─────────────────────────

  Widget _person(Map<String, dynamic> u) {
    final username = '${u['username'] ?? ''}';
    final name = '${u['display_name'] ?? u['name'] ?? ''}';
    final picked = _selected.contains(username);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(username),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    url: (u['avatar_url'] ?? u['profile_picture'])?.toString(),
                    size: 68,
                  ),
                  if (picked)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF1B1B1B),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 17, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (name.isNotEmpty)
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _target(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFF242424),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _people() {
    if (_loading && _users.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null && _users.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(_error!, style: const TextStyle(color: _muted)),
        ),
      );
    }

    if (_users.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Tidak ada orang ditemukan.',
              style: TextStyle(color: _muted)),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _users.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _person(_users[i]),
      ),
    );
  }

  Widget _bottom() {
    if (_selected.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _message,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Kirim Pesan...',
                hintStyle: TextStyle(color: _muted, fontSize: 18),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF3040), fontSize: 13),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F5F7),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(0xFF3A3A3A),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Kirim',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 142,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        children: [
          _target(
            'WhatsApp',
            Icons.chat_rounded,
            const Color(0xFF25D366),
            _shareWhatsApp,
          ),
          const SizedBox(width: 8),
          _target(
            'cerita Instagram',
            Icons.add_circle_outline,
            const Color(0xFFE1306C),
            () => _copyLink('Tautan disalin. Tempel di Instagram.'),
          ),
          const SizedBox(width: 8),
          _target(
            'Tautan',
            Icons.link_rounded,
            Colors.white,
            () => _copyLink('Tautan postingan disalin.'),
          ),
          const SizedBox(width: 8),
          _target(
            'Lainnya',
            Icons.ios_share,
            Colors.white,
            () => _copyLink('Tautan postingan disalin.'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF5A5A5A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (_) => _load(),
                style: const TextStyle(color: Colors.white, fontSize: 19),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _field,
                  hintText: 'Cari',
                  hintStyle: const TextStyle(color: _muted, fontSize: 19),
                  prefixIcon: const Icon(Icons.search, color: _muted, size: 26),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _people(),
            const Divider(height: 1, color: Color(0xFF2C2C2C)),
            _bottom(),
          ],
        ),
      ),
    );
  }
}