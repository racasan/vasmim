import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/canvas_snap_resolver.dart';

void main() {
  const canvasSize = Size(4000, 3000);
  const movingBounds = Rect.fromLTWH(100, 100, 60, 40);

  test('snaps every horizontal moving-bounds anchor to the grid', () {
    for (final testCase in [
      (desired: 57.0, expected: 60.0),
      (desired: 107.0, expected: 110.0),
      (desired: 157.0, expected: 160.0),
    ]) {
      final result = CanvasSnapResolver.resolve(
        movingBounds: movingBounds,
        desiredDelta: Offset(testCase.desired, 25),
        peerBounds: const [],
        viewportScale: 1,
        canvasSize: canvasSize,
        gridSpacing: 80,
      );

      expect(result.delta.dx, testCase.expected);
      expect(
        result.guides.where(
          (guide) => guide.axis == CanvasSnapGuideAxis.vertical,
        ),
        hasLength(1),
      );
    }
  });

  test('snaps every vertical moving-bounds anchor to the grid', () {
    for (final testCase in [
      (desired: 57.0, expected: 60.0),
      (desired: 97.0, expected: 100.0),
      (desired: 137.0, expected: 140.0),
    ]) {
      final result = CanvasSnapResolver.resolve(
        movingBounds: movingBounds,
        desiredDelta: Offset(25, testCase.desired),
        peerBounds: const [],
        viewportScale: 1,
        canvasSize: canvasSize,
        gridSpacing: 80,
      );

      expect(result.delta.dy, testCase.expected);
      expect(
        result.guides.where(
          (guide) => guide.axis == CanvasSnapGuideAxis.horizontal,
        ),
        hasLength(1),
      );
    }
  });

  test('aligns and touches peer edges', () {
    final result = CanvasSnapResolver.resolve(
      movingBounds: const Rect.fromLTWH(100, 100, 100, 80),
      desiredDelta: const Offset(104, 0),
      peerBounds: const [Rect.fromLTWH(307, 300, 100, 80)],
      viewportScale: 1,
      canvasSize: canvasSize,
      gridSpacing: 1000,
    );

    expect(result.delta.dx, 107);
    expect(result.guides.single.source, CanvasSnapGuideSource.peer);
    expect(result.guides.single.position, 307);
  });

  test('aligns centres when peer edges are outside the threshold', () {
    final result = CanvasSnapResolver.resolve(
      movingBounds: const Rect.fromLTWH(0, 100, 100, 80),
      desiredDelta: const Offset(300, 0),
      peerBounds: const [Rect.fromLTWH(273, 300, 160, 80)],
      viewportScale: 1,
      canvasSize: canvasSize,
      gridSpacing: 1000,
    );

    expect(result.delta.dx, 303);
    expect(result.guides.single.position, 353);
  });

  test('resolves horizontal and vertical axes independently', () {
    final result = CanvasSnapResolver.resolve(
      movingBounds: const Rect.fromLTWH(100, 100, 100, 80),
      desiredDelta: const Offset(104, 57),
      peerBounds: const [Rect.fromLTWH(307, 500, 100, 80)],
      viewportScale: 1,
      canvasSize: canvasSize,
      gridSpacing: 80,
    );

    expect(result.delta, const Offset(107, 60));
    expect(result.guides, hasLength(2));
    expect(result.guides.first.source, CanvasSnapGuideSource.peer);
    expect(result.guides.last.source, CanvasSnapGuideSource.grid);
  });

  test('uses a screen-space threshold at every zoom', () {
    CanvasSnapResult resolve(double scale) => CanvasSnapResolver.resolve(
      movingBounds: const Rect.fromLTWH(100, 100, 60, 40),
      desiredDelta: const Offset(54, 25),
      peerBounds: const [],
      viewportScale: scale,
      canvasSize: canvasSize,
      gridSpacing: 80,
    );

    expect(resolve(2).delta.dx, 54);
    expect(resolve(0.5).delta.dx, 60);
  });

  test('prefers a peer over the grid at the same distance', () {
    final result = CanvasSnapResolver.resolve(
      movingBounds: const Rect.fromLTWH(100, 100, 100, 80),
      desiredDelta: const Offset(37, 25),
      peerBounds: const [Rect.fromLTWH(240, 500, 100, 80)],
      viewportScale: 1,
      canvasSize: canvasSize,
      gridSpacing: 80,
    );

    expect(result.delta.dx, 40);
    expect(result.guides.first.source, CanvasSnapGuideSource.peer);
  });

  test('keeps snapped bounds on the Board', () {
    final result = CanvasSnapResolver.resolve(
      movingBounds: const Rect.fromLTWH(350, 100, 40, 40),
      desiredDelta: Offset.zero,
      peerBounds: const [Rect.fromLTWH(397, 300, 2, 40)],
      viewportScale: 0.2,
      canvasSize: const Size(400, 300),
      gridSpacing: 80,
    );

    final resultBounds = const Rect.fromLTWH(
      350,
      100,
      40,
      40,
    ).shift(result.delta);
    expect(resultBounds.left, greaterThanOrEqualTo(0));
    expect(resultBounds.right, lessThanOrEqualTo(400));
  });

  test('preserves free movement when no candidate is close enough', () {
    final result = CanvasSnapResolver.resolve(
      movingBounds: movingBounds,
      desiredDelta: const Offset(70, 70),
      peerBounds: const [Rect.fromLTWH(900, 900, 100, 100)],
      viewportScale: 1,
      canvasSize: canvasSize,
      gridSpacing: 80,
    );

    expect(result.delta, const Offset(70, 70));
    expect(result.guides, isEmpty);
  });
}
