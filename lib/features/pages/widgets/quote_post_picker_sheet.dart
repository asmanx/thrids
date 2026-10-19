import 'package:flutter/material.dart';

import '../../../services/api_service.dart';

/// Bottom sheet untuk memilih postingan yang akan dikutip.
/// Mengembalikan map postingan yang dipilih (punya id, content, username, ...).
class QuotePostPickerSheet extends StatefulWidget {
  const QuotePostPickerSheet({super.key});

  @override
  State<QuotePostPickerSheet> createState() => _QuotePostPickerSheetState();
}

class _QuotePostPickerSheetState extends State<QuotePostPickerSheet> {
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);

  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final posts = await ApiService.getPosts();

      if (!mounted) return;

      setState(() {
        _posts = posts;
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
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
              'Pilih postingan untuk dikutip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, color: separator),
          Expanded(child: _buildBody()),
        ],
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

    if (_posts.isEmpty) {
      return const Center(
        child: Text('Belum ada postingan.', style: TextStyle(color: muted)),
      );
    }

    return ListView.separated(
      itemCount: _posts.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: separator),
      itemBuilder: (context, index) {
        final post = _posts[index];
        final content = (post['content'] as String?)?.trim() ?? '';
        final hasMedia = (post['media'] is List) &&
            (post['media'] as List).isNotEmpty;

        return ListTile(
          onTap: () => Navigator.pop(context, post),
          title: Text(
            post['username'] as String? ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            content.isNotEmpty
                ? content
                : (hasMedia ? '[Foto/video]' : '[Tanpa teks]'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted),
          ),
        );
      },
    );
  }
}
