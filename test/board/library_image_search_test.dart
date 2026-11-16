import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_image_search.dart';
import 'package:vasmim/board/library_search_target.dart';
import 'package:vasmim/image/board_image.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 26, 12);

  BoardImage image(String id, String fileName, {String? caption}) => BoardImage(
    id: id,
    x: 0,
    y: 0,
    width: 320,
    height: 200,
    assetPath: 'assets/$id.png',
    originalFileName: fileName,
    caption: caption,
    pixelWidth: 800,
    pixelHeight: 500,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  BoardDocument board(String id, List<BoardImage> images) => BoardDocument(
    id: id,
    name: 'Board $id',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: const [],
    images: images,
  );

  test(
    'matches filenames literally across boards in stable supplied order',
    () {
      final results = LibraryImageSearch.find([
        board('favorite', [
          image('first', 'Shared.Map.PNG'),
          image('second', 'shared.map.backup.png'),
        ]),
        board('other', [
          image('third', 'another-shared.map.png'),
          image('unmatched', 'sharedXmap.png'),
        ]),
      ], '  SHARED.MAP  ');

      expect(results.map((result) => (result.board.id, result.image.id)), [
        ('favorite', 'first'),
        ('favorite', 'second'),
        ('other', 'third'),
      ]);
      expect(results.map((result) => result.fileName), [
        'Shared.Map.PNG',
        'shared.map.backup.png',
        'another-shared.map.png',
      ]);
      expect(LibraryImageSearch.find([], '   '), isEmpty);
    },
  );

  test('validates exact image identity and current matching filename', () {
    final current = board('board-a', [image('image-a', 'Current Map.PNG')]);
    const target = LibrarySearchTarget.image(
      boardId: 'board-a',
      imageId: 'image-a',
      query: ' map.png ',
    );

    expect(LibraryImageSearch.isCurrentTarget(current, target), isTrue);
    expect(
      LibraryImageSearch.isCurrentTarget(
        board('board-a', [image('image-a', 'Renamed.png')]),
        target,
      ),
      isFalse,
    );
    expect(
      LibraryImageSearch.isCurrentTarget(
        current,
        const LibrarySearchTarget.note(
          boardId: 'board-a',
          noteId: 'image-a',
          query: 'map.png',
        ),
      ),
      isFalse,
    );
  });

  test(
    'matches and revalidates a caption while retaining filename context',
    () {
      final current = board('board-a', [
        image(
          'image-a',
          'source-diagram.png',
          caption: 'Deployment sequence reference',
        ),
      ]);
      const target = LibrarySearchTarget.image(
        boardId: 'board-a',
        imageId: 'image-a',
        query: 'sequence',
      );

      final result = LibraryImageSearch.find([current], 'sequence').single;
      expect(result.primaryLabel, 'Deployment sequence reference');
      expect(result.fileName, 'source-diagram.png');
      expect(LibraryImageSearch.isCurrentTarget(current, target), isTrue);
    },
  );
}
