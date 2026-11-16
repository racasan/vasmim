class NoteLinkResolver {
  NoteLinkResolver._();

  static final RegExp _webUrlPattern = RegExp(
    r'https?://[^\s<>"\x27]+',
    caseSensitive: false,
  );

  static Uri? resolveSingle(String text) {
    final urls = resolveAll(text);
    return urls.length == 1 ? urls.single : null;
  }

  static Uri? resolveWhole(String text) {
    final trimmed = text.trim();
    final match = _webUrlPattern.firstMatch(trimmed);
    if (match == null || match.start != 0 || match.end != trimmed.length) {
      return null;
    }
    final urls = resolveAll(trimmed);
    if (urls.length != 1 || urls.single.toString() != trimmed) {
      return null;
    }
    return urls.single;
  }

  static List<Uri>? resolveWholeList(String text) {
    final urls = <Uri>[];
    final seen = <String>{};
    for (final rawLine in text.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final uri = resolveWhole(line);
      if (uri == null) {
        return null;
      }
      if (seen.add(uri.toString())) {
        urls.add(uri);
      }
    }
    return urls.length > 1 ? List.unmodifiable(urls) : null;
  }

  static String? resolvePlainTextFallback(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        resolveWhole(trimmed) != null ||
        resolveWholeList(trimmed) != null) {
      return null;
    }
    return trimmed;
  }

  static List<Uri> resolveAll(String text) {
    final urls = <Uri>[];
    final seen = <String>{};
    for (final match in _webUrlPattern.allMatches(text)) {
      final candidate = _trimSentencePunctuation(match.group(0)!);
      final uri = Uri.tryParse(candidate);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          (uri.scheme.toLowerCase() != 'http' &&
              uri.scheme.toLowerCase() != 'https') ||
          !seen.add(uri.toString())) {
        continue;
      }
      urls.add(uri);
    }
    return List.unmodifiable(urls);
  }

  static Uri conventionalIconUrl(Uri websiteUrl) =>
      websiteUrl.resolve('/favicon.ico');

  static String _trimSentencePunctuation(String candidate) {
    var result = candidate;
    while (result.isNotEmpty && '.,;:!?'.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1);
    }
    for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
      while (result.endsWith(pair.$2) &&
          _count(result, pair.$2) > _count(result, pair.$1)) {
        result = result.substring(0, result.length - 1);
      }
    }
    return result;
  }

  static int _count(String value, String character) =>
      value.split(character).length - 1;
}
