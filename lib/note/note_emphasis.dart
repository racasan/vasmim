enum NoteEmphasisStyle { bold, underline, italic }

class NoteEmphasisRange {
  const NoteEmphasisRange({
    required this.start,
    required this.end,
    this.bold = false,
    this.underline = false,
    this.italic = false,
  });

  final int start;
  final int end;
  final bool bold;
  final bool underline;
  final bool italic;

  Map<String, Object> toJson() => {
    'start': start,
    'end': end,
    'bold': bold,
    'underline': underline,
    'italic': italic,
  };

  factory NoteEmphasisRange.fromJson(
    Map<String, dynamic> json, {
    bool readItalic = true,
  }) {
    return NoteEmphasisRange(
      start: json['start'] as int,
      end: json['end'] as int,
      bold: json['bold'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
      italic: readItalic ? json['italic'] as bool? ?? false : false,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoteEmphasisRange &&
        start == other.start &&
        end == other.end &&
        bold == other.bold &&
        underline == other.underline &&
        italic == other.italic;
  }

  @override
  int get hashCode => Object.hash(start, end, bold, underline, italic);

  @override
  String toString() {
    return 'NoteEmphasisRange($start, $end, bold: $bold, underline: $underline, italic: $italic)';
  }
}

class NoteEmphasis {
  const NoteEmphasis._();

  /// Apply imported styles in one pass, retaining existing emphasis.
  static List<NoteEmphasisRange> merge({
    required int textLength,
    required List<NoteEmphasisRange> ranges,
    required List<NoteEmphasisRange> additions,
  }) {
    final styles = _expand(textLength, ranges);
    for (final range in additions) {
      if (range.start < 0 ||
          range.end > textLength ||
          range.start >= range.end) {
        throw RangeError('Invalid Note emphasis range: $range');
      }
      for (var index = range.start; index < range.end; index++) {
        styles.bold[index] = styles.bold[index] || range.bold;
        styles.underline[index] = styles.underline[index] || range.underline;
        styles.italic[index] = styles.italic[index] || range.italic;
      }
    }
    return _collapse(styles.bold, styles.underline, styles.italic);
  }

  static List<NoteEmphasisRange> toggle({
    required int textLength,
    required List<NoteEmphasisRange> ranges,
    required int start,
    required int end,
    required NoteEmphasisStyle style,
  }) {
    if (start < 0 || end > textLength || start > end) {
      throw RangeError.range(start, 0, textLength, 'selection');
    }
    if (start == end) {
      return List.unmodifiable(ranges);
    }
    final styles = _expand(textLength, ranges);
    final isFullyApplied = switch (style) {
      NoteEmphasisStyle.bold =>
        styles.bold.getRange(start, end).every((value) => value),
      NoteEmphasisStyle.underline =>
        styles.underline.getRange(start, end).every((value) => value),
      NoteEmphasisStyle.italic =>
        styles.italic.getRange(start, end).every((value) => value),
    };
    final apply = !isFullyApplied;
    for (var index = start; index < end; index++) {
      switch (style) {
        case NoteEmphasisStyle.bold:
          styles.bold[index] = apply;
        case NoteEmphasisStyle.underline:
          styles.underline[index] = apply;
        case NoteEmphasisStyle.italic:
          styles.italic[index] = apply;
      }
    }
    return _collapse(styles.bold, styles.underline, styles.italic);
  }

  static List<NoteEmphasisRange> transformEdit({
    required String oldText,
    required String newText,
    required List<NoteEmphasisRange> ranges,
  }) {
    if (oldText == newText || ranges.isEmpty) {
      return List.unmodifiable(ranges);
    }
    var prefix = 0;
    final sharedLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < sharedLength &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    if (prefix > 0 &&
        (_splitsSurrogatePair(oldText, prefix) ||
            _splitsSurrogatePair(newText, prefix))) {
      prefix--;
    }
    var suffix = 0;
    while (suffix < oldText.length - prefix &&
        suffix < newText.length - prefix &&
        oldText.codeUnitAt(oldText.length - suffix - 1) ==
            newText.codeUnitAt(newText.length - suffix - 1)) {
      suffix++;
    }
    while (suffix > 0 &&
        (_splitsSurrogatePair(oldText, oldText.length - suffix) ||
            _splitsSurrogatePair(newText, newText.length - suffix))) {
      suffix--;
    }

    final oldEnd = oldText.length - suffix;
    final newEnd = newText.length - suffix;
    final insertedLength = newEnd - prefix;
    final oldStyles = _expand(oldText.length, ranges);
    final newBold = List.filled(newText.length, false);
    final newUnderline = List.filled(newText.length, false);
    final newItalic = List.filled(newText.length, false);

    for (var index = 0; index < prefix; index++) {
      newBold[index] = oldStyles.bold[index];
      newUnderline[index] = oldStyles.underline[index];
      newItalic[index] = oldStyles.italic[index];
    }
    for (var index = oldEnd; index < oldText.length; index++) {
      final newIndex = newEnd + index - oldEnd;
      newBold[newIndex] = oldStyles.bold[index];
      newUnderline[newIndex] = oldStyles.underline[index];
      newItalic[newIndex] = oldStyles.italic[index];
    }

    final inheritBold = _inheritsStyle(
      oldStyles.bold,
      start: prefix,
      end: oldEnd,
    );
    final inheritUnderline = _inheritsStyle(
      oldStyles.underline,
      start: prefix,
      end: oldEnd,
    );
    final inheritItalic = _inheritsStyle(
      oldStyles.italic,
      start: prefix,
      end: oldEnd,
    );
    for (var index = 0; index < insertedLength; index++) {
      newBold[prefix + index] = inheritBold;
      newUnderline[prefix + index] = inheritUnderline;
      newItalic[prefix + index] = inheritItalic;
    }
    return _collapse(newBold, newUnderline, newItalic);
  }

  static String? invalidReason(String text, List<NoteEmphasisRange> ranges) {
    var previousEnd = 0;
    NoteEmphasisRange? previous;
    for (final range in ranges) {
      if (range.start < 0 ||
          range.end <= range.start ||
          range.end > text.length) {
        return 'Note emphasis ranges must fit inside the Note body.';
      }
      if (!range.bold && !range.underline && !range.italic) {
        return 'A Note emphasis range must contain bold, underline, or italic.';
      }
      if (range.start < previousEnd) {
        return 'Note emphasis ranges must be ordered and non-overlapping.';
      }
      if (_splitsSurrogatePair(text, range.start) ||
          _splitsSurrogatePair(text, range.end)) {
        return 'Note emphasis ranges must follow character boundaries.';
      }
      if (previous != null &&
          previous.end == range.start &&
          previous.bold == range.bold &&
          previous.underline == range.underline &&
          previous.italic == range.italic) {
        return 'Adjacent identical Note emphasis ranges must be merged.';
      }
      previous = range;
      previousEnd = range.end;
    }
    return null;
  }

  static _ExpandedStyles _expand(
    int textLength,
    List<NoteEmphasisRange> ranges,
  ) {
    final bold = List.filled(textLength, false);
    final underline = List.filled(textLength, false);
    final italic = List.filled(textLength, false);
    for (final range in ranges) {
      if (range.start < 0 ||
          range.end > textLength ||
          range.start >= range.end) {
        throw RangeError('Invalid Note emphasis range: $range');
      }
      for (var index = range.start; index < range.end; index++) {
        bold[index] = range.bold;
        underline[index] = range.underline;
        italic[index] = range.italic;
      }
    }
    return _ExpandedStyles(bold, underline, italic);
  }

  static bool _inheritsStyle(
    List<bool> styles, {
    required int start,
    required int end,
  }) {
    if (start < end) {
      return styles.getRange(start, end).every((value) => value);
    }
    return start > 0 &&
        start < styles.length &&
        styles[start - 1] &&
        styles[start];
  }

  static List<NoteEmphasisRange> _collapse(
    List<bool> bold,
    List<bool> underline,
    List<bool> italic,
  ) {
    final ranges = <NoteEmphasisRange>[];
    var index = 0;
    while (index < bold.length) {
      if (!bold[index] && !underline[index] && !italic[index]) {
        index++;
        continue;
      }
      final start = index;
      final isBold = bold[index];
      final isUnderline = underline[index];
      final isItalic = italic[index];
      index++;
      while (index < bold.length &&
          bold[index] == isBold &&
          underline[index] == isUnderline &&
          italic[index] == isItalic) {
        index++;
      }
      ranges.add(
        NoteEmphasisRange(
          start: start,
          end: index,
          bold: isBold,
          underline: isUnderline,
          italic: isItalic,
        ),
      );
    }
    return List.unmodifiable(ranges);
  }

  static bool _splitsSurrogatePair(String text, int offset) {
    if (offset <= 0 || offset >= text.length) {
      return false;
    }
    final left = text.codeUnitAt(offset - 1);
    final right = text.codeUnitAt(offset);
    return left >= 0xD800 &&
        left <= 0xDBFF &&
        right >= 0xDC00 &&
        right <= 0xDFFF;
  }
}

class _ExpandedStyles {
  const _ExpandedStyles(this.bold, this.underline, this.italic);

  final List<bool> bold;
  final List<bool> underline;
  final List<bool> italic;
}
