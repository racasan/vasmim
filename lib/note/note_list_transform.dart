import 'package:flutter/services.dart';

import 'note_emphasis.dart';
import 'note_text_link.dart';

enum NoteListStyle { bulleted, numbered }

class NoteListTransformation {
  NoteListTransformation({
    required this.text,
    required this.selection,
    required Iterable<NoteEmphasisRange> emphasis,
    required Iterable<NoteTextLinkRange> links,
  }) : emphasis = List.unmodifiable(emphasis),
       links = List.unmodifiable(links);

  final String text;
  final TextSelection selection;
  final List<NoteEmphasisRange> emphasis;
  final List<NoteTextLinkRange> links;
}

class NoteListTransformer {
  const NoteListTransformer._();

  static const bulletMarker = '• ';
  static final RegExp _numberPrefix = RegExp(r'^\d+\. ');

  static NoteListTransformation? toggle({
    required String text,
    required TextSelection selection,
    required List<NoteEmphasisRange> emphasis,
    required List<NoteTextLinkRange> links,
    required NoteListStyle style,
  }) {
    if (!selection.isValid ||
        selection.isCollapsed ||
        selection.start < 0 ||
        selection.end > text.length) {
      return null;
    }

    final blockStart = _lineStart(text, selection.start);
    final blockEnd = _lineEnd(text, selection.end - 1);
    final lines = _selectedLines(text, blockStart, blockEnd);
    final nonEmptyLines = lines.where((line) => line.text.isNotEmpty).toList();
    if (nonEmptyLines.isEmpty) return null;

    final removeRequestedStyle = nonEmptyLines.every(
      (line) => _prefix(line.text).style == style,
    );
    var number = 1;
    final edits = <_LinePrefixEdit>[];
    for (final line in lines) {
      final prefix = _prefix(line.text);
      if (line.text.isEmpty) continue;
      if (removeRequestedStyle) {
        edits.add(
          _LinePrefixEdit(
            start: line.start,
            removeLength: prefix.style == style ? prefix.length : 0,
            insert: '',
          ),
        );
        continue;
      }

      final content = line.text.substring(prefix.length);
      final marker = content.isEmpty
          ? ''
          : switch (style) {
              NoteListStyle.bulleted => bulletMarker,
              NoteListStyle.numbered => '${number++}. ',
            };
      edits.add(
        _LinePrefixEdit(
          start: line.start,
          removeLength: prefix.length,
          insert: marker,
        ),
      );
    }

    final changedEdits = edits
        .where(
          (edit) =>
              text.substring(edit.start, edit.start + edit.removeLength) !=
              edit.insert,
        )
        .toList();
    if (changedEdits.isEmpty) return null;

    final remapped = _applyEdits(text, changedEdits);
    final newBlockEnd =
        blockEnd +
        changedEdits.fold<int>(
          0,
          (delta, edit) => delta + edit.insert.length - edit.removeLength,
        );
    final isForward = selection.baseOffset <= selection.extentOffset;
    final nextSelection = TextSelection(
      baseOffset: isForward ? blockStart : newBlockEnd,
      extentOffset: isForward ? newBlockEnd : blockStart,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );

    return NoteListTransformation(
      text: remapped.text,
      selection: nextSelection,
      emphasis: _remapEmphasis(
        newLength: remapped.text.length,
        oldToNew: remapped.oldToNew,
        ranges: emphasis,
      ),
      links: _remapLinks(
        newLength: remapped.text.length,
        oldToNew: remapped.oldToNew,
        ranges: links,
      ),
    );
  }

  static int _lineStart(String text, int offset) {
    if (offset <= 0) return 0;
    return text.lastIndexOf('\n', offset - 1) + 1;
  }

  static int _lineEnd(String text, int offset) {
    final newline = text.indexOf('\n', offset);
    return newline < 0 ? text.length : newline;
  }

  static List<_SelectedLine> _selectedLines(
    String text,
    int blockStart,
    int blockEnd,
  ) {
    final lines = <_SelectedLine>[];
    var start = blockStart;
    while (start <= blockEnd) {
      final newline = text.indexOf('\n', start);
      final end = newline < 0 || newline > blockEnd ? blockEnd : newline;
      lines.add(_SelectedLine(start: start, text: text.substring(start, end)));
      if (newline < 0 || newline >= blockEnd) break;
      start = newline + 1;
    }
    return lines;
  }

  static _RecognizedPrefix _prefix(String line) {
    if (line.startsWith(bulletMarker)) {
      return const _RecognizedPrefix(style: NoteListStyle.bulleted, length: 2);
    }
    final number = _numberPrefix.firstMatch(line);
    if (number != null) {
      return _RecognizedPrefix(
        style: NoteListStyle.numbered,
        length: number.end,
      );
    }
    return const _RecognizedPrefix(style: null, length: 0);
  }

  static _RemappedText _applyEdits(String text, List<_LinePrefixEdit> edits) {
    final output = StringBuffer();
    final oldToNew = List<int?>.filled(text.length, null);
    var oldCursor = 0;
    var newCursor = 0;

    void copyUntil(int end) {
      if (end <= oldCursor) return;
      output.write(text.substring(oldCursor, end));
      for (var index = oldCursor; index < end; index++) {
        oldToNew[index] = newCursor + index - oldCursor;
      }
      newCursor += end - oldCursor;
      oldCursor = end;
    }

    for (final edit in edits) {
      copyUntil(edit.start);
      output.write(edit.insert);
      newCursor += edit.insert.length;
      oldCursor += edit.removeLength;
    }
    copyUntil(text.length);
    return _RemappedText(text: output.toString(), oldToNew: oldToNew);
  }

  static List<NoteEmphasisRange> _remapEmphasis({
    required int newLength,
    required List<int?> oldToNew,
    required List<NoteEmphasisRange> ranges,
  }) {
    final bold = List<bool>.filled(newLength, false);
    final underline = List<bool>.filled(newLength, false);
    final italic = List<bool>.filled(newLength, false);
    for (final range in ranges) {
      for (var oldIndex = range.start; oldIndex < range.end; oldIndex++) {
        final newIndex = oldToNew[oldIndex];
        if (newIndex == null) continue;
        bold[newIndex] = range.bold;
        underline[newIndex] = range.underline;
        italic[newIndex] = range.italic;
      }
    }

    final result = <NoteEmphasisRange>[];
    var start = 0;
    while (start < newLength) {
      if (!bold[start] && !underline[start] && !italic[start]) {
        start++;
        continue;
      }
      var end = start + 1;
      while (end < newLength &&
          bold[end] == bold[start] &&
          underline[end] == underline[start] &&
          italic[end] == italic[start]) {
        end++;
      }
      result.add(
        NoteEmphasisRange(
          start: start,
          end: end,
          bold: bold[start],
          underline: underline[start],
          italic: italic[start],
        ),
      );
      start = end;
    }
    return List.unmodifiable(result);
  }

  static List<NoteTextLinkRange> _remapLinks({
    required int newLength,
    required List<int?> oldToNew,
    required List<NoteTextLinkRange> ranges,
  }) {
    final destinations = List<String?>.filled(newLength, null);
    for (final range in ranges) {
      for (var oldIndex = range.start; oldIndex < range.end; oldIndex++) {
        final newIndex = oldToNew[oldIndex];
        if (newIndex != null) destinations[newIndex] = range.destination;
      }
    }

    final result = <NoteTextLinkRange>[];
    var start = 0;
    while (start < newLength) {
      final destination = destinations[start];
      if (destination == null) {
        start++;
        continue;
      }
      var end = start + 1;
      while (end < newLength && destinations[end] == destination) {
        end++;
      }
      result.add(
        NoteTextLinkRange(start: start, end: end, destination: destination),
      );
      start = end;
    }
    return List.unmodifiable(result);
  }
}

class _SelectedLine {
  const _SelectedLine({required this.start, required this.text});

  final int start;
  final String text;
}

class _RecognizedPrefix {
  const _RecognizedPrefix({required this.style, required this.length});

  final NoteListStyle? style;
  final int length;
}

class _LinePrefixEdit {
  const _LinePrefixEdit({
    required this.start,
    required this.removeLength,
    required this.insert,
  });

  final int start;
  final int removeLength;
  final String insert;
}

class _RemappedText {
  const _RemappedText({required this.text, required this.oldToNew});

  final String text;
  final List<int?> oldToNew;
}
