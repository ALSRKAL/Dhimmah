import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app's clock is never slowed in shipped code.
///
/// `timeDilation` was used once, in a debug build, to record a motion at a
/// speed a camera could see. The line was removed from the source but the build
/// on the phone still carried it, and every transition on that phone ran ten
/// times slower. A guard is cheaper than remembering to rebuild.
void main() {
  test("no file under lib slows the app's clock", () {
    final List<String> found = <String>[];
    for (final FileSystemEntity entity
        in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      bool inBlockComment = false;
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final ({String code, bool inBlock}) stripped =
            _withoutComments(lines[i], inBlockComment);
        inBlockComment = stripped.inBlock;
        if (stripped.code.contains('timeDilation')) {
          found.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(
      found,
      isEmpty,
      reason: 'a file under lib still slows the app: ${found.join(', ')}',
    );
  });
}

/// [line] with its comments stripped, and whether it ended inside a block.
({String code, bool inBlock}) _withoutComments(String line, bool inBlock) {
  final StringBuffer kept = StringBuffer();
  bool block = inBlock;
  int index = 0;
  while (index < line.length) {
    if (block) {
      final int end = line.indexOf('*/', index);
      if (end == -1) {
        index = line.length;
      } else {
        index = end + 2;
        block = false;
      }
      continue;
    }
    final int lineComment = line.indexOf('//', index);
    final int blockStart = line.indexOf('/*', index);
    if (lineComment != -1 &&
        (blockStart == -1 || lineComment < blockStart)) {
      kept.write(line.substring(index, lineComment));
      index = line.length;
    } else if (blockStart != -1) {
      kept.write(line.substring(index, blockStart));
      index = blockStart + 2;
      block = true;
    } else {
      kept.write(line.substring(index));
      index = line.length;
    }
  }
  return (code: kept.toString(), inBlock: block);
}
