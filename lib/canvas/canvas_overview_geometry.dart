import 'dart:math' as math;

import 'package:flutter/material.dart';

class CanvasOverviewGeometry {
  const CanvasOverviewGeometry._();

  static Offset canvasPointForOverview({
    required Offset overviewPoint,
    required Size overviewSize,
    required Size boardSize,
  }) {
    final x = (overviewPoint.dx / overviewSize.width).clamp(0.0, 1.0);
    final y = (overviewPoint.dy / overviewSize.height).clamp(0.0, 1.0);
    return Offset(x * boardSize.width, y * boardSize.height);
  }

  static Rect overviewRectForCanvasRect({
    required Rect canvasRect,
    required Size overviewSize,
    required Size boardSize,
  }) {
    final scaleX = overviewSize.width / boardSize.width;
    final scaleY = overviewSize.height / boardSize.height;
    return Rect.fromLTRB(
      canvasRect.left * scaleX,
      canvasRect.top * scaleY,
      canvasRect.right * scaleX,
      canvasRect.bottom * scaleY,
    );
  }

  static Rect canvasViewportRect({
    required Matrix4 transform,
    required Size viewportSize,
  }) {
    final inverse = Matrix4.inverted(transform);
    final first = MatrixUtils.transformPoint(inverse, Offset.zero);
    final second = MatrixUtils.transformPoint(
      inverse,
      Offset(viewportSize.width, viewportSize.height),
    );
    return Rect.fromLTRB(
      math.min(first.dx, second.dx),
      math.min(first.dy, second.dy),
      math.max(first.dx, second.dx),
      math.max(first.dy, second.dy),
    );
  }

  static Rect overviewViewportRect({
    required Matrix4 transform,
    required Size viewportSize,
    required Size overviewSize,
    required Size boardSize,
  }) {
    final mapped = overviewRectForCanvasRect(
      canvasRect: canvasViewportRect(
        transform: transform,
        viewportSize: viewportSize,
      ),
      overviewSize: overviewSize,
      boardSize: boardSize,
    );
    return Rect.fromLTRB(
      mapped.left.clamp(0.0, overviewSize.width),
      mapped.top.clamp(0.0, overviewSize.height),
      mapped.right.clamp(0.0, overviewSize.width),
      mapped.bottom.clamp(0.0, overviewSize.height),
    );
  }

  static Matrix4 recenteredTransform({
    required Matrix4 currentTransform,
    required Size viewportSize,
    required Offset canvasPoint,
  }) {
    final scale = currentTransform.getMaxScaleOnAxis();
    final translation = viewportSize.center(Offset.zero) - canvasPoint * scale;
    return Matrix4.diagonal3Values(scale, scale, scale)
      ..setTranslationRaw(translation.dx, translation.dy, 0);
  }
}
