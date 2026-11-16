import 'package:flutter/material.dart';

import 'canvas_heading.dart';

class CanvasHeadingGeometry {
  const CanvasHeadingGeometry._();

  static const minimumWidth = 120.0;
  static const maximumWidth = 720.0;
  static const horizontalPadding = 16.0;
  static const verticalPadding = 12.0;

  static Size sizeFor(CanvasHeading heading) {
    final estimatedTextWidth =
        heading.text.characters.length * heading.fontSize * 0.62;
    final width = (estimatedTextWidth + horizontalPadding * 2)
        .clamp(minimumWidth, maximumWidth)
        .toDouble();
    final height = heading.fontSize * 1.35 + verticalPadding * 2;
    return Size(width, height);
  }

  static Rect boundsFor(CanvasHeading heading) {
    final size = sizeFor(heading);
    return Rect.fromLTWH(heading.x, heading.y, size.width, size.height);
  }
}
