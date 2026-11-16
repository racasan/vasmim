import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/attachment/attachment_preview_generator.dart';
import 'package:vasmim/attachment/board_attachment.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'vasmim_attachment_preview_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'reads an embedded modern Office thumbnail without extracting it',
    () async {
      final previewBytes = <int>[0xff, 0xd8, 0xff, 0xd9];
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('word/document.xml', <int>[1]))
        ..addFile(ArchiveFile.bytes('docProps/thumbnail.jpeg', previewBytes));
      final file = File('${temporaryDirectory.path}/reference.docx');
      await file.writeAsBytes(ZipEncoder().encode(archive));
      final time = DateTime.utc(2026, 9, 9);
      final attachment = BoardAttachment(
        id: 'attachment-1',
        x: 0,
        y: 0,
        width: 300,
        height: 112,
        assetPath: 'assets/reference.docx',
        originalFileName: 'reference.docx',
        kind: AttachmentKind.word,
        byteSize: await file.length(),
        createdAt: time,
        modifiedAt: time,
      );

      final preview = await const ManagedAttachmentPreviewGenerator().generate(
        attachment,
        file,
      );

      expect(preview?.bytes, previewBytes);
      expect(preview?.extension, '.jpg');
      final entries = await temporaryDirectory.list().toList();
      expect(entries, hasLength(1));
      expect(
        entries.single.path.replaceAll('\\', '/'),
        file.path.replaceAll('\\', '/'),
      );
    },
  );
}
