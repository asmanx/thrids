import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// API key Giphy (gratis di https://developers.giphy.com/ -> Create an App -> API).
///
/// Cara mengisi, pilih salah satu:
///   1. Tempel key kamu di `defaultValue` di bawah, atau
///   2. Jalankan: flutter run --dart-define=GIPHY_API_KEY=key_kamu

const String kGiphyApiKey = 'uiWZMNrCABVijEYb8nOQ50IiHfsKa2Su';


class _GiphyItem {
  final String previewUrl;
  final String url;

  const _GiphyItem(this.previewUrl, this.url);
}

/// Bottom sheet pemilih GIF atau stiker. Mengembalikan URL yang dipilih.
class GiphyPickerSheet extends StatefulWidget {
  final bool stickers;

  const GiphyPickerSheet({super.key, required this.stickers});

  @override
  State<GiphyPickerSheet> createState() => _GiphyPickerSheetState();
}

class _GiphyPickerSheetState extends State<GiphyPickerSheet> {
  static const muted = Color(0xFF858585);
  static const separator = Color(0xFF292929);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  int _requestId = 0;

  List<_GiphyItem> _items = [];
  bool _loading = false;
  String? _error;

  String get _label => widget.stickers ? 'stiker' : 'GIF';

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(value));
  }

  Future<void> _load(String query) async {
    if (kGiphyApiKey.isEmpty) {
      setState(() {
        _error = 'API key Giphy belum diisi.\n'
            'Buka giphy_picker_sheet.dart lalu isi kGiphyApiKey, '
            'atau jalankan dengan --dart-define=GIPHY_API_KEY=...';
      });
      return;
    }

    final requestId = ++_requestId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final kind = widget.stickers ? 'stickers' : 'gifs';
      final text = query.trim();

      final uri = Uri.https(
        'api.giphy.com',
        text.isEmpty ? '/v1/$kind/trending' : '/v1/$kind/search',
        {
          'api_key': kGiphyApiKey,
          'limit': '30',
          'rating': 'g',
          if (text.isNotEmpty) 'q': text,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Giphy ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = <_GiphyItem>[];

      for (final raw in (data['data'] as List? ?? const [])) {
        final images = (raw as Map<String, dynamic>)['images'] as Map?;
        final full = (images?['fixed_height'] as Map?)?['url'] as String?;
        final preview =
            ((images?['fixed_width_small'] ?? images?['fixed_width']) as Map?)?[
                    'url'] as String? ??
                full;

        if (full != null && preview != null) {
          items.add(_GiphyItem(preview, full));
        }
      }

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _loading = false;
        _error = 'Gagal memuat $_label. Periksa koneksi internet lalu coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Cari $_label',
                  hintStyle: const TextStyle(color: muted),
                  prefixIcon: const Icon(Icons.search, color: muted),
                  filled: true,
                  fillColor: const Color(0xFF1C1C1C),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody()),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Powered by GIPHY',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.4),
          ),
        ),
      );
    }

    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada $_label ditemukan.',
          style: const TextStyle(color: muted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];

        return GestureDetector(
          onTap: () => Navigator.pop(context, item.url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: const Color(0xFF222222),
              child: Image.network(
                item.previewUrl,
                fit: widget.stickers ? BoxFit.contain : BoxFit.cover,
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.broken_image_outlined,
                  color: muted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
