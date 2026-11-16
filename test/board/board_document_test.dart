import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/board_paper_tone.dart';
import 'package:vasmim/board/board_store.dart';
import 'package:vasmim/attachment/board_attachment.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/group/board_group.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_text_link.dart';
import 'package:vasmim/scene/scene.dart';
import 'package:vasmim/shape/board_shape.dart';

void main() {
  test('format 31 stores audio and format 30 rejects invented audio', () {
    final time = DateTime.utc(2026, 9, 24);
    final board = BoardDocument(
      id: 'audio-board',
      name: 'Memo',
      createdAt: time,
      modifiedAt: time,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      attachments: [
        BoardAttachment(
          id: 'memo',
          x: 0,
          y: 0,
          width: 300,
          height: 112,
          assetPath: 'assets/memo.mp3',
          originalFileName: 'memo.mp3',
          kind: AttachmentKind.audio,
          byteSize: 7,
          createdAt: time,
          modifiedAt: time,
        ),
      ],
    );
    final json = board.toJson();
    expect(json['formatVersion'], 31);
    expect(
      BoardDocument.fromJson(json).attachments.single.kind,
      AttachmentKind.audio,
    );
    expect(
      () => BoardDocument.fromJson({...json, 'formatVersion': 30}),
      throwsFormatException,
    );
  });

  test('round-trips versioned board data through JSON values', () {
    final createdAt = DateTime.utc(2026, 8, 6, 10);
    final modifiedAt = createdAt.add(const Duration(minutes: 5));
    final board = BoardDocument(
      id: 'board-1',
      name: 'Prototype Board',
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      viewportX: 120,
      viewportY: 80,
      viewportZoom: 0.75,
      notes: [
        Note(
          id: 'note-1',
          x: 300,
          y: 200,
          width: 260,
          height: 170,
          text: 'Saved note',
          title: 'Release plan',
          emphasis: const [
            NoteEmphasisRange(start: 0, end: 5, bold: true, italic: true),
          ],
          links: const [
            NoteTextLinkRange(
              start: 6,
              end: 10,
              destination: 'https://example.com/source',
            ),
          ],
          createdAt: createdAt,
          modifiedAt: modifiedAt,
          color: NoteColor.blue,
        ),
        Note(
          id: 'note-2',
          x: 700,
          y: 500,
          width: 260,
          height: 170,
          text: 'Connected note',
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      connectors: [
        Connector(
          id: 'connector-1',
          objectAId: 'note-1',
          objectBId: 'image-1',
          label: 'supports',
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      images: [
        BoardImage(
          id: 'image-1',
          x: 1100,
          y: 300,
          width: 320,
          height: 180,
          assetPath: 'assets/image-1.png',
          originalFileName: 'reference.png',
          caption: 'Enemy silhouette reference',
          pixelWidth: 1920,
          pixelHeight: 1080,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      scenes: [
        Scene(
          id: '123e4567-e89b-42d3-a456-426614174000',
          name: 'References',
          x: 900,
          y: 350,
          zoom: 1.25,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      headings: [
        CanvasHeading(
          id: 'heading-1',
          x: 120,
          y: 900,
          text: 'References',
          size: CanvasHeadingSize.extraLarge,
          background: CanvasHeadingBackground.transparent,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      shapes: [
        BoardShape(
          id: 'shape-1',
          type: BoardShapeType.roundedRectangle,
          x: 80,
          y: 820,
          width: 900,
          height: 420,
          lineStartsAtTopLeft: true,
          lineReversed: false,
          fillColorValue: 0xFF90CAF9,
          fillOpacity: 0.25,
          outlineColorValue: 0xFF37474F,
          outlineWidth: 2,
          heading: const ShapeHeading(text: 'Reference area'),
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      groups: [
        BoardGroup(
          id: 'group-1',
          memberIds: const ['note-1', 'image-1', 'shape-1'],
          isVisible: false,
          createdAt: createdAt,
          modifiedAt: modifiedAt,
        ),
      ],
      isSnappingEnabled: false,
    );

    final json = board.toJson();
    final restored = BoardDocument.fromJson(json);

    expect(json['formatVersion'], BoardDocument.currentFormatVersion);
    expect(restored.id, board.id);
    expect(restored.name, board.name);
    expect(restored.viewportX, board.viewportX);
    expect(restored.viewportY, board.viewportY);
    expect(restored.viewportZoom, board.viewportZoom);
    expect(
      restored.notes.map((note) => note.toJson()),
      board.notes.map((note) => note.toJson()),
    );
    expect(restored.notes.first.title, 'Release plan');
    expect(restored.notes.first.emphasis, board.notes.first.emphasis);
    expect(restored.notes.first.links, board.notes.first.links);
    expect(
      restored.connectors.single.toJson(),
      board.connectors.single.toJson(),
    );
    expect(restored.images.single.toJson(), board.images.single.toJson());
    expect(restored.images.single.caption, 'Enemy silhouette reference');
    expect(restored.scenes.single.toJson(), board.scenes.single.toJson());
    expect(restored.headings.single.toJson(), board.headings.single.toJson());
    expect(restored.shapes.single.toJson(), board.shapes.single.toJson());
    expect(restored.groups.single.toJson(), board.groups.single.toJson());
    expect(restored.isSnappingEnabled, isFalse);
    expect((json['snapping'] as Map<String, Object>)['enabled'], isFalse);
  });

  test('migrates format 24 with snapping disabled', () {
    final now = DateTime.utc(2026, 9, 16);
    final json =
        BoardDocument(
            id: 'format-24-board',
            name: 'Older board',
            createdAt: now,
            modifiedAt: now,
            viewportX: 0,
            viewportY: 0,
            viewportZoom: 1,
            notes: const [],
          ).toJson()
          ..['formatVersion'] = 24
          ..remove('snapping');

    final migrated = BoardDocument.fromJson(json);

    expect(migrated.isSnappingEnabled, isFalse);
    expect(
      migrated.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test('migrates format 11 with an empty heading collection', () {
    final timestamp = DateTime.utc(2026, 9, 8).toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 11,
      'board': {
        'id': 'format-11-board',
        'name': 'Older board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': <Object>[],
      'scenes': <Object>[],
      'headings': [
        {
          'id': 'future-heading',
          'x': 20,
          'y': 40,
          'text': 'Ignored future field',
          'size': 'large',
          'background': 'transparent',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
    });

    expect(board.headings, isEmpty);
    expect(board.attachments, isEmpty);
    expect(board.youTubeEmbeds, isEmpty);
    expect(board.shapes, isEmpty);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
    expect(board.toJson()['headings'], isEmpty);
    expect(board.toJson()['attachments'], isEmpty);
  });

  test('migrates version 1 without losing notes or viewport state', () {
    final timestamp = DateTime.utc(2026, 8, 6).toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 1,
      'board': {
        'id': 'prototype-0.1-board',
        'name': 'Older board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': [
        {
          'id': 'older-note',
          'x': 10,
          'y': 20,
          'width': 260,
          'height': 170,
          'text': 'Still opens',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
    });

    expect(board.notes.single.color, NoteColor.yellow);
    expect(board.viewportX, 0);
    expect(board.viewportY, 0);
    expect(board.viewportZoom, 1);
    expect(board.connectors, isEmpty);
    expect(board.images, isEmpty);
    expect(board.scenes, isEmpty);
    expect(board.notes.single.title, isNull);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
  });

  test('migrates format 9 images without inventing a caption', () {
    final timestamp = DateTime.utc(2026, 9, 6).toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 9,
      'board': {
        'id': 'format-9-image-board',
        'name': 'Older image board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': [
        {
          'id': 'older-image',
          'x': 20,
          'y': 40,
          'width': 320,
          'height': 180,
          'assetPath': 'assets/older-image.png',
          'originalFileName': 'older-image.png',
          'caption': 'Ignored future field',
          'pixelWidth': 1600,
          'pixelHeight': 900,
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
      'scenes': <Object>[],
    });

    expect(board.images.single.caption, isNull);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
    expect(board.toJson()['images'], [containsPair('id', 'older-image')]);
    expect(
      (board.toJson()['images'] as List).single,
      isNot(contains('caption')),
    );
  });

  test('migrates format 10 Notes without accepting future italic data', () {
    final timestamp = DateTime.utc(2026, 9, 7).toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 10,
      'board': {
        'id': 'format-10-note-board',
        'name': 'Older note board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': [
        {
          'id': 'older-note',
          'x': 20,
          'y': 40,
          'width': 260,
          'height': 170,
          'text': 'Italic stays future data',
          'emphasis': [
            {'start': 0, 'end': 6, 'italic': true},
          ],
          'createdAt': timestamp,
          'modifiedAt': timestamp,
          'color': 'yellow',
        },
      ],
      'connectors': <Object>[],
      'images': <Object>[],
      'scenes': <Object>[],
    });

    expect(board.notes.single.emphasis, isEmpty);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
  });

  test('rejects non-canonical format 10 image captions', () {
    final timestamp = DateTime.utc(2026, 9, 6).toIso8601String();
    final json = {
      'formatVersion': 10,
      'board': {
        'id': 'invalid-caption-board',
        'name': 'Invalid caption board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 0, 'y': 0, 'zoom': 1},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': [
        {
          'id': 'invalid-caption-image',
          'x': 20,
          'y': 40,
          'width': 320,
          'height': 180,
          'assetPath': 'assets/invalid-caption-image.png',
          'originalFileName': 'invalid-caption-image.png',
          'caption': ' not trimmed ',
          'pixelWidth': 1600,
          'pixelHeight': 900,
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
      'scenes': <Object>[],
    };

    expect(() => BoardDocument.fromJson(json), throwsFormatException);
  });

  test('migrates version 2 connectors with an empty image collection', () {
    final timestamp = DateTime.utc(2026, 8, 12).toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 2,
      'board': {
        'id': 'prototype-0.3-board',
        'name': 'Connected older board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 40, 'y': 60, 'zoom': 0.8},
      'notes': [
        {
          'id': 'note-a',
          'x': 10,
          'y': 20,
          'width': 260,
          'height': 170,
          'text': 'A',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
        {
          'id': 'note-b',
          'x': 400,
          'y': 20,
          'width': 260,
          'height': 170,
          'text': 'B',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
      'connectors': [
        {
          'id': 'connector-a-b',
          'noteAId': 'note-a',
          'noteBId': 'note-b',
          'createdAt': timestamp,
          'modifiedAt': timestamp,
        },
      ],
    });

    expect(board.connectors.single.id, 'connector-a-b');
    expect(board.connectors.single.objectAId, 'note-a');
    expect(board.connectors.single.objectBId, 'note-b');
    expect(board.images, isEmpty);
    expect(board.scenes, isEmpty);
    expect(board.viewportX, 40);
    expect(board.viewportY, 60);
    expect(board.viewportZoom, 0.8);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
  });

  test('migrates version 3 images with an empty scene collection', () {
    final timestamp = DateTime.utc(2026, 8, 12).toIso8601String();
    final board = BoardDocument.fromJson({
      'formatVersion': 3,
      'board': {
        'id': 'prototype-0.4-board',
        'name': 'Mixed-media board',
        'createdAt': timestamp,
        'modifiedAt': timestamp,
      },
      'viewport': {'x': 15, 'y': 25, 'zoom': 1.2},
      'notes': <Object>[],
      'connectors': <Object>[],
      'images': <Object>[],
    });

    expect(board.scenes, isEmpty);
    expect(board.viewportX, 15);
    expect(board.viewportY, 25);
    expect(board.viewportZoom, 1.2);
    expect(board.toJson()['formatVersion'], BoardDocument.currentFormatVersion);
  });

  test('migrates version 4 note endpoints without changing identities', () {
    final timestamp = DateTime.utc(2026, 8, 19);
    final board = BoardDocument(
      id: 'prototype-0.10-board',
      name: 'Version 4 board',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        for (final id in ['note-a', 'note-b'])
          Note(
            id: id,
            x: id == 'note-a' ? 0 : 300,
            y: 0,
            width: 260,
            height: 170,
            text: id,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
      ],
      connectors: [
        Connector(
          id: 'connector-a-b',
          objectAId: 'note-a',
          objectBId: 'note-b',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );
    final json = board.toJson();
    json['formatVersion'] = 4;
    final connectorJson = (json['connectors']! as List).single as Map;
    connectorJson['noteAId'] = connectorJson.remove('objectAId');
    connectorJson['noteBId'] = connectorJson.remove('objectBId');

    final migrated = BoardDocument.fromJson(json);

    expect(migrated.connectors.single.id, 'connector-a-b');
    expect(migrated.connectors.single.objectAId, 'note-a');
    expect(migrated.connectors.single.objectBId, 'note-b');
    expect(migrated.connectors.single.label, isNull);
    expect(
      migrated.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test(
    'migrates version 5 connectors as unlabeled without identity changes',
    () {
      final timestamp = DateTime.utc(2026, 8, 25);
      final board = BoardDocument(
        id: 'prototype-0.21-board',
        name: 'Version 5 board',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: [
          for (final (id, x) in [('note-a', 0.0), ('note-b', 300.0)])
            Note(
              id: id,
              x: x,
              y: 0,
              width: 260,
              height: 170,
              text: id,
              createdAt: timestamp,
              modifiedAt: timestamp,
            ),
        ],
        connectors: [
          Connector(
            id: 'connector-a-b',
            objectAId: 'note-a',
            objectBId: 'note-b',
            label: 'would not have existed',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
      );
      final json = board.toJson();
      json['formatVersion'] = 5;
      final connectorJson = (json['connectors']! as List).single as Map;
      connectorJson.remove('label');

      final migrated = BoardDocument.fromJson(json);

      expect(migrated.connectors.single.id, 'connector-a-b');
      expect(migrated.connectors.single.objectAId, 'note-a');
      expect(migrated.connectors.single.objectBId, 'note-b');
      expect(migrated.connectors.single.label, isNull);
      expect(
        migrated.toJson()['formatVersion'],
        BoardDocument.currentFormatVersion,
      );
    },
  );

  test('migrates version 6 Notes without accepting future title data', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    final board = BoardDocument(
      id: 'version-6-board',
      name: 'Version 6 board',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'note-a',
          x: 0,
          y: 0,
          width: 260,
          height: 170,
          text: 'Body',
          title: 'Future field',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );
    final json = board.toJson()..['formatVersion'] = 6;

    final migrated = BoardDocument.fromJson(json);

    expect(migrated.notes.single.title, isNull);
    expect(
      migrated.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test('rejects invalid optional Note titles', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    BoardDocument boardWithTitle(String title) => BoardDocument(
      id: 'title-validation-board',
      name: 'Title validation',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'note-a',
          x: 0,
          y: 0,
          width: 260,
          height: 170,
          text: 'Body',
          title: title,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );

    expect(() => boardWithTitle(' untrimmed '), throwsArgumentError);
    expect(() => boardWithTitle('line one\nline two'), throwsArgumentError);
    expect(
      () => boardWithTitle(List.filled(81, 'a').join()),
      throwsArgumentError,
    );
  });

  test('migrates version 7 Notes without accepting future emphasis data', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    final board = BoardDocument(
      id: 'version-7-board',
      name: 'Version 7 board',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'note-a',
          x: 0,
          y: 0,
          width: 260,
          height: 170,
          text: 'Bold body',
          title: 'Retained title',
          emphasis: const [NoteEmphasisRange(start: 0, end: 4, bold: true)],
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );
    final json = board.toJson()..['formatVersion'] = 7;

    final migrated = BoardDocument.fromJson(json);

    expect(migrated.notes.single.title, 'Retained title');
    expect(migrated.notes.single.emphasis, isEmpty);
    expect(
      migrated.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test('rejects invalid or non-canonical Note emphasis ranges', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    BoardDocument boardWith(List<NoteEmphasisRange> emphasis) => BoardDocument(
      id: 'emphasis-validation-board',
      name: 'Emphasis validation',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'note-a',
          x: 0,
          y: 0,
          width: 260,
          height: 170,
          text: 'Body text',
          emphasis: emphasis,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );

    expect(
      () => boardWith(const [
        NoteEmphasisRange(start: 0, end: 5, bold: true),
        NoteEmphasisRange(start: 4, end: 8, underline: true),
      ]),
      throwsArgumentError,
    );
    expect(
      () => boardWith(const [NoteEmphasisRange(start: 0, end: 99, bold: true)]),
      throwsArgumentError,
    );
    final json = boardWith(const [
      NoteEmphasisRange(start: 0, end: 4, bold: true),
    ]).toJson();
    final rangeJson =
        (((json['notes']! as List).single as Map)['emphasis'] as List).single
            as Map;
    rangeJson['end'] = 99;
    expect(() => BoardDocument.fromJson(json), throwsFormatException);
  });

  test('migrates version 8 Notes without accepting future text links', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    final board = BoardDocument(
      id: 'version-8-board',
      name: 'Version 8 board',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'note-a',
          x: 0,
          y: 0,
          width: 260,
          height: 170,
          text: 'Linked body',
          emphasis: const [NoteEmphasisRange(start: 0, end: 6, bold: true)],
          links: const [
            NoteTextLinkRange(
              start: 0,
              end: 6,
              destination: 'https://example.com',
            ),
          ],
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );
    final json = board.toJson()..['formatVersion'] = 8;

    final migrated = BoardDocument.fromJson(json);

    expect(migrated.notes.single.emphasis, board.notes.single.emphasis);
    expect(migrated.notes.single.links, isEmpty);
    expect(
      migrated.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test('rejects invalid or non-canonical Note text-link ranges', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    BoardDocument boardWith(List<NoteTextLinkRange> links) => BoardDocument(
      id: 'link-validation-board',
      name: 'Link validation',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        Note(
          id: 'note-a',
          x: 0,
          y: 0,
          width: 260,
          height: 170,
          text: 'Body text',
          links: links,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );

    expect(
      () => boardWith(const [
        NoteTextLinkRange(start: 0, end: 5, destination: 'https://a.test'),
        NoteTextLinkRange(start: 4, end: 8, destination: 'https://b.test'),
      ]),
      throwsArgumentError,
    );
    expect(
      () => boardWith(const [
        NoteTextLinkRange(start: 0, end: 99, destination: 'https://a.test'),
      ]),
      throwsArgumentError,
    );
    expect(
      () => boardWith(const [
        NoteTextLinkRange(start: 0, end: 4, destination: 'not-a-url'),
      ]),
      throwsArgumentError,
    );
    final json = boardWith(const [
      NoteTextLinkRange(start: 0, end: 4, destination: 'https://a.test'),
    ]).toJson();
    final rangeJson =
        (((json['notes']! as List).single as Map)['links'] as List).single
            as Map;
    rangeJson['end'] = 99;
    expect(() => BoardDocument.fromJson(json), throwsFormatException);
  });

  group('scene invariants', () {
    final timestamp = DateTime.utc(2026, 8, 13);

    Scene scene({
      String id = '123e4567-e89b-42d3-a456-426614174000',
      String name = 'Plan',
      double x = 100,
      double y = 200,
      double zoom = 1,
    }) => Scene(
      id: id,
      name: name,
      x: x,
      y: y,
      zoom: zoom,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    BoardDocument boardWith(List<Scene> scenes) => BoardDocument(
      id: 'scene-board',
      name: 'Scene invariants',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      scenes: scenes,
    );

    test('preserves scene order and protects the collection', () {
      final mutableScenes = [
        scene(name: 'First'),
        scene(id: '123e4567-e89b-42d3-b456-426614174001', name: 'Second'),
      ];
      final board = boardWith(mutableScenes);
      mutableScenes.clear();

      expect(board.scenes.map((scene) => scene.name), ['First', 'Second']);
      expect(() => board.scenes.clear(), throwsUnsupportedError);
    });

    test('rejects invalid or duplicate scene identities', () {
      expect(() => boardWith([scene(id: 'not-a-uuid')]), throwsArgumentError);
      expect(() => boardWith([scene(), scene()]), throwsArgumentError);
    });

    test('rejects empty names, non-finite coordinates, and invalid zoom', () {
      expect(() => boardWith([scene(name: '  ')]), throwsArgumentError);
      expect(() => boardWith([scene(x: double.nan)]), throwsArgumentError);
      expect(() => boardWith([scene(y: double.infinity)]), throwsArgumentError);
      expect(() => boardWith([scene(zoom: 0.09)]), throwsArgumentError);
      expect(() => boardWith([scene(zoom: 4.01)]), throwsArgumentError);
    });

    test('rejects invalid scene data loaded from JSON', () {
      final json = boardWith([scene()]).toJson();
      final sceneJson = (json['scenes']! as List).single as Map;
      sceneJson['name'] = ' ';

      expect(() => BoardDocument.fromJson(json), throwsFormatException);
    });
  });

  group('image invariants', () {
    final timestamp = DateTime.utc(2026, 8, 12);

    BoardImage image({
      String id = 'image-1',
      double width = 320,
      String assetPath = 'assets/image-1.png',
      int pixelWidth = 1920,
    }) {
      return BoardImage(
        id: id,
        x: 100,
        y: 200,
        width: width,
        height: 180,
        assetPath: assetPath,
        originalFileName: 'reference.png',
        pixelWidth: pixelWidth,
        pixelHeight: 1080,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
    }

    BoardDocument boardWith(List<BoardImage> images) {
      return BoardDocument(
        id: 'image-board',
        name: 'Image invariants',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        images: images,
      );
    }

    test('accepts a valid managed image reference', () {
      expect(boardWith([image()]).images, hasLength(1));
    });

    test('rejects duplicate image identifiers', () {
      expect(() => boardWith([image(), image()]), throwsArgumentError);
    });

    test('rejects non-positive displayed or pixel dimensions', () {
      expect(() => boardWith([image(width: 0)]), throwsArgumentError);
      expect(() => boardWith([image(pixelWidth: 0)]), throwsArgumentError);
    });

    test('rejects absolute and traversing managed asset paths', () {
      expect(
        () => boardWith([image(assetPath: r'C:\source\image.png')]),
        throwsArgumentError,
      );
      expect(
        () => boardWith([image(assetPath: '../outside.png')]),
        throwsArgumentError,
      );
    });

    test('rejects invalid image data loaded from JSON', () {
      final json = boardWith([image()]).toJson();
      final imageJson = (json['images']! as List).single as Map;
      imageJson['assetPath'] = '../outside.png';

      expect(() => BoardDocument.fromJson(json), throwsFormatException);
    });

    test('protects validated image collections from later mutation', () {
      final mutableImages = [image()];
      final board = boardWith(mutableImages);

      mutableImages.clear();

      expect(board.images, hasLength(1));
      expect(() => board.images.clear(), throwsUnsupportedError);
    });
  });

  group('connector invariants', () {
    final timestamp = DateTime.utc(2026, 8, 12);
    final notes = [
      Note(
        id: 'note-a',
        x: 0,
        y: 0,
        width: 260,
        height: 170,
        text: 'A',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
      Note(
        id: 'note-b',
        x: 300,
        y: 0,
        width: 260,
        height: 170,
        text: 'B',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ];
    final images = [
      for (final (id, x) in [('image-a', 600.0), ('image-b', 900.0)])
        BoardImage(
          id: id,
          x: x,
          y: 0,
          width: 240,
          height: 180,
          assetPath: 'assets/$id.png',
          originalFileName: '$id.png',
          pixelWidth: 800,
          pixelHeight: 600,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
    ];

    BoardDocument boardWith(List<Connector> connectors) {
      return BoardDocument(
        id: 'connector-board',
        name: 'Connector invariants',
        createdAt: timestamp,
        modifiedAt: timestamp,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: notes,
        connectors: connectors,
        images: images,
      );
    }

    Connector connector({
      String id = 'connector-1',
      String objectAId = 'note-a',
      String objectBId = 'note-b',
      String? label,
    }) {
      return Connector(
        id: id,
        objectAId: objectAId,
        objectBId: objectBId,
        label: label,
        createdAt: timestamp,
        modifiedAt: timestamp,
      );
    }

    test('accepts one valid connector between existing notes', () {
      expect(boardWith([connector()]).connectors, hasLength(1));
    });

    test('accepts note-image and image-image connectors', () {
      expect(
        boardWith([
          connector(objectBId: 'image-a'),
          connector(
            id: 'connector-images',
            objectAId: 'image-a',
            objectBId: 'image-b',
          ),
        ]).connectors,
        hasLength(2),
      );
    });

    test('accepts a trimmed optional connection label', () {
      final board = boardWith([connector(label: 'supports')]);

      expect(board.connectors.single.label, 'supports');
      expect(
        (board.toJson()['connectors'] as List).single,
        containsPair('label', 'supports'),
      );
    });

    test('counts user-perceived Unicode characters in the label limit', () {
      final family = '👨‍👩‍👧‍👦';
      final label = List.filled(80, family).join();

      expect(
        boardWith([connector(label: label)]).connectors.single.label,
        label,
      );
      expect(
        () => boardWith([connector(label: '$label$family')]),
        throwsArgumentError,
      );
    });

    test('rejects empty, untrimmed, multiline, and overlong labels', () {
      expect(() => boardWith([connector(label: '')]), throwsArgumentError);
      expect(
        () => boardWith([connector(label: ' supports ')]),
        throwsArgumentError,
      );
      expect(
        () => boardWith([connector(label: 'supports\nidea')]),
        throwsArgumentError,
      );
      expect(
        () => boardWith([connector(label: List.filled(81, 'a').join())]),
        throwsArgumentError,
      );
    });

    test('rejects a self-linked connector', () {
      expect(
        () => boardWith([connector(objectBId: 'note-a')]),
        throwsArgumentError,
      );
    });

    test('rejects an orphaned connector endpoint', () {
      expect(
        () => boardWith([connector(objectBId: 'missing-object')]),
        throwsArgumentError,
      );
    });

    test('rejects duplicate undirected object pairs', () {
      expect(
        () => boardWith([
          connector(),
          connector(
            id: 'connector-2',
            objectAId: 'note-b',
            objectBId: 'note-a',
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects invalid connector data loaded from JSON', () {
      final json = boardWith([connector()]).toJson();
      final connectorJson = (json['connectors']! as List).single as Map;
      connectorJson['objectBId'] = 'note-a';

      expect(() => BoardDocument.fromJson(json), throwsFormatException);
    });

    test('protects validated collections from later mutation', () {
      final mutableConnectors = [connector()];
      final board = boardWith(mutableConnectors);

      mutableConnectors.clear();

      expect(board.connectors, hasLength(1));
      expect(() => board.connectors.clear(), throwsUnsupportedError);
    });
  });

  test('rejects unsupported board format versions', () {
    expect(
      () => BoardDocument.fromJson({'formatVersion': 99}),
      throwsFormatException,
    );
  });

  group('group invariants', () {
    final now = DateTime.utc(2026, 9, 14);

    BoardDocument boardWith(List<BoardGroup> groups) => BoardDocument(
      id: 'group-board',
      name: 'Groups',
      createdAt: now,
      modifiedAt: now,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [
        for (final id in ['note-a', 'note-b', 'note-c'])
          Note(
            id: id,
            x: 10,
            y: 10,
            width: 260,
            height: 170,
            text: id,
            createdAt: now,
            modifiedAt: now,
          ),
      ],
      groups: groups,
    );

    BoardGroup selectionSet(String id, List<String> members) => BoardGroup(
      id: id,
      memberIds: members,
      isVisible: true,
      createdAt: now,
      modifiedAt: now,
    );

    test('migrates format 22 without inventing groups', () {
      final json = boardWith(const []).toJson()..['formatVersion'] = 22;
      json.remove('groups');

      expect(BoardDocument.fromJson(json).groups, isEmpty);
    });

    test('migrates format 23 groups without inventing names', () {
      final json = boardWith([
        selectionSet('group-a', ['note-a', 'note-b']),
      ]).toJson()..['formatVersion'] = 23;
      ((json['groups'] as List).single as Map)['name'] = 'Ignored old field';

      final migrated = BoardDocument.fromJson(json);

      expect(migrated.groups.single.name, isNull);
      expect(
        migrated.toJson()['formatVersion'],
        BoardDocument.currentFormatVersion,
      );
    });

    test('round-trips canonical group names and rejects malformed names', () {
      final named = boardWith([
        BoardGroup(
          id: 'group-a',
          memberIds: const ['note-a', 'note-b'],
          isVisible: true,
          name: 'Quest outline',
          createdAt: now,
          modifiedAt: now,
        ),
      ]);

      expect(
        BoardDocument.fromJson(named.toJson()).groups.single.name,
        'Quest outline',
      );
      for (final invalid in ['', ' padded ', List.filled(81, 'x').join()]) {
        expect(
          () => boardWith([
            BoardGroup(
              id: 'group-a',
              memberIds: const ['note-a', 'note-b'],
              isVisible: true,
              name: invalid,
              createdAt: now,
              modifiedAt: now,
            ),
          ]),
          throwsArgumentError,
        );
      }
    });

    test('accepts a hidden group and protects its members', () {
      final members = ['note-a', 'note-b'];
      final board = boardWith([
        BoardGroup(
          id: 'group-a',
          memberIds: members,
          isVisible: false,
          createdAt: now,
          modifiedAt: now,
        ),
      ]);
      members.clear();

      expect(board.groups.single.memberIds, ['note-a', 'note-b']);
      expect(
        () => board.groups.single.memberIds.add('note-c'),
        throwsUnsupportedError,
      );
    });

    test('rejects too few, missing, duplicate, and shared members', () {
      expect(
        () => boardWith([
          selectionSet('group-a', ['note-a']),
        ]),
        throwsArgumentError,
      );
      expect(
        () => boardWith([
          selectionSet('group-a', ['note-a', 'missing']),
        ]),
        throwsArgumentError,
      );
      expect(
        () => boardWith([
          selectionSet('group-a', ['note-a', 'note-a']),
        ]),
        throwsArgumentError,
      );
      expect(
        () => boardWith([
          selectionSet('group-a', ['note-a', 'note-b']),
          selectionSet('group-b', ['note-b', 'note-c']),
        ]),
        throwsArgumentError,
      );
    });

    test('rejects duplicate group IDs and malformed JSON', () {
      expect(
        () => boardWith([
          selectionSet('group-a', ['note-a', 'note-b']),
          selectionSet('group-a', ['note-c', 'note-b']),
        ]),
        throwsArgumentError,
      );
      final json = boardWith([
        selectionSet('group-a', ['note-a', 'note-b']),
      ]).toJson();
      ((json['groups'] as List).single as Map)['memberIds'] = ['note-a'];
      expect(() => BoardDocument.fromJson(json), throwsFormatException);
    });
  });

  group('foreground position locks', () {
    final timestamp = DateTime.utc(2026, 9, 18);
    Note note(String id) => Note(
      id: id,
      x: 100,
      y: 120,
      width: 280,
      height: 180,
      text: 'Locked layout',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    BoardDocument board({Iterable<String> lockedObjectIds = const []}) =>
        BoardDocument(
          id: 'position-lock-board',
          name: 'Position lock',
          createdAt: timestamp,
          modifiedAt: timestamp,
          viewportX: 0,
          viewportY: 0,
          viewportZoom: 1,
          notes: [note('note-a')],
          lockedObjectIds: lockedObjectIds,
        );

    test('round trips current format and migrates format 25 unlocked', () {
      final locked = board(lockedObjectIds: const ['note-a']);
      final json = locked.toJson();

      expect(json['formatVersion'], BoardDocument.currentFormatVersion);
      expect(BoardDocument.fromJson(json).lockedObjectIds, ['note-a']);

      json
        ..['formatVersion'] = 25
        ..remove('lockedObjectIds');
      expect(BoardDocument.fromJson(json).lockedObjectIds, isEmpty);
    });

    test('rejects missing and ineligible locked identifiers', () {
      expect(
        () => board(lockedObjectIds: const ['missing']),
        throwsArgumentError,
      );
      expect(
        () => board(lockedObjectIds: const ['note-a', 'note-a']),
        throwsArgumentError,
      );
      final malformed = board(lockedObjectIds: const ['note-a']).toJson();
      malformed['lockedObjectIds'] = ['missing'];
      expect(() => BoardDocument.fromJson(malformed), throwsFormatException);
    });
  });
  group('format 28 Shape group membership', () {
    final timestamp = DateTime.utc(2026, 9, 21, 12);
    final note = Note(
      id: 'note-member',
      x: 100,
      y: 120,
      width: 240,
      height: 160,
      text: 'Foreground member',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );
    final shape = BoardShape(
      id: 'shape-member',
      type: BoardShapeType.database,
      x: 420,
      y: 180,
      width: 220,
      height: 140,
      fillColorValue: 0xFF90CAF9,
      fillOpacity: 0.5,
      outlineColorValue: 0xFF37474F,
      outlineWidth: 2,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    BoardDocument mixedBoard() => BoardDocument(
      id: 'mixed-group-board',
      name: 'Mixed group',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: [note],
      shapes: [shape],
      groups: [
        BoardGroup(
          id: 'mixed-group',
          memberIds: const ['note-member', 'shape-member'],
          isVisible: true,
          name: 'Quest system',
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
    );

    test('round trips mixed foreground and Shape members', () {
      final json = mixedBoard().toJson();

      expect(json['formatVersion'], BoardDocument.currentFormatVersion);
      expect(BoardDocument.fromJson(json).groups.single.memberIds, [
        'note-member',
        'shape-member',
      ]);
    });

    test('rejects a format 27 claim containing Shape membership', () {
      final json = mixedBoard().toJson()..['formatVersion'] = 27;

      expect(() => BoardDocument.fromJson(json), throwsFormatException);
    });
  });
  test('paper tone round trips and older formats migrate to Default', () {
    final now = DateTime.utc(2026, 9, 23);
    final board = BoardDocument(
      id: 'tone-board',
      name: 'Tone',
      createdAt: now,
      modifiedAt: now,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      paperTone: BoardPaperTone.warm,
    );
    final json = board.toJson();

    expect(json['formatVersion'], BoardDocument.currentFormatVersion);
    expect(json['paperTone'], 'warm');
    expect(BoardDocument.fromJson(json).paperTone, BoardPaperTone.warm);
    expect(board.copyWith(name: 'Copy').paperTone, BoardPaperTone.warm);

    final oldJson = Map<String, dynamic>.from(json)
      ..['formatVersion'] = 28
      ..remove('paperTone');
    expect(
      BoardDocument.fromJson(oldJson).paperTone,
      BoardPaperTone.defaultTone,
    );
    expect(
      () => BoardDocument.fromJson({...json, 'paperTone': 'purple'}),
      throwsFormatException,
    );
    expect(
      () => BoardDocument.fromJson({...json, 'paperTone': null}),
      throwsFormatException,
    );
  });
  test('file store writes and reloads a board document', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vasmim_board_store_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final store = FileBoardStore(directoryProvider: () async => directory);
    final now = DateTime.utc(2026, 8, 6);
    final board = BoardDocument(
      id: 'board-file-test',
      name: 'File Test',
      createdAt: now,
      modifiedAt: now,
      viewportX: 40,
      viewportY: 60,
      viewportZoom: 0.8,
      notes: const [],
    );

    await store.save(board);
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.id, board.id);
    expect(restored.viewportZoom, board.viewportZoom);
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}board.json',
      ).exists(),
      isTrue,
    );
  });
}
