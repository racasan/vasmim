import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:pdfx/pdfx.dart';

import 'board_attachment.dart';

class AttachmentPreviewData {
  const AttachmentPreviewData(this.bytes, this.extension);

  final Uint8List bytes;
  final String extension;
}

abstract interface class AttachmentPreviewGenerator {
  Future<AttachmentPreviewData?> generate(
    BoardAttachment attachment,
    File managedFile,
  );
}

class ManagedAttachmentPreviewGenerator implements AttachmentPreviewGenerator {
  const ManagedAttachmentPreviewGenerator();

  static const _maximumEmbeddedPreviewBytes = 5 * 1024 * 1024;

  @override
  Future<AttachmentPreviewData?> generate(
    BoardAttachment attachment,
    File managedFile,
  ) async {
    try {
      return await switch (attachment.kind) {
        AttachmentKind.pdf => _renderPdf(managedFile),
        AttachmentKind.word || AttachmentKind.spreadsheet => _readOfficePreview(
          attachment,
          managedFile,
        ),
        AttachmentKind.video || AttachmentKind.audio => null,
      };
    } catch (_) {
      return null;
    }
  }

  Future<AttachmentPreviewData?> _renderPdf(File file) async {
    PdfDocument? document;
    PdfPage? page;
    try {
      document = await PdfDocument.openFile(file.path);
      page = await document.getPage(1);
      const width = 240.0;
      final height = width * page.height / page.width;
      if (!height.isFinite || height <= 0 || height > 4096) return null;
      final rendered = await page.render(
        width: width,
        height: height,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
        quality: 82,
      );
      final bytes = rendered?.bytes;
      return bytes == null ? null : AttachmentPreviewData(bytes, '.jpg');
    } finally {
      await page?.close();
      await document?.close();
    }
  }

  Future<AttachmentPreviewData?> _readOfficePreview(
    BoardAttachment attachment,
    File file,
  ) async {
    final lowerName = attachment.originalFileName.toLowerCase();
    if (!lowerName.endsWith('.docx') && !lowerName.endsWith('.xlsx')) {
      return null;
    }

    InputFileStream? input;
    try {
      input = InputFileStream(file.path);
      final archive = ZipDecoder().decodeStream(input);
      for (final name in const [
        'docProps/thumbnail.jpeg',
        'docProps/thumbnail.jpg',
        'docProps/thumbnail.png',
      ]) {
        final entry = archive.files
            .where((file) => file.name == name)
            .firstOrNull;
        if (entry == null ||
            entry.size <= 0 ||
            entry.size > _maximumEmbeddedPreviewBytes) {
          continue;
        }
        final bytes = entry.readBytes();
        if (bytes != null && bytes.isNotEmpty) {
          final extension = entry.name.toLowerCase().endsWith('.png')
              ? '.png'
              : '.jpg';
          return AttachmentPreviewData(bytes, extension);
        }
      }
      return null;
    } finally {
      await input?.close();
    }
  }
}
