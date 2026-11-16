import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/shape/board_shape.dart';
import 'package:vasmim/shape/shape_layer.dart';

void main() {
  final time = DateTime.utc(2026, 9, 11);

  BoardShape shape(String id, double x) => BoardShape(
    id: id,
    type: BoardShapeType.rectangle,
    x: x,
    y: 100,
    width: 180,
    height: 120,
    lineStartsAtTopLeft: true,
    lineReversed: false,
    fillColorValue: 0xFF90CAF9,
    fillOpacity: 0.2,
    outlineColorValue: 0xFF37474F,
    outlineWidth: 2,
    createdAt: time,
    modifiedAt: time,
  );

  BoardDocument board({List<BoardShape>? shapes, List<ShapeLayer>? layers}) =>
      BoardDocument(
        id: 'board-layers',
        name: 'Layers',
        createdAt: time,
        modifiedAt: time,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        shapes: shapes ?? const [],
        shapeLayers: layers,
      );

  test('normalizes valid names and rejects unsafe names', () {
    expect(ShapeLayer.normalizeName('  References  '), 'References');
    expect(() => ShapeLayer.normalizeName('   '), throwsFormatException);
    expect(() => ShapeLayer.normalizeName('one\ntwo'), throwsFormatException);
    expect(() => ShapeLayer.normalizeName('x' * 81), throwsFormatException);
  });

  test('format 19 migrates every shape to one stable default layer', () {
    final shapes = [shape('back', 100), shape('front', 320)];
    final json = board(shapes: shapes).toJson()
      ..['formatVersion'] = 19
      ..remove('shapeLayers');

    final restored = BoardDocument.fromJson(json);

    expect(restored.shapeLayers, hasLength(1));
    expect(restored.shapeLayers.single.name, 'Shape layer 1');
    expect(restored.shapeLayers.single.shapeIds, ['back', 'front']);
    expect(
      restored.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
    expect(restored.shapeLayers.single.isVisible, isTrue);
    expect(restored.shapeLayers.single.opacity, 1);
  });

  test('format 20 migrates every layer as visible', () {
    final json = board(
      shapes: [shape('only', 100)],
      layers: [
        ShapeLayer(
          id: 'existing-layer',
          name: 'Existing',
          shapeIds: const ['only'],
          createdAt: time,
          modifiedAt: time,
        ),
      ],
    ).toJson()..['formatVersion'] = 20;
    for (final layer in json['shapeLayers'] as List) {
      (layer as Map).remove('isVisible');
    }

    final restored = BoardDocument.fromJson(json);

    expect(restored.shapeLayers.single.isVisible, isTrue);
    expect(
      restored.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
    expect(restored.shapeLayers.single.opacity, 1);
  });

  test('format 21 migrates every layer at full opacity', () {
    final json = board(
      shapes: [shape('only', 100)],
      layers: [
        ShapeLayer(
          id: 'existing-layer',
          name: 'Existing',
          shapeIds: const ['only'],
          createdAt: time,
          modifiedAt: time,
          isVisible: false,
        ),
      ],
    ).toJson()..['formatVersion'] = 21;
    for (final layer in json['shapeLayers'] as List) {
      (layer as Map).remove('opacity');
    }

    final restored = BoardDocument.fromJson(json);

    expect(restored.shapeLayers.single.isVisible, isFalse);
    expect(restored.shapeLayers.single.opacity, 1);
    expect(
      restored.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test('format 22 round trips layer order visibility and opacity', () {
    final shapes = [shape('back', 100), shape('front', 320)];
    final layers = [
      ShapeLayer(
        id: 'background',
        name: 'Background',
        shapeIds: const ['back'],
        createdAt: time,
        modifiedAt: time,
        isVisible: false,
        opacity: 0.25,
      ),
      ShapeLayer(
        id: 'directions',
        name: 'Directions',
        shapeIds: const ['front'],
        createdAt: time,
        modifiedAt: time,
        opacity: 0.75,
      ),
    ];

    final restored = BoardDocument.fromJson(
      board(shapes: shapes, layers: layers).toJson(),
    );

    expect(restored.shapeLayers, layers);
    expect(restored.shapeLayers.first.isVisible, isFalse);
    expect(restored.shapeLayers.last.isVisible, isTrue);
    expect(restored.shapeLayers.first.opacity, 0.25);
    expect(restored.shapeLayers.last.opacity, 0.75);
    expect(restored.shapeLayers.expand((layer) => layer.shapeIds), [
      'back',
      'front',
    ]);
  });

  test('rejects malformed layer identity name and membership', () {
    final shapes = [shape('a', 100), shape('b', 320)];
    ShapeLayer layer(String id, String name, List<String> ids) => ShapeLayer(
      id: id,
      name: name,
      shapeIds: ids,
      createdAt: time,
      modifiedAt: time,
    );

    expect(() => board(shapes: shapes, layers: const []), throwsArgumentError);
    expect(
      () => board(
        shapes: shapes,
        layers: [
          layer('one', 'Layer', ['a']),
          layer('one', 'Other', ['b']),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => board(
        shapes: shapes,
        layers: [
          layer('one', 'Layer', ['a']),
          layer('two', 'layer', ['b']),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => board(
        shapes: shapes,
        layers: [
          layer('one', 'One', ['a', 'b']),
          layer('two', 'Two', ['b']),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => board(
        shapes: shapes,
        layers: [
          layer('one', 'One', ['a']),
          layer('two', 'Two', ['missing']),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => board(
        shapes: shapes,
        layers: [
          layer('one', 'One', ['a']),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rejects malformed format 22 visibility and opacity', () {
    final json = board().toJson();
    final layers = json['shapeLayers'] as List;
    (layers.single as Map)['isVisible'] = 'yes';

    expect(() => BoardDocument.fromJson(json), throwsFormatException);

    final unsupported = board().toJson();
    ((unsupported['shapeLayers'] as List).single as Map)['opacity'] = 0.6;
    expect(() => BoardDocument.fromJson(unsupported), throwsFormatException);

    final nonFinite = ShapeLayer(
      id: 'non-finite',
      name: 'Non-finite',
      shapeIds: const [],
      createdAt: time,
      modifiedAt: time,
      opacity: double.nan,
    );
    expect(() => board(layers: [nonFinite]), throwsArgumentError);
  });
}
