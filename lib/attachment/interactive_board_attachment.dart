import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../canvas/foreground_item_style.dart';
import '../image/image_asset_store.dart';
import 'board_attachment.dart';

class InteractiveBoardAttachment extends StatelessWidget {
  const InteractiveBoardAttachment({
    required this.attachment,
    required this.assetStore,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
    required this.onSecondaryTapDown,
    required this.onBeginMoving,
    required this.onMove,
    required this.onEndMoving,
    this.showMediaControls = true,
    super.key,
  });

  final BoardAttachment attachment;
  final ImageAssetStore assetStore;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final GestureTapDownCallback onSecondaryTapDown;
  final ValueChanged<Offset> onBeginMoving;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEndMoving;
  final bool showMediaControls;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMedia =
        attachment.kind == AttachmentKind.video ||
        attachment.kind == AttachmentKind.audio;
    final treatment = switch (attachment.kind) {
      AttachmentKind.pdf => (
        const Color(0xfff8e7e5),
        const Color(0xffb83a32),
        Icons.picture_as_pdf_outlined,
      ),
      AttachmentKind.word => (
        const Color(0xffe7effb),
        const Color(0xff2b579a),
        Icons.description_outlined,
      ),
      AttachmentKind.spreadsheet => (
        const Color(0xffe5f4e9),
        const Color(0xff217346),
        Icons.table_chart_outlined,
      ),
      AttachmentKind.video => (
        const Color(0xffe7e8f8),
        const Color(0xff50569d),
        Icons.movie_outlined,
      ),
      AttachmentKind.audio => (
        const Color(0xffe8f4f2),
        const Color(0xff18756b),
        Icons.audiotrack_outlined,
      ),
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        key: ValueKey('attachment-card-${attachment.id}'),
        duration: const Duration(milliseconds: 120),
        width: attachment.width,
        height: attachment.height,
        padding: const EdgeInsets.all(14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: treatment.$1,
          borderRadius: BorderRadius.circular(14),
          boxShadow: ForegroundItemStyle.shadows,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSelect,
                onDoubleTap: onOpen,
                onSecondaryTapDown: onSecondaryTapDown,
                onPanStart: (details) => onBeginMoving(details.globalPosition),
                onPanUpdate: (details) => onMove(details.globalPosition),
                onPanEnd: (_) => onEndMoving(),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isMedia && showMediaControls ? 28 : 0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        key: ValueKey('attachment-preview-${attachment.id}'),
                        width: isMedia ? 50 : 72,
                        height: isMedia ? 48 : 78,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: treatment.$2,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (attachment.previewAssetPath case final path?)
                              _ManagedAttachmentPreview(
                                assetPath: path,
                                assetStore: assetStore,
                                fallbackColor: treatment.$2,
                                fallbackIcon: treatment.$3,
                              )
                            else
                              Icon(treatment.$3, color: Colors.white, size: 32),
                            Positioned(
                              right: 5,
                              bottom: 5,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: treatment.$2,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    treatment.$3,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              attachment.originalFileName,
                              key: ValueKey('attachment-name-${attachment.id}'),
                              maxLines: isMedia ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${attachment.kind.label} - ${readableByteSize(attachment.byteSize)}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (!isMedia)
                        Icon(
                          Icons.open_in_new,
                          color: scheme.onSurfaceVariant,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (isMedia && showMediaControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: TextButton.icon(
                    key: ValueKey('board-media-open-${attachment.id}'),
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 27),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text(
                      'Open in player',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagedAttachmentPreview extends StatefulWidget {
  const _ManagedAttachmentPreview({
    required this.assetPath,
    required this.assetStore,
    required this.fallbackColor,
    required this.fallbackIcon,
  });

  final String assetPath;
  final ImageAssetStore assetStore;
  final Color fallbackColor;
  final IconData fallbackIcon;

  @override
  State<_ManagedAttachmentPreview> createState() =>
      _ManagedAttachmentPreviewState();
}

class _ManagedAttachmentPreviewState extends State<_ManagedAttachmentPreview> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() async =>
      (await widget.assetStore.resolve(widget.assetPath)).readAsBytes();

  @override
  void didUpdateWidget(covariant _ManagedAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.assetStore != widget.assetStore) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null) return _fallback();
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    },
  );

  Widget _fallback() => ColoredBox(
    color: widget.fallbackColor,
    child: Icon(widget.fallbackIcon, color: Colors.white, size: 32),
  );
}

String readableByteSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(kib >= 10 ? 0 : 1)} KB';
  final mib = kib / 1024;
  if (mib < 1024) return '${mib.toStringAsFixed(mib >= 10 ? 0 : 1)} MB';
  final gib = mib / 1024;
  return '${gib.toStringAsFixed(gib >= 10 ? 0 : 1)} GB';
}
