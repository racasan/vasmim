import '../heading/canvas_heading.dart';

class HeadingSearchResult {
  const HeadingSearchResult({required this.heading});

  final CanvasHeading heading;
}

class HeadingSearch {
  const HeadingSearch._();

  static List<HeadingSearchResult> find(
    Iterable<CanvasHeading> headings,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final heading in headings)
        if (heading.text.toLowerCase().contains(query))
          HeadingSearchResult(heading: heading),
    ];
  }
}
