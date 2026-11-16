import '../scene/scene.dart';
import 'board_document.dart';
import 'library_search_target.dart';

class LibrarySceneSearchResult {
  const LibrarySceneSearchResult({required this.board, required this.scene});

  final BoardDocument board;
  final Scene scene;

  String get name => scene.name;
}

class LibrarySceneSearch {
  const LibrarySceneSearch._();

  static List<LibrarySceneSearchResult> find(
    List<BoardDocument> orderedBoards,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final board in orderedBoards)
        for (final scene in board.scenes)
          if (scene.name.toLowerCase().contains(query))
            LibrarySceneSearchResult(board: board, scene: scene),
    ];
  }

  static bool isCurrentTarget(BoardDocument board, LibrarySearchTarget target) {
    if (target.type != LibrarySearchTargetType.scene ||
        board.id != target.boardId) {
      return false;
    }
    final query = target.query.trim().toLowerCase();
    if (query.isEmpty) {
      return false;
    }
    return board.scenes.any(
      (scene) =>
          scene.id == target.objectId &&
          scene.name.toLowerCase().contains(query),
    );
  }
}
