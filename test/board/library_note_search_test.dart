import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_note_search.dart';
import 'package:vasmim/board/library_search_target.dart';
import 'package:vasmim/note/note.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 26, 12);

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

  BoardDocument board({
    required String id,
    required String name,
    required DateTime modifiedAt,
    required List<Note> notes,
  }) => BoardDocument(
    id: id,
    name: name,
    createdAt: timestamp,
    modifiedAt: modifiedAt,
    viewportX: 0,
    viewportY: 0,
    viewportZoom: 1,
    notes: notes,
  );

  test('orders favorites first then applies time and board-id ties', () {
    final tiedTime = DateTime.utc(2026, 7, 1);
    final boards = [
      board(
        id: 'middle-b',
        name: 'Middle B',
        modifiedAt: tiedTime,
        notes: const [],
      ),
      board(
        id: 'newest',
        name: 'Newest',
        modifiedAt: DateTime.utc(2026, 8, 1),
        notes: const [],
      ),
      board(
        id: 'favorite',
        name: 'Favorite',
        modifiedAt: DateTime.utc(2026, 6, 1),
        notes: const [],
      ),
      board(
        id: 'middle-a',
        name: 'Middle A',
        modifiedAt: tiedTime,
        notes: const [],
      ),
    ];

    expect(
      LibraryNoteSearch.orderBoards(
        boards,
        favoriteBoardIds: const {'favorite'},
        newestFirst: true,
      ).map((board) => board.id),
      ['favorite', 'newest', 'middle-a', 'middle-b'],
    );
    expect(
      LibraryNoteSearch.orderBoards(
        boards,
        favoriteBoardIds: const {'favorite'},
        newestFirst: false,
      ).map((board) => board.id),
      ['favorite', 'middle-a', 'middle-b', 'newest'],
    );
  });

  test('matches written notes literally across boards in supplied order', () {
    final results = LibraryNoteSearch.find([
      board(
        id: 'favorite-board',
        name: 'Same name',
        modifiedAt: timestamp,
        notes: [
          note('first', 'Alpha shared phrase'),
          note('empty', '   '),
          note('second', 'SHARED PHRASE beta'),
        ],
      ),
      board(
        id: 'other-board',
        name: 'Same name',
        modifiedAt: timestamp,
        notes: [note('third', 'Another shared phrase')],
      ),
    ], '  Shared Phrase  ');

    expect(results.map((result) => (result.board.id, result.note.id)), [
      ('favorite-board', 'first'),
      ('favorite-board', 'second'),
      ('other-board', 'third'),
    ]);
    expect(results.every((result) => result.excerpt.isNotEmpty), isTrue);
    expect(
      LibraryNoteSearch.find([
        board(
          id: 'literal',
          name: 'Literal',
          modifiedAt: timestamp,
          notes: [note('dot', 'a.b'), note('other', 'axb')],
        ),
      ], 'a.b').map((result) => result.note.id),
      ['dot'],
    );
    expect(LibraryNoteSearch.find([], '   '), isEmpty);
  });

  test(
    'validates a fresh target against identity and current matching text',
    () {
      final current = board(
        id: 'board-a',
        name: 'Board A',
        modifiedAt: timestamp,
        notes: [note('note-a', 'Current shared phrase')],
      );
      const target = LibrarySearchTarget.note(
        boardId: 'board-a',
        noteId: 'note-a',
        query: ' shared phrase ',
      );

      expect(LibraryNoteSearch.isCurrentTarget(current, target), isTrue);
      expect(
        LibraryNoteSearch.isCurrentTarget(
          _withNotes(current, [note('note-a', 'Changed text')]),
          target,
        ),
        isFalse,
      );
      expect(
        LibraryNoteSearch.isCurrentTarget(
          current,
          const LibrarySearchTarget.note(
            boardId: 'other-board',
            noteId: 'note-a',
            query: 'shared phrase',
          ),
        ),
        isFalse,
      );
    },
  );

  test('finds and revalidates a Note by title across the library', () {
    final current = board(
      id: 'board-title',
      name: 'Launch',
      modifiedAt: timestamp,
      notes: [note('note-title', 'Checklist body', title: 'FretFlip release')],
    );
    final results = LibraryNoteSearch.find([current], 'fretflip');
    const target = LibrarySearchTarget.note(
      boardId: 'board-title',
      noteId: 'note-title',
      query: 'fretflip',
    );

    expect(results.single.note.title, 'FretFlip release');
    expect(LibraryNoteSearch.isCurrentTarget(current, target), isTrue);
  });
}

BoardDocument _withNotes(BoardDocument board, List<Note> notes) {
  return BoardDocument(
    id: board.id,
    name: board.name,
    createdAt: board.createdAt,
    modifiedAt: board.modifiedAt,
    viewportX: board.viewportX,
    viewportY: board.viewportY,
    viewportZoom: board.viewportZoom,
    notes: notes,
    connectors: board.connectors,
    images: board.images,
    scenes: board.scenes,
  );
}
