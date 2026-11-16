import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/shape_search.dart';
import 'package:vasmim/shape/board_shape.dart';

void main() {
  test('searches only written shape headings case-insensitively', () {
    final shapes = [
      BoardShape(
        id: 'shape-1',
        type: BoardShapeType.rectangle,
        x: 10,
        y: 20,
        width: 300,
        height: 200,
        heading: const ShapeHeading(text: 'Research boundary'),
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      ),
      BoardShape(
        id: 'shape-2',
        type: BoardShapeType.ellipse,
        x: 30,
        y: 40,
        width: 100,
        height: 100,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      ),
    ];

    expect(
      ShapeSearch.find(shapes, 'RESEARCH').map((result) => result.shape.id),
      ['shape-1'],
    );
    expect(ShapeSearch.find(shapes, 'missing'), isEmpty);
  });
}
