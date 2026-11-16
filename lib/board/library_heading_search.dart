import '../canvas/heading_search.dart';
import '../heading/canvas_heading.dart';
import 'board_document.dart';
import 'library_search_target.dart';

class LibraryHeadingSearchResult {
  const LibraryHeadingSearchResult({
    required this.board,
    required this.heading,
  });

  final BoardDocument board;
  final CanvasHeading heading;
}

class LibraryHeadingSearch {
  const LibraryHeadingSearch._();

  static List<LibraryHeadingSearchResult> find(
    List<BoardDocument> orderedBoards,
    String rawQuery,
  ) {
    if (rawQuery.trim().isEmpty) {
      return const [];
    }
    return [
      for (final board in orderedBoards)
        for (final result in HeadingSearch.find(board.headings, rawQuery))
          LibraryHeadingSearchResult(board: board, heading: result.heading),
    ];
  }

  static bool isCurrentTarget(BoardDocument board, LibrarySearchTarget target) {
    if (target.type != LibrarySearchTargetType.heading ||
        board.id != target.boardId) {
      return false;
    }
    final query = target.query.trim().toLowerCase();
    if (query.isEmpty) {
      return false;
    }
    return board.headings.any(
      (heading) =>
          heading.id == target.objectId &&
          heading.text.toLowerCase().contains(query),
    );
  }
}
