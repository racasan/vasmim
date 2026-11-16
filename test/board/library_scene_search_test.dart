import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_scene_search.dart';
import 'package:vasmim/board/library_search_target.dart';
import 'package:vasmim/scene/scene.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 28, 15);

  Scene scene(String id, String name) => Scene(
    id: id,
    name: name,
    x: 100,
    y: 200,
    zoom: 0.75,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  BoardDocument board(String id, List<Scene> scenes) => BoardDocument(
    id: id,
    name: 'Board $id',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: const [],
    scenes: scenes,
  );

  test('matches Scene names literally in stable board and Scene order', () {
    final results = LibrarySceneSearch.find([
      board('favorite', [
        scene('123e4567-e89b-42d3-a456-426614174201', 'Shared View'),
        scene('123e4567-e89b-42d3-a456-426614174202', 'SHARED VIEW detail'),
      ]),
      board('other', [
        scene('123e4567-e89b-42d3-a456-426614174203', 'Another shared view'),
        scene('123e4567-e89b-42d3-a456-426614174204', 'sharedXview'),
      ]),
    ], '  SHARED VIEW  ');

    expect(results.map((result) => (result.board.id, result.scene.id)), [
      ('favorite', '123e4567-e89b-42d3-a456-426614174201'),
      ('favorite', '123e4567-e89b-42d3-a456-426614174202'),
      ('other', '123e4567-e89b-42d3-a456-426614174203'),
    ]);
    expect(results.map((result) => result.name), [
      'Shared View',
      'SHARED VIEW detail',
      'Another shared view',
    ]);
    expect(LibrarySceneSearch.find([], '   '), isEmpty);
  });

  test('reflects the current saved Scene sequence without a second sort', () {
    final results = LibrarySceneSearch.find([
      board('reordered', [
        scene('123e4567-e89b-42d3-a456-426614174212', 'Plan view'),
        scene('123e4567-e89b-42d3-a456-426614174210', 'Question view'),
        scene('123e4567-e89b-42d3-a456-426614174211', 'Evidence view'),
      ]),
    ], 'view');

    expect(results.map((result) => result.name), [
      'Plan view',
      'Question view',
      'Evidence view',
    ]);
  });

  test('validates exact Scene identity and current matching name', () {
    const sceneId = '123e4567-e89b-42d3-a456-426614174205';
    final current = board('board-a', [scene(sceneId, 'Current View')]);
    const target = LibrarySearchTarget.scene(
      boardId: 'board-a',
      sceneId: sceneId,
      query: ' view ',
    );

    expect(LibrarySceneSearch.isCurrentTarget(current, target), isTrue);
    expect(
      LibrarySceneSearch.isCurrentTarget(
        board('board-a', [scene(sceneId, 'Renamed')]),
        target,
      ),
      isFalse,
    );
    expect(
      LibrarySceneSearch.isCurrentTarget(
        current,
        const LibrarySearchTarget.note(
          boardId: 'board-a',
          noteId: sceneId,
          query: 'view',
        ),
      ),
      isFalse,
    );
  });

  test('returns the current saved viewport for an unchanged Scene target', () {
    const sceneId = '123e4567-e89b-42d3-a456-426614174206';
    final updatedScene = Scene(
      id: sceneId,
      name: 'Evidence View',
      x: 720,
      y: 540,
      zoom: 1.1,
      createdAt: timestamp,
      modifiedAt: timestamp.add(const Duration(hours: 1)),
    );
    final current = board('board-a', [updatedScene]);
    const target = LibrarySearchTarget.scene(
      boardId: 'board-a',
      sceneId: sceneId,
      query: 'evidence',
    );

    expect(LibrarySceneSearch.isCurrentTarget(current, target), isTrue);
    final result = LibrarySceneSearch.find([current], 'evidence').single;
    expect(result.scene.toJson(), updatedScene.toJson());
  });
}
