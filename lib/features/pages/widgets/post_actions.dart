import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import 'post_events.dart';

/// Aksi bersama untuk postingan milik sendiri.
///
///   final deleted = await PostActions.deleteWithConfirm(
///     context,
///     token: widget.token,
///     post: post,
///   );
///
/// Setelah berhasil, [PostEvents.notifyDeleted] dipanggil supaya Beranda dan
/// Profil langsung membuang postingan itu dari daftarnya.
class PostActions {
  PostActions._();

  static const _danger = Color(0xFFFF3040);

  /// Dialog "Hapus postingan?". True bila pengguna menekan Hapus.
  static Future<bool> confirmDelete(
    BuildContext context, {
    required bool isNote,
  }) async {
    final what = isNote ? 'catatan' : 'postingan';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Hapus $what?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Tindakan ini tidak bisa dibatalkan. Suka, balasan, dan lampiran '
          'pada $what ini juga ikut terhapus.',
          style: const TextStyle(color: Color(0xFFB5B5B5), fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: _danger,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return ok == true;
  }

  /// Minta konfirmasi, hapus di server, lalu beri kabar ke halaman lain.
  /// Mengembalikan true bila postingan benar-benar terhapus.
  static Future<bool> deleteWithConfirm(
    BuildContext context, {
    required String token,
    required Map<String, dynamic> post,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final isNote = post['expires_at'] != null;

    if (!await confirmDelete(context, isNote: isNote)) return false;

    try {
      await ApiService.deletePost(token: token, postId: post['id']);

      PostEvents.notifyDeleted(post['id']);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(isNote ? 'Catatan dihapus.' : 'Postingan dihapus.'),
          ),
        );

      return true;
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );

      return false;
    }
  }
}