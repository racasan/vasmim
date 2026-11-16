import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_emphasis.dart';

void main() {
  test('toggles bold and underline into canonical overlapping ranges', () {
    final bold = NoteEmphasis.toggle(
      textLength: 11,
      ranges: const [],
      start: 0,
      end: 5,
      style: NoteEmphasisStyle.bold,
    );
    final overlapped = NoteEmphasis.toggle(
      textLength: 11,
      ranges: bold,
      start: 3,
      end: 8,
      style: NoteEmphasisStyle.underline,
    );

    expect(overlapped, [
      const NoteEmphasisRange(start: 0, end: 3, bold: true),
      const NoteEmphasisRange(start: 3, end: 5, bold: true, underline: true),
      const NoteEmphasisRange(start: 5, end: 8, underline: true),
    ]);
  });

  test('toggles italic independently and preserves three-style overlap', () {
    const source = [
      NoteEmphasisRange(start: 0, end: 4, bold: true),
      NoteEmphasisRange(start: 4, end: 8, underline: true),
    ];

    final italic = NoteEmphasis.toggle(
      textLength: 8,
      ranges: source,
      start: 2,
      end: 6,
      style: NoteEmphasisStyle.italic,
    );

    expect(italic, [
      const NoteEmphasisRange(start: 0, end: 2, bold: true),
      const NoteEmphasisRange(start: 2, end: 4, bold: true, italic: true),
      const NoteEmphasisRange(start: 4, end: 6, underline: true, italic: true),
      const NoteEmphasisRange(start: 6, end: 8, underline: true),
    ]);
    expect(
      NoteEmphasis.toggle(
        textLength: 8,
        ranges: italic,
        start: 2,
        end: 6,
        style: NoteEmphasisStyle.italic,
      ),
      source,
    );
  });

  test(
    'a fully emphasized selection toggles off while a mixed one applies',
    () {
      const source = [NoteEmphasisRange(start: 2, end: 6, bold: true)];

      expect(
        NoteEmphasis.toggle(
          textLength: 10,
          ranges: source,
          start: 2,
          end: 6,
          style: NoteEmphasisStyle.bold,
        ),
        isEmpty,
      );
      expect(
        NoteEmphasis.toggle(
          textLength: 10,
          ranges: source,
          start: 0,
          end: 4,
          style: NoteEmphasisStyle.bold,
        ),
        [const NoteEmphasisRange(start: 0, end: 6, bold: true)],
      );
    },
  );

  test('text edits shift preserve and conservatively inherit emphasis', () {
    const source = [NoteEmphasisRange(start: 2, end: 6, bold: true)];

    expect(
      NoteEmphasis.transformEdit(
        oldText: 'abcdefgh',
        newText: 'Xabcdefgh',
        ranges: source,
      ),
      [const NoteEmphasisRange(start: 3, end: 7, bold: true)],
    );
    expect(
      NoteEmphasis.transformEdit(
        oldText: 'abcdefgh',
        newText: 'abcdXefgh',
        ranges: source,
      ),
      [const NoteEmphasisRange(start: 2, end: 7, bold: true)],
    );
    expect(
      NoteEmphasis.transformEdit(
        oldText: 'abcdefgh',
        newText: 'abXcdefgh',
        ranges: source,
      ),
      [const NoteEmphasisRange(start: 3, end: 7, bold: true)],
    );
  });

  test('text edits preserve and inherit italic with other styles', () {
    const source = [
      NoteEmphasisRange(start: 2, end: 6, bold: true, italic: true),
    ];

    expect(
      NoteEmphasis.transformEdit(
        oldText: 'abcdefgh',
        newText: 'abcdXefgh',
        ranges: source,
      ),
      [const NoteEmphasisRange(start: 2, end: 7, bold: true, italic: true)],
    );
  });

  test(
    'replacement inherits only styles covering the complete replaced text',
    () {
      const source = [
        NoteEmphasisRange(start: 1, end: 3, bold: true),
        NoteEmphasisRange(start: 3, end: 5, bold: true, underline: true),
        NoteEmphasisRange(start: 5, end: 7, underline: true),
      ];

      expect(
        NoteEmphasis.transformEdit(
          oldText: 'abcdefgh',
          newText: 'aXYfgh',
          ranges: source,
        ),
        [
          const NoteEmphasisRange(start: 1, end: 3, bold: true),
          const NoteEmphasisRange(start: 3, end: 5, underline: true),
        ],
      );
    },
  );

  test('edit transforms never split a surrogate-pair character', () {
    const source = [NoteEmphasisRange(start: 1, end: 3, bold: true)];

    final transformed = NoteEmphasis.transformEdit(
      oldText: 'A😀B',
      newText: 'A😁B',
      ranges: source,
    );

    expect(transformed, source);
    expect(NoteEmphasis.invalidReason('A😁B', transformed), isNull);
  });
}
