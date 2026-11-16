class YouTubeUrl {
  const YouTubeUrl({required this.originalUrl, required this.videoId});
  final String originalUrl;
  final String videoId;

  static YouTubeUrl? parse(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    String? id;
    if (host == 'youtu.be' || host == 'www.youtu.be') {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com') {
      if (uri.path == '/watch') id = uri.queryParameters['v'];
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' ||
              uri.pathSegments.first == 'embed')) {
        id = uri.pathSegments[1];
      }
    }
    if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
    return YouTubeUrl(originalUrl: trimmed, videoId: id);
  }

  String get embedUrl =>
      'https://www.youtube-nocookie.com/embed/$videoId?autoplay=0&rel=0';
}
