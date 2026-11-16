import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'canvas_snap_resolver.dart';

class CanvasSnapGuidePainter extends CustomPainter {
  const CanvasSnapGuidePainter({
    required this.guides,
    required this.viewportScale,
    required this.color,
  });

  final List<CanvasSnapGuide> guides;
  final double viewportScale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5 / viewportScale;
    for (final guide in guides) {
      switch (guide.axis) {
        case CanvasSnapGuideAxis.vertical:
          canvas.drawLine(
            Offset(guide.position, guide.start),
            Offset(guide.position, guide.end),
            paint,
          );
        case CanvasSnapGuideAxis.horizontal:
          canvas.drawLine(
            Offset(guide.start, guide.position),
            Offset(guide.end, guide.position),
            paint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasSnapGuidePainter oldDelegate) =>
      oldDelegate.viewportScale != viewportScale ||
      oldDelegate.color != color ||
      !listEquals(oldDelegate.guides, guides);
}
