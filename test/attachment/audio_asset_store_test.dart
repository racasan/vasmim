import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/attachment/attachment_asset_store.dart';
import 'package:vasmim/attachment/board_attachment.dart';

void main() {
  late Directory root;
  late FileAttachmentAssetStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vasmim_audio_import_');
    store = FileAttachmentAssetStore.scoped(
      boardDirectoryProvider: () async => root,
      idGenerator: () => 'audioasset',
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('imports independent managed audio bytes', () async {
    final source = File('${root.path}/memo.mp3');
    final bytes = <int>[0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00];
    await source.writeAsBytes(bytes);
    final candidate = await store.inspectPath(source.path);
    expect(candidate?.kind, AttachmentKind.audio);

    final managed = await store.importCandidate(candidate!);
    expect(managed.assetPath, 'assets/audioasset.mp3');
    await source.delete();
    expect(await (await store.resolve(managed.assetPath)).readAsBytes(), bytes);
  });

  test('rejects an audio extension with unrelated contents', () async {
    final source = File('${root.path}/bad.wav');
    await source.writeAsBytes(List<int>.filled(16, 0));
    final candidate = await store.inspectPath(source.path);
    await expectLater(store.importCandidate(candidate!), throwsFormatException);
    expect(await Directory('${root.path}/assets').exists(), isFalse);
  });
}
