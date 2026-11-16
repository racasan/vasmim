import 'dart:typed_data';

import 'package:archive/archive_io.dart';

/// Public beta budgets. Native media remains streamed rather than held in RAM.
class PortableBoardLimits {
  static const maximumEntries = 10000;
  static const maximumPackageBytes = 4 * 1024 * 1024 * 1024;
  static const maximumEntryBytes = 2 * 1024 * 1024 * 1024;
  static const maximumJsonBytes = 32 * 1024 * 1024;

  static Archive decode(InputFileStream input) {
    if (input.length > maximumPackageBytes) {
      throw const FormatException('Portable Board exceeds the 4 GiB limit.');
    }
    final directory = ZipDirectory()..read(input);
    if (directory.fileHeaders.length > maximumEntries ||
        directory.centralDirectorySize > 8 * 1024 * 1024) {
      throw const FormatException('Portable Board contains too many entries.');
    }
    var total = 0;
    for (final header in directory.fileHeaders) {
      final size = header.file?.uncompressedSize ?? header.uncompressedSize;
      total += size;
      if (size < 0 ||
          size > maximumEntryBytes ||
          header.uncompressedSize > maximumEntryBytes ||
          total > maximumPackageBytes ||
          ((header.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
        throw const FormatException(
          'Portable Board exceeds safe extraction limits.',
        );
      }
    }
    input.setPosition(0);
    return ZipDecoder().decodeStream(input, verify: true);
  }
}

/// Enforces actual decompressed output, including misleading ZIP size headers.
class LimitedArchiveOutput extends OutputStream {
  LimitedArchiveOutput(this.output, this.maximumBytes)
    : super(byteOrder: output.byteOrder);

  final OutputStream output;
  final int maximumBytes;

  @override
  int get length => output.length;

  void _check(int additional) {
    if (additional < 0 || length + additional > maximumBytes) {
      throw const FormatException(
        'Archive entry exceeds its extraction budget.',
      );
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    output.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    output.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    output.writeStream(stream);
  }

  @override
  void flush() => output.flush();
  @override
  void clear() => output.clear();
  @override
  Uint8List subset(int start, [int? end]) => output.subset(start, end);
}
