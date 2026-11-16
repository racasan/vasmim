enum LibrarySearchTargetType { note, image, heading, shape, connector, scene }

class LibrarySearchTarget {
  const LibrarySearchTarget.note({
    required this.boardId,
    required String noteId,
    required this.query,
  }) : type = LibrarySearchTargetType.note,
       objectId = noteId;

  const LibrarySearchTarget.image({
    required this.boardId,
    required String imageId,
    required this.query,
  }) : type = LibrarySearchTargetType.image,
       objectId = imageId;

  const LibrarySearchTarget.heading({
    required this.boardId,
    required String headingId,
    required this.query,
  }) : type = LibrarySearchTargetType.heading,
       objectId = headingId;

  const LibrarySearchTarget.shape({
    required this.boardId,
    required String shapeId,
    required this.query,
  }) : type = LibrarySearchTargetType.shape,
       objectId = shapeId;

  const LibrarySearchTarget.connector({
    required this.boardId,
    required String connectorId,
    required this.query,
  }) : type = LibrarySearchTargetType.connector,
       objectId = connectorId;

  const LibrarySearchTarget.scene({
    required this.boardId,
    required String sceneId,
    required this.query,
  }) : type = LibrarySearchTargetType.scene,
       objectId = sceneId;

  final LibrarySearchTargetType type;
  final String boardId;
  final String objectId;
  final String query;
}
