import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/note/note_emphasis.dart';
import 'package:vasmim/note/note_markdown_import.dart';

void main() {
  test('imports common Markdown into editable Note presentation', () {
    final result = NoteMarkdownImport.parse(
      '# Title\n- **Bold** and *italic*\n[Site](https://example.com)',
    );

    expect(result.text, 'Title\n• Bold and italic\nSite');
    expect(
      result.emphasis,
      contains(const NoteEmphasisRange(start: 0, end: 5, bold: true)),
    );
    expect(
      result.emphasis,
      contains(const NoteEmphasisRange(start: 8, end: 12, bold: true)),
    );
    expect(
      result.emphasis,
      contains(const NoteEmphasisRange(start: 17, end: 23, italic: true)),
    );
    expect(result.links.single.destination, 'https://example.com');
    expect(result.links.single.start, 24);
    expect(result.links.single.end, 28);
  });

  test('leaves ordinary text unchanged', () {
    const source = 'ordinary plain text';
    expect(NoteMarkdownImport.looksLikeMarkdown(source), isFalse);
    final result = NoteMarkdownImport.parse(source);
    expect(result.text, source);
    expect(result.emphasis, isEmpty);
    expect(result.links, isEmpty);
  });
}
