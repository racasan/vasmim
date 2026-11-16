import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/connector/connector_geometry.dart';

void main() {
  test('anchors a horizontal connector at facing note edges', () {
    final segment = ConnectorGeometry.betweenRects(
      const Rect.fromLTWH(0, 0, 100, 80),
      const Rect.fromLTWH(200, 0, 100, 80),
    );

    expect(segment.start, const Offset(100, 40));
    expect(segment.end, const Offset(200, 40));
  });

  test('anchors a vertical connector at facing note edges', () {
    final segment = ConnectorGeometry.betweenRects(
      const Rect.fromLTWH(20, 10, 120, 100),
      const Rect.fromLTWH(20, 210, 120, 100),
    );

    expect(segment.start, const Offset(80, 110));
    expect(segment.end, const Offset(80, 210));
  });

  test('anchors a diagonal connector on the first boundary it meets', () {
    final segment = ConnectorGeometry.betweenRects(
      const Rect.fromLTWH(0, 0, 200, 100),
      const Rect.fromLTWH(300, 250, 100, 100),
    );

    expect(segment.start, const Offset(150, 100));
    expect(segment.end, const Offset(300, 250));
  });

  test('keeps both anchors on their boundaries when notes overlap', () {
    final segment = ConnectorGeometry.betweenRects(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Rect.fromLTWH(50, 0, 100, 100),
    );

    expect(segment.start, const Offset(100, 50));
    expect(segment.end, const Offset(50, 50));
  });

  test('uses deterministic horizontal boundaries for a shared centre', () {
    final segment = ConnectorGeometry.betweenRects(
      const Rect.fromLTWH(50, 0, 100, 100),
      const Rect.fromLTWH(0, 0, 200, 100),
    );

    expect(segment.start, const Offset(150, 50));
    expect(segment.end, const Offset(0, 50));
  });
}
