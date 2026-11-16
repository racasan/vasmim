import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/attachment/board_attachment.dart';
import 'package:vasmim/canvas/cross_board_clipboard.dart';
import 'package:vasmim/canvas/cross_board_foreground_snapshot.dart';
import 'package:vasmim/image/board_image.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/youtube/youtube_embed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'mixed snapshot survives source deletion and cleans up on clear',
    () async {
      final source = await Directory.systemTemp.createTemp(
        'vasmim-source-test-',
      );
      addTearDown(() async {
        if (await source.exists()) await source.delete(recursive: true);
      });
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final files = <String, File>{};
      for (final name in ['image.png', 'preview.png', 'thumb.png']) {
        files['assets/$name'] = await File(
          '${source.path}${Platform.pathSeparator}$name',
        ).writeAsBytes(png);
      }
      files['assets/reference.pdf'] = await File(
        '${source.path}${Platform.pathSeparator}reference.pdf',
      ).writeAsBytes('%PDF-1.4 example'.codeUnits);
      if (Platform.isWindows) {
        final result = await Process.run('attrib', [
          '+R',
          files['assets/reference.pdf']!.path,
        ]);
        expect(result.exitCode, 0);
      }
      final now = DateTime.utc(2026, 9, 23);
      final snapshot = await CrossBoardForegroundSnapshot.capture(
        notes: [
          Note(
            id: 'note',
            x: 0,
            y: 0,
            width: 260,
            height: 170,
            text: 'Source thought',
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        connectors: const [],
        images: [
          BoardImage(
            id: 'image',
            x: 300,
            y: 0,
            width: 200,
            height: 120,
            assetPath: 'assets/image.png',
            originalFileName: 'image.png',
            pixelWidth: 1,
            pixelHeight: 1,
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        headings: const [],
        attachments: [
          BoardAttachment(
            id: 'attachment',
            x: 0,
            y: 200,
            width: 300,
            height: 112,
            assetPath: 'assets/reference.pdf',
            originalFileName: 'reference.pdf',
            kind: AttachmentKind.pdf,
            byteSize: 16,
            previewAssetPath: 'assets/preview.png',
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        youTubeEmbeds: [
          YouTubeEmbed(
            id: 'youtube',
            x: 400,
            y: 200,
            width: 300,
            height: 168,
            originalUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
            videoId: 'abcdefghijk',
            thumbnailAssetPath: 'assets/thumb.png',
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        groups: const [],
        lockedObjectIds: const {'image'},
        resolveImage: (path) async => files[path]!,
        resolveAttachment: (path) async => files[path]!,
      );
      final clipboard = CrossBoardClipboard()
        ..publish(
          CrossBoardClipboardPayload(
            sourceBoardId: 'source-board',
            notes: const [],
            connectors: const [],
            headings: const [],
            groups: const [],
            lockedObjectIds: const {},
            foreground: snapshot,
          ),
        );
      if (Platform.isWindows) {
        await Process.run('attrib', [
          '-R',
          files['assets/reference.pdf']!.path,
        ]);
      }
      await source.delete(recursive: true);
      expect(snapshot.notes.single.text, 'Source thought');
      expect(snapshot.imageBytes('assets/image.png'), orderedEquals(png));
      expect(snapshot.imageBytes('assets/preview.png'), orderedEquals(png));
      expect(snapshot.imageBytes('assets/thumb.png'), orderedEquals(png));
      expect(
        await snapshot.attachmentFile('assets/reference.pdf').readAsBytes(),
        '%PDF-1.4 example'.codeUnits,
      );
      final stagedDirectory = snapshot.temporaryDirectory;
      await clipboard.clear();
      expect(await stagedDirectory.exists(), isFalse);
    },
  );

  test('rejects a damaged managed Attachment during Copy', () async {
    final directory = await Directory.systemTemp.createTemp('vasmim-bad-copy-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final file = await File(
      '${directory.path}/damaged.pdf',
    ).writeAsBytes('not a PDF'.codeUnits);
    final now = DateTime.utc(2026, 9, 23);
    await expectLater(
      CrossBoardForegroundSnapshot.capture(
        notes: const [],
        connectors: const [],
        images: const [],
        headings: const [],
        attachments: [
          BoardAttachment(
            id: 'damaged',
            x: 0,
            y: 0,
            width: 300,
            height: 112,
            assetPath: 'assets/damaged.pdf',
            originalFileName: 'damaged.pdf',
            kind: AttachmentKind.pdf,
            byteSize: 9,
            createdAt: now,
            modifiedAt: now,
          ),
        ],
        youTubeEmbeds: const [],
        groups: const [],
        lockedObjectIds: const {},
        resolveImage: (_) async => throw StateError('unexpected image'),
        resolveAttachment: (_) async => file,
      ),
      throwsFormatException,
    );
  });
}
