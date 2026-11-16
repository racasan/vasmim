import '../canvas/shape_search.dart';
import '../shape/board_shape.dart';
import 'board_document.dart';
import 'library_search_target.dart';

class LibraryShapeSearchResult {
  const LibraryShapeSearchResult({required this.board, required this.shape});
  final BoardDocument board;
  final BoardShape shape;
}

class LibraryShapeSearch {
  const LibraryShapeSearch._();

  static List<LibraryShapeSearchResult> find(
    List<BoardDocument> boards,
    String query,
  ) => [
    for (final board in boards)
      for (final result in ShapeSearch.find(board.shapes, query))
        LibraryShapeSearchResult(board: board, shape: result.shape),
  ];

  static bool isCurrentTarget(BoardDocument board, LibrarySearchTarget target) {
    if (target.type != LibrarySearchTargetType.shape ||
        board.id != target.boardId) {
      return false;
    }
    final query = target.query.trim().toLowerCase();
    return query.isNotEmpty &&
        board.shapes.any(
          (shape) =>
              shape.id == target.objectId &&
              (shape.heading?.text.toLowerCase().contains(query) ?? false),
        );
  }
}
