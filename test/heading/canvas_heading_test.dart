import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/heading/canvas_heading.dart';

void main() {
  test('round-trips canonical heading data', () {
    final timestamp = DateTime.utc(2026, 9, 8);
    final heading = CanvasHeading(
      id: 'heading-a',
      x: 120,
      y: 240,
      text: 'Opening sequence',
      size: CanvasHeadingSize.large,
      background: CanvasHeadingBackground.purple,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final restored = CanvasHeading.fromJson(heading.toJson());

    expect(restored.id, heading.id);
    expect(restored.x, 120);
    expect(restored.y, 240);
    expect(restored.text, 'Opening sequence');
    expect(restored.size, CanvasHeadingSize.large);
    expect(restored.fontSize, 40);
    expect(restored.background, CanvasHeadingBackground.purple);
    expect(restored.toJson(), heading.toJson());
  });

  test('normalizes heading text and rejects invalid persisted values', () {
    expect(CanvasHeading.normalizeText('  Act one  '), 'Act one');
    expect(CanvasHeading.normalizeText('   '), isNull);
    expect(
      () => CanvasHeading.normalizeText('Two\nlines'),
      throwsFormatException,
    );
    expect(
      () => CanvasHeading.normalizeText(List.filled(81, 'x').join()),
      throwsFormatException,
    );
  });

  test('size presets expose the approved point values', () {
    expect(CanvasHeadingSize.values.map((size) => size.fontSize), [
      20,
      28,
      40,
      56,
    ]);
  });
}
