import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'board_shape.dart';
import 'shape_definition.dart';

class ShapeLayerPainter extends CustomPainter {
  const ShapeLayerPainter({
    required this.shapes,
    required this.opacityByShapeId,
    this.preview,
    this.previewOpacity = 1,
    this.brightness = Brightness.light,
  });

  final List<BoardShape> shapes;
  final Map<String, double> opacityByShapeId;
  final BoardShape? preview;
  final double previewOpacity;
  final Brightness brightness;

  Color headingColor(int value) => value == 0xFF000000 || value == 0xFFFFFFFF
      ? (brightness == Brightness.dark ? Colors.white : Colors.black)
      : Color(value);

  @override
  void paint(Canvas canvas, Size size) {
    for (final shape in [...shapes, ?preview]) {
      final layerOpacity = shape == preview
          ? previewOpacity
          : opacityByShapeId[shape.id] ?? 1;
      final definition = ShapeDefinition.forType(shape.type);
      final path = definition.pathFor(shape);
      if (definition.supportsFill && shape.fillOpacity > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = colorWithLayerOpacity(
              Color(shape.fillColorValue),
              layerOpacity,
              objectOpacity: shape.fillOpacity,
            ),
        );
      }
      final outlinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shape.outlineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colorWithLayerOpacity(
          Color(shape.outlineColorValue),
          layerOpacity,
        );
      canvas.drawPath(path, outlinePaint);
      canvas.drawPath(definition.detailPathFor(shape), outlinePaint);
      _paintHeading(canvas, shape, layerOpacity);
    }
  }

  @visibleForTesting
  static Color colorWithLayerOpacity(
    Color color,
    double layerOpacity, {
    double objectOpacity = 1,
  }) => color.withValues(alpha: color.a * layerOpacity * objectOpacity);

  void _paintHeading(Canvas canvas, BoardShape shape, double layerOpacity) {
    final heading = shape.heading;
    if (heading == null) return;
    final textAlign = switch (heading.alignment) {
      ShapeHeadingAlignment.left => TextAlign.left,
      ShapeHeadingAlignment.center => TextAlign.center,
      ShapeHeadingAlignment.right => TextAlign.right,
    };
    final usableWidth = shape.isOpen
        ? shape.width.clamp(120.0, 520.0)
        : (shape.width - 24).clamp(40.0, 520.0);
    final painter = TextPainter(
      text: TextSpan(
        text: heading.text,
        style: TextStyle(
          color: colorWithLayerOpacity(
            headingColor(heading.colorValue),
            layerOpacity,
          ),
          fontSize: heading.fontSize,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: usableWidth);
    final top = heading.placement == ShapeHeadingPlacement.above
        ? shape.y - painter.height - 8
        : shape.y + 12;
    final left = shape.x + (shape.width - painter.width) / 2;
    painter.paint(canvas, Offset(left, top));
  }

  @override
  bool shouldRepaint(covariant ShapeLayerPainter oldDelegate) =>
      oldDelegate.brightness != brightness ||
      oldDelegate.shapes != shapes ||
      !mapEquals(oldDelegate.opacityByShapeId, opacityByShapeId) ||
      oldDelegate.preview != preview ||
      oldDelegate.previewOpacity != previewOpacity;
}
