import 'package:flutter/material.dart';

import '../board/board_paper_tone.dart';
import 'canvas_paper_painter.dart';
import 'canvas_overview_geometry.dart';

class CanvasOverviewObject {
  const CanvasOverviewObject({
    required this.id,
    required this.bounds,
    required this.color,
    this.isSelected = false,
  });

  final String id;
  final Rect bounds;
  final Color color;
  final bool isSelected;
}

class CanvasOverviewLink {
  const CanvasOverviewLink({required this.objectAId, required this.objectBId});

  final String objectAId;
  final String objectBId;
}

class CanvasOverviewMap extends StatelessWidget {
  const CanvasOverviewMap({
    required this.transformationController,
    required this.viewportSize,
    required this.boardSize,
    required this.objects,
    required this.links,
    required this.onRecenter,
    this.paperTone = BoardPaperTone.defaultTone,
    super.key,
  });

  static const overviewSize = Size(180, 135);

  final TransformationController transformationController;
  final Size viewportSize;
  final Size boardSize;
  final List<CanvasOverviewObject> objects;
  final List<CanvasOverviewLink> links;
  final ValueChanged<Offset> onRecenter;
  final BoardPaperTone paperTone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      image: true,
      label:
          'Canvas overview showing ${objects.length} objects and the current viewport',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Canvas overview — click to recenter',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const ValueKey('canvas-overview-map'),
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: (details) {
              onRecenter(
                CanvasOverviewGeometry.canvasPointForOverview(
                  overviewPoint: details.localPosition,
                  overviewSize: overviewSize,
                  boardSize: boardSize,
                ),
              );
            },
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: AnimatedBuilder(
                animation: transformationController,
                builder: (context, child) => CustomPaint(
                  key: const ValueKey('canvas-overview-paint'),
                  size: overviewSize,
                  painter: CanvasOverviewPainter(
                    boardSize: boardSize,
                    overviewSize: overviewSize,
                    viewportSize: viewportSize,
                    transform: transformationController.value,
                    objects: objects,
                    links: links,
                    backgroundColor: paperTone == BoardPaperTone.defaultTone
                        ? colorScheme.surfaceContainerHighest
                        : LayeredCanvasPaperPainter.paperColorFor(
                            paperTone,
                            isDark:
                                Theme.of(context).brightness == Brightness.dark,
                          ),
                    borderColor: colorScheme.outlineVariant,
                    linkColor: colorScheme.outline,
                    viewportColor: colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CanvasOverviewPainter extends CustomPainter {
  static const normalObjectOutlineWidth = 0.8;
  static const selectedObjectOutlineWidth = 2.0;

  CanvasOverviewPainter({
    required this.boardSize,
    required this.overviewSize,
    required this.viewportSize,
    required Matrix4 transform,
    required this.objects,
    required this.links,
    required this.backgroundColor,
    required this.borderColor,
    required this.linkColor,
    required this.viewportColor,
    this.showViewport = true,
  }) : transform = Matrix4.copy(transform);

  final Size boardSize;
  final Size overviewSize;
  final Size viewportSize;
  final Matrix4 transform;
  final List<CanvasOverviewObject> objects;
  final List<CanvasOverviewLink> links;
  final Color backgroundColor;
  final Color borderColor;
  final Color linkColor;
  final Color viewportColor;
  final bool showViewport;

  Rect get viewportRect => CanvasOverviewGeometry.overviewViewportRect(
    transform: transform,
    viewportSize: viewportSize,
    overviewSize: overviewSize,
    boardSize: boardSize,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = backgroundColor);

    final objectsById = {for (final object in objects) object.id: object};
    final linkPaint = Paint()
      ..color = linkColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (final link in links) {
      final first = objectsById[link.objectAId];
      final second = objectsById[link.objectBId];
      if (first == null || second == null) {
        continue;
      }
      canvas.drawLine(
        _mapRect(first.bounds, size).center,
        _mapRect(second.bounds, size).center,
        linkPaint,
      );
    }

    for (final object in objects) {
      final mapped = _minimumVisibleRect(_mapRect(object.bounds, size));
      canvas.drawRRect(
        RRect.fromRectAndRadius(mapped, const Radius.circular(1.5)),
        Paint()..color = object.color,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(mapped, const Radius.circular(1.5)),
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = object.isSelected
              ? selectedObjectOutlineWidth
              : normalObjectOutlineWidth,
      );
    }

    if (showViewport) {
      final visibleViewport = CanvasOverviewGeometry.overviewViewportRect(
        transform: transform,
        viewportSize: viewportSize,
        overviewSize: size,
        boardSize: boardSize,
      );
      if (!visibleViewport.isEmpty) {
        canvas.drawRect(
          visibleViewport,
          Paint()..color = viewportColor.withValues(alpha: 0.12),
        );
        canvas.drawRect(
          visibleViewport.deflate(1),
          Paint()
            ..color = viewportColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    canvas.drawRect(
      bounds.deflate(0.5),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Rect _mapRect(Rect canvasRect, Size size) {
    return CanvasOverviewGeometry.overviewRectForCanvasRect(
      canvasRect: canvasRect,
      overviewSize: size,
      boardSize: boardSize,
    );
  }

  Rect _minimumVisibleRect(Rect rect) {
    const minimum = 3.0;
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width < minimum ? minimum : rect.width,
      height: rect.height < minimum ? minimum : rect.height,
    );
  }

  @override
  bool shouldRepaint(covariant CanvasOverviewPainter oldDelegate) {
    return oldDelegate.boardSize != boardSize ||
        oldDelegate.overviewSize != overviewSize ||
        oldDelegate.viewportSize != viewportSize ||
        oldDelegate.transform != transform ||
        oldDelegate.objects != objects ||
        oldDelegate.links != links ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.linkColor != linkColor ||
        oldDelegate.viewportColor != viewportColor ||
        oldDelegate.showViewport != showViewport;
  }
}
