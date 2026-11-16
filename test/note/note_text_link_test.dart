import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_text_link.dart';

void main() {
  test('pasted links override inherited links and stay in canonical order', () {
    final merged = NoteTextLinks.merge(
      textLength: 12,
      ranges: const [
        NoteTextLinkRange(
          start: 0,
          end: 12,
          destination: 'https://old.example',
        ),
      ],
      additions: const [
        NoteTextLinkRange(start: 3, end: 6, destination: 'https://new.example'),
      ],
    );
    expect(merged, const [
      NoteTextLinkRange(start: 0, end: 3, destination: 'https://old.example'),
      NoteTextLinkRange(start: 3, end: 6, destination: 'https://new.example'),
      NoteTextLinkRange(start: 6, end: 12, destination: 'https://old.example'),
    ]);
    expect(NoteTextLinks.invalidReason('abcdefghijkl', merged), isNull);
  });
  group('NoteTextLinks', () {
    const source = 'https://example.com/source';

    test('normalizes only complete supported web destinations', () {
      expect(NoteTextLinks.normalizeDestination('  $source  '), source);
      expect(
        NoteTextLinks.normalizeDestination('mailto:test@example.com'),
        isNull,
      );
      expect(NoteTextLinks.normalizeDestination('example.com'), isNull);
      expect(NoteTextLinks.normalizeDestination('$source trailing'), isNull);
    });

    test('validates ordered non-overlapping canonical ranges', () {
      const text = 'Alpha beta';
      expect(
        NoteTextLinks.invalidReason(text, const [
          NoteTextLinkRange(start: 0, end: 5, destination: source),
        ]),
        isNull,
      );
      expect(
        NoteTextLinks.invalidReason(text, const [
          NoteTextLinkRange(start: 0, end: 5, destination: source),
          NoteTextLinkRange(start: 4, end: 10, destination: 'https://b.test'),
        ]),
        contains('non-overlapping'),
      );
      expect(
        NoteTextLinks.invalidReason(text, const [
          NoteTextLinkRange(start: 0, end: 5, destination: source),
          NoteTextLinkRange(start: 5, end: 10, destination: source),
        ]),
        contains('merged'),
      );
    });

    test('adds edits and removes an unambiguous selected-text link', () {
      final added = NoteTextLinks.add(
        textLength: 10,
        ranges: const [],
        start: 0,
        end: 5,
        destination: source,
      );
      expect(added, const [
        NoteTextLinkRange(start: 0, end: 5, destination: source),
      ]);
      expect(NoteTextLinks.linkContaining(added, 1, 4), added.single);
      expect(NoteTextLinks.singleIntersecting(added, 0, 6), added.single);
      expect(NoteTextLinks.canAdd(added, 5, 10), isTrue);
      expect(NoteTextLinks.canAdd(added, 4, 10), isFalse);

      final edited = NoteTextLinks.replace(
        ranges: added,
        target: added.single,
        destination: 'https://edited.test',
      );
      expect(edited.single.destination, 'https://edited.test');
      expect(NoteTextLinks.remove(edited, edited.single), isEmpty);
    });

    test('rejects an ambiguous selection touching several links', () {
      const links = [
        NoteTextLinkRange(start: 0, end: 5, destination: source),
        NoteTextLinkRange(
          start: 6,
          end: 10,
          destination: 'https://second.test',
        ),
      ];
      expect(NoteTextLinks.singleIntersecting(links, 0, 10), isNull);
    });

    test('remaps surviving links and inherits only wholly inside', () {
      const linked = [NoteTextLinkRange(start: 2, end: 6, destination: source)];
      expect(
        NoteTextLinks.transformEdit(
          oldText: 'abcdefgh',
          newText: 'abcXdefgh',
          ranges: linked,
        ),
        const [NoteTextLinkRange(start: 2, end: 7, destination: source)],
      );
      expect(
        NoteTextLinks.transformEdit(
          oldText: 'abcdefgh',
          newText: 'abXcdefgh',
          ranges: linked,
        ),
        const [NoteTextLinkRange(start: 3, end: 7, destination: source)],
      );
      expect(
        NoteTextLinks.transformEdit(
          oldText: 'abcdefgh',
          newText: 'abXgh',
          ranges: linked,
        ),
        const [NoteTextLinkRange(start: 2, end: 3, destination: source)],
      );
    });

    test('does not split a linked Unicode character', () {
      const linked = [NoteTextLinkRange(start: 1, end: 3, destination: source)];
      final transformed = NoteTextLinks.transformEdit(
        oldText: 'a😀b',
        newText: 'aXb',
        ranges: linked,
      );
      expect(transformed, const [
        NoteTextLinkRange(start: 1, end: 2, destination: source),
      ]);
    });
  });
}
