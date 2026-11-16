import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/youtube/youtube_url.dart';

void main() {
  test('recognizes canonical YouTube video URL forms', () {
    expect(
      YouTubeUrl.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ')?.videoId,
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeUrl.parse('https://youtu.be/dQw4w9WgXcQ?t=4')?.videoId,
      'dQw4w9WgXcQ',
    );
    expect(
      YouTubeUrl.parse('https://www.youtube.com/shorts/dQw4w9WgXcQ')?.videoId,
      'dQw4w9WgXcQ',
    );
  });

  test('rejects non-video and non-https URLs', () {
    expect(YouTubeUrl.parse('https://example.com/watch?v=dQw4w9WgXcQ'), isNull);
    expect(YouTubeUrl.parse('http://youtu.be/dQw4w9WgXcQ'), isNull);
    expect(YouTubeUrl.parse('https://youtu.be/short'), isNull);
  });
}
