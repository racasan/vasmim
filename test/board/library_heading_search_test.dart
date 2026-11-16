import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_heading_search.dart';
import 'package:vasmim/board/library_search_target.dart';
import 'package:vasmim/heading/canvas_heading.dart';

void main() {
  final heading = CanvasHeading(
    id: 'heading-1',
    x: 10,
    y: 20,
    text: 'Character arcs',
    size: CanvasHeadingSize.large,
    background: CanvasHeadingBackground.transparent,
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
  );
  final board = BoardDocument(
    id: 'board-1',
    name: 'Outline',
    createdAt: DateTime.utc(2026),
    modifiedAt: DateTime.utc(2026),
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: const [],
    headings: [heading],
  );

  test('find returns heading results with their board', () {
    final results = LibraryHeadingSearch.find([board], 'ARCS');

    expect(results, hasLength(1));
    expect(results.single.board.id, 'board-1');
    expect(results.single.heading.id, 'heading-1');
  });

  test('current target requires the same heading and matching query', () {
    expect(
      LibraryHeadingSearch.isCurrentTarget(
        board,
        const LibrarySearchTarget.heading(
          boardId: 'board-1',
          headingId: 'heading-1',
          query: 'arcs',
        ),
      ),
      isTrue,
    );
  });
}
