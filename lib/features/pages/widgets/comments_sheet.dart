import 'package:flutter/material.dart';

import '../../../services/api_service.dart';

/// Bottom sheet komentar sebuah postingan: daftar komentar + kolom balas.
///
///   await CommentsSheet.show(
///     context,
///     token: token,
///     post: post,
///     onCountChanged: (count) => setState(() => post['comment_count'] = count),
///   );
class CommentsSheet extends StatefulWidget {
  final String token;
  final Map<String, dynamic> post;
  final ValueChanged<int> onCountChanged;

  const CommentsSheet({
    super.key,
    required this.token,
    required this.post,
    required this.onCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String token,
    required Map<String, dynamic> post,
    required ValueChanged<int> onCountChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF181818),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(
        token: token,
        post: post,
        onCountChanged: onCountChanged,
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final comments = await ApiService.getComments(postId: widget.post['id']);

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final result = await ApiService.addComment(
        token: widget.token,
        postId: widget.post['id'],
        content: text,
      );

      if (!mounted) return;

      final comment = Map<String, dynamic>.from(result['comment'] as Map);

      setState(() {
        _comments = [..._comments, comment];
        _controller.clear();
      });

      widget.onCountChanged((result['comment_count'] as num?)?.toInt() ?? _comments.length);

      // Gulir ke komentar terbaru setelah daftar dibangun ulang.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse('$value');
    if (date == null) return '';

    final difference = DateTime.now().difference(date.toLocal());

    if (difference.inSeconds < 60) return 'Baru saja';
    if (difference.inMinutes < 60) return '${difference.inMinutes} m';
    if (difference.inHours < 24) return '${difference.inHours} j';
    if (difference.inDays < 7) return '${difference.inDays} h';

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.85,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Balasan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 1, color: separator),
            Expanded(child: _buildBody()),
            const Divider(height: 1, color: separator),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: muted)),
            TextButton(onPressed: _load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }

    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada balasan. Jadilah yang pertama!',
          style: TextStyle(color: muted),
        ),
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) => _buildComment(_comments[index]),
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    final username = (comment['username'] ?? 'user').toString();
    final initial = username.isEmpty ? 'U' : username.substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF383838),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment['created_at']),
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  (comment['content'] ?? '').toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Balas...',
                hintStyle: const TextStyle(color: muted),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF1C1C1C),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: 'Kirim',
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
        ],
      ),
    );
  }
}