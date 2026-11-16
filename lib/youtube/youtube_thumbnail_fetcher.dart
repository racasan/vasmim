import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

abstract interface class YouTubeThumbnailFetcher {
  Future<Uint8List?> fetch(String videoId);
}

class NetworkYouTubeThumbnailFetcher implements YouTubeThumbnailFetcher {
  const NetworkYouTubeThumbnailFetcher();

  static const _maximumBytes = 5 * 1024 * 1024;
  static const _timeout = Duration(seconds: 10);

  @override
  Future<Uint8List?> fetch(String videoId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
      return null;
    }

    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client
          .getUrl(Uri.https('i.ytimg.com', '/vi/$videoId/hqdefault.jpg'))
          .timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'image/jpeg');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok ||
          response.headers.contentType?.mimeType != 'image/jpeg' ||
          response.contentLength > _maximumBytes) {
        await response.drain<void>();
        return null;
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_timeout)) {
        if (builder.length + chunk.length > _maximumBytes) {
          return null;
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      return bytes.isEmpty ? null : bytes;
    } on Exception {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
