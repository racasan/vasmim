import 'package:flutter/material.dart';

import 'note_link_resolver.dart';

typedef NoteWebsiteMarkerBuilder = Widget Function(Uri websiteUrl);

Widget buildNoteWebsiteMarker(Uri websiteUrl) =>
    NoteWebsiteMarker(websiteUrl: websiteUrl);

class NoteWebsiteMarker extends StatelessWidget {
  const NoteWebsiteMarker({
    required this.websiteUrl,
    this.imageProvider,
    super.key,
  });

  final Uri websiteUrl;
  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final iconUrl = NoteLinkResolver.conventionalIconUrl(websiteUrl);
    final fallback = Icon(
      Icons.public,
      key: const ValueKey('note-website-marker-fallback'),
      size: 18,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Tooltip(
      message: 'Website: ${websiteUrl.host}',
      child: SizedBox.square(
        dimension: 22,
        child: Center(
          child: Image(
            image: imageProvider ?? NetworkImage(iconUrl.toString()),
            width: 18,
            height: 18,
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                wasSynchronouslyLoaded || frame != null ? child : fallback,
            errorBuilder: (context, error, stackTrace) => fallback,
          ),
        ),
      ),
    );
  }
}
