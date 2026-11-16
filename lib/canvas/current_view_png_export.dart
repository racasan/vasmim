import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/rendering.dart';
import 'package:super_clipboard/super_clipboard.dart';

typedef CurrentViewPngPathPicker =
    Future<String?> Function(String suggestedName);

typedef CurrentViewPngPublisher =
    Future<void> Function(String path, Uint8List bytes);

typedef CurrentViewPngCapturer =
    Future<Uint8List> Function(
      RenderRepaintBoundary boundary,
      double pixelRatio,
    );

typedef CurrentViewPngClipboardWriter = Future<void> Function(Uint8List bytes);

Future<Uint8List> captureCurrentViewPng(
  RenderRepaintBoundary boundary,
  double pixelRatio,
) async {
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode the current view');
    }
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } finally {
    image.dispose();
  }
}

String currentViewPngSuggestedName(String boardName) {
  return '${_safePngStem(boardName)} current view.png';
}

String wholeBoardPngSuggestedName(String boardName) {
  return '${_safePngStem(boardName)} whole Board.png';
}

String _safePngStem(String boardName) {
  var safeName = boardName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .trim()
      .replaceFirst(RegExp(r'[ .]+$'), '');
  if (safeName.isEmpty) {
    safeName = 'Board';
  }
  const reservedNames = {
    'CON',
    'PRN',
    'AUX',
    'NUL',
    'COM1',
    'COM2',
    'COM3',
    'COM4',
    'COM5',
    'COM6',
    'COM7',
    'COM8',
    'COM9',
    'LPT1',
    'LPT2',
    'LPT3',
    'LPT4',
    'LPT5',
    'LPT6',
    'LPT7',
    'LPT8',
    'LPT9',
  };
  if (reservedNames.contains(safeName.toUpperCase())) {
    safeName = '_$safeName';
  }
  return safeName;
}

Future<String?> pickCurrentViewPngExportPath(String suggestedName) async {
  const pngType = XTypeGroup(label: 'PNG image', extensions: ['png']);
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [pngType],
    confirmButtonText: 'Export',
  );
  final path = location?.path;
  if (path == null) {
    return null;
  }
  return path.toLowerCase().endsWith('.png') ? path : '$path.png';
}

Future<void> publishCurrentViewPng(String path, Uint8List bytes) async {
  final target = File(path);
  final directory = target.parent;
  if (!await directory.exists()) {
    throw FileSystemException(
      'Export directory does not exist',
      directory.path,
    );
  }

  final token = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
  final staged = File('${target.path}.$token.tmp');
  final backup = File('${target.path}.$token.bak');
  var movedExistingTarget = false;
  try {
    await staged.writeAsBytes(bytes, flush: true);
    if (await target.exists()) {
      await target.rename(backup.path);
      movedExistingTarget = true;
    }
    await staged.rename(target.path);
    if (movedExistingTarget && await backup.exists()) {
      await backup.delete();
    }
  } catch (_) {
    if (movedExistingTarget && await backup.exists()) {
      if (await target.exists()) {
        await target.delete();
      }
      await backup.rename(target.path);
    }
    rethrow;
  } finally {
    if (await staged.exists()) {
      await staged.delete();
    }
    if (await backup.exists()) {
      await backup.delete();
    }
  }
}

Future<void> writeCurrentViewPngToClipboard(Uint8List bytes) async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) {
    throw UnsupportedError('Clipboard API is not available');
  }
  final item = DataWriterItem(suggestedName: 'Vasmim current view.png')
    ..add(Formats.png(bytes));
  await clipboard.write([item]);
}
