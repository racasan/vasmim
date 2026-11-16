import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_shape_search.dart';
import 'package:vasmim/shape/board_shape.dart';

void main() {
  test('finds shape headings across boards with board context', () {
    final board = BoardDocument(
      id: 'board-1',
      name: 'Game outline',
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      shapes: [
        BoardShape(
          id: 'shape-1',
          type: BoardShapeType.arrow,
          x: 10,
          y: 20,
          width: 200,
          height: 80,
          heading: const ShapeHeading(text: 'Player journey'),
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026),
        ),
      ],
    );

    final results = LibraryShapeSearch.find([board], 'journey');

    expect(results, hasLength(1));
    expect(results.single.board.id, 'board-1');
    expect(results.single.shape.id, 'shape-1');
  });
}
