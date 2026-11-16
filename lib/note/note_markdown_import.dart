import 'note_emphasis.dart';
import 'note_text_link.dart';

class NoteMarkdownImport {
  const NoteMarkdownImport({
    required this.text,
    required this.emphasis,
    required this.links,
  });

  final String text;
  final List<NoteEmphasisRange> emphasis;
  final List<NoteTextLinkRange> links;

  static final _inline = RegExp(
    r'\[([^\]]+)\]\((https?://[^\s)]+)\)|\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_',
  );
  static final _heading = RegExp(r'^#{1,6} ');
  static final _bullet = RegExp(r'^\s*[-*+] ');

  static bool looksLikeMarkdown(String source) =>
      _inline.hasMatch(source) ||
      source
          .split('\n')
          .any((line) => _heading.hasMatch(line) || _bullet.hasMatch(line));

  static NoteMarkdownImport parse(String source) {
    final output = StringBuffer();
    final emphasis = <NoteEmphasisRange>[];
    final links = <NoteTextLinkRange>[];
    var length = 0;

    void append(String value) {
      output.write(value);
      length += value.length;
    }

    final lines = source
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      if (lineIndex > 0) append('\n');
      var line = lines[lineIndex];
      final isHeading = _heading.hasMatch(line);
      if (isHeading) {
        line = line.replaceFirst(_heading, '');
      } else if (_bullet.hasMatch(line)) {
        line = line.replaceFirst(_bullet, '• ');
      }
      final headingStart = length;
      var position = 0;
      for (final match in _inline.allMatches(line)) {
        append(line.substring(position, match.start));
        final content =
            match.group(1) ??
            match.group(3) ??
            match.group(4) ??
            match.group(5) ??
            match.group(6)!;
        final start = length;
        append(content);
        if (match.group(1) != null) {
          final destination = NoteTextLinks.normalizeDestination(
            match.group(2)!,
          );
          if (destination != null) {
            links.add(
              NoteTextLinkRange(
                start: start,
                end: length,
                destination: destination,
              ),
            );
          }
        } else {
          emphasis.add(
            NoteEmphasisRange(
              start: start,
              end: length,
              bold: match.group(3) != null || match.group(4) != null,
              italic: match.group(5) != null || match.group(6) != null,
            ),
          );
        }
        position = match.end;
      }
      append(line.substring(position));
      if (isHeading && length > headingStart) {
        emphasis.add(
          NoteEmphasisRange(start: headingStart, end: length, bold: true),
        );
      }
    }
    final bold = List<bool>.filled(length, false);
    final italic = List<bool>.filled(length, false);
    for (final range in emphasis) {
      for (var index = range.start; index < range.end; index++) {
        bold[index] = bold[index] || range.bold;
        italic[index] = italic[index] || range.italic;
      }
    }
    final normalized = <NoteEmphasisRange>[];
    for (var start = 0; start < length;) {
      if (!bold[start] && !italic[start]) {
        start++;
        continue;
      }
      var end = start + 1;
      while (end < length &&
          bold[end] == bold[start] &&
          italic[end] == italic[start]) {
        end++;
      }
      normalized.add(
        NoteEmphasisRange(
          start: start,
          end: end,
          bold: bold[start],
          italic: italic[start],
        ),
      );
      start = end;
    }
    return NoteMarkdownImport(
      text: output.toString(),
      emphasis: List.unmodifiable(normalized),
      links: List.unmodifiable(links),
    );
  }
}
