import 'package:flutter/material.dart';

class NoteMultiWebsiteMarker extends StatelessWidget {
  const NoteMultiWebsiteMarker({required this.linkCount, super.key});

  final int linkCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '$linkCount website links',
      child: SizedBox.square(
        dimension: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: Icon(
                Icons.hub_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  linkCount > 9 ? '9+' : '$linkCount',
                  key: const ValueKey('multi-website-link-count'),
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    height: 1,
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
