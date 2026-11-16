import '../canvas/connector_search.dart';
import '../connector/connector.dart';
import 'board_document.dart';
import 'library_search_target.dart';

class LibraryConnectorSearchResult {
  const LibraryConnectorSearchResult({
    required this.board,
    required this.connector,
  });

  final BoardDocument board;
  final Connector connector;

  String get label => connector.label!;
}

class LibraryConnectorSearch {
  const LibraryConnectorSearch._();

  static List<LibraryConnectorSearchResult> find(
    List<BoardDocument> orderedBoards,
    String rawQuery,
  ) {
    if (rawQuery.trim().isEmpty) {
      return const [];
    }
    return [
      for (final board in orderedBoards)
        for (final result in ConnectorSearch.find(board.connectors, rawQuery))
          LibraryConnectorSearchResult(
            board: board,
            connector: result.connector,
          ),
    ];
  }

  static bool isCurrentTarget(BoardDocument board, LibrarySearchTarget target) {
    if (target.type != LibrarySearchTargetType.connector ||
        board.id != target.boardId) {
      return false;
    }
    final query = target.query.trim().toLowerCase();
    if (query.isEmpty) {
      return false;
    }
    return board.connectors.any(
      (connector) =>
          connector.id == target.objectId &&
          connector.label != null &&
          connector.label!.toLowerCase().contains(query),
    );
  }
}
