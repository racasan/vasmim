enum CanvasInitialTargetType { note, image, heading, shape, connector, scene }

class CanvasInitialTarget {
  const CanvasInitialTarget.note(String noteId)
    : type = CanvasInitialTargetType.note,
      objectId = noteId;

  const CanvasInitialTarget.image(String imageId)
    : type = CanvasInitialTargetType.image,
      objectId = imageId;

  const CanvasInitialTarget.heading(String headingId)
    : type = CanvasInitialTargetType.heading,
      objectId = headingId;

  const CanvasInitialTarget.shape(String shapeId)
    : type = CanvasInitialTargetType.shape,
      objectId = shapeId;

  const CanvasInitialTarget.connector(String connectorId)
    : type = CanvasInitialTargetType.connector,
      objectId = connectorId;

  const CanvasInitialTarget.scene(String sceneId)
    : type = CanvasInitialTargetType.scene,
      objectId = sceneId;

  final CanvasInitialTargetType type;
  final String objectId;
}
