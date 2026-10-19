import 'package:flutter/material.dart';

import '../create_post_page.dart';

/// Alur catatan:
///   1. (opsional) sheet pengantar "Bagikan postingan yang tidak tampil
///      selamanya" dengan tombol [Coba]
///   2. [CreatePostPage] yang sudah ada, langsung dalam mode catatan.
///      Tombol hantu di halaman itu bisa mengganti ke utas biasa.
///
///   final posted = await NoteFlow.start(context, token: t, user: u);
class NoteFlow {
  static Future<bool> start(
    BuildContext context, {
    required String token,
    required Map<String, dynamic> user,
    bool showIntro = true,
  }) async {
    if (showIntro) {
      final go = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF262626),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const _NoteIntroSheet(),
      );

      if (go != true || !context.mounted) return false;
    }

    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(
          token: token,
          user: user,
          startAsNote: true,
        ),
      ),
    );

    return posted == true;
  }
}

class _NoteIntroSheet extends StatelessWidget {
  const _NoteIntroSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 12, 30, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF5A5A5A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 44),
            const Icon(
              Icons.sentiment_satisfied_alt_outlined,
              color: Colors.white,
              size: 72,
            ),
            const SizedBox(height: 40),
            const Text(
              'Bagikan postingan yang tidak tampil selamanya',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Postingan sementara diarsipkan setelah 24 jam. Anda bisa '
              'memilih untuk mendapatkan balasan sebagai pesan atau '
              'melihatnya di postingan Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17, height: 1.5),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F5F7),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text(
                  'Coba',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}