import '../canvas/image_search.dart';
import '../image/board_image.dart';
import 'board_document.dart';
import 'library_search_target.dart';

class LibraryImageSearchResult {
  const LibraryImageSearchResult({required this.board, required this.image});

  final BoardDocument board;
  final BoardImage image;

  String get fileName => image.originalFileName;
  String? get caption => image.caption;
  String get primaryLabel => caption ?? fileName;
}

class LibraryImageSearch {
  const LibraryImageSearch._();

  static List<LibraryImageSearchResult> find(
    List<BoardDocument> orderedBoards,
    String rawQuery,
  ) {
    if (rawQuery.trim().isEmpty) {
      return const [];
    }
    return [
      for (final board in orderedBoards)
        for (final result in ImageSearch.find(board.images, rawQuery))
          LibraryImageSearchResult(board: board, image: result.image),
    ];
  }

  static bool isCurrentTarget(BoardDocument board, LibrarySearchTarget target) {
    if (target.type != LibrarySearchTargetType.image ||
        board.id != target.boardId) {
      return false;
    }
    return board.images.any(
      (image) =>
          image.id == target.objectId &&
          ImageSearch.matches(image, target.query),
    );
  }
}
