import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/canvas/note_search.dart';
import 'package:vasmim/note/note.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 25, 19);
  Note note(String id, String text, {String? title}) => Note(
    id: id,
    x: 0,
    y: 0,
    width: 260,
    height: 170,
    text: text,
    title: title,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  test('matches trimmed literal text case-insensitively in note order', () {
    final results = NoteSearch.find([
      note('first', 'Alpha shared phrase'),
      note('empty', '   '),
      note('second', 'SHARED PHRASE beta'),
      note('other', 'Unrelated'),
    ], '  Shared Phrase  ');

    expect(results.map((result) => result.note.id), ['first', 'second']);
    expect(NoteSearch.find([note('regex', 'a.b')], 'a.b'), hasLength(1));
    expect(NoteSearch.find([note('regex', 'axb')], 'a.b'), isEmpty);
    expect(NoteSearch.find([note('empty', 'text')], '   '), isEmpty);
  });

  test('normalizes whitespace and bounds excerpts around a late match', () {
    final text = '${'prefix ' * 30}\n\tRemember THIS phrase\n${'suffix ' * 30}';
    final excerpt = NoteSearch.excerpt(text, query: 'remember this');

    expect(excerpt, contains('Remember THIS'));
    expect(excerpt, isNot(contains('\n')));
    expect(excerpt, isNot(contains('\t')));
    expect(excerpt.characters.length, lessThanOrEqualTo(102));
    expect(excerpt, startsWith('…'));
    expect(excerpt, endsWith('…'));
  });

  test('matches optional titles and keeps title and body context distinct', () {
    final titleMatch = NoteSearch.find([
      note('title', 'Body without the query', title: 'FretFlip release'),
      note('body', 'Release checklist', title: 'Different heading'),
      note('none', 'Unrelated'),
    ], 'release');

    expect(titleMatch.map((result) => result.note.id), ['title', 'body']);
    expect(titleMatch.first.title, 'FretFlip release');
    expect(titleMatch.first.excerpt, 'Body without the query');
    expect(titleMatch.last.title, 'Different heading');
  });
}
