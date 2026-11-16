import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../canvas/foreground_item_style.dart';
import '../image/image_asset_store.dart';
import 'youtube_embed.dart';

class InteractiveYouTubeEmbed extends StatelessWidget {
  const InteractiveYouTubeEmbed({
    required this.embed,
    required this.assetStore,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
    required this.onSecondaryTapDown,
    required this.onBeginMoving,
    required this.onMove,
    required this.onEndMoving,
    this.showInteractionChrome = true,
    super.key,
  });

  final YouTubeEmbed embed;
  final ImageAssetStore assetStore;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final GestureTapDownCallback onSecondaryTapDown;
  final ValueChanged<Offset> onBeginMoving;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEndMoving;
  final bool showInteractionChrome;

  @override
  Widget build(BuildContext context) => GestureDetector(
    dragStartBehavior: DragStartBehavior.down,
    onTap: onSelect,
    onSecondaryTapDown: onSecondaryTapDown,
    onPanStart: (details) => onBeginMoving(details.globalPosition),
    onPanUpdate: (details) => onMove(details.globalPosition),
    onPanEnd: (_) => onEndMoving(),
    child: Container(
      key: ValueKey('youtube-card-${embed.id}'),
      width: embed.width,
      height: embed.height,
      decoration: BoxDecoration(
        color: const Color(0xff291719),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : const Color(0xffbc3e42),
          width: isSelected ? 3 : 1.5,
        ),
        boxShadow: ForegroundItemStyle.shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Open video on YouTube',
              child: Semantics(
                link: true,
                label: 'Open video on YouTube',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: ValueKey('youtube-open-${embed.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (HardwareKeyboard.instance.isControlPressed) {
                        onSelect();
                      } else {
                        onOpen();
                      }
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (embed.thumbnailAssetPath case final path?)
                          _ManagedYouTubeThumbnail(
                            key: ValueKey('youtube-thumbnail-${embed.id}'),
                            assetPath: path,
                            assetStore: assetStore,
                          )
                        else
                          const ColoredBox(color: Color(0xff291719)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xcc160b0c)],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: Colors.white,
                            size: 48,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          bottom: 10,
                          child: Row(
                            children: [
                              Text(
                                'Open in YouTube',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.open_in_new,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showInteractionChrome)
            Tooltip(
              message: 'Select or drag this card',
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: GestureDetector(
                  key: ValueKey('youtube-select-${embed.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onSelect,
                  child: const SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        SizedBox(width: 8),
                        Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: Colors.white70,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'YouTube video',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ManagedYouTubeThumbnail extends StatefulWidget {
  const _ManagedYouTubeThumbnail({
    required this.assetPath,
    required this.assetStore,
    super.key,
  });

  final String assetPath;
  final ImageAssetStore assetStore;

  @override
  State<_ManagedYouTubeThumbnail> createState() =>
      _ManagedYouTubeThumbnailState();
}

class _ManagedYouTubeThumbnailState extends State<_ManagedYouTubeThumbnail> {
  late Future<Uint8List> _bytes = _loadBytes();

  Future<Uint8List> _loadBytes() async {
    final file = await widget.assetStore.resolve(widget.assetPath);
    return file.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant _ManagedYouTubeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.assetStore != widget.assetStore) {
      _bytes = _loadBytes();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) {
        return const ColoredBox(color: Color(0xff291719));
      }
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xff291719)),
      );
    },
  );
}
