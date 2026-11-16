import 'package:flutter/material.dart';

import 'board_shape.dart';
import 'shape_definition.dart';

List<Offset> shapeHandlePositions(BoardShape shape) {
  if (shape.isOpen) {
    final definition = ShapeDefinition.forType(shape.type);
    final endpoints = definition.lineEndpoints(shape);
    return shape.isOrthogonal
        ? [endpoints.$1, definition.orthogonalSpineHandle(shape), endpoints.$2]
        : [endpoints.$1, endpoints.$2];
  }
  final rect = Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height);
  return [
    rect.topLeft,
    rect.topCenter,
    rect.topRight,
    rect.centerRight,
    rect.bottomRight,
    rect.bottomCenter,
    rect.bottomLeft,
    rect.centerLeft,
  ];
}

Offset shapeMoveHandlePosition(BoardShape shape) =>
    Offset(shape.x + shape.width / 2, shape.y + shape.height / 2);

class ShapeSelectionPainter extends CustomPainter {
  const ShapeSelectionPainter({required this.shape, required this.scale});

  final BoardShape? shape;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final current = shape;
    if (current == null) return;
    final primary = const Color(0xFF5B5FA6);
    final stroke = 1.5 / scale;
    final handleRadius = 6 / scale;
    final bounds = Rect.fromLTWH(
      current.x,
      current.y,
      current.width,
      current.height,
    );
    canvas.drawRect(
      bounds.inflate(4 / scale),
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    for (final indexed in shapeHandlePositions(current).indexed) {
      final point = indexed.$2;
      final isSpine = current.isOrthogonal && indexed.$1 == 1;
      if (isSpine) {
        final radius = handleRadius * 1.15;
        final diamond = Path()
          ..moveTo(point.dx, point.dy - radius)
          ..lineTo(point.dx + radius, point.dy)
          ..lineTo(point.dx, point.dy + radius)
          ..lineTo(point.dx - radius, point.dy)
          ..close();
        canvas.drawPath(diamond, Paint()..color = Colors.white);
        canvas.drawPath(
          diamond,
          Paint()
            ..color = primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
        continue;
      }
      canvas.drawCircle(point, handleRadius, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        handleRadius,
        Paint()
          ..color = primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }
    final movePoint = shapeMoveHandlePosition(current);
    final moveRadius = 10 / scale;
    canvas.drawCircle(movePoint, moveRadius, Paint()..color = primary);
    final glyph = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5 / scale
      ..strokeCap = StrokeCap.round;
    final arm = 5 / scale;
    canvas
      ..drawLine(
        Offset(movePoint.dx - arm, movePoint.dy),
        Offset(movePoint.dx + arm, movePoint.dy),
        glyph,
      )
      ..drawLine(
        Offset(movePoint.dx, movePoint.dy - arm),
        Offset(movePoint.dx, movePoint.dy + arm),
        glyph,
      );
  }

  @override
  bool shouldRepaint(covariant ShapeSelectionPainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.scale != scale;
}
