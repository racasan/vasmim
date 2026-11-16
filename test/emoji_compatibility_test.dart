import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_heading_search.dart';
import 'package:vasmim/board/library_note_search.dart';
import 'package:vasmim/canvas/heading_search.dart';
import 'package:vasmim/canvas/note_search.dart';
import 'package:vasmim/heading/canvas_heading.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/note/note_emphasis.dart';

void main() {
  const face = '\u{1F600}';
  const heart = '\u2764\uFE0F';
  const tonedThumb = '\u{1F44D}\u{1F3FD}';
  const ukrainianFlag = '\u{1F1FA}\u{1F1E6}';
  const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}\u200D\u{1F466}';
  const compatibilityText =
      'Status $face $heart $tonedThumb $ukrainianFlag $family';
  final timestamp = DateTime.utc(2026, 9, 21, 18);

  BoardDocument board() => BoardDocument(
    id: 'emoji-board',
    name: 'Emoji compatibility',
    createdAt: timestamp,
    modifiedAt: timestamp,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: [
      Note(
        id: 'emoji-note',
        x: 100,
        y: 120,
        width: 320,
        height: 200,
        text: compatibilityText,
        title: 'Signals $tonedThumb $ukrainianFlag',
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
    headings: [
      CanvasHeading(
        id: 'emoji-heading',
        x: 100,
        y: 40,
        text: 'Family $family',
        size: CanvasHeadingSize.large,
        background: CanvasHeadingBackground.transparent,
        createdAt: timestamp,
        modifiedAt: timestamp,
      ),
    ],
  );

  test('round-trips representative emoji through encoded Board JSON', () {
    final encoded = jsonEncode(board().toJson());
    final restored = BoardDocument.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );

    expect(restored.notes.single.text, compatibilityText);
    expect(restored.notes.single.title, 'Signals $tonedThumb $ukrainianFlag');
    expect(restored.headings.single.text, 'Family $family');
  });

  test('title and heading limits count complete emoji graphemes', () {
    expect(Note.normalizeTitle(family * 80), family * 80);
    expect(CanvasHeading.normalizeText(tonedThumb * 80), tonedThumb * 80);
    expect(
      () => Note.normalizeTitle('$family${face * 80}'),
      throwsFormatException,
    );
    expect(
      () => CanvasHeading.normalizeText('$tonedThumb${heart * 80}'),
      throwsFormatException,
    );
  });

  test('complete emoji emphasis remains valid through nearby editing', () {
    final oldText = 'A$family B';
    final emojiStart = 1;
    final emojiEnd = emojiStart + family.length;
    final emphasized = NoteEmphasis.toggle(
      textLength: oldText.length,
      ranges: const [],
      start: emojiStart,
      end: emojiEnd,
      style: NoteEmphasisStyle.bold,
    );

    final edited = NoteEmphasis.transformEdit(
      oldText: oldText,
      newText: 'A$family! B',
      ranges: emphasized,
    );

    expect(edited, [
      NoteEmphasisRange(start: emojiStart, end: emojiEnd, bold: true),
    ]);
    expect(NoteEmphasis.invalidReason('A$family! B', edited), isNull);
  });

  test('Board and Library search match exact emoji text', () {
    final source = board();

    expect(
      NoteSearch.find(source.notes, tonedThumb).single.note.id,
      'emoji-note',
    );
    expect(
      HeadingSearch.find(source.headings, family).single.heading.id,
      'emoji-heading',
    );
    expect(
      LibraryNoteSearch.find([source], ukrainianFlag).single.note.id,
      'emoji-note',
    );
    expect(
      LibraryHeadingSearch.find([source], family).single.heading.id,
      'emoji-heading',
    );
  });
}
