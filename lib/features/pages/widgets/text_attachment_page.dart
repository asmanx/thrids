import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════
//  FORMAT LAMPIRAN TEKS
// ════════════════════════════════════════════════════════════════════
//
// Lampiran teks disimpan sebagai satu string dengan penanda gaya yang
// memakai karakter privat (tidak mungkin diketik pengguna), mis.
//   <b>tebal</b>  ->  "\uE000b\uE001tebal\uE000/b\uE001"
// Backend cukup menyimpannya apa adanya (kolom posts.text_attachment).

const int kStyleBold = 1;
const int kStyleItalic = 2;
const int kStyleUnderline = 4;
const int kStyleStrike = 8;

const String _open = '\uE000';
const String _close = '\uE001';

const List<int> _bits = [kStyleBold, kStyleItalic, kStyleUnderline, kStyleStrike];

String _tagOf(int bit) {
  switch (bit) {
    case kStyleBold:
      return 'b';
    case kStyleItalic:
      return 'i';
    case kStyleUnderline:
      return 'u';
    default:
      return 's';
  }
}

int _bitOf(String tag) {
  switch (tag) {
    case 'b':
      return kStyleBold;
    case 'i':
      return kStyleItalic;
    case 'u':
      return kStyleUnderline;
    case 's':
      return kStyleStrike;
    default:
      return 0;
  }
}

TextStyle _maskStyle(int mask) {
  final decorations = <TextDecoration>[
    if (mask & kStyleUnderline != 0) TextDecoration.underline,
    if (mask & kStyleStrike != 0) TextDecoration.lineThrough,
  ];

  return TextStyle(
    fontWeight: mask & kStyleBold != 0 ? FontWeight.w700 : null,
    fontStyle: mask & kStyleItalic != 0 ? FontStyle.italic : null,
    decoration: decorations.isEmpty ? null : TextDecoration.combine(decorations),
  );
}

/// Mengubah teks + gaya per karakter menjadi string penanda, dan sebaliknya.
class TextAttachmentMarkup {
  TextAttachmentMarkup._();

  static String encode(String text, List<int> masks) {
    final out = StringBuffer();
    var i = 0;

    while (i < text.length) {
      final mask = masks[i];
      var j = i + 1;

      while (j < text.length && masks[j] == mask) {
        j++;
      }

      final chunk = text.substring(i, j);
      final active = _bits.where((bit) => mask & bit != 0).toList();

      for (final bit in active) {
        out.write('$_open${_tagOf(bit)}$_close');
      }

      out.write(chunk);

      for (final bit in active.reversed) {
        out.write('$_open/${_tagOf(bit)}$_close');
      }

      i = j;
    }

    return out.toString();
  }

  static ({String text, List<int> masks}) decode(String markup) {
    final text = StringBuffer();
    final masks = <int>[];
    var mask = 0;
    var i = 0;

    while (i < markup.length) {
      final ch = markup[i];

      if (ch == _open) {
        final end = markup.indexOf(_close, i + 1);

        if (end != -1) {
          final tag = markup.substring(i + 1, end);
          final closing = tag.startsWith('/');
          final bit = _bitOf(closing ? tag.substring(1) : tag);

          if (bit != 0) {
            mask = closing ? (mask & ~bit) : (mask | bit);
          }

          i = end + 1;
          continue;
        }
      }

      text.write(ch);
      masks.add(mask);
      i++;
    }

    return (text: text.toString(), masks: masks);
  }

  /// Teks polos (tanpa gaya), mis. untuk cuplikan.
  static String plain(String markup) => decode(markup).text;

  /// Potongan teks bergaya, siap dipakai di `TextSpan(children: ...)`.
  static List<InlineSpan> spans(String markup) {
    final decoded = decode(markup);
    final text = decoded.text;
    final masks = decoded.masks;
    final result = <InlineSpan>[];
    var i = 0;

    while (i < text.length) {
      final mask = masks[i];
      var j = i + 1;

      while (j < text.length && masks[j] == mask) {
        j++;
      }

      result.add(TextSpan(text: text.substring(i, j), style: _maskStyle(mask)));
      i = j;
    }

    return result;
  }
}

// ════════════════════════════════════════════════════════════════════
//  KONTROLER TEKS BERGAYA
// ════════════════════════════════════════════════════════════════════

/// TextEditingController yang menyimpan gaya (tebal, miring, garis bawah,
/// coret) untuk setiap karakter.
class StyledTextController extends TextEditingController {
  List<int> _masks = [];
  String _last = '';
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);

  /// Gaya untuk huruf yang akan diketik berikutnya (kursor tanpa pilihan).
  int typing = 0;

  StyledTextController({String markup = ''}) {
    if (markup.isNotEmpty) {
      final decoded = TextAttachmentMarkup.decode(markup);
      _last = decoded.text;
      _masks = List<int>.from(decoded.masks);
      text = decoded.text;
    }

    addListener(_onChanged);
  }

  String toMarkup() => TextAttachmentMarkup.encode(text, _masks);

  void _onChanged() {
    final now = text;
    final old = _last;

    if (now != old) {
      var prefix = 0;
      final shortest = now.length < old.length ? now.length : old.length;

      while (prefix < shortest &&
          old.codeUnitAt(prefix) == now.codeUnitAt(prefix)) {
        prefix++;
      }

      var suffix = 0;
      final maxSuffix = shortest - prefix;

      while (suffix < maxSuffix &&
          old.codeUnitAt(old.length - 1 - suffix) ==
              now.codeUnitAt(now.length - 1 - suffix)) {
        suffix++;
      }

      final removed = old.length - prefix - suffix;
      final inserted = now.length - prefix - suffix;

      _masks.replaceRange(prefix, prefix + removed, List<int>.filled(inserted, typing));
      _last = now;
    } else if (selection != _lastSelection) {
      // Kursor dipindah: ikuti gaya huruf di sebelah kirinya.
      if (selection.isValid && selection.isCollapsed) {
        final offset = selection.start;
        typing = offset > 0 && offset <= _masks.length ? _masks[offset - 1] : 0;
      }
    }

    _lastSelection = selection;
  }

  /// Apakah gaya [bit] aktif pada pilihan / posisi kursor sekarang.
  bool isActive(int bit) {
    final sel = selection;

    if (!sel.isValid || sel.isCollapsed) return typing & bit != 0;

    final end = sel.end > _masks.length ? _masks.length : sel.end;

    for (var i = sel.start; i < end; i++) {
      if (_masks[i] & bit == 0) return false;
    }

    return end > sel.start;
  }

  void toggle(int bit) {
    final sel = selection;

    if (!sel.isValid || sel.isCollapsed) {
      typing ^= bit;
      notifyListeners();
      return;
    }

    final end = sel.end > _masks.length ? _masks.length : sel.end;
    final turnOff = isActive(bit);

    for (var i = sel.start; i < end; i++) {
      _masks[i] = turnOff ? (_masks[i] & ~bit) : (_masks[i] | bit);
    }

    notifyListeners();
  }

  void clearFormatting() {
    final sel = selection;

    if (!sel.isValid || sel.isCollapsed) {
      typing = 0;
      notifyListeners();
      return;
    }

    final end = sel.end > _masks.length ? _masks.length : sel.end;

    for (var i = sel.start; i < end; i++) {
      _masks[i] = 0;
    }

    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_masks.length != text.length) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final spans = <InlineSpan>[];
    var i = 0;

    while (i < text.length) {
      final mask = _masks[i];
      var j = i + 1;

      while (j < text.length && _masks[j] == mask) {
        j++;
      }

      spans.add(TextSpan(text: text.substring(i, j), style: _maskStyle(mask)));
      i = j;
    }

    return TextSpan(style: style, children: spans);
  }
}

// ════════════════════════════════════════════════════════════════════
//  HALAMAN EDITOR "LAMPIRAN TEKS"
// ════════════════════════════════════════════════════════════════════

/// Halaman penuh untuk menulis teks panjang (maks. 10.000 karakter).
/// Mengembalikan string penanda lewat `Navigator.pop`; string kosong berarti
/// lampiran dihapus; null berarti dibatalkan.
class TextAttachmentPage extends StatefulWidget {
  final String initialMarkup;

  const TextAttachmentPage({super.key, this.initialMarkup = ''});

  @override
  State<TextAttachmentPage> createState() => _TextAttachmentPageState();
}

class _TextAttachmentPageState extends State<TextAttachmentPage> {
  static const kBg = Color(0xFF101010);
  static const kMuted = Color(0xFF6E6E6E);

  late final StyledTextController _controller =
      StyledTextController(markup: widget.initialMarkup);
  final FocusNode _focus = FocusNode();

  bool get _canFinish =>
      _controller.text.trim().isNotEmpty || widget.initialMarkup.isNotEmpty;

  bool get _changed => _controller.toMarkup() != widget.initialMarkup;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    FocusScope.of(context).unfocus();

    if (_controller.text.trim().isNotEmpty && _changed) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF262626),
          title: const Text(
            'Buang lampiran teks?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Lanjut menulis'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Buang',
                style: TextStyle(color: Color(0xFFFF3040)),
              ),
            ),
          ],
        ),
      );

      if (discard != true || !mounted) return;
    }

    Navigator.of(context).pop();
  }

  void _finish() {
    if (!_canFinish) return;

    FocusScope.of(context).unfocus();

    Navigator.of(context).pop(
      _controller.text.trim().isEmpty ? '' : _controller.toMarkup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: _close,
                          icon: const Icon(Icons.close, size: 30),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Lampiran teks',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _canFinish ? _finish : null,
                          child: Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _canFinish
                                  ? Colors.white
                                  : const Color(0xFF5A5A5A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        maxLength: 10000,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(
                            RegExp('[\uE000\uE001]'),
                          ),
                        ],
                        cursorColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.4,
                          fontFamily: 'serif',
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Tuliskan lebih banyak lagi…',
                          hintStyle: TextStyle(
                            color: kMuted,
                            fontSize: 22,
                            fontFamily: 'serif',
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.fromLTRB(0, 16, 0, 96),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: Center(child: _buildToolbar()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        Widget button(Widget child, bool active, VoidCallback onTap) {
          return InkWell(
            onTap: onTap,
            canRequestFocus: false,
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? const Color(0xFF333333) : Colors.transparent,
              ),
              child: child,
            ),
          );
        }

        Widget letter(String text, int bit, TextStyle style) {
          final active = _controller.isActive(bit);

          return button(
            Text(
              text,
              style: style.copyWith(
                color: active ? Colors.white : const Color(0xFFD0D0D0),
                fontSize: 24,
              ),
            ),
            active,
            () => _controller.toggle(bit),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 18),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              letter('B', kStyleBold, const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              letter(
                'I',
                kStyleItalic,
                const TextStyle(fontStyle: FontStyle.italic, fontFamily: 'serif'),
              ),
              const SizedBox(width: 10),
              letter(
                'U',
                kStyleUnderline,
                const TextStyle(decoration: TextDecoration.underline),
              ),
              const SizedBox(width: 10),
              letter(
                'S',
                kStyleStrike,
                const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(width: 10),
              button(
                const Icon(Icons.format_clear, color: Color(0xFFD0D0D0), size: 26),
                false,
                _controller.clearFormatting,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  TAMPILAN LAMPIRAN TEKS DI UTAS
// ════════════════════════════════════════════════════════════════════

/// Kartu lampiran teks di bawah isi utas. Diketuk = baca selengkapnya.
class TextAttachmentCard extends StatelessWidget {
  final String markup;

  const TextAttachmentCard({super.key, required this.markup});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TextAttachmentReaderPage(markup: markup),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF292929)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.article_outlined, size: 18, color: Color(0xFF858585)),
                SizedBox(width: 6),
                Text(
                  'Lampiran teks',
                  style: TextStyle(
                    color: Color(0xFF858585),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
                children: TextAttachmentMarkup.spans(markup),
              ),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            const Text(
              'Baca selengkapnya',
              style: TextStyle(color: Color(0xFF858585), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Halaman baca penuh lampiran teks.
class TextAttachmentReaderPage extends StatelessWidget {
  final String markup;

  const TextAttachmentReaderPage({super.key, required this.markup});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Tutup',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close, size: 28),
        ),
        title: const Text(
          'Lampiran teks',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: SelectableText.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.5,
                fontFamily: 'serif',
              ),
              children: TextAttachmentMarkup.spans(markup),
            ),
          ),
        ),
      ),
    );
  }
}