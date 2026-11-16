import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/shape/board_shape.dart';
import 'package:vasmim/shape/shape_definition.dart';
import 'package:vasmim/shape/shape_selection_painter.dart';

void main() {
  final time = DateTime.utc(2026, 9, 9);

  BoardShape shape(BoardShapeType type) => BoardShape(
    id: 'shape-${type.name}',
    type: type,
    x: 100,
    y: 120,
    width: 240,
    height: 140,
    lineStartsAtTopLeft: true,
    lineReversed: false,
    fillColorValue: 0xFF00AAFF,
    fillOpacity: type.supportsFill ? 0.3 : 0,
    outlineColorValue: 0xFF112233,
    outlineWidth: 4,
    heading: ShapeHeading(
      text: '${type.label} area',
      fontSize: 28,
      colorValue: 0xFF445566,
      alignment: ShapeHeadingAlignment.right,
      placement: type.supportsFill
          ? ShapeHeadingPlacement.insideTop
          : ShapeHeadingPlacement.above,
    ),
    createdAt: time,
    modifiedAt: time,
  );

  test('all accepted definitions create useful vector paths', () {
    for (final type in BoardShapeType.values) {
      final definition = ShapeDefinition.forType(type);
      final path = definition.pathFor(shape(type));
      expect(path.computeMetrics().isNotEmpty, isTrue, reason: type.name);
      expect(definition.supportsFill, type.supportsFill);
    }
  });

  test('expanded closed shapes have stable expected path bounds', () {
    const expanded = [
      BoardShapeType.triangle,
      BoardShapeType.rightTriangle,
      BoardShapeType.diamond,
      BoardShapeType.parallelogram,
      BoardShapeType.trapezoid,
      BoardShapeType.hexagon,
    ];
    for (final type in expanded) {
      final value = shape(type);
      final definition = ShapeDefinition.forType(type);
      expect(definition.supportsFill, isTrue, reason: type.name);
      expect(
        definition.pathFor(value).getBounds(),
        const Rect.fromLTWH(100, 120, 240, 140),
      );
      expect(
        definition.hitTest(
          value.copyWith(fillOpacity: 0),
          const Offset(220, 220),
          4,
        ),
        isFalse,
        reason: '${type.name} hollow centre',
      );
      expect(
        definition.hitTest(value, const Offset(220, 220), 4),
        isTrue,
        reason: '${type.name} filled centre',
      );
    }
  });

  test(
    'hollow shapes hit only their outline while filled shapes hit inside',
    () {
      final definition = ShapeDefinition.forType(BoardShapeType.rectangle);
      final hollow = shape(BoardShapeType.rectangle).copyWith(fillOpacity: 0);
      expect(definition.hitTest(hollow, const Offset(220, 190), 8), isFalse);
      expect(definition.hitTest(hollow, const Offset(100, 190), 8), isTrue);
      expect(
        definition.hitTest(
          shape(BoardShapeType.rectangle),
          const Offset(220, 190),
          8,
        ),
        isTrue,
      );
    },
  );

  test('arrow head remains attached to its second endpoint', () {
    final forward = shape(BoardShapeType.arrow);
    final definition = ShapeDefinition.forType(BoardShapeType.arrow);
    expect(definition.lineEndpoints(forward).$2, const Offset(340, 260));
    final reversed = forward.copyWith(lineReversed: true);
    expect(definition.lineEndpoints(reversed).$2, const Offset(100, 120));
  });

  test('orthogonal routes retain right angles and their persisted spine', () {
    final value = shape(BoardShapeType.elbowLine).copyWith(
      routeAxis: OrthogonalRouteAxis.horizontalFirst,
      spinePosition: 0.25,
    );
    final definition = ShapeDefinition.forType(value.type);
    expect(definition.orthogonalPoints(value), const [
      Offset(100, 120),
      Offset(160, 120),
      Offset(160, 260),
      Offset(340, 260),
    ]);

    final vertical = value.copyWith(
      routeAxis: OrthogonalRouteAxis.verticalFirst,
      spinePosition: 0.75,
    );
    expect(definition.orthogonalPoints(vertical), const [
      Offset(100, 120),
      Offset(100, 225),
      Offset(340, 225),
      Offset(340, 260),
    ]);
    expect(definition.hitTest(vertical, const Offset(220, 225), 4), isTrue);
    expect(definition.hitTest(vertical, const Offset(220, 190), 4), isFalse);
  });

  test('orthogonal arrow keeps its head on the routed final endpoint', () {
    final value = shape(BoardShapeType.elbowArrow).copyWith(
      routeAxis: OrthogonalRouteAxis.horizontalFirst,
      spinePosition: 0.3,
    );
    final definition = ShapeDefinition.forType(value.type);
    expect(definition.orthogonalPoints(value).last, const Offset(340, 260));
    expect(definition.pathFor(value).computeMetrics(), hasLength(3));
  });

  test('double-ended arrows draw one head at each endpoint', () {
    for (final type in const [
      BoardShapeType.doubleArrow,
      BoardShapeType.doubleElbowArrow,
    ]) {
      final value = shape(type).copyWith(
        routeAxis: OrthogonalRouteAxis.verticalFirst,
        spinePosition: 0.4,
      );
      final definition = ShapeDefinition.forType(type);
      final metrics = definition.pathFor(value).computeMetrics().toList();
      expect(definition.supportsFill, isFalse, reason: type.name);
      expect(
        metrics,
        hasLength(5),
        reason: '${type.name} main route plus four arrowhead strokes',
      );
      expect(definition.lineEndpoints(value).$1, const Offset(100, 120));
      expect(definition.lineEndpoints(value).$2, const Offset(340, 260));
      expect(
        metrics[1].getTangentForOffset(0)!.position,
        const Offset(100, 120),
      );
      expect(
        metrics[2].getTangentForOffset(0)!.position,
        const Offset(100, 120),
      );
      expect(
        metrics[3].getTangentForOffset(0)!.position,
        const Offset(340, 260),
      );
      expect(
        metrics[4].getTangentForOffset(0)!.position,
        const Offset(340, 260),
      );
    }
  });

  test('four block arrows have stable bounds and fixed directions', () {
    final cases = <BoardShapeType, (Offset, Offset)>{
      BoardShapeType.blockArrowRight: (
        const Offset(330, 190),
        const Offset(110, 130),
      ),
      BoardShapeType.blockArrowLeft: (
        const Offset(110, 190),
        const Offset(330, 130),
      ),
      BoardShapeType.blockArrowUp: (
        const Offset(220, 130),
        const Offset(110, 250),
      ),
      BoardShapeType.blockArrowDown: (
        const Offset(220, 250),
        const Offset(110, 130),
      ),
    };
    for (final entry in cases.entries) {
      final value = shape(entry.key);
      final definition = ShapeDefinition.forType(entry.key);
      expect(definition.supportsFill, isTrue, reason: entry.key.name);
      expect(
        definition.pathFor(value).getBounds(),
        const Rect.fromLTWH(100, 120, 240, 140),
      );
      expect(
        definition.hitTest(value, entry.value.$1, 2),
        isTrue,
        reason: '${entry.key.name} tip',
      );
      expect(
        definition.hitTest(value, entry.value.$2, 2),
        isFalse,
        reason: '${entry.key.name} outside corner',
      );
      expect(
        definition.hitTest(
          value.copyWith(fillOpacity: 0),
          const Offset(220, 190),
          2,
        ),
        isFalse,
        reason: '${entry.key.name} hollow centre',
      );
    }
  });

  test('four flowchart shapes have stable silhouettes and details', () {
    final cases = <BoardShapeType, int>{
      BoardShapeType.terminator: 0,
      BoardShapeType.document: 0,
      BoardShapeType.database: 1,
      BoardShapeType.predefinedProcess: 2,
    };
    for (final entry in cases.entries) {
      final value = shape(entry.key);
      final definition = ShapeDefinition.forType(entry.key);
      expect(definition.supportsFill, isTrue, reason: entry.key.name);
      expect(
        definition.pathFor(value).getBounds(),
        const Rect.fromLTWH(100, 120, 240, 140),
        reason: entry.key.name,
      );
      expect(
        definition.detailPathFor(value).computeMetrics(),
        hasLength(entry.value),
        reason: '${entry.key.name} detail strokes',
      );
      expect(
        definition.hitTest(value, const Offset(220, 190), 2),
        isTrue,
        reason: '${entry.key.name} filled centre',
      );
      expect(
        definition.hitTest(
          value.copyWith(fillOpacity: 0),
          const Offset(220, 190),
          2,
        ),
        isFalse,
        reason: '${entry.key.name} hollow centre',
      );
    }
  });

  test('named catalogue shapes stay inside their bounds and support fill', () {
    const types = [
      BoardShapeType.pentagon,
      BoardShapeType.octagon,
      BoardShapeType.heart,
      BoardShapeType.lightning,
      BoardShapeType.leftBracket,
      BoardShapeType.rightBracket,
      BoardShapeType.smiley,
      BoardShapeType.moon,
      BoardShapeType.cloud,
      BoardShapeType.turnBlockArrow,
      BoardShapeType.uTurnBlockArrow,
      BoardShapeType.splitBlockArrow,
      BoardShapeType.mergeBlockArrow,
      BoardShapeType.circularBlockArrow,
      BoardShapeType.star,
      BoardShapeType.banner,
      BoardShapeType.callout,
    ];
    const declared = Rect.fromLTWH(100, 120, 240, 140);
    for (final type in types) {
      final definition = ShapeDefinition.forType(type);
      final value = shape(type);
      final bounds = definition.pathFor(value).getBounds();
      expect(definition.supportsFill, isTrue, reason: type.name);
      expect(bounds.isEmpty, isFalse, reason: type.name);
      expect(
        declared.inflate(0.01).contains(bounds.topLeft),
        isTrue,
        reason: type.name,
      );
      expect(
        declared.inflate(0.01).contains(bounds.bottomRight),
        isTrue,
        reason: type.name,
      );
    }
    expect(
      ShapeDefinition.forType(
        BoardShapeType.smiley,
      ).detailPathFor(shape(BoardShapeType.smiley)).computeMetrics(),
      hasLength(3),
    );
  });

  test('curved and multi-bend lines retain endpoints and stay in bounds', () {
    for (final type in const [
      BoardShapeType.curvedLine,
      BoardShapeType.multiBendLine,
    ]) {
      final value = shape(type);
      final definition = ShapeDefinition.forType(type);
      final path = definition.pathFor(value);
      const bounds = Rect.fromLTWH(100, 120, 240, 140);
      expect(definition.supportsFill, isFalse);
      expect(definition.lineEndpoints(value), (
        const Offset(100, 120),
        const Offset(340, 260),
      ));
      expect(bounds.inflate(0.01).contains(path.getBounds().topLeft), isTrue);
      expect(
        bounds.inflate(0.01).contains(path.getBounds().bottomRight),
        isTrue,
      );
      expect(definition.hitTest(value, const Offset(100, 120), 5), isTrue);
      expect(definition.hitTest(value, const Offset(340, 260), 5), isTrue);
      expect(
        ShapeDefinition.forType(type)
            .pathFor(value.copyWith(lineReversed: true))
            .computeMetrics()
            .isNotEmpty,
        isTrue,
      );
    }
  });

  test('format 30 persists the named catalogue and format 29 rejects it', () {
    for (final type in BoardShapeType.values.where(
      (type) => type.isCatalogue30,
    )) {
      final board = BoardDocument(
        id: 'catalogue-board',
        name: 'Catalogue',
        createdAt: time,
        modifiedAt: time,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        shapes: [shape(type)],
      );
      final json = board.toJson();
      expect(json['formatVersion'], BoardDocument.currentFormatVersion);
      json['formatVersion'] = 30;
      expect(BoardDocument.fromJson(json).shapes.single.type, type);
      json['formatVersion'] = 29;
      expect(() => BoardDocument.fromJson(json), throwsFormatException);
    }
  });

  test('flowchart detail strokes participate in outline hit testing', () {
    final database = shape(BoardShapeType.database).copyWith(fillOpacity: 0);
    final databaseDefinition = ShapeDefinition.forType(database.type);
    expect(
      databaseDefinition.hitTest(database, const Offset(220, 164), 4),
      isTrue,
    );

    final predefined = shape(
      BoardShapeType.predefinedProcess,
    ).copyWith(fillOpacity: 0);
    final predefinedDefinition = ShapeDefinition.forType(predefined.type);
    expect(
      predefinedDefinition.hitTest(predefined, const Offset(136, 190), 4),
      isTrue,
    );
  });

  test('orthogonal selection exposes two endpoints and a spine target', () {
    final value = shape(BoardShapeType.elbowLine).copyWith(spinePosition: 0.25);
    expect(shapeHandlePositions(value), const [
      Offset(100, 120),
      Offset(160, 169),
      Offset(340, 260),
    ]);
    expect(shapeMoveHandlePosition(value), const Offset(220, 190));
  });

  test('format 14 migrates with no invented shapes', () {
    final timestamp = time.toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 14,
      'board': {
        'id': 'older',
        'name': 'Older',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': <Object>[],
      'scenes': <Object>[],
      'headings': <Object>[],
      'attachments': <Object>[],
      'youTubeEmbeds': <Object>[],
      'shapes': [shape(BoardShapeType.rectangle).toJson()],
    });
    expect(board.shapes, isEmpty);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
  });

  test('format 15 rejects future expanded shape vocabulary', () {
    final timestamp = time.toIso8601String();
    expect(
      () => BoardDocument.fromJson({
        'formatVersion': 15,
        'board': {
          'id': 'older',
          'name': 'Older',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
        'viewport': {'x': 0, 'y': 0, 'zoom': 1},
        'notes': <Object>[],
        'connectors': <Object>[],
        'images': <Object>[],
        'scenes': <Object>[],
        'headings': <Object>[],
        'attachments': <Object>[],
        'youTubeEmbeds': <Object>[],
        'shapes': [shape(BoardShapeType.hexagon).toJson()],
      }),
      throwsFormatException,
    );
  });

  test(
    'format 16 rejects orthogonal shapes and format 17 round-trips them',
    () {
      final timestamp = time.toIso8601String();
      final orthogonal = shape(BoardShapeType.elbowLine).copyWith(
        routeAxis: OrthogonalRouteAxis.verticalFirst,
        spinePosition: 0.7,
      );
      Map<String, Object> document(int version) => {
        'formatVersion': version,
        'board': {
          'id': 'route-board',
          'name': 'Routes',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
        'viewport': {'x': 0, 'y': 0, 'zoom': 1},
        'notes': <Object>[],
        'connectors': <Object>[],
        'images': <Object>[],
        'scenes': <Object>[],
        'headings': <Object>[],
        'attachments': <Object>[],
        'youTubeEmbeds': <Object>[],
        'shapes': [orthogonal.toJson()],
      };

      expect(() => BoardDocument.fromJson(document(16)), throwsFormatException);
      final restored = BoardDocument.fromJson(document(17)).shapes.single;
      expect(restored.type, BoardShapeType.elbowLine);
      expect(restored.routeAxis, OrthogonalRouteAxis.verticalFirst);
      expect(restored.spinePosition, 0.7);
    },
  );

  test('format 17 rejects double-ended arrows and format 18 restores them', () {
    final timestamp = time.toIso8601String();
    final doubleEnded = shape(BoardShapeType.doubleElbowArrow).copyWith(
      routeAxis: OrthogonalRouteAxis.verticalFirst,
      spinePosition: 0.65,
    );
    Map<String, Object> document(int version) => {
      'formatVersion': version,
      'board': {
        'id': 'double-arrow-board',
        'name': 'Double arrows',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': <Object>[],
      'scenes': <Object>[],
      'headings': <Object>[],
      'attachments': <Object>[],
      'youTubeEmbeds': <Object>[],
      'shapes': [doubleEnded.toJson()],
    };

    expect(() => BoardDocument.fromJson(document(17)), throwsFormatException);
    final restored = BoardDocument.fromJson(document(18)).shapes.single;
    expect(restored.type, BoardShapeType.doubleElbowArrow);
    expect(restored.routeAxis, OrthogonalRouteAxis.verticalFirst);
    expect(restored.spinePosition, 0.65);
  });

  test('format 18 rejects block arrows and format 19 restores them', () {
    final timestamp = time.toIso8601String();
    final blockArrow = shape(BoardShapeType.blockArrowUp);
    Map<String, Object> document(int version) => {
      'formatVersion': version,
      'board': {
        'id': 'block-arrow-board',
        'name': 'Block arrows',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': <Object>[],
      'scenes': <Object>[],
      'headings': <Object>[],
      'attachments': <Object>[],
      'youTubeEmbeds': <Object>[],
      'shapes': [blockArrow.toJson()],
    };

    expect(() => BoardDocument.fromJson(document(18)), throwsFormatException);
    final restored = BoardDocument.fromJson(document(19)).shapes.single;
    expect(restored.type, BoardShapeType.blockArrowUp);
    expect(restored.fillOpacity, 0.3);
  });

  test('format 26 rejects flowchart shapes and format 27 restores them', () {
    final timestamp = time.toIso8601String();
    final flowchart = shape(BoardShapeType.database);
    Map<String, Object> document(int version) => {
      'formatVersion': version,
      'board': {
        'id': 'flowchart-board',
        'name': 'Flowchart',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': <Object>[],
      'scenes': <Object>[],
      'headings': <Object>[],
      'attachments': <Object>[],
      'youTubeEmbeds': <Object>[],
      'shapes': [flowchart.toJson()],
      'shapeLayers': [
        {
          'id': 'shape-layer-1',
          'name': 'Shape layer 1',
          'shapeIds': [flowchart.id],
          'isVisible': true,
          'opacity': 1.0,
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
      'groups': <Object>[],
      'snapping': {'enabled': false},
      'lockedObjectIds': <Object>[],
    };

    expect(() => BoardDocument.fromJson(document(26)), throwsFormatException);
    final restored = BoardDocument.fromJson(document(27)).shapes.single;
    expect(restored.type, BoardShapeType.database);
    expect(restored.fillOpacity, 0.3);
  });

  test('rejects malformed shape appearance and duplicate identities', () {
    final valid = shape(BoardShapeType.ellipse);
    expect(
      () => BoardDocument(
        id: 'board',
        name: 'Board',
        createdAt: time,
        modifiedAt: time,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        shapes: [valid.copyWith(fillOpacity: 2)],
      ),
      throwsArgumentError,
    );
    expect(
      () => BoardDocument(
        id: 'board',
        name: 'Board',
        createdAt: time,
        modifiedAt: time,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        shapes: [valid, valid],
      ),
      throwsArgumentError,
    );
    expect(
      () => BoardDocument(
        id: 'board',
        name: 'Board',
        createdAt: time,
        modifiedAt: time,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        shapes: [shape(BoardShapeType.elbowLine).copyWith(spinePosition: 1.2)],
      ),
      throwsArgumentError,
    );
  });
}
