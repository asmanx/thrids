
import 'package:flutter/material.dart';

/// Gelembung dengan garis putus-putus (tampilan postingan sementara / catatan).
/// Sudut kiri atas dibuat lebih kecil agar terlihat seperti ekor gelembung.
class DashedBubble extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color fill;
  final double radius;

  const DashedBubble({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.color = const Color(0xFF8A8A8A),
    this.fill = const Color(0xFF1C1C1C),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBubblePainter(color: color, fill: fill, radius: radius),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedBubblePainter extends CustomPainter {
  final Color color;
  final Color fill;
  final double radius;

  const _DashedBubblePainter({
    required this.color,
    required this.fill,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(radius);
    final rrect = RRect.fromRectAndCorners(
      (Offset.zero & size).deflate(1),
      topLeft: const Radius.circular(5),
      topRight: r,
      bottomLeft: r,
      bottomRight: r,
    );

    canvas.drawRRect(rrect, Paint()..color = fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    const dash = 6.0;
    const gap = 4.0;

    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;

      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), stroke);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBubblePainter old) =>
      old.color != color || old.fill != fill || old.radius != radius;
}