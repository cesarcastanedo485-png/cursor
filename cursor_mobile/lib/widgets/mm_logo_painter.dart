import 'package:flutter/material.dart';

/// Pixel-style "MM" logo (neon cyan / magenta on dark).
class MmLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0d0221);
    canvas.drawRect(Offset.zero & size, bg);

    final cell = size.shortestSide / 16;
    void px(double gx, double gy, Color c) {
      final p = Paint()..color = c;
      canvas.drawRect(Rect.fromLTWH(gx * cell, gy * cell, cell, cell), p);
    }

    const cyan = Color(0xFF00f5d4);
    const magenta = Color(0xFFFF006e);
    // Left M (cyan)
    for (var y = 2; y < 14; y++) {
      px(2, y.toDouble(), cyan);
      px(3, y.toDouble(), cyan);
    }
    px(4, 4, cyan);
    px(5, 5, cyan);
    px(6, 6, cyan);
    px(7, 5, cyan);
    px(8, 4, cyan);
    for (var y = 2; y < 14; y++) {
      px(9, y.toDouble(), cyan);
      px(10, y.toDouble(), cyan);
    }
    // Right M (magenta)
    for (var y = 2; y < 14; y++) {
      px(12, y.toDouble(), magenta);
      px(13, y.toDouble(), magenta);
    }
    px(14, 4, magenta);
    px(15, 5, magenta);
    px(16, 6, magenta);
    px(17, 5, magenta);
    px(18, 4, magenta);
    for (var y = 2; y < 14; y++) {
      px(19, y.toDouble(), magenta);
      px(20, y.toDouble(), magenta);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
