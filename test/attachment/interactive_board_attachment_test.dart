import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/attachment/board_attachment.dart';
import 'package:vasmim/attachment/interactive_board_attachment.dart';
import 'package:vasmim/image/image_asset_store.dart';

void main() {
  BoardAttachment attachment(AttachmentKind kind, String fileName) =>
      BoardAttachment(
        id: 'attachment-1',
        x: 0,
        y: 0,
        width: BoardAttachment.defaultWidth,
        height: BoardAttachment.defaultHeight,
        assetPath: 'assets/$fileName',
        originalFileName: fileName,
        kind: kind,
        byteSize: 2048,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
      );

  Future<int Function()> pumpCard(
    WidgetTester tester,
    BoardAttachment value, {
    bool showMediaControls = true,
  }) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractiveBoardAttachment(
              attachment: value,
              assetStore: _UnusedImageAssetStore(),
              isSelected: false,
              showMediaControls: showMediaControls,
              onSelect: () {},
              onOpen: () => opened++,
              onSecondaryTapDown: (_) {},
              onBeginMoving: (_) {},
              onMove: (_) {},
              onEndMoving: () {},
            ),
          ),
        ),
      ),
    );
    return () => opened;
  }

  const openButton = ValueKey('board-media-open-attachment-1');

  for (final (kind, fileName) in const [
    (AttachmentKind.audio, 'theme.mp3'),
    (AttachmentKind.video, 'trailer.mp4'),
  ]) {
    testWidgets('${kind.label} card opens through its player button', (
      tester,
    ) async {
      final opened = await pumpCard(tester, attachment(kind, fileName));

      expect(find.text('Open in player'), findsOneWidget);
      expect(find.text('Play'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Stop'), findsNothing);

      await tester.tap(find.byKey(openButton));
      await tester.pump();

      expect(opened(), 1);
    });
  }

  testWidgets('media card hides its button while a Board image is captured', (
    tester,
  ) async {
    await pumpCard(
      tester,
      attachment(AttachmentKind.video, 'trailer.mp4'),
      showMediaControls: false,
    );

    expect(find.byKey(openButton), findsNothing);
    expect(find.text('trailer.mp4'), findsOneWidget);
  });

  testWidgets('document cards have no player button', (tester) async {
    await pumpCard(tester, attachment(AttachmentKind.pdf, 'brief.pdf'));

    expect(find.byKey(openButton), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
  });
}

class _UnusedImageAssetStore implements ImageAssetStore {
  @override
  Future<ManagedImageAsset?> importBytes(
    Uint8List? bytes, {
    required String originalFileName,
  }) => throw UnimplementedError();

  @override
  Future<ManagedImageAsset?> importPath(String? sourcePath) =>
      throw UnimplementedError();

  @override
  Future<File> resolve(String assetPath) => throw UnimplementedError();
}
