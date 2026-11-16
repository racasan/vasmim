import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/image_search.dart';
import 'package:vasmim/image/board_image.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 26, 12);
  BoardImage image(String id, String originalFileName) => BoardImage(
    id: id,
    x: 0,
    y: 0,
    width: 320,
    height: 180,
    assetPath: 'assets/$id.png',
    originalFileName: originalFileName,
    pixelWidth: 1600,
    pixelHeight: 900,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  test(
    'matches trimmed literal filenames case-insensitively in image order',
    () {
      final results = ImageSearch.find([
        image('first', 'Alpha Shared Reference.PNG'),
        image('second', 'shared reference detail.jpg'),
        image('other', 'Unrelated diagram.png'),
      ], '  SHARED Reference  ');

      expect(results.map((result) => result.image.id), ['first', 'second']);
      expect(
        ImageSearch.find([image('literal', 'diagram[1].png')], '[1]'),
        hasLength(1),
      );
      expect(
        ImageSearch.find([image('empty', 'reference.png')], '   '),
        isEmpty,
      );
    },
  );

  test('uses retained metadata without depending on asset availability', () {
    final unavailable = image('missing', 'Unavailable Diagram.png');

    final results = ImageSearch.find([unavailable], 'diagram');

    expect(results.single.image, same(unavailable));
    expect(results.single.fileName, 'Unavailable Diagram.png');
  });

  test('matches a caption while retaining its source filename', () {
    final captioned = image(
      'captioned',
      'scene-reference.png',
    ).copyWith(caption: 'Enemy silhouette reference');

    final result = ImageSearch.find([captioned], 'silhouette').single;

    expect(result.image, same(captioned));
    expect(result.caption, 'Enemy silhouette reference');
    expect(result.fileName, 'scene-reference.png');
    expect(result.primaryLabel, 'Enemy silhouette reference');
  });
}
