import 'package:characters/characters.dart';

import '../note/note.dart';

class NoteSearchResult {
  const NoteSearchResult({
    required this.note,
    required this.excerpt,
    required this.title,
  });

  final Note note;
  final String excerpt;
  final String? title;
}

class NoteSearch {
  const NoteSearch._();

  static const maximumExcerptCharacters = 100;

  static List<NoteSearchResult> find(List<Note> notes, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final note in notes)
        if (note.text.toLowerCase().contains(query) ||
            (note.title?.toLowerCase().contains(query) ?? false))
          NoteSearchResult(
            note: note,
            excerpt: note.text.trim().isEmpty
                ? ''
                : excerpt(note.text, query: query),
            title: note.title,
          ),
    ];
  }

  static String excerpt(String text, {required String query}) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final characters = normalized.characters.toList(growable: false);
    if (characters.length <= maximumExcerptCharacters) {
      return normalized;
    }
    final matchIndex = normalized.toLowerCase().indexOf(query.toLowerCase());
    final matchCharacterIndex = matchIndex < 0
        ? 0
        : normalized.substring(0, matchIndex).characters.length;
    final start = (matchCharacterIndex - 30)
        .clamp(0, characters.length - maximumExcerptCharacters)
        .toInt();
    final end = start + maximumExcerptCharacters;
    return '${start > 0 ? '…' : ''}'
        '${characters.sublist(start, end).join()}'
        '${end < characters.length ? '…' : ''}';
  }
}
