import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The Dhimmah mark as a printed statement carries it.
///
/// The identity is a picture, not a drawing, and the statement shows the same
/// picture the launcher and the app show. It is embedded as a bitmap rather than
/// reconstructed as vectors, so the document cannot quietly become a different
/// logo: `tool/generate_icons.py` derives this file from the master artwork
/// along with every other icon.
///
/// The asset is 256px across a logo that prints at 26pt — about 700dpi, sharp at
/// any zoom a reader will use, and small enough that a statement stays a
/// document rather than a download.
class BrandMark {
  const BrandMark._(this._image, this.aspect);

  /// Loads the mark. Cheap, and the result is worth keeping.
  static Future<BrandMark> load() async {
    final ByteData bytes = await rootBundle.load(_assetPath);
    final Uint8List raw = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    return BrandMark._(pw.MemoryImage(raw), await _aspectOf(raw));
  }

  static const String _assetPath = 'assets/icon/mark_document.png';

  final pw.MemoryImage _image;

  /// Width divided by height, so a caller can place it without distorting it.
  final double aspect;

  /// Reads the pixel dimensions out of the PNG's own header.
  ///
  /// The renderer needs the aspect to lay the logo out, and the alternative is
  /// to write the numbers down in two places and let them disagree.
  static Future<double> _aspectOf(Uint8List png) async {
    // PNG: 8-byte signature, then the IHDR chunk — length (4), type (4),
    // width (4), height (4), all big-endian.
    if (png.length < 24 || png[0] != 0x89 || png[1] != 0x50) return 1;
    final int width = (png[16] << 24) | (png[17] << 16) | (png[18] << 8) | png[19];
    final int height = (png[20] << 24) | (png[21] << 16) | (png[22] << 8) | png[23];
    if (width <= 0 || height <= 0) return 1;
    return width / height;
  }

  /// The mark as a document widget, [height] points tall.
  pw.Widget widget({required double height}) {
    return pw.SizedBox(
      width: height * aspect,
      height: height,
      child: pw.Image(_image),
    );
  }
}
