import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tombol bulat kecil berisi ikon "+" dengan garis lingkaran putus-putus.
/// Dipakai di kiri bawah foto profil untuk menambah catatan.
///
///   DashedCircleButton(size: 30, onTap: _addNote)
class DashedCircleButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  final Color color;
  final Color fill;

  const DashedCircleButton({
    super.key,
    required this.onTap,
    this.size = 30,
    this.color = Colors.white,
    this.fill = const Color(0xFF1C1C1C),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        size: Size.square(size),
        painter: _DashedCirclePainter(color: color, fill: fill),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(Icons.add_rounded, size: size * 0.6, color: color),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final Color fill;

  const _DashedCirclePainter({required this.color, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.6;
    const dashCount = 14;

    final rect = (Offset.zero & size).deflate(strokeWidth / 2);

    canvas.drawOval(rect, Paint()..color = fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const step = 2 * math.pi / dashCount;

    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color || old.fill != fill;
}