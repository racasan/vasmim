import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note.dart';
import 'package:vasmim/thinking/fresh_pair_selector.dart';

void main() {
  test('requires three written notes and ignores blank notes', () {
    final selector = FreshPairSelector(pickIndex: (_) => 0);

    expect(
      FreshPairSelector.canSelect([
        _note('a', 'Alpha'),
        _note('blank', '  \n '),
        _note('b', 'Beta'),
      ]),
      isFalse,
    );
    expect(
      selector.select([
        _note('a', 'Alpha'),
        _note('blank', ''),
        _note('b', 'Beta'),
      ]),
      isNull,
    );

    final notes = [
      _note('a', 'Alpha'),
      _note('blank', '   '),
      _note('b', 'Beta'),
      _note('c', 'Gamma'),
    ];
    expect(FreshPairSelector.canSelect(notes), isTrue);
    expect(selector.select(notes)!.noteIds, {'a', 'b'});
  });

  test('chooses deterministic distinct pairs from unordered combinations', () {
    final requestedCandidateCounts = <int>[];
    final selector = FreshPairSelector(
      pickIndex: (candidateCount) {
        requestedCandidateCounts.add(candidateCount);
        return candidateCount - 1;
      },
    );

    final pair = selector.select([
      _note('a', 'Alpha'),
      _note('b', 'Beta'),
      _note('c', 'Gamma'),
    ]);

    expect(requestedCandidateCounts, [3]);
    expect(pair!.noteIds, {'b', 'c'});
  });

  test('does not immediately repeat the previous undirected pair', () {
    final selector = FreshPairSelector(pickIndex: (_) => 0);
    final notes = [
      _note('a', 'Alpha'),
      _note('b', 'Beta'),
      _note('c', 'Gamma'),
    ];

    final first = selector.select(notes)!;
    final next = selector.select(
      notes,
      previousPair: FreshPair(
        firstNoteId: first.secondNoteId,
        secondNoteId: first.firstNoteId,
      ),
    )!;

    expect(first.noteIds, {'a', 'b'});
    expect(next.noteIds, {'a', 'c'});
    expect(next.hasSameNotesAs(first), isFalse);
  });

  test('rejects an invalid injected candidate index', () {
    final selector = FreshPairSelector(pickIndex: (count) => count);

    expect(
      () => selector.select([
        _note('a', 'Alpha'),
        _note('b', 'Beta'),
        _note('c', 'Gamma'),
      ]),
      throwsRangeError,
    );
  });
}

Note _note(String id, String text) {
  final timestamp = DateTime.utc(2026, 8, 19);
  return Note(
    id: id,
    x: 0,
    y: 0,
    width: 260,
    height: 170,
    text: text,
    createdAt: timestamp,
    modifiedAt: timestamp,
  );
}
