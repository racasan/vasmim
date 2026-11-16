import 'package:flutter/widgets.dart';

import 'scene.dart';

class SceneViewportController {
  const SceneViewportController._();

  static const matchTolerance = 0.001;

  static Scene capture({
    required TransformationController transformationController,
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) {
    final viewportOrigin = transformationController.toScene(Offset.zero);
    return Scene(
      id: id,
      name: name,
      x: viewportOrigin.dx,
      y: viewportOrigin.dy,
      zoom: transformationController.value.getMaxScaleOnAxis(),
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
  }

  static void activate({
    required TransformationController transformationController,
    required Scene scene,
  }) {
    transformationController.value = transformFor(scene);
  }

  static bool matches({
    required TransformationController transformationController,
    required Scene scene,
    double tolerance = matchTolerance,
  }) {
    final viewportOrigin = transformationController.toScene(Offset.zero);
    final zoom = transformationController.value.getMaxScaleOnAxis();
    return (viewportOrigin.dx - scene.x).abs() <= tolerance &&
        (viewportOrigin.dy - scene.y).abs() <= tolerance &&
        (zoom - scene.zoom).abs() <= tolerance;
  }

  static Scene updatedFromViewport({
    required TransformationController transformationController,
    required Scene scene,
    required DateTime modifiedAt,
  }) {
    final viewportOrigin = transformationController.toScene(Offset.zero);
    return Scene(
      id: scene.id,
      name: scene.name,
      x: viewportOrigin.dx,
      y: viewportOrigin.dy,
      zoom: transformationController.value.getMaxScaleOnAxis(),
      createdAt: scene.createdAt,
      modifiedAt: modifiedAt,
    );
  }

  static Matrix4 transformFor(Scene scene) {
    return Matrix4.diagonal3Values(scene.zoom, scene.zoom, scene.zoom)
      ..setTranslationRaw(-scene.x * scene.zoom, -scene.y * scene.zoom, 0);
  }
}
