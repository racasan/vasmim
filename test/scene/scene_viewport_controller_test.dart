import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/scene/scene.dart';
import 'package:vasmim/scene/scene_viewport_controller.dart';

void main() {
  test('captures the exact canvas origin and zoom from a viewport', () {
    final controller = TransformationController(
      Matrix4.diagonal3Values(1.25, 1.25, 1.25)
        ..setTranslationRaw(-150, -300, 0),
    );
    addTearDown(controller.dispose);
    final timestamp = DateTime.utc(2026, 8, 13);

    final scene = SceneViewportController.capture(
      transformationController: controller,
      id: '123e4567-e89b-42d3-a456-426614174000',
      name: 'Plan',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    expect(scene.x, closeTo(120, 0.0001));
    expect(scene.y, closeTo(240, 0.0001));
    expect(scene.zoom, closeTo(1.25, 0.0001));
    expect(scene.name, 'Plan');
  });

  test('activates a scene without changing its saved values', () {
    final controller = TransformationController();
    addTearDown(controller.dispose);
    final timestamp = DateTime.utc(2026, 8, 13);
    final scene = Scene(
      id: '123e4567-e89b-42d3-a456-426614174000',
      name: 'References',
      x: 640,
      y: 480,
      zoom: 0.75,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    SceneViewportController.activate(
      transformationController: controller,
      scene: scene,
    );

    expect(controller.toScene(Offset.zero).dx, closeTo(640, 0.0001));
    expect(controller.toScene(Offset.zero).dy, closeTo(480, 0.0001));
    expect(controller.value.getMaxScaleOnAxis(), closeTo(0.75, 0.0001));
    expect(scene.x, 640);
    expect(scene.y, 480);
    expect(scene.zoom, 0.75);
  });

  test('matches and updates only the saved viewport and modification time', () {
    final createdAt = DateTime.utc(2026, 8, 13);
    final modifiedAt = DateTime.utc(2026, 8, 14);
    final updatedAt = DateTime.utc(2026, 9, 1);
    final scene = Scene(
      id: '123e4567-e89b-42d3-a456-426614174001',
      name: 'Evidence',
      x: 640,
      y: 480,
      zoom: 0.75,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
    final controller = TransformationController(
      SceneViewportController.transformFor(scene),
    );
    addTearDown(controller.dispose);

    expect(
      SceneViewportController.matches(
        transformationController: controller,
        scene: scene,
      ),
      isTrue,
    );
    controller.value = Matrix4.diagonal3Values(1.25, 1.25, 1.25)
      ..setTranslationRaw(-150, -300, 0);
    expect(
      SceneViewportController.matches(
        transformationController: controller,
        scene: scene,
      ),
      isFalse,
    );

    final updated = SceneViewportController.updatedFromViewport(
      transformationController: controller,
      scene: scene,
      modifiedAt: updatedAt,
    );
    expect(updated.id, scene.id);
    expect(updated.name, scene.name);
    expect(updated.createdAt, scene.createdAt);
    expect(updated.modifiedAt, updatedAt);
    expect(updated.x, closeTo(120, 0.0001));
    expect(updated.y, closeTo(240, 0.0001));
    expect(updated.zoom, closeTo(1.25, 0.0001));
  });
}
