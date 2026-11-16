import 'dart:math';

import '../note/note.dart';

typedef FreshPairIndexPicker = int Function(int candidateCount);

class FreshPair {
  const FreshPair({required this.firstNoteId, required this.secondNoteId})
    : assert(firstNoteId != secondNoteId);

  final String firstNoteId;
  final String secondNoteId;

  Set<String> get noteIds => {firstNoteId, secondNoteId};

  bool hasSameNotesAs(FreshPair other) {
    return noteIds.containsAll(other.noteIds) &&
        other.noteIds.containsAll(noteIds);
  }
}

class FreshPairSelector {
  FreshPairSelector({FreshPairIndexPicker? pickIndex})
    : _pickIndex = pickIndex ?? Random().nextInt;

  static const minimumEligibleNotes = 3;

  final FreshPairIndexPicker _pickIndex;

  static List<Note> eligibleNotes(Iterable<Note> notes) {
    return [
      for (final note in notes)
        if (note.text.trim().isNotEmpty) note,
    ];
  }

  static bool canSelect(Iterable<Note> notes) {
    return eligibleNotes(notes).length >= minimumEligibleNotes;
  }

  FreshPair? select(Iterable<Note> notes, {FreshPair? previousPair}) {
    final eligible = eligibleNotes(notes);
    if (eligible.length < minimumEligibleNotes) {
      return null;
    }

    var candidates = <FreshPair>[
      for (var firstIndex = 0; firstIndex < eligible.length - 1; firstIndex++)
        for (
          var secondIndex = firstIndex + 1;
          secondIndex < eligible.length;
          secondIndex++
        )
          FreshPair(
            firstNoteId: eligible[firstIndex].id,
            secondNoteId: eligible[secondIndex].id,
          ),
    ];

    if (previousPair != null && candidates.length > 1) {
      candidates = [
        for (final candidate in candidates)
          if (!candidate.hasSameNotesAs(previousPair)) candidate,
      ];
    }

    final selectedIndex = _pickIndex(candidates.length);
    if (selectedIndex < 0 || selectedIndex >= candidates.length) {
      throw RangeError.range(
        selectedIndex,
        0,
        candidates.length - 1,
        'selectedIndex',
      );
    }
    return candidates[selectedIndex];
  }
}
