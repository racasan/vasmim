import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_list_transform.dart';
import 'package:vasmim/note/note_text_link.dart';

void main() {
  test('bullets every complete line touched by a partial selection', () {
    final result = NoteListTransformer.toggle(
      text: 'Alpha\nBeta\nGamma',
      selection: const TextSelection(baseOffset: 2, extentOffset: 8),
      emphasis: const [],
      links: const [],
      style: NoteListStyle.bulleted,
    )!;

    expect(result.text, '• Alpha\n• Beta\nGamma');
    expect(
      result.selection,
      const TextSelection(baseOffset: 0, extentOffset: 14),
    );
  });

  test('choosing the active bullet style removes its markers', () {
    final result = NoteListTransformer.toggle(
      text: '• Alpha\n• Beta',
      selection: const TextSelection(baseOffset: 0, extentOffset: 14),
      emphasis: const [],
      links: const [],
      style: NoteListStyle.bulleted,
    )!;

    expect(result.text, 'Alpha\nBeta');
    expect(
      result.selection,
      const TextSelection(baseOffset: 0, extentOffset: 10),
    );
  });

  test(
    'numbers non-empty lines and does not consume a number for an empty line',
    () {
      final result = NoteListTransformer.toggle(
        text: 'Alpha\n\nBeta',
        selection: const TextSelection(baseOffset: 0, extentOffset: 11),
        emphasis: const [],
        links: const [],
        style: NoteListStyle.numbered,
      )!;

      expect(result.text, '1. Alpha\n\n2. Beta');
    },
  );

  test('converts recognised prefixes without stacking markers', () {
    final result = NoteListTransformer.toggle(
      text: '9. Alpha\n2026. Plan',
      selection: const TextSelection(baseOffset: 0, extentOffset: 19),
      emphasis: const [],
      links: const [],
      style: NoteListStyle.bulleted,
    )!;

    expect(result.text, '• Alpha\n• Plan');
  });

  test('keeps original emphasis and links off inserted markers', () {
    final result = NoteListTransformer.toggle(
      text: 'Alpha\nBeta',
      selection: const TextSelection(baseOffset: 1, extentOffset: 8),
      emphasis: const [
        NoteEmphasisRange(start: 0, end: 5, bold: true),
        NoteEmphasisRange(start: 6, end: 10, italic: true),
      ],
      links: const [
        NoteTextLinkRange(
          start: 6,
          end: 10,
          destination: 'https://example.com/beta',
        ),
      ],
      style: NoteListStyle.bulleted,
    )!;

    expect(result.text, '• Alpha\n• Beta');
    expect(result.emphasis, const [
      NoteEmphasisRange(start: 2, end: 7, bold: true),
      NoteEmphasisRange(start: 10, end: 14, italic: true),
    ]);
    expect(result.links, const [
      NoteTextLinkRange(
        start: 10,
        end: 14,
        destination: 'https://example.com/beta',
      ),
    ]);
  });

  test('preserves backward selection and emoji character boundaries', () {
    final source = '😀 one\nTwo';
    final result = NoteListTransformer.toggle(
      text: source,
      selection: TextSelection(
        baseOffset: source.length,
        extentOffset: 1,
        isDirectional: true,
      ),
      emphasis: const [NoteEmphasisRange(start: 0, end: 2, underline: true)],
      links: const [],
      style: NoteListStyle.numbered,
    )!;

    expect(result.text, '1. 😀 one\n2. Two');
    expect(result.selection.baseOffset, result.text.length);
    expect(result.selection.extentOffset, 0);
    expect(result.emphasis, const [
      NoteEmphasisRange(start: 3, end: 5, underline: true),
    ]);
  });

  test('empty or collapsed selections are non-mutating', () {
    expect(
      NoteListTransformer.toggle(
        text: '\n',
        selection: const TextSelection(baseOffset: 0, extentOffset: 1),
        emphasis: const [],
        links: const [],
        style: NoteListStyle.bulleted,
      ),
      isNull,
    );
    expect(
      NoteListTransformer.toggle(
        text: 'Alpha',
        selection: const TextSelection.collapsed(offset: 2),
        emphasis: const [],
        links: const [],
        style: NoteListStyle.numbered,
      ),
      isNull,
    );
  });
}
