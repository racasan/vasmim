import '../shape/board_shape.dart';

class ShapeSearchResult {
  const ShapeSearchResult(this.shape);
  final BoardShape shape;
}

class ShapeSearch {
  const ShapeSearch._();

  static List<ShapeSearchResult> find(
    List<BoardShape> shapes,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final shape in shapes)
        if (shape.heading?.text.toLowerCase().contains(query) ?? false)
          ShapeSearchResult(shape),
    ];
  }
}
