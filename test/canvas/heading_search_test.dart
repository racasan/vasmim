import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/heading_search.dart';
import 'package:vasmim/heading/canvas_heading.dart';

void main() {
  test('find matches heading text case-insensitively', () {
    final headings = [
      CanvasHeading(
        id: 'heading-1',
        x: 10,
        y: 20,
        text: 'Act One',
        size: CanvasHeadingSize.large,
        background: CanvasHeadingBackground.transparent,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      ),
    ];

    final results = HeadingSearch.find(headings, 'act one');

    expect(results, hasLength(1));
    expect(results.single.heading.id, 'heading-1');
  });

  test('find returns no results for a blank query', () {
    expect(HeadingSearch.find(const [], '  '), isEmpty);
  });
}
