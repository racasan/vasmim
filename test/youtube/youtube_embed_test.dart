import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/board_document.dart';
import 'package:vasmim/youtube/youtube_embed.dart';

void main() {
  test('persists YouTube embeds in format 14', () {
    final time = DateTime.utc(2026, 9, 8);
    final board = BoardDocument(
      id: 'youtube-board',
      name: 'YouTube',
      createdAt: time,
      modifiedAt: time,
      viewportX: 0,
      viewportY: 0,
      viewportZoom: 1,
      notes: const [],
      youTubeEmbeds: [
        YouTubeEmbed(
          id: 'youtube-1',
          x: 10,
          y: 20,
          width: 300,
          height: 168,
          originalUrl: 'https://youtu.be/dQw4w9WgXcQ',
          videoId: 'dQw4w9WgXcQ',
          thumbnailAssetPath: 'assets/youtube-preview.jpg',
          createdAt: time,
          modifiedAt: time,
        ),
      ],
    );

    final restored = BoardDocument.fromJson(board.toJson());
    expect(restored.youTubeEmbeds.single.videoId, 'dQw4w9WgXcQ');
    expect(
      restored.youTubeEmbeds.single.thumbnailAssetPath,
      'assets/youtube-preview.jpg',
    );
    expect(
      restored.toJson()['formatVersion'],
      BoardDocument.currentFormatVersion,
    );
  });

  test('rejects an unsafe YouTube thumbnail path', () {
    final time = DateTime.utc(2026, 9, 8);
    expect(
      () => BoardDocument(
        id: 'youtube-board',
        name: 'YouTube',
        createdAt: time,
        modifiedAt: time,
        viewportX: 0,
        viewportY: 0,
        viewportZoom: 1,
        notes: const [],
        youTubeEmbeds: [
          YouTubeEmbed(
            id: 'youtube-1',
            x: 10,
            y: 20,
            width: 300,
            height: 168,
            originalUrl: 'https://youtu.be/dQw4w9WgXcQ',
            videoId: 'dQw4w9WgXcQ',
            thumbnailAssetPath: '../preview.jpg',
            createdAt: time,
            modifiedAt: time,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
