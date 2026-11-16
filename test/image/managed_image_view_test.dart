import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/image/image_asset_store.dart';
import 'package:vasmim/image/managed_image_view.dart';

import 'animated_gif_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late FileImageAssetStore store;
  late BoardImage image;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vasmim_gif_view_');
    store = FileImageAssetStore(
      directoryProvider: () async => directory,
      idGenerator: () => 'animation',
    );
    final managed = (await store.importBytes(
      twoFrameGif,
      originalFileName: 'animation.gif',
    ))!;
    final now = DateTime.utc(2026, 9, 24);
    image = BoardImage(
      id: 'gif-image',
      x: 0,
      y: 0,
      width: 200,
      height: 120,
      assetPath: managed.assetPath,
      originalFileName: managed.originalFileName,
      pixelWidth: managed.pixelWidth,
      pixelHeight: managed.pixelHeight,
      createdAt: now,
      modifiedAt: now,
    );
  });

  tearDown(() async => directory.delete(recursive: true));

  testWidgets('GIF stays on its first frame until Play is chosen', (
    tester,
  ) async {
    var playing = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ManagedImageView(
              image: image,
              assetStore: store,
              isPlaying: playing,
              onTogglePlayback: () => setState(() => playing = !playing),
            ),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 10; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.byType(RawImage).evaluate().isNotEmpty) break;
    }

    expect(find.byType(RawImage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('managed-image-file-gif-image')),
      findsNothing,
    );
    expect(find.byTooltip('Play GIF'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gif-playback-gif-image')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('managed-image-file-gif-image')),
      findsOneWidget,
    );
    expect(find.byTooltip('Pause GIF'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gif-playback-gif-image')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('managed-image-file-gif-image')),
      findsNothing,
    );
    expect(find.byTooltip('Play GIF'), findsOneWidget);
  });
}
