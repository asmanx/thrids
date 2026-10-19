import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';

/// Avatar pengguna. Kalau tidak ada foto (atau gagal dimuat), tampil avatar
/// bawaan: lingkaran terang dengan siluet orang abu-abu.
///
///   UserAvatar(url: user['profile_picture'], size: 42)
///
/// [url] boleh berupa URL penuh atau path server ("/uploads/abc.jpg").
/// [bytes] dipakai untuk pratinjau foto yang baru dipilih (belum diunggah).
class UserAvatar extends StatelessWidget {
  final String? url;
  final Uint8List? bytes;
  final double size;

  const UserAvatar({super.key, this.url, this.bytes, required this.size});

  static const background = Color(0xFFF4F5F7);
  static const silhouette = Color(0xFF828894);

  @override
  Widget build(BuildContext context) {
    final raw = (url ?? '').trim();

    Widget child;

    if (bytes != null) {
      child = Image.memory(
        bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    } else if (raw.isEmpty) {
      child = _fallback();
    } else {
      child = Image.network(
        ApiService.resolveUrl(raw),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: child),
    );
  }

  Widget _fallback() {
    return CustomPaint(
      size: Size(size, size),
      painter: const _SilhouettePainter(),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  const _SilhouettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = UserAvatar.background,
    );

    final paint = Paint()..color = UserAvatar.silhouette;

    // Kepala
    canvas.drawCircle(Offset(w * 0.5, h * 0.36), w * 0.19, paint);

    // Bahu (terpotong oleh tepi lingkaran)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.92),
        width: w * 0.74,
        height: h * 0.62,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) => false;
}