import '../canvas/note_search.dart';
import '../note/note.dart';
import 'board_document.dart';
import 'library_search_target.dart';

class LibraryNoteSearchResult {
  const LibraryNoteSearchResult({
    required this.board,
    required this.note,
    required this.excerpt,
  });

  final BoardDocument board;
  final Note note;
  final String excerpt;
}

class LibraryNoteSearch {
  const LibraryNoteSearch._();

  static List<BoardDocument> orderBoards(
    Iterable<BoardDocument> boards, {
    required Set<String> favoriteBoardIds,
    required bool newestFirst,
  }) {
    final ordered = boards.toList();
    ordered.sort((left, right) {
      final leftIsFavorite = favoriteBoardIds.contains(left.id);
      final rightIsFavorite = favoriteBoardIds.contains(right.id);
      if (leftIsFavorite != rightIsFavorite) {
        return leftIsFavorite ? -1 : 1;
      }
      final modifiedOrder = newestFirst
          ? right.modifiedAt.compareTo(left.modifiedAt)
          : left.modifiedAt.compareTo(right.modifiedAt);
      return modifiedOrder != 0 ? modifiedOrder : left.id.compareTo(right.id);
    });
    return ordered;
  }

  static List<LibraryNoteSearchResult> find(
    List<BoardDocument> orderedBoards,
    String rawQuery,
  ) {
    if (rawQuery.trim().isEmpty) {
      return const [];
    }
    return [
      for (final board in orderedBoards)
        for (final result in NoteSearch.find(board.notes, rawQuery))
          LibraryNoteSearchResult(
            board: board,
            note: result.note,
            excerpt: result.excerpt,
          ),
    ];
  }

  static bool isCurrentTarget(BoardDocument board, LibrarySearchTarget target) {
    if (target.type != LibrarySearchTargetType.note ||
        board.id != target.boardId) {
      return false;
    }
    final query = target.query.trim().toLowerCase();
    if (query.isEmpty) {
      return false;
    }
    return board.notes.any(
      (note) =>
          note.id == target.objectId &&
          (note.text.toLowerCase().contains(query) ||
              (note.title?.toLowerCase().contains(query) ?? false)),
    );
  }
}
