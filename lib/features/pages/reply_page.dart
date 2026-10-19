import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'widgets/user_avatar.dart';

/// Layar penuh "Balas": postingan yang dibalas di atas, lalu kolom balasan
/// dengan baris ikon (foto, GIF, stiker, musik, lainnya), "Tambahkan balasan
/// lain", "Opsi balasan", dan tombol Posting.
///
///   final posted = await Navigator.push<bool>(context, MaterialPageRoute(
///     builder: (_) => ReplyPage(
///       token: token,
///       post: post,
///       currentUser: user,
///       // target: komentar yang dibalas (kosong = membalas utasnya langsung)
///     ),
///   ));
///
/// Setelah berhasil, `post['comment_count']` diperbarui langsung dan halaman
/// ditutup dengan hasil `true`.
class ReplyPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> post;
  final Map<String, dynamic>? target;
  final Map<String, dynamic> currentUser;

  const ReplyPage({
    super.key,
    required this.token,
    required this.post,
    required this.currentUser,
    this.target,
  });

  @override
  State<ReplyPage> createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  static const _bg = Color(0xFF101010);
  static const _muted = Color(0xFF858585);
  static const _line = Color(0xFF292929);

  final List<TextEditingController> _fields = [TextEditingController()];
  final List<FocusNode> _focuses = [FocusNode()];

  bool _sending = false;
  String? _error;

  Map<String, dynamic> get _replied => widget.target ?? widget.post;
  String get _repliedName => '${_replied['username'] ?? 'user'}';
  String get _myName => '${widget.currentUser['username'] ?? ''}';

  String? get _myPicture =>
      (widget.currentUser['avatar_url'] ?? widget.currentUser['profile_picture'])
          ?.toString();

  bool get _canPost =>
      !_sending && _fields.first.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focuses.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    super.dispose();
  }

  void _soon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Segera hadir.')));
  }

  void _addField() {
    setState(() {
      _fields.add(TextEditingController());
      _focuses.add(FocusNode());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focuses.last.requestFocus();
    });
  }

  Future<void> _submit() async {
    if (!_canPost) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    // Balasan pertama ke postingan/komentar yang dibalas; balasan berikutnya
    // menyambung ke balasan sebelumnya (satu utas).
    Object? parent = widget.target?['id'];
    int? count;

    try {
      for (final field in _fields) {
        final text = field.text.trim();
        if (text.isEmpty) continue;

        final result = await ApiService.addComment(
          token: widget.token,
          postId: widget.post['id'],
          content: text,
          parentId: parent,
        );

        final comment = Map<String, dynamic>.from(result['comment'] as Map);
        parent = comment['id'];

        final n = result['comment_count'];
        if (n is num) count = n.toInt();
      }

      if (count != null) widget.post['comment_count'] = count;

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _sending = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ───────────────────────── UI ─────────────────────────

  Widget _iconButton(Widget icon) {
    return InkWell(
      onTap: _soon,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.all(8), child: icon),
    );
  }

  Widget _gifIcon() {
    return Container(
      width: 28,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: _muted, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _toolRow() {
    return Row(
      children: [
        _iconButton(const Icon(Icons.image_outlined, color: _muted, size: 28)),
        _iconButton(_gifIcon()),
        _iconButton(
          const Icon(Icons.sticky_note_2_outlined, color: _muted, size: 28),
        ),
        _iconButton(const Icon(Icons.music_note_outlined, color: _muted, size: 28)),
        _iconButton(const Icon(Icons.more_horiz_rounded, color: _muted, size: 28)),
      ],
    );
  }

  /// Postingan / komentar yang sedang dibalas.
  Widget _repliedPreview() {
    final content = '${_replied['content'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            url: (_replied['avatar_url'] ?? _replied['profile_picture'])
                ?.toString(),
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _repliedName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      content,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _firstField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(url: _myPicture, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _myName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: _muted, size: 22),
                    const SizedBox(width: 2),
                    const Flexible(
                      child: Text(
                        'Komunitas atau topik',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _muted, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _fields.first,
                  focusNode: _focuses.first,
                  minLines: 1,
                  maxLines: 8,
                  maxLength: 500,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'Balas $_repliedName...',
                    hintStyle: const TextStyle(color: _muted, fontSize: 18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                _toolRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Balasan tambahan (index >= 1).
  Widget _extraField(int i) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(url: _myPicture, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: TextField(
              controller: _fields[i],
              focusNode: _focuses[i],
              minLines: 1,
              maxLines: 6,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                counterText: '',
                hintText: 'Tambahkan balasan lain',
                hintStyle: TextStyle(color: _muted, fontSize: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addAnother() {
    final enabled = _fields.last.text.trim().isNotEmpty;

    return InkWell(
      onTap: enabled ? _addField : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 18, 16, 8),
        child: Row(
          children: [
            Opacity(
              opacity: enabled ? 1 : 0.45,
              child: UserAvatar(url: _myPicture, size: 28),
            ),
            const SizedBox(width: 20),
            Text(
              'Tambahkan balasan lain',
              style: TextStyle(
                color: enabled ? _muted : const Color(0xFF4A4A4A),
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Balas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _soon,
                    icon: const Icon(Icons.article_outlined,
                        color: Colors.white, size: 30),
                  ),
                  IconButton(
                    onPressed: _soon,
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: Colors.white, size: 30),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _repliedPreview(),
                    _firstField(),
                    for (var i = 1; i < _fields.length; i++) _extraField(i),
                    _addAnother(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFFF3040),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: _soon,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: _muted, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Opsi balasan',
                            style: TextStyle(color: _muted, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _canPost ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F5F7),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF242424),
                        disabledForegroundColor: const Color(0xFF5E5E5E),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Posting',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}