import 'note_link_resolver.dart';

class NoteTextLinkRange {
  const NoteTextLinkRange({
    required this.start,
    required this.end,
    required this.destination,
  });

  final int start;
  final int end;
  final String destination;

  Uri get uri => Uri.parse(destination);

  Map<String, Object> toJson() => {
    'start': start,
    'end': end,
    'destination': destination,
  };

  factory NoteTextLinkRange.fromJson(Map<String, dynamic> json) {
    return NoteTextLinkRange(
      start: json['start'] as int,
      end: json['end'] as int,
      destination: json['destination'] as String,
    );
  }

  NoteTextLinkRange copyWith({String? destination}) {
    return NoteTextLinkRange(
      start: start,
      end: end,
      destination: destination ?? this.destination,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NoteTextLinkRange &&
        start == other.start &&
        end == other.end &&
        destination == other.destination;
  }

  @override
  int get hashCode => Object.hash(start, end, destination);

  @override
  String toString() => 'NoteTextLinkRange($start, $end, $destination)';
}

class NoteTextLinks {
  const NoteTextLinks._();

  /// Imported links take precedence over inherited links in the pasted text.
  static List<NoteTextLinkRange> merge({
    required int textLength,
    required List<NoteTextLinkRange> ranges,
    required List<NoteTextLinkRange> additions,
  }) {
    final destinations = _expand(textLength, ranges);
    for (final range in additions) {
      if (range.start < 0 ||
          range.end > textLength ||
          range.start >= range.end) {
        throw RangeError('A selected-text link must fit inside the Note body.');
      }
      for (var index = range.start; index < range.end; index++) {
        destinations[index] = range.destination;
      }
    }
    return _collapse(destinations);
  }

  static String? normalizeDestination(String rawDestination) {
    final trimmed = rawDestination.trim();
    return NoteLinkResolver.resolveWhole(trimmed)?.toString();
  }

  static bool canAdd(List<NoteTextLinkRange> ranges, int start, int end) {
    if (start >= end) {
      return false;
    }
    return ranges.every((range) => end <= range.start || start >= range.end);
  }

  static NoteTextLinkRange? linkContaining(
    List<NoteTextLinkRange> ranges,
    int start,
    int end,
  ) {
    if (start >= end) {
      return null;
    }
    for (final range in ranges) {
      if (start >= range.start && end <= range.end) {
        return range;
      }
    }
    return null;
  }

  static NoteTextLinkRange? singleIntersecting(
    List<NoteTextLinkRange> ranges,
    int start,
    int end,
  ) {
    if (start >= end) {
      return null;
    }
    NoteTextLinkRange? result;
    for (final range in ranges) {
      if (start < range.end && end > range.start) {
        if (result != null) {
          return null;
        }
        result = range;
      }
    }
    return result;
  }

  static NoteTextLinkRange? linkAt(List<NoteTextLinkRange> ranges, int offset) {
    for (final range in ranges) {
      if (offset >= range.start && offset < range.end) {
        return range;
      }
    }
    return null;
  }

  static List<NoteTextLinkRange> add({
    required int textLength,
    required List<NoteTextLinkRange> ranges,
    required int start,
    required int end,
    required String destination,
  }) {
    if (start < 0 || end > textLength || start >= end) {
      throw RangeError('A selected-text link must fit inside the Note body.');
    }
    if (!canAdd(ranges, start, end)) {
      throw ArgumentError('Selected-text links cannot overlap.');
    }
    final normalized = normalizeDestination(destination);
    if (normalized == null) {
      throw const FormatException(
        'Enter a complete http or https website address.',
      );
    }
    return _canonicalize([
      ...ranges,
      NoteTextLinkRange(start: start, end: end, destination: normalized),
    ]);
  }

  static List<NoteTextLinkRange> replace({
    required List<NoteTextLinkRange> ranges,
    required NoteTextLinkRange target,
    required String destination,
  }) {
    final normalized = normalizeDestination(destination);
    if (normalized == null) {
      throw const FormatException(
        'Enter a complete http or https website address.',
      );
    }
    return _canonicalize([
      for (final range in ranges)
        if (range == target) range.copyWith(destination: normalized) else range,
    ]);
  }

  static List<NoteTextLinkRange> remove(
    List<NoteTextLinkRange> ranges,
    NoteTextLinkRange target,
  ) {
    return List.unmodifiable(ranges.where((range) => range != target));
  }

  static List<NoteTextLinkRange> transformEdit({
    required String oldText,
    required String newText,
    required List<NoteTextLinkRange> ranges,
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
    final oldDestinations = _expand(oldText.length, ranges);
    final next = List<String?>.filled(newText.length, null);
    for (var index = 0; index < prefix; index++) {
      next[index] = oldDestinations[index];
    }
    for (var index = oldEnd; index < oldText.length; index++) {
      next[newEnd + index - oldEnd] = oldDestinations[index];
    }
    final inherited = _inheritedDestination(
      oldDestinations,
      start: prefix,
      end: oldEnd,
    );
    for (var index = prefix; index < newEnd; index++) {
      next[index] = inherited;
    }
    return _collapse(next);
  }

  static String? invalidReason(String text, List<NoteTextLinkRange> ranges) {
    NoteTextLinkRange? previous;
    for (final range in ranges) {
      if (range.start < 0 ||
          range.end <= range.start ||
          range.end > text.length) {
        return 'Note text-link ranges must fit inside the Note body.';
      }
      if (_splitsSurrogatePair(text, range.start) ||
          _splitsSurrogatePair(text, range.end)) {
        return 'Note text-link ranges must follow character boundaries.';
      }
      if (normalizeDestination(range.destination) != range.destination) {
        return 'A Note text-link destination must be a normalized http or https URL.';
      }
      if (previous != null) {
        if (range.start < previous.end) {
          return 'Note text-link ranges must be ordered and non-overlapping.';
        }
        if (range.start == previous.end &&
            range.destination == previous.destination) {
          return 'Adjacent Note text-link ranges with one destination must be merged.';
        }
      }
      previous = range;
    }
    return null;
  }

  static List<String?> _expand(int textLength, List<NoteTextLinkRange> ranges) {
    final destinations = List<String?>.filled(textLength, null);
    for (final range in ranges) {
      for (var index = range.start; index < range.end; index++) {
        destinations[index] = range.destination;
      }
    }
    return destinations;
  }

  static String? _inheritedDestination(
    List<String?> destinations, {
    required int start,
    required int end,
  }) {
    if (start < end) {
      final destination = destinations[start];
      if (destination != null &&
          destinations
              .getRange(start, end)
              .every((candidate) => candidate == destination)) {
        return destination;
      }
      return null;
    }
    if (start <= 0 || start >= destinations.length) {
      return null;
    }
    final left = destinations[start - 1];
    return left != null && left == destinations[start] ? left : null;
  }

  static List<NoteTextLinkRange> _collapse(List<String?> destinations) {
    final ranges = <NoteTextLinkRange>[];
    var index = 0;
    while (index < destinations.length) {
      final destination = destinations[index];
      if (destination == null) {
        index++;
        continue;
      }
      final start = index;
      index++;
      while (index < destinations.length &&
          destinations[index] == destination) {
        index++;
      }
      ranges.add(
        NoteTextLinkRange(start: start, end: index, destination: destination),
      );
    }
    return List.unmodifiable(ranges);
  }

  static List<NoteTextLinkRange> _canonicalize(List<NoteTextLinkRange> ranges) {
    final sorted = [...ranges]..sort((left, right) => left.start - right.start);
    final canonical = <NoteTextLinkRange>[];
    for (final range in sorted) {
      if (canonical.isNotEmpty &&
          canonical.last.end == range.start &&
          canonical.last.destination == range.destination) {
        final previous = canonical.removeLast();
        canonical.add(
          NoteTextLinkRange(
            start: previous.start,
            end: range.end,
            destination: range.destination,
          ),
        );
      } else {
        canonical.add(range);
      }
    }
    return List.unmodifiable(canonical);
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
