import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'board_image.dart';
import 'image_asset_store.dart';

class ManagedImageView extends StatefulWidget {
  const ManagedImageView({
    required this.image,
    required this.assetStore,
    this.isPlaying = false,
    this.onTogglePlayback,
    super.key,
  });

  final BoardImage image;
  final ImageAssetStore assetStore;
  final bool isPlaying;
  final VoidCallback? onTogglePlayback;

  @override
  State<ManagedImageView> createState() => _ManagedImageViewState();
}

class _ManagedImageViewState extends State<ManagedImageView> {
  late Future<_LoadedImage> _loaded;

  @override
  void initState() {
    super.initState();
    _loaded = _loadImage();
  }

  @override
  void didUpdateWidget(covariant ManagedImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetStore != widget.assetStore ||
        oldWidget.image.assetPath != widget.image.assetPath) {
      _loaded.then((value) => value.dispose(), onError: (_) {});
      _loaded = _loadImage();
    }
  }

  @override
  void dispose() {
    _loaded.then((value) => value.dispose(), onError: (_) {});
    super.dispose();
  }

  Future<_LoadedImage> _loadImage() async {
    final file = await widget.assetStore.resolve(widget.image.assetPath);
    final bytes = await file.readAsBytes();
    if (!widget.image.isGif) return _LoadedImage(bytes: bytes);
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return _LoadedImage(bytes: bytes, poster: frame.image);
    } finally {
      codec.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.image.width,
      height: widget.image.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F8),
              border: Border.all(color: const Color(0xFF8B93A7)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: FutureBuilder<_LoadedImage>(
                key: ValueKey(_loaded),
                future: _loaded,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MissingImagePlaceholder(image: widget.image);
                  }
                  final loaded = snapshot.data;
                  if (loaded == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (widget.image.isGif && !widget.isPlaying) {
                    return RawImage(image: loaded.poster, fit: BoxFit.contain);
                  }
                  return Image.memory(
                    loaded.bytes,
                    key: ValueKey('managed-image-file-${widget.image.id}'),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _MissingImagePlaceholder(image: widget.image),
                  );
                },
              ),
            ),
          ),
          if (widget.image.isGif && widget.onTogglePlayback != null)
            Positioned(
              top: 8,
              right: 8,
              child: Tooltip(
                message: widget.isPlaying ? 'Pause GIF' : 'Play GIF',
                child: FilledButton.tonalIcon(
                  key: ValueKey('gif-playback-${widget.image.id}'),
                  onPressed: widget.onTogglePlayback,
                  icon: Icon(widget.isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(widget.isPlaying ? 'Pause GIF' : 'Play GIF'),
                ),
              ),
            ),
          if (widget.image.caption case final caption?)
            _ImageCaptionBand(imageId: widget.image.id, caption: caption),
        ],
      ),
    );
  }
}

class _LoadedImage {
  const _LoadedImage({required this.bytes, this.poster});

  final Uint8List bytes;
  final ui.Image? poster;

  void dispose() => poster?.dispose();
}

class _ImageCaptionBand extends StatelessWidget {
  const _ImageCaptionBand({required this.imageId, required this.caption});

  final String imageId;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 1,
      right: 1,
      bottom: 1,
      child: IgnorePointer(
        child: DecoratedBox(
          key: ValueKey('image-caption-band-$imageId'),
          decoration: const BoxDecoration(
            color: Color(0xB8191D27),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 42, 6),
            child: Text(
              caption,
              key: ValueKey('image-caption-text-$imageId'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingImagePlaceholder extends StatelessWidget {
  const _MissingImagePlaceholder({required this.image});

  final BoardImage image;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Image unavailable: ${image.originalFileName}',
      child: Center(
        key: ValueKey('missing-image-${image.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, size: 36),
              const SizedBox(height: 8),
              const Text(
                'Image unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                image.originalFileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
