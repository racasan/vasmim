import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_text_link.dart';

void main() {
  test('moving a note preserves its permanent identity and content', () {
    final createdAt = DateTime.utc(2026, 8, 6);
    final modifiedAt = createdAt.add(const Duration(minutes: 1));
    final note = Note(
      id: 'note-1',
      x: 10,
      y: 20,
      width: 260,
      height: 170,
      text: 'Keep this text',
      createdAt: createdAt,
      modifiedAt: createdAt,
    );

    final movedNote = note.copyWith(x: 50, y: 80, modifiedAt: modifiedAt);

    expect(movedNote.id, note.id);
    expect(movedNote.text, note.text);
    expect(movedNote.createdAt, note.createdAt);
    expect(movedNote.modifiedAt, modifiedAt);
    expect(movedNote.x, 50);
    expect(movedNote.y, 80);
  });

  test('copyWith changes note colour without changing identity', () {
    final timestamp = DateTime.utc(2026, 8, 9);
    final note = Note(
      id: 'note-colour',
      x: 10,
      y: 20,
      width: 260,
      height: 170,
      text: 'Colour me',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final blueNote = note.copyWith(color: NoteColor.blue);

    expect(note.color, NoteColor.yellow);
    expect(blueNote.color, NoteColor.blue);
    expect(blueNote.id, note.id);
    expect(blueNote.text, note.text);
  });

  test('copyWith can add, change, and remove an optional title', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    final note = Note(
      id: 'titled-note',
      x: 10,
      y: 20,
      width: 260,
      height: 170,
      text: 'Body stays separate',
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final titled = note.copyWith(title: 'Release plan');
    final renamed = titled.copyWith(title: 'Launch plan');
    final untitled = renamed.copyWith(title: null);

    expect(note.title, isNull);
    expect(titled.title, 'Release plan');
    expect(renamed.title, 'Launch plan');
    expect(untitled.title, isNull);
    expect(untitled.text, note.text);
  });

  test('normalizes valid titles and rejects invalid title text', () {
    expect(Note.normalizeTitle('  Release plan  '), 'Release plan');
    expect(Note.normalizeTitle('   '), isNull);
    expect(
      () => Note.normalizeTitle('line one\nline two'),
      throwsFormatException,
    );
    expect(
      () => Note.normalizeTitle(List.filled(81, '😀').join()),
      throwsFormatException,
    );
    expect(Note.normalizeTitle(List.filled(80, '😀').join()), isNotNull);
  });

  test('copyWith preserves and replaces immutable emphasis ranges', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    final source = Note(
      id: 'emphasis-note',
      x: 0,
      y: 0,
      width: 260,
      height: 170,
      text: 'Bold body',
      emphasis: const [NoteEmphasisRange(start: 0, end: 4, bold: true)],
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final cleared = source.copyWith(emphasis: const []);

    expect(source.emphasis, hasLength(1));
    expect(cleared.emphasis, isEmpty);
    expect(cleared.text, source.text);
    expect(() => source.emphasis.clear(), throwsUnsupportedError);
  });

  test('copyWith preserves and replaces immutable text-link ranges', () {
    final timestamp = DateTime.utc(2026, 9, 4);
    final source = Note(
      id: 'linked-note',
      x: 0,
      y: 0,
      width: 260,
      height: 170,
      text: 'Source text',
      links: const [
        NoteTextLinkRange(start: 0, end: 6, destination: 'https://example.com'),
      ],
      createdAt: timestamp,
      modifiedAt: timestamp,
    );

    final cleared = source.copyWith(links: const []);

    expect(source.links, hasLength(1));
    expect(cleared.links, isEmpty);
    expect(cleared.text, source.text);
    expect(() => source.links.clear(), throwsUnsupportedError);
  });
}
