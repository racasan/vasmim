import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/shape/shape_layer_painter.dart';

void main() {
  test('multiplies object and layer opacity without changing RGB', () {
    const color = Color(0xFF336699);

    final outline = ShapeLayerPainter.colorWithLayerOpacity(color, 0.25);
    final fill = ShapeLayerPainter.colorWithLayerOpacity(
      color,
      0.25,
      objectOpacity: 0.2,
    );

    expect(outline.r, closeTo(color.r, 0.0001));
    expect(outline.g, closeTo(color.g, 0.0001));
    expect(outline.b, closeTo(color.b, 0.0001));
    expect(outline.a, closeTo(0.25, 0.0001));
    expect(fill.a, closeTo(0.05, 0.0001));
  });
}
