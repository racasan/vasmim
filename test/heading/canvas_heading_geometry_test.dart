import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/heading/canvas_heading_geometry.dart';

void main() {
  test('derives stable padded bounds from heading content and size', () {
    final timestamp = DateTime.utc(2026, 9, 8);
    final heading = CanvasHeading(
      id: 'heading',
      x: 100,
      y: 200,
      text: 'Act one',
      size: CanvasHeadingSize.large,
      background: CanvasHeadingBackground.transparent,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final bounds = CanvasHeadingGeometry.boundsFor(heading);

    expect(bounds.left, 100);
    expect(bounds.top, 200);
    expect(bounds.width, greaterThanOrEqualTo(120));
    expect(bounds.height, 78);
    expect(
      CanvasHeadingGeometry.boundsFor(heading),
      CanvasHeadingGeometry.boundsFor(heading),
    );
  });
}
