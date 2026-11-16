import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/canvas_overview_geometry.dart';

void main() {
  const boardSize = Size(4000, 3000);
  const overviewSize = Size(180, 135);

  test('maps overview points to fixed board coordinates with clamping', () {
    expect(
      CanvasOverviewGeometry.canvasPointForOverview(
        overviewPoint: const Offset(90, 67.5),
        overviewSize: overviewSize,
        boardSize: boardSize,
      ),
      const Offset(2000, 1500),
    );
    expect(
      CanvasOverviewGeometry.canvasPointForOverview(
        overviewPoint: const Offset(300, -10),
        overviewSize: overviewSize,
        boardSize: boardSize,
      ),
      const Offset(4000, 0),
    );
  });

  test('maps canvas object bounds into overview bounds', () {
    final result = CanvasOverviewGeometry.overviewRectForCanvasRect(
      canvasRect: const Rect.fromLTWH(1000, 750, 400, 300),
      overviewSize: overviewSize,
      boardSize: boardSize,
    );

    expect(result, const Rect.fromLTWH(45, 33.75, 18, 13.5));
  });

  test('maps and clips the visible viewport into the overview', () {
    final transform = Matrix4.diagonal3Values(0.5, 0.5, 0.5)
      ..setTranslationRaw(-100, -50, 0);
    final result = CanvasOverviewGeometry.overviewViewportRect(
      transform: transform,
      viewportSize: const Size(800, 600),
      overviewSize: overviewSize,
      boardSize: boardSize,
    );

    expect(result.left, closeTo(9, 0.001));
    expect(result.top, closeTo(4.5, 0.001));
    expect(result.width, closeTo(72, 0.001));
    expect(result.height, closeTo(54, 0.001));
  });

  test('recenters a viewport while preserving its zoom', () {
    final current = Matrix4.diagonal3Values(0.75, 0.75, 0.75)
      ..setTranslationRaw(-80, -40, 0);
    final result = CanvasOverviewGeometry.recenteredTransform(
      currentTransform: current,
      viewportSize: const Size(800, 600),
      canvasPoint: const Offset(2000, 1500),
    );
    final inverse = Matrix4.inverted(result);
    final center = MatrixUtils.transformPoint(inverse, const Offset(400, 300));

    expect(result.getMaxScaleOnAxis(), closeTo(0.75, 0.001));
    expect(center.dx, closeTo(2000, 0.001));
    expect(center.dy, closeTo(1500, 0.001));
  });
}
