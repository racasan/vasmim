import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfAttachmentViewer extends StatefulWidget {
  const PdfAttachmentViewer({
    required this.file,
    required this.fileName,
    required this.onOpenExternally,
    super.key,
  });

  final File file;
  final String fileName;
  final Future<void> Function() onOpenExternally;

  @override
  State<PdfAttachmentViewer> createState() => _PdfAttachmentViewerState();
}

class _PdfAttachmentViewerState extends State<PdfAttachmentViewer> {
  late final PdfController _controller;
  int _page = 1;
  int? _pageCount;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = PdfController(
      document: PdfDocument.openFile(widget.file.path),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _moveTo(int page) {
    if (_pageCount == null || page < 1 || page > _pageCount!) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              key: const ValueKey('pdf-previous-page-button'),
              tooltip: 'Previous page',
              onPressed: _page > 1 ? () => _moveTo(_page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(_pageCount == null ? 'Loading...' : '$_page / $_pageCount'),
            IconButton(
              key: const ValueKey('pdf-next-page-button'),
              tooltip: 'Next page',
              onPressed: _pageCount != null && _page < _pageCount!
                  ? () => _moveTo(_page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              key: const ValueKey('pdf-open-externally-button'),
              tooltip: 'Open externally',
              onPressed: widget.onOpenExternally,
              icon: const Icon(Icons.open_in_new),
            ),
            IconButton(
              key: const ValueKey('close-pdf-viewer-button'),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: _error == null
            ? PdfView(
                controller: _controller,
                scrollDirection: Axis.vertical,
                onDocumentLoaded: (document) =>
                    setState(() => _pageCount = document.pagesCount),
                onPageChanged: (page) => setState(() => _page = page),
                onDocumentError: (error) => setState(() => _error = error),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text('Vasmim could not display this PDF.'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const ValueKey('pdf-error-open-externally-button'),
                        onPressed: widget.onOpenExternally,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open externally'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
