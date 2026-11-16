import 'dart:math' as math;
import 'dart:ui';

class ConnectorSegment {
  const ConnectorSegment({required this.start, required this.end});

  final Offset start;
  final Offset end;
}

abstract final class ConnectorGeometry {
  static ConnectorSegment betweenRects(Rect first, Rect second) {
    final delta = second.center - first.center;
    if (delta.distanceSquared == 0) {
      return ConnectorSegment(start: first.centerRight, end: second.centerLeft);
    }

    return ConnectorSegment(
      start: _boundaryPoint(first, delta),
      end: _boundaryPoint(second, -delta),
    );
  }

  static Offset _boundaryPoint(Rect rect, Offset direction) {
    final horizontalScale = direction.dx == 0
        ? double.infinity
        : rect.width / 2 / direction.dx.abs();
    final verticalScale = direction.dy == 0
        ? double.infinity
        : rect.height / 2 / direction.dy.abs();
    final scale = math.min(horizontalScale, verticalScale);
    return rect.center + direction * scale;
  }
}
