import 'package:flutter/material.dart';

import '../board/board_paper_tone.dart';

class CanvasPaperDot {
  const CanvasPaperDot({
    required this.position,
    required this.color,
    required this.radius,
    required this.isAnchor,
  });

  final Offset position;
  final Color color;
  final double radius;
  final bool isAnchor;
}

class CanvasPaperGridLine {
  const CanvasPaperGridLine({
    required this.start,
    required this.end,
    required this.isAnchor,
  });

  final Offset start;
  final Offset end;
  final bool isAnchor;
}

class LayeredCanvasPaperPainter extends CustomPainter {
  const LayeredCanvasPaperPainter({
    this.isDark = false,
    this.viewportScale = 1,
    this.tone = BoardPaperTone.defaultTone,
  });

  static const paperColor = Color(0xFFF7F8FC);
  static const darkPaperColor = Color(0xFF202631);
  static const minorDotColor = Color(0xFFDDE3EE);
  static const anchorDotColor = Color(0xFFBCC7D8);
  static const darkMinorDotColor = Color(0xFF3F4959);
  static const darkAnchorDotColor = Color(0xFF5A687D);
  static const minorGridColor = Color(0xFFEDF0F6);
  static const anchorGridColor = Color(0xFFE4E9F1);
  static const darkMinorGridColor = Color(0xFF29313D);
  static const darkAnchorGridColor = Color(0xFF333E4C);
  static const minorDotRadius = 1.25;
  static const anchorDotRadius = 2.2;
  static const minorSpacing = 80.0;
  static const anchorInterval = 5;

  final bool isDark;
  final double viewportScale;
  final BoardPaperTone tone;

  static Color paperColorFor(BoardPaperTone tone, {required bool isDark}) =>
      switch ((tone, isDark)) {
        (BoardPaperTone.defaultTone, false) => paperColor,
        (BoardPaperTone.defaultTone, true) => darkPaperColor,
        (BoardPaperTone.warm, false) => const Color(0xFFFFF8EC),
        (BoardPaperTone.warm, true) => const Color(0xFF2A2622),
        (BoardPaperTone.blue, false) => const Color(0xFFEFF6FF),
        (BoardPaperTone.blue, true) => const Color(0xFF202938),
        (BoardPaperTone.green, false) => const Color(0xFFEFF8F1),
        (BoardPaperTone.green, true) => const Color(0xFF202C29),
      };

  Color _paperDetailColor(Color defaultColor) =>
      tone == BoardPaperTone.defaultTone
      ? defaultColor
      : Color.lerp(defaultColor, paperColorFor(tone, isDark: isDark), 0.24)!;

  List<CanvasPaperGridLine> linesFor(Size size) {
    final maximumColumn = (size.width / minorSpacing).floor();
    final maximumRow = (size.height / minorSpacing).floor();
    return [
      for (var column = 0; column <= maximumColumn; column++)
        CanvasPaperGridLine(
          start: Offset(column * minorSpacing, 0),
          end: Offset(column * minorSpacing, size.height),
          isAnchor: column % anchorInterval == 0,
        ),
      for (var row = 0; row <= maximumRow; row++)
        CanvasPaperGridLine(
          start: Offset(0, row * minorSpacing),
          end: Offset(size.width, row * minorSpacing),
          isAnchor: row % anchorInterval == 0,
        ),
    ];
  }

  List<CanvasPaperDot> dotsFor(Size size) {
    final maximumColumn = (size.width / minorSpacing).floor();
    final maximumRow = (size.height / minorSpacing).floor();
    return [
      for (var column = 0; column <= maximumColumn; column++)
        for (var row = 0; row <= maximumRow; row++) _dotAt(column, row),
    ];
  }

  CanvasPaperDot _dotAt(int column, int row) {
    final isAnchor = column % anchorInterval == 0 && row % anchorInterval == 0;
    return CanvasPaperDot(
      position: Offset(column * minorSpacing, row * minorSpacing),
      color: _paperDetailColor(
        isDark
            ? (isAnchor ? darkAnchorDotColor : darkMinorDotColor)
            : (isAnchor ? anchorDotColor : minorDotColor),
      ),
      radius: isAnchor ? anchorDotRadius : minorDotRadius,
      isAnchor: isAnchor,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = paperColorFor(tone, isDark: isDark),
    );
    final scale = viewportScale.isFinite && viewportScale > 0
        ? viewportScale
        : 1.0;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / scale;
    for (final line in linesFor(size)) {
      gridPaint.color = _paperDetailColor(
        isDark
            ? (line.isAnchor ? darkAnchorGridColor : darkMinorGridColor)
            : (line.isAnchor ? anchorGridColor : minorGridColor),
      );
      canvas.drawLine(line.start, line.end, gridPaint);
    }
    final paint = Paint();
    for (final dot in dotsFor(size)) {
      paint.color = dot.color;
      canvas.drawCircle(dot.position, dot.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant LayeredCanvasPaperPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.viewportScale != viewportScale ||
      oldDelegate.tone != tone;
}
