import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/board/library_connector_search.dart';
import 'package:vasmim/board/library_search_target.dart';
import 'package:vasmim/connector/connector.dart';
import 'package:vasmim/note/note.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 28, 12);

  Note note(String id) => Note(
    id: id,
    x: 0,
    y: 0,
    width: 260,
    height: 170,
    text: id,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  Connector connector(String id, String? label) => Connector(
    id: id,
    objectAId: 'note-a',
    objectBId: 'note-b',
    label: label,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );

  BoardDocument board(String id, List<Connector> connectors) {
    final notes = [
      for (var index = 0; index <= connectors.length; index++)
        note('note-$index'),
    ];
    return BoardDocument(
      id: id,
      name: 'Board $id',
      createdAt: timestamp,
      modifiedAt: timestamp,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: notes,
      connectors: [
        for (var index = 0; index < connectors.length; index++)
          Connector(
            id: connectors[index].id,
            objectAId: notes[index].id,
            objectBId: notes[index + 1].id,
            label: connectors[index].label,
            createdAt: timestamp,
            modifiedAt: timestamp,
          ),
      ],
    );
  }

  test('matches labels literally across boards in stable supplied order', () {
    final results = LibraryConnectorSearch.find([
      board('favorite', [
        connector('first', 'Shared relationship'),
        connector('unlabeled', null),
        connector('second', 'SHARED RELATIONSHIP detail'),
      ]),
      board('other', [
        connector('third', 'Another shared relationship'),
        connector('unmatched', 'sharedXrelationship'),
      ]),
    ], '  SHARED RELATIONSHIP  ');

    expect(results.map((result) => (result.board.id, result.connector.id)), [
      ('favorite', 'first'),
      ('favorite', 'second'),
      ('other', 'third'),
    ]);
    expect(results.map((result) => result.label), [
      'Shared relationship',
      'SHARED RELATIONSHIP detail',
      'Another shared relationship',
    ]);
    expect(LibraryConnectorSearch.find([], '   '), isEmpty);
  });

  test('validates exact connector identity and current matching label', () {
    final current = board('board-a', [
      connector('connector-a', 'Current relationship'),
    ]);
    const target = LibrarySearchTarget.connector(
      boardId: 'board-a',
      connectorId: 'connector-a',
      query: ' relationship ',
    );

    expect(LibraryConnectorSearch.isCurrentTarget(current, target), isTrue);
    expect(
      LibraryConnectorSearch.isCurrentTarget(
        board('board-a', [connector('connector-a', 'Relabeled')]),
        target,
      ),
      isFalse,
    );
    expect(
      LibraryConnectorSearch.isCurrentTarget(
        current,
        const LibrarySearchTarget.image(
          boardId: 'board-a',
          imageId: 'connector-a',
          query: 'relationship',
        ),
      ),
      isFalse,
    );
  });
}
