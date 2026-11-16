import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vasmim/board/portable_board_limits.dart';

void main() {
  test('limits actual output even when declared sizes are misleading', () {
    final memory = OutputMemoryStream();
    final output = LimitedArchiveOutput(memory, 3);
    output.writeBytes([1, 2]);
    expect(() => output.writeBytes([3, 4]), throwsFormatException);
    expect(memory.getBytes(), [1, 2]);
  });

  test('rejects excessive archive entries before extraction', () async {
    final root = await Directory.systemTemp.createTemp('vasmim_budget_test_');
    try {
      final archive = Archive();
      for (var i = 0; i <= PortableBoardLimits.maximumEntries; i++) {
        archive.add(ArchiveFile.string('entry-$i', ''));
      }
      final file = File('${root.path}/large.vasmim');
      await file.writeAsBytes(ZipEncoder().encode(archive));
      final input = InputFileStream(file.path);
      try {
        expect(() => PortableBoardLimits.decode(input), throwsFormatException);
      } finally {
        await input.close();
      }
    } finally {
      await root.delete(recursive: true);
    }
  });
}
