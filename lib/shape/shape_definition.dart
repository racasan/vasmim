import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'board_shape.dart';

class ShapeDefinition {
  const ShapeDefinition({
    required this.type,
    required this.category,
    required this.icon,
  });

  final BoardShapeType type;
  final String category;
  final IconData icon;

  bool get supportsFill => type.supportsFill;

  Path pathFor(BoardShape shape) {
    final rect = Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height);
    return switch (type) {
      BoardShapeType.rectangle => Path()..addRect(rect),
      BoardShapeType.roundedRectangle =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(
              math.min(24, math.min(rect.width, rect.height) / 4),
            ),
          ),
        ),
      BoardShapeType.ellipse => Path()..addOval(rect),
      BoardShapeType.line => _linePath(shape),
      BoardShapeType.arrow => _linePath(shape, endArrow: true),
      BoardShapeType.triangle => _polygon(rect, const [
        Offset(0.5, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]),
      BoardShapeType.rightTriangle => _polygon(rect, const [
        Offset(0, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]),
      BoardShapeType.diamond => _polygon(rect, const [
        Offset(0.5, 0),
        Offset(1, 0.5),
        Offset(0.5, 1),
        Offset(0, 0.5),
      ]),
      BoardShapeType.parallelogram => _polygon(rect, const [
        Offset(0.2, 0),
        Offset(1, 0),
        Offset(0.8, 1),
        Offset(0, 1),
      ]),
      BoardShapeType.trapezoid => _polygon(rect, const [
        Offset(0.2, 0),
        Offset(0.8, 0),
        Offset(1, 1),
        Offset(0, 1),
      ]),
      BoardShapeType.hexagon => _polygon(rect, const [
        Offset(0.25, 0),
        Offset(0.75, 0),
        Offset(1, 0.5),
        Offset(0.75, 1),
        Offset(0.25, 1),
        Offset(0, 0.5),
      ]),
      BoardShapeType.elbowLine => _orthogonalPath(shape),
      BoardShapeType.elbowArrow => _orthogonalPath(shape, endArrow: true),
      BoardShapeType.doubleArrow => _linePath(
        shape,
        startArrow: true,
        endArrow: true,
      ),
      BoardShapeType.doubleElbowArrow => _orthogonalPath(
        shape,
        startArrow: true,
        endArrow: true,
      ),
      BoardShapeType.blockArrowRight => _polygon(rect, const [
        Offset(0, 0.25),
        Offset(0.62, 0.25),
        Offset(0.62, 0),
        Offset(1, 0.5),
        Offset(0.62, 1),
        Offset(0.62, 0.75),
        Offset(0, 0.75),
      ]),
      BoardShapeType.blockArrowLeft => _polygon(rect, const [
        Offset(1, 0.25),
        Offset(0.38, 0.25),
        Offset(0.38, 0),
        Offset(0, 0.5),
        Offset(0.38, 1),
        Offset(0.38, 0.75),
        Offset(1, 0.75),
      ]),
      BoardShapeType.blockArrowUp => _polygon(rect, const [
        Offset(0.25, 1),
        Offset(0.25, 0.38),
        Offset(0, 0.38),
        Offset(0.5, 0),
        Offset(1, 0.38),
        Offset(0.75, 0.38),
        Offset(0.75, 1),
      ]),
      BoardShapeType.blockArrowDown => _polygon(rect, const [
        Offset(0.25, 0),
        Offset(0.25, 0.62),
        Offset(0, 0.62),
        Offset(0.5, 1),
        Offset(1, 0.62),
        Offset(0.75, 0.62),
        Offset(0.75, 0),
      ]),
      BoardShapeType.terminator =>
        Path()..addRRect(
          RRect.fromRectAndRadius(
            rect,
            Radius.circular(math.min(rect.width, rect.height) / 2),
          ),
        ),
      BoardShapeType.document => _documentPath(rect),
      BoardShapeType.database => _databasePath(rect),
      BoardShapeType.predefinedProcess => Path()..addRect(rect),
      BoardShapeType.pentagon => _polygon(rect, const [
        Offset(0.5, 0),
        Offset(1, 0.38),
        Offset(0.81, 1),
        Offset(0.19, 1),
        Offset(0, 0.38),
      ]),
      BoardShapeType.octagon => _polygon(rect, const [
        Offset(0.29, 0),
        Offset(0.71, 0),
        Offset(1, 0.29),
        Offset(1, 0.71),
        Offset(0.71, 1),
        Offset(0.29, 1),
        Offset(0, 0.71),
        Offset(0, 0.29),
      ]),
      BoardShapeType.heart => _heartPath(rect),
      BoardShapeType.lightning => _polygon(rect, const [
        Offset(0.58, 0),
        Offset(0.16, 0.55),
        Offset(0.48, 0.55),
        Offset(0.35, 1),
        Offset(0.88, 0.42),
        Offset(0.55, 0.42),
        Offset(0.78, 0),
      ]),
      BoardShapeType.leftBracket => _bracketPath(rect, left: true),
      BoardShapeType.rightBracket => _bracketPath(rect, left: false),
      BoardShapeType.smiley => Path()..addOval(rect),
      BoardShapeType.moon => _moonPath(rect),
      BoardShapeType.cloud => _cloudPath(rect),
      BoardShapeType.turnBlockArrow => _polygon(rect, const [
        Offset(0.15, 0),
        Offset(0.45, 0),
        Offset(0.45, 0.5),
        Offset(0.72, 0.5),
        Offset(0.72, 0.28),
        Offset(1, 0.65),
        Offset(0.72, 1),
        Offset(0.72, 0.78),
        Offset(0.15, 0.78),
      ]),
      BoardShapeType.uTurnBlockArrow => _polygon(rect, const [
        Offset(0.08, 1),
        Offset(0.08, 0.34),
        Offset(0.22, 0.08),
        Offset(0.72, 0.08),
        Offset(0.88, 0.34),
        Offset(0.88, 0.67),
        Offset(1, 0.67),
        Offset(0.77, 1),
        Offset(0.54, 0.67),
        Offset(0.66, 0.67),
        Offset(0.66, 0.37),
        Offset(0.59, 0.29),
        Offset(0.39, 0.29),
        Offset(0.3, 0.38),
        Offset(0.3, 1),
      ]),
      BoardShapeType.splitBlockArrow => _splitBlockArrow(rect),
      BoardShapeType.mergeBlockArrow => _mergeBlockArrow(rect),
      BoardShapeType.circularBlockArrow => _circularBlockArrow(rect),
      BoardShapeType.star => _starPath(rect),
      BoardShapeType.banner => _polygon(rect, const [
        Offset(0, 0.12),
        Offset(0.16, 0.12),
        Offset(0.16, 0),
        Offset(0.84, 0),
        Offset(0.84, 0.12),
        Offset(1, 0.12),
        Offset(0.88, 0.5),
        Offset(1, 0.88),
        Offset(0.84, 0.88),
        Offset(0.84, 1),
        Offset(0.16, 1),
        Offset(0.16, 0.88),
        Offset(0, 0.88),
        Offset(0.12, 0.5),
      ]),
      BoardShapeType.callout => _polygon(rect, const [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 0.78),
        Offset(0.38, 0.78),
        Offset(0.18, 1),
        Offset(0.22, 0.78),
        Offset(0, 0.78),
      ]),
      BoardShapeType.curvedLine => _curvedLinePath(shape),
      BoardShapeType.multiBendLine => _multiBendLinePath(shape),
    };
  }

  Path detailPathFor(BoardShape shape) {
    final rect = Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height);
    return switch (type) {
      BoardShapeType.database => _databaseDetailPath(rect),
      BoardShapeType.predefinedProcess =>
        Path()
          ..moveTo(rect.left + rect.width * 0.15, rect.top)
          ..lineTo(rect.left + rect.width * 0.15, rect.bottom)
          ..moveTo(rect.right - rect.width * 0.15, rect.top)
          ..lineTo(rect.right - rect.width * 0.15, rect.bottom),
      BoardShapeType.smiley => _smileyDetailPath(rect),
      _ => Path(),
    };
  }

  Path _heartPath(Rect rect) => Path()
    ..moveTo(rect.center.dx, rect.bottom)
    ..cubicTo(
      rect.left,
      rect.top + rect.height * 0.53,
      rect.left,
      rect.top + rect.height * 0.07,
      rect.left + rect.width * 0.25,
      rect.top + rect.height * 0.07,
    )
    ..cubicTo(
      rect.left + rect.width * 0.38,
      rect.top + rect.height * 0.07,
      rect.center.dx,
      rect.top + rect.height * 0.2,
      rect.center.dx,
      rect.top + rect.height * 0.28,
    )
    ..cubicTo(
      rect.center.dx,
      rect.top + rect.height * 0.2,
      rect.left + rect.width * 0.62,
      rect.top + rect.height * 0.07,
      rect.left + rect.width * 0.75,
      rect.top + rect.height * 0.07,
    )
    ..cubicTo(
      rect.right,
      rect.top + rect.height * 0.07,
      rect.right,
      rect.top + rect.height * 0.53,
      rect.center.dx,
      rect.bottom,
    )
    ..close();

  Path _bracketPath(Rect rect, {required bool left}) {
    final points = left
        ? const [
            Offset(0, 0),
            Offset(1, 0),
            Offset(1, 0.13),
            Offset(0.18, 0.13),
            Offset(0.18, 0.87),
            Offset(1, 0.87),
            Offset(1, 1),
            Offset(0, 1),
          ]
        : const [
            Offset(0, 0),
            Offset(1, 0),
            Offset(1, 1),
            Offset(0, 1),
            Offset(0, 0.87),
            Offset(0.82, 0.87),
            Offset(0.82, 0.13),
            Offset(0, 0.13),
          ];
    return _polygon(rect, points);
  }

  Path _moonPath(Rect rect) => Path()
    ..moveTo(rect.left + rect.width * 0.55, rect.top)
    ..cubicTo(
      rect.left,
      rect.top + rect.height * 0.07,
      rect.left,
      rect.bottom - rect.height * 0.07,
      rect.left + rect.width * 0.55,
      rect.bottom,
    )
    ..cubicTo(
      rect.left + rect.width * 0.17,
      rect.bottom - rect.height * 0.3,
      rect.left + rect.width * 0.17,
      rect.top + rect.height * 0.3,
      rect.left + rect.width * 0.55,
      rect.top,
    )
    ..close();

  Path _cloudPath(Rect rect) => Path()
    ..moveTo(rect.left + rect.width * 0.18, rect.top + rect.height * 0.78)
    ..cubicTo(
      rect.left,
      rect.top + rect.height * 0.78,
      rect.left,
      rect.top + rect.height * 0.43,
      rect.left + rect.width * 0.2,
      rect.top + rect.height * 0.43,
    )
    ..cubicTo(
      rect.left + rect.width * 0.2,
      rect.top + rect.height * 0.2,
      rect.left + rect.width * 0.39,
      rect.top + rect.height * 0.14,
      rect.left + rect.width * 0.52,
      rect.top + rect.height * 0.28,
    )
    ..cubicTo(
      rect.left + rect.width * 0.7,
      rect.top + rect.height * 0.12,
      rect.left + rect.width * 0.87,
      rect.top + rect.height * 0.3,
      rect.left + rect.width * 0.83,
      rect.top + rect.height * 0.48,
    )
    ..cubicTo(
      rect.right,
      rect.top + rect.height * 0.49,
      rect.right,
      rect.top + rect.height * 0.82,
      rect.left + rect.width * 0.83,
      rect.top + rect.height * 0.82,
    )
    ..lineTo(rect.left + rect.width * 0.18, rect.top + rect.height * 0.82)
    ..close();

  Path _smileyDetailPath(Rect rect) {
    final eyeRadius = math.min(rect.width, rect.height) * 0.035;
    return Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(
            rect.left + rect.width * 0.35,
            rect.top + rect.height * 0.38,
          ),
          radius: eyeRadius,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(
            rect.left + rect.width * 0.65,
            rect.top + rect.height * 0.38,
          ),
          radius: eyeRadius,
        ),
      )
      ..moveTo(rect.left + rect.width * 0.25, rect.top + rect.height * 0.62)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top + rect.height * 0.88,
        rect.left + rect.width * 0.75,
        rect.top + rect.height * 0.62,
      );
  }

  Path _splitBlockArrow(Rect rect) {
    final stem = _polygon(rect, const [
      Offset(0, 0.42),
      Offset(0.5, 0.42),
      Offset(0.5, 0.58),
      Offset(0, 0.58),
    ]);
    final fork = _polygon(rect, const [
      Offset(0.42, 0.27),
      Offset(0.56, 0.27),
      Offset(0.56, 0.73),
      Offset(0.42, 0.73),
    ]);
    final upper = _polygon(rect, const [
      Offset(0.5, 0.17),
      Offset(0.77, 0.17),
      Offset(0.77, 0.05),
      Offset(1, 0.26),
      Offset(0.77, 0.46),
      Offset(0.77, 0.35),
      Offset(0.5, 0.35),
    ]);
    final lower = _polygon(rect, const [
      Offset(0.5, 0.65),
      Offset(0.77, 0.65),
      Offset(0.77, 0.54),
      Offset(1, 0.74),
      Offset(0.77, 0.95),
      Offset(0.77, 0.83),
      Offset(0.5, 0.83),
    ]);
    return Path.combine(
      PathOperation.union,
      Path.combine(
        PathOperation.union,
        Path.combine(PathOperation.union, stem, fork),
        upper,
      ),
      lower,
    );
  }

  Path _mergeBlockArrow(Rect rect) {
    final upper = _polygon(rect, const [
      Offset(0, 0.18),
      Offset(0.52, 0.18),
      Offset(0.52, 0.46),
      Offset(0, 0.46),
    ]);
    final lower = _polygon(rect, const [
      Offset(0, 0.54),
      Offset(0.52, 0.54),
      Offset(0.52, 0.82),
      Offset(0, 0.82),
    ]);
    final outgoing = _polygon(rect, const [
      Offset(0.43, 0.35),
      Offset(0.76, 0.35),
      Offset(0.76, 0.13),
      Offset(1, 0.5),
      Offset(0.76, 0.87),
      Offset(0.76, 0.65),
      Offset(0.43, 0.65),
    ]);
    return Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, upper, lower),
      outgoing,
    );
  }

  Path _circularBlockArrow(Rect rect) {
    final center = rect.center;
    final rx = rect.width * 0.47;
    final ry = rect.height * 0.47;
    const start = -2.35;
    const end = 2.25;
    final path = Path();
    for (var step = 0; step <= 32; step++) {
      final angle = start + (end - start) * step / 32;
      final x = center.dx + rx * math.cos(angle);
      final y = center.dy + ry * math.sin(angle);
      if (step == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.lineTo(rect.left, rect.top + rect.height * 0.9);
    for (var step = 32; step >= 0; step--) {
      final angle = start + (end - start) * step / 32;
      path.lineTo(
        center.dx + rx * 0.57 * math.cos(angle),
        center.dy + ry * 0.57 * math.sin(angle),
      );
    }
    return path..close();
  }

  Path _starPath(Rect rect) {
    final points = <Offset>[];
    for (var index = 0; index < 10; index++) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final radius = index.isEven ? 0.5 : 0.22;
      points.add(
        Offset(0.5 + radius * math.cos(angle), 0.5 + radius * math.sin(angle)),
      );
    }
    return _polygon(rect, points);
  }

  Path _curvedLinePath(BoardShape shape) {
    final (start, end) = lineEndpoints(shape);
    final delta = end - start;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + delta.dx * 0.25,
        start.dy + delta.dy * 0.88,
        start.dx + delta.dx * 0.75,
        start.dy + delta.dy * 0.12,
        end.dx,
        end.dy,
      );
  }

  Path _multiBendLinePath(BoardShape shape) {
    final (start, end) = lineEndpoints(shape);
    final delta = end - start;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(start.dx + delta.dx * 0.25, start.dy)
      ..lineTo(start.dx + delta.dx * 0.25, start.dy + delta.dy * 0.45)
      ..lineTo(start.dx + delta.dx * 0.75, start.dy + delta.dy * 0.45)
      ..lineTo(start.dx + delta.dx * 0.75, end.dy)
      ..lineTo(end.dx, end.dy);
  }

  Path _documentPath(Rect rect) {
    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..cubicTo(
        rect.left + rect.width * 0.78,
        rect.bottom,
        rect.left + rect.width * 0.70,
        rect.top + rect.height * 0.72,
        rect.left + rect.width * 0.5,
        rect.top + rect.height * 0.84,
      )
      ..cubicTo(
        rect.left + rect.width * 0.30,
        rect.top + rect.height * 0.96,
        rect.left + rect.width * 0.20,
        rect.bottom,
        rect.left,
        rect.bottom,
      );
    return path..close();
  }

  Path _databasePath(Rect rect) {
    final depth = rect.height * 0.18;
    return Path()
      ..moveTo(rect.left, rect.top + depth)
      ..cubicTo(
        rect.left,
        rect.top,
        rect.right,
        rect.top,
        rect.right,
        rect.top + depth,
      )
      ..lineTo(rect.right, rect.bottom - depth)
      ..cubicTo(
        rect.right,
        rect.bottom,
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - depth,
      )
      ..close();
  }

  Path _databaseDetailPath(Rect rect) {
    final depth = rect.height * 0.18;
    return Path()
      ..moveTo(rect.left, rect.top + depth)
      ..cubicTo(
        rect.left,
        rect.top + depth * 2,
        rect.right,
        rect.top + depth * 2,
        rect.right,
        rect.top + depth,
      );
  }

  Path _polygon(Rect rect, List<Offset> points) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final point = Offset(
        rect.left + points[index].dx * rect.width,
        rect.top + points[index].dy * rect.height,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Path _linePath(
    BoardShape shape, {
    bool startArrow = false,
    bool endArrow = false,
  }) {
    final endpoints = lineEndpoints(shape);
    final start = endpoints.$1;
    final end = endpoints.$2;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    if (startArrow) _addArrowHead(path, tip: start, from: end, shape: shape);
    if (endArrow) _addArrowHead(path, tip: end, from: start, shape: shape);
    return path;
  }

  Path _orthogonalPath(
    BoardShape shape, {
    bool startArrow = false,
    bool endArrow = false,
  }) {
    final points = orthogonalPoints(shape);
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    if (startArrow) {
      _addArrowHead(path, tip: points.first, from: points[1], shape: shape);
    }
    if (endArrow) {
      _addArrowHead(
        path,
        tip: points.last,
        from: points[points.length - 2],
        shape: shape,
      );
    }
    return path;
  }

  void _addArrowHead(
    Path path, {
    required Offset tip,
    required Offset from,
    required BoardShape shape,
  }) {
    final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
    final head = math.max(12.0, shape.outlineWidth * 4);
    const spread = math.pi / 7;
    path
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - head * math.cos(angle - spread),
        tip.dy - head * math.sin(angle - spread),
      )
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - head * math.cos(angle + spread),
        tip.dy - head * math.sin(angle + spread),
      );
  }

  List<Offset> orthogonalPoints(BoardShape shape) {
    final endpoints = lineEndpoints(shape);
    final start = endpoints.$1;
    final end = endpoints.$2;
    if (shape.routeAxis == OrthogonalRouteAxis.horizontalFirst) {
      final spineX = start.dx + (end.dx - start.dx) * shape.spinePosition;
      return [start, Offset(spineX, start.dy), Offset(spineX, end.dy), end];
    }
    final spineY = start.dy + (end.dy - start.dy) * shape.spinePosition;
    return [start, Offset(start.dx, spineY), Offset(end.dx, spineY), end];
  }

  Offset orthogonalSpineHandle(BoardShape shape) {
    final points = orthogonalPoints(shape);
    return Offset.lerp(points[1], points[2], 0.35)!;
  }

  (Offset, Offset) lineEndpoints(BoardShape shape) {
    final points = shape.lineStartsAtTopLeft
        ? (
            Offset(shape.x, shape.y),
            Offset(shape.x + shape.width, shape.y + shape.height),
          )
        : (
            Offset(shape.x + shape.width, shape.y),
            Offset(shape.x, shape.y + shape.height),
          );
    return shape.lineReversed ? (points.$2, points.$1) : points;
  }

  bool hitTest(BoardShape shape, Offset point, double tolerance) {
    final path = pathFor(shape);
    if (supportsFill && shape.fillOpacity > 0 && path.contains(point)) {
      return true;
    }
    if (_isNearPath(path, point, tolerance)) return true;
    return _isNearPath(detailPathFor(shape), point, tolerance);
  }

  bool _isNearPath(Path path, Offset point, double tolerance) {
    for (final metric in path.computeMetrics()) {
      final step = math.max(2.0, tolerance / 2);
      for (var distance = 0.0; distance <= metric.length; distance += step) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null &&
            (tangent.position - point).distance <= tolerance) {
          return true;
        }
      }
      final end = metric.getTangentForOffset(metric.length);
      if (end != null && (end.position - point).distance <= tolerance) {
        return true;
      }
    }
    return false;
  }

  static const definitions = <ShapeDefinition>[
    ShapeDefinition(
      type: BoardShapeType.line,
      category: 'Lines',
      icon: Icons.horizontal_rule,
    ),
    ShapeDefinition(
      type: BoardShapeType.arrow,
      category: 'Lines',
      icon: Icons.arrow_right_alt,
    ),
    ShapeDefinition(
      type: BoardShapeType.elbowLine,
      category: 'Lines',
      icon: Icons.turn_right,
    ),
    ShapeDefinition(
      type: BoardShapeType.elbowArrow,
      category: 'Lines',
      icon: Icons.subdirectory_arrow_right,
    ),
    ShapeDefinition(
      type: BoardShapeType.doubleArrow,
      category: 'Lines',
      icon: Icons.compare_arrows,
    ),
    ShapeDefinition(
      type: BoardShapeType.doubleElbowArrow,
      category: 'Lines',
      icon: Icons.swap_calls,
    ),
    ShapeDefinition(
      type: BoardShapeType.curvedLine,
      category: 'Lines',
      icon: Icons.show_chart,
    ),
    ShapeDefinition(
      type: BoardShapeType.multiBendLine,
      category: 'Lines',
      icon: Icons.multiline_chart,
    ),
    ShapeDefinition(
      type: BoardShapeType.blockArrowRight,
      category: 'Block arrows',
      icon: Icons.arrow_right,
    ),
    ShapeDefinition(
      type: BoardShapeType.blockArrowLeft,
      category: 'Block arrows',
      icon: Icons.arrow_left,
    ),
    ShapeDefinition(
      type: BoardShapeType.blockArrowUp,
      category: 'Block arrows',
      icon: Icons.arrow_upward,
    ),
    ShapeDefinition(
      type: BoardShapeType.blockArrowDown,
      category: 'Block arrows',
      icon: Icons.arrow_downward,
    ),
    ShapeDefinition(
      type: BoardShapeType.rectangle,
      category: 'Rectangles & basic shapes',
      icon: Icons.rectangle_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.roundedRectangle,
      category: 'Rectangles & basic shapes',
      icon: Icons.crop_16_9,
    ),
    ShapeDefinition(
      type: BoardShapeType.ellipse,
      category: 'Rectangles & basic shapes',
      icon: Icons.circle_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.triangle,
      category: 'Rectangles & basic shapes',
      icon: Icons.change_history,
    ),
    ShapeDefinition(
      type: BoardShapeType.rightTriangle,
      category: 'Rectangles & basic shapes',
      icon: Icons.signal_cellular_4_bar,
    ),
    ShapeDefinition(
      type: BoardShapeType.diamond,
      category: 'Rectangles & basic shapes',
      icon: Icons.diamond_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.parallelogram,
      category: 'Rectangles & basic shapes',
      icon: Icons.view_week_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.trapezoid,
      category: 'Rectangles & basic shapes',
      icon: Icons.filter_hdr_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.hexagon,
      category: 'Rectangles & basic shapes',
      icon: Icons.hexagon_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.terminator,
      category: 'Flowchart',
      icon: Icons.play_circle_outline,
    ),
    ShapeDefinition(
      type: BoardShapeType.document,
      category: 'Flowchart',
      icon: Icons.description_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.database,
      category: 'Flowchart',
      icon: Icons.storage,
    ),
    ShapeDefinition(
      type: BoardShapeType.predefinedProcess,
      category: 'Flowchart',
      icon: Icons.view_week_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.pentagon,
      category: 'Symbols',
      icon: Icons.pentagon_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.octagon,
      category: 'Symbols',
      icon: Icons.stop_circle_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.heart,
      category: 'Symbols',
      icon: Icons.favorite_border,
    ),
    ShapeDefinition(
      type: BoardShapeType.lightning,
      category: 'Symbols',
      icon: Icons.bolt_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.leftBracket,
      category: 'Symbols',
      icon: Icons.data_array,
    ),
    ShapeDefinition(
      type: BoardShapeType.rightBracket,
      category: 'Symbols',
      icon: Icons.data_array,
    ),
    ShapeDefinition(
      type: BoardShapeType.smiley,
      category: 'Symbols',
      icon: Icons.sentiment_satisfied_alt,
    ),
    ShapeDefinition(
      type: BoardShapeType.moon,
      category: 'Symbols',
      icon: Icons.nightlight_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.cloud,
      category: 'Symbols',
      icon: Icons.cloud_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.turnBlockArrow,
      category: 'Block arrows',
      icon: Icons.turn_right,
    ),
    ShapeDefinition(
      type: BoardShapeType.uTurnBlockArrow,
      category: 'Block arrows',
      icon: Icons.u_turn_right,
    ),
    ShapeDefinition(
      type: BoardShapeType.splitBlockArrow,
      category: 'Block arrows',
      icon: Icons.call_split,
    ),
    ShapeDefinition(
      type: BoardShapeType.mergeBlockArrow,
      category: 'Block arrows',
      icon: Icons.merge,
    ),
    ShapeDefinition(
      type: BoardShapeType.circularBlockArrow,
      category: 'Block arrows',
      icon: Icons.autorenew,
    ),
    ShapeDefinition(
      type: BoardShapeType.star,
      category: 'Symbols',
      icon: Icons.star_border,
    ),
    ShapeDefinition(
      type: BoardShapeType.banner,
      category: 'Symbols',
      icon: Icons.flag_outlined,
    ),
    ShapeDefinition(
      type: BoardShapeType.callout,
      category: 'Symbols',
      icon: Icons.chat_bubble_outline,
    ),
  ];

  static ShapeDefinition forType(BoardShapeType type) =>
      definitions.singleWhere((definition) => definition.type == type);
}
