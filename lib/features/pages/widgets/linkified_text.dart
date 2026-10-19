import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/api_service.dart';
import '../post_detail_page.dart';

/// Teks biasa, tetapi alamat web di dalamnya (https://..., http://..., www....)
/// berwarna biru dan bisa diketuk.
///
///   LinkifiedText(
///     text: post['content'],
///     style: const TextStyle(color: Colors.white, fontSize: 17),
///     onTapLink: (url) => openLink(context, url, token: t, currentUser: u),
///   )
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color linkColor;
  final int? maxLines;
  final TextOverflow? overflow;
  final ValueChanged<String> onTapLink;

  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.onTapLink,
    this.linkColor = const Color(0xFF4EA8FF),
    this.maxLines,
    this.overflow,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  static final RegExp _urlPattern = RegExp(
    r'(https?://[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );

  /// Tanda baca di ujung tautan bukan bagian dari alamatnya.
  static const String _trailing = '.,;:!?)]}\'"';

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _spans() {
    _disposeRecognizers();

    final text = widget.text;
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in _urlPattern.allMatches(text)) {
      var url = match.group(0)!;
      var tail = '';

      while (url.isNotEmpty && _trailing.contains(url[url.length - 1])) {
        tail = '${url[url.length - 1]}$tail';
        url = url.substring(0, url.length - 1);
      }

      if (url.isEmpty) continue;

      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onTapLink(url);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: url,
          recognizer: recognizer,
          style: widget.style.copyWith(
            color: widget.linkColor,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor,
          ),
        ),
      );

      if (tail.isNotEmpty) spans.add(TextSpan(text: tail));

      cursor = match.end;
    }

    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    // Tanpa tautan: Text biasa (tanpa pengenal ketukan).
    if (!_urlPattern.hasMatch(widget.text)) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return Text.rich(
      TextSpan(style: widget.style, children: _spans()),
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
    );
  }
}

/// Membuka tautan:
///  - tautan postingan Thrids ({server}/post/12) dibuka di dalam aplikasi
///  - tautan lain dibuka di browser / aplikasi yang sesuai
Future<void> openLink(
  BuildContext context,
  String url, {
  required String token,
  required Map<String, dynamic> currentUser,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  void say(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  final uri = Uri.tryParse(url.toLowerCase().startsWith('www.') ? 'https://$url' : url);

  if (uri == null || !uri.hasScheme) {
    say('Tautan tidak valid.');
    return;
  }

  final server = Uri.tryParse(ApiService.serverUrl);
  final match = RegExp(r'^/post/(\d+)/?$').firstMatch(uri.path);

  if (match != null && server != null && uri.host == server.host) {
    try {
      final posts = await ApiService.getPosts(token: token);

      Map<String, dynamic>? found;
      for (final p in posts) {
        if ('${p['id']}' == match.group(1)) {
          found = p;
          break;
        }
      }

      if (found == null) {
        say('Postingan tidak ditemukan, sudah kedaluwarsa, atau akunnya privat.');
        return;
      }

      final post = found;

      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => PostDetailPage(
            token: token,
            post: post,
            currentUser: currentUser,
            onChanged: () {},
          ),
        ),
      );
      return;
    } catch (_) {
      // Gagal memuat di dalam aplikasi: coba buka lewat browser.
    }
  }

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) say('Tidak bisa membuka tautan.');
  } catch (_) {
    say('Tidak bisa membuka tautan.');
  }
}