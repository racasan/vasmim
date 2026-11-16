import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/cross_board_clipboard.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/group/board_group.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/note/note.dart';

import '../image/animated_gif_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final timestamp = DateTime.utc(2026, 9, 21, 19);
  final note = Note(
    id: 'note-a',
    x: 10,
    y: 20,
    width: 260,
    height: 170,
    text: 'Portable thought',
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
  final heading = CanvasHeading(
    id: 'heading-a',
    x: 30,
    y: 40,
    text: 'Portable section',
    size: CanvasHeadingSize.medium,
    background: CanvasHeadingBackground.blue,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  test('publishes replaces and clears one immutable payload', () {
    final clipboard = CrossBoardClipboard();
    final notes = [note];
    final payload = CrossBoardClipboardPayload(
      sourceBoardId: 'board-a',
      notes: notes,
      connectors: const [],
      headings: [heading],
      groups: [
        BoardGroup(
          id: 'group-a',
          memberIds: const ['note-a', 'heading-a'],
          isVisible: true,
          createdAt: timestamp,
          modifiedAt: timestamp,
        ),
      ],
      lockedObjectIds: const {'note-a'},
    );

    clipboard.publish(payload);
    notes.clear();

    expect(clipboard.hasPayload, isTrue);
    expect(clipboard.payload, same(payload));
    expect(payload.notes, [note]);
    expect(() => payload.notes.clear(), throwsUnsupportedError);
    expect(() => payload.lockedObjectIds.clear(), throwsUnsupportedError);

    final staleRevision = clipboard.revision;
    clipboard.clear();
    expect(
      clipboard.publishIfUnchanged(payload, revision: staleRevision),
      isFalse,
    );
    expect(clipboard.hasPayload, isFalse);

    clipboard.publish(payload);
    clipboard.clear();
    expect(clipboard.hasPayload, isFalse);
    expect(clipboard.payload, isNull);
  });

  test('rejects orphaned Connector Group and lock references', () {
    expect(
      () => CrossBoardClipboardPayload(
        sourceBoardId: 'board-a',
        notes: [note],
        connectors: [
          Connector(
            id: 'connector-a',
            objectAId: 'note-a',
            objectBId: 'missing-note',
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        headings: const [],
        groups: const [],
        lockedObjectIds: const {},
      ),
      throwsArgumentError,
    );
    expect(
      () => CrossBoardClipboardPayload(
        sourceBoardId: 'board-a',
        notes: [note],
        connectors: const [],
        headings: const [],
        groups: [
          BoardGroup(
            id: 'group-a',
            memberIds: const ['note-a', 'missing-heading'],
            isVisible: true,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
        ],
        lockedObjectIds: const {},
      ),
      throwsArgumentError,
    );
    expect(
      () => CrossBoardClipboardPayload(
        sourceBoardId: 'board-a',
        notes: [note],
        connectors: const [],
        headings: const [],
        groups: const [],
        lockedObjectIds: const {'missing-note'},
      ),
      throwsArgumentError,
    );
  });

  test('captures one defensive validated Image snapshot', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vasmim-cross-board-image-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}source.png');
    await file.writeAsBytes(_onePixelPng, flush: true);
    final image = BoardImage(
      id: 'image-a',
      x: 10,
      y: 20,
      width: 200,
      height: 120,
      assetPath: 'assets/source.png',
      originalFileName: 'Source image.png',
      pixelWidth: 1,
      pixelHeight: 1,
      caption: 'Reference',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final snapshot = await CrossBoardImageSnapshot.capture(
      image: image,
      sourceFile: file,
    );
    final firstRead = snapshot.bytes;
    firstRead[0] = 0;
    expect(snapshot.bytes, orderedEquals(_onePixelPng));

    final payload = CrossBoardClipboardPayload(
      sourceBoardId: 'board-a',
      notes: const [],
      connectors: const [],
      headings: const [],
      groups: const [],
      lockedObjectIds: const {'image-a'},
      image: snapshot,
    );
    expect(payload.image!.image.caption, 'Reference');
    expect(payload.lockedObjectIds, const {'image-a'});
    expect(
      () => CrossBoardClipboardPayload(
        sourceBoardId: 'board-a',
        notes: [note],
        connectors: const [],
        headings: const [],
        groups: const [],
        lockedObjectIds: const {},
        image: snapshot,
      ),
      throwsArgumentError,
    );

    await file.writeAsBytes(const [1, 2, 3], flush: true);
    await expectLater(
      CrossBoardImageSnapshot.capture(image: image, sourceFile: file),
      throwsA(isA<FormatException>()),
    );
  });

  test('captures GIF bytes for cross-Board paste', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vasmim-cross-board-gif-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}source.gif');
    await file.writeAsBytes(twoFrameGif, flush: true);
    final image = BoardImage(
      id: 'gif-a',
      x: 10,
      y: 20,
      width: 200,
      height: 120,
      assetPath: 'assets/source.gif',
      originalFileName: 'Source animation.gif',
      pixelWidth: 2,
      pixelHeight: 2,
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final snapshot = await CrossBoardImageSnapshot.capture(
      image: image,
      sourceFile: file,
    );

    expect(snapshot.bytes, orderedEquals(twoFrameGif));
  });
}

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
  '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
