import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/attachment/board_attachment.dart';

void main() {
  test('classifies accepted reference filenames', () {
    expect(AttachmentKind.fromFileName('brief.PDF'), AttachmentKind.pdf);
    expect(AttachmentKind.fromFileName('draft.docx'), AttachmentKind.word);
    expect(
      AttachmentKind.fromFileName('ledger.xls'),
      AttachmentKind.spreadsheet,
    );
    expect(AttachmentKind.fromFileName('clip.webm'), AttachmentKind.video);
    expect(AttachmentKind.fromFileName('memo.MP3'), AttachmentKind.audio);
    expect(AttachmentKind.fromFileName('memo.wav'), AttachmentKind.audio);
  });

  test('round trips an optional managed preview', () {
    final time = DateTime.utc(2026, 9, 9);
    final attachment = BoardAttachment(
      id: 'attachment-1',
      x: 10,
      y: 20,
      width: 300,
      height: 112,
      assetPath: 'assets/document.pdf',
      originalFileName: 'document.pdf',
      kind: AttachmentKind.pdf,
      byteSize: 1200,
      previewAssetPath: 'assets/preview.jpg',
      createdAt: time,
      modifiedAt: time,
    );

    final restored = BoardAttachment.fromJson(attachment.toJson());
    expect(restored.previewAssetPath, 'assets/preview.jpg');
    expect(
      BoardAttachment.fromJson(
        attachment.toJson(),
        readPreview: false,
      ).previewAssetPath,
      isNull,
    );
  });

  test('format 30 cannot claim an audio attachment', () {
    final time = DateTime.utc(2026, 9, 24);
    final attachment = BoardAttachment(
      id: 'audio-1',
      x: 0,
      y: 0,
      width: 300,
      height: 112,
      assetPath: 'assets/memo.mp3',
      originalFileName: 'memo.mp3',
      kind: AttachmentKind.audio,
      byteSize: 10,
      createdAt: time,
      modifiedAt: time,
    );
    expect(
      () => BoardAttachment.fromJson(attachment.toJson(), readAudio: false),
      throwsFormatException,
    );
    expect(
      BoardAttachment.fromJson(attachment.toJson()).kind,
      AttachmentKind.audio,
    );
  });
}
