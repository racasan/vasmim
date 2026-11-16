import '../image/board_image.dart';

class ImageSearchResult {
  const ImageSearchResult({required this.image});

  final BoardImage image;

  String get fileName => image.originalFileName;
  String? get caption => image.caption;
  String get primaryLabel => caption ?? fileName;
}

class ImageSearch {
  const ImageSearch._();

  static List<ImageSearchResult> find(
    List<BoardImage> images,
    String rawQuery,
  ) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return const [];
    }
    return [
      for (final image in images)
        if (matches(image, query)) ImageSearchResult(image: image),
    ];
  }

  static bool matches(BoardImage image, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return false;
    }
    return image.originalFileName.toLowerCase().contains(query) ||
        (image.caption?.toLowerCase().contains(query) ?? false);
  }
}
