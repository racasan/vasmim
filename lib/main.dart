import 'package:flutter/material.dart';

import 'appearance/app_appearance_store.dart';
import 'board/board_store.dart';
import 'board/board_library_screen.dart';
import 'board/board_library_store.dart';
import 'board/vasmim_application_support.dart';
import 'attachment/attachment_preview_generator.dart';
import 'attachment/attachment_asset_store.dart';
import 'canvas/canvas_experiment.dart';
import 'canvas/current_view_png_export.dart';
import 'canvas/cross_board_clipboard.dart';
import 'image/board_image.dart';
import 'image/clipboard_image_reader.dart';
import 'image/image_asset_store.dart';
import 'image/image_path_picker.dart';
import 'note/note_link_launcher.dart';
import 'note/note_website_marker.dart';
import 'youtube/youtube_thumbnail_fetcher.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({
    this.boardStore,
    this.imageAssetStore,
    this.imagePicker,
    this.imageViewBuilder,
    this.clipboardImageReader,
    this.boardLibraryStore,
    this.externalUrlLauncher,
    this.websiteIconBuilder,
    this.youTubeThumbnailFetcher,
    this.attachmentPreviewGenerator,
    this.attachmentAssetStore,
    this.currentViewPngPathPicker,
    this.currentViewPngPublisher,
    this.currentViewPngCapturer,
    this.currentViewPngClipboardWriter,
    this.crossBoardClipboard,
    this.appearanceStore,
    super.key,
  });

  final BoardStore? boardStore;
  final ImageAssetStore? imageAssetStore;
  final ImagePathPicker? imagePicker;
  final Widget Function(BoardImage image)? imageViewBuilder;
  final ClipboardImageReader? clipboardImageReader;
  final BoardLibraryStore? boardLibraryStore;
  final ExternalUrlLauncher? externalUrlLauncher;
  final NoteWebsiteMarkerBuilder? websiteIconBuilder;
  final YouTubeThumbnailFetcher? youTubeThumbnailFetcher;
  final AttachmentPreviewGenerator? attachmentPreviewGenerator;
  final AttachmentAssetStore? attachmentAssetStore;
  final CurrentViewPngPathPicker? currentViewPngPathPicker;
  final CurrentViewPngPublisher? currentViewPngPublisher;
  final CurrentViewPngCapturer? currentViewPngCapturer;
  final CurrentViewPngClipboardWriter? currentViewPngClipboardWriter;
  final CrossBoardClipboard? crossBoardClipboard;
  final AppAppearanceStore? appearanceStore;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final CrossBoardClipboard _ownedCrossBoardClipboard = CrossBoardClipboard();
  late final AppAppearanceStore _appearanceStore;
  bool _isDarkMode = false;
  bool _isAppearanceSaving = false;
  int _appearanceRevision = 0;

  CrossBoardClipboard get _crossBoardClipboard =>
      widget.crossBoardClipboard ?? _ownedCrossBoardClipboard;

  @override
  void dispose() {
    _ownedCrossBoardClipboard.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _appearanceStore =
        widget.appearanceStore ??
        (widget.boardStore != null || widget.boardLibraryStore != null
            ? MemoryAppAppearanceStore()
            : FileAppAppearanceStore());
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final revision = _appearanceRevision;
    try {
      final isDark = await _appearanceStore.readDarkMode();
      if (mounted && revision == _appearanceRevision) {
        setState(() => _isDarkMode = isDark);
      }
    } catch (_) {
      // A damaged or unavailable preference must not prevent opening Boards.
    }
  }

  Future<void> _toggleDarkMode() async {
    if (_isAppearanceSaving) return;
    final isDark = !_isDarkMode;
    final revision = ++_appearanceRevision;
    setState(() {
      _isDarkMode = isDark;
      _isAppearanceSaving = true;
    });
    try {
      await _appearanceStore.writeDarkMode(isDark);
    } catch (_) {
      if (mounted && revision == _appearanceRevision) {
        setState(() => _isDarkMode = !isDark);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save appearance preference')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAppearanceSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vasmim',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4255FF)),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B9CFF),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.boardStore == null
          ? BoardLibraryScreen(
              libraryStore:
                  widget.boardLibraryStore ??
                  FileBoardLibraryStore(
                    directoryProvider: vasmimApplicationSupportDirectory,
                  ),
              clipboardImageReader:
                  widget.clipboardImageReader ?? SystemClipboardImageReader(),
              crossBoardClipboard: _crossBoardClipboard,
              isDarkMode: _isDarkMode,
              onToggleDarkMode: _toggleDarkMode,
            )
          : CanvasExperiment(
              boardStore: widget.boardStore!,
              imageAssetStore: widget.imageAssetStore ?? FileImageAssetStore(),
              imagePicker: widget.imagePicker ?? pickImagePath,
              clipboardImageReader:
                  widget.clipboardImageReader ?? SystemClipboardImageReader(),
              imageViewBuilder: widget.imageViewBuilder,
              externalUrlLauncher: widget.externalUrlLauncher,
              websiteIconBuilder: widget.websiteIconBuilder,
              attachmentPreviewGenerator:
                  widget.attachmentPreviewGenerator ??
                  const ManagedAttachmentPreviewGenerator(),
              attachmentAssetStore: widget.attachmentAssetStore,
              youTubeThumbnailFetcher:
                  widget.youTubeThumbnailFetcher ??
                  const NetworkYouTubeThumbnailFetcher(),
              currentViewPngPathPicker:
                  widget.currentViewPngPathPicker ??
                  pickCurrentViewPngExportPath,
              currentViewPngPublisher:
                  widget.currentViewPngPublisher ?? publishCurrentViewPng,
              currentViewPngCapturer:
                  widget.currentViewPngCapturer ?? captureCurrentViewPng,
              currentViewPngClipboardWriter:
                  widget.currentViewPngClipboardWriter ??
                  writeCurrentViewPngToClipboard,
              crossBoardClipboard: _crossBoardClipboard,
              isDarkMode: _isDarkMode,
              onToggleDarkMode: _toggleDarkMode,
            ),
    );
  }
}
