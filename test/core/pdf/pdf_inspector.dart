/// Reads back what a generated PDF actually tells a viewer to draw.
///
/// This exists because "the file was produced" and "the file is correct" are
/// different claims, and only one of them can be checked by looking at the code
/// that produced it. The failure this is built for is concrete: a debt title
/// measured in one form and drawn in another, so its last word was printed past
/// the right margin and cut off — a defect that no amount of unit testing on the
/// layout code would have caught, because the layout code was doing what it was
/// told.
///
/// So these tests parse the page's own content stream, work out where every run
/// of text lands, and assert on the result: that nothing is drawn outside the
/// margins, and that a right-to-left line reads in the order a person reads it.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


/// One run of text as the page draws it.
class PdfRun {
  const PdfRun({
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.text,
  });

  final int page;

  /// The left edge, in points from the page's left.
  final double x;

  /// The baseline, in points from the page's bottom.
  final double y;

  final double width;

  /// The code points the run draws, decoded through the font's ToUnicode map.
  final String text;

  double get right => x + width;

  @override
  String toString() => 'p$page x=${x.toStringAsFixed(1)}..'
      '${right.toStringAsFixed(1)} y=${y.toStringAsFixed(1)} "$text"';
}

/// A page's drawing instructions, read back.
class PdfInspection {
  const PdfInspection({
    required this.runs,
    required this.pageCount,
    required this.width,
    required this.height,
    required this.content,
    required this.images,
  });

  final List<PdfRun> runs;
  final int pageCount;
  final double width;
  final double height;

  /// Every page's drawing instructions, decoded.
  final String content;

  /// Whether any page paints [colour], given as 0..1 RGB components — the form
  /// the renderer writes colour operators in.
  bool paints(double r, double g, double b) {
    String f(double v) => v.toStringAsFixed(5).replaceFirst(RegExp(r'0+$'), '');
    return content.contains('${f(r)} ${f(g)} ${f(b)} rg');
  }

  /// Whether any page draws an image: the `Do` operator, which invokes an
  /// XObject.
  bool get drawsImage => RegExp(r'(^| )Do( |$)').hasMatch(content);

  /// The pixel size of the first embedded image, or null if there is none.
  ///
  /// Asserting on the size rather than on the pixels says the right artwork is
  /// in the file without pinning a bitmap that would fail the moment the
  /// reference is re-exported.
  List<int>? get imageSize => images.isEmpty ? null : images.first;

  /// Every embedded image's pixel size, in the order they appear.
  final List<List<int>> images;

  /// Runs grouped into lines, each sorted left to right.
  ///
  /// A line is a set of runs sharing a baseline on one page, which is how the
  /// renderer emits them: one run per word.
  List<List<PdfRun>> get lines {
    final Map<String, List<PdfRun>> byLine = <String, List<PdfRun>>{};
    for (final PdfRun run in runs) {
      final String key = '${run.page}@${run.y.toStringAsFixed(1)}';
      (byLine[key] ??= <PdfRun>[]).add(run);
    }
    return <List<PdfRun>>[
      for (final List<PdfRun> line in byLine.values)
        line..sort((PdfRun a, PdfRun b) => a.x.compareTo(b.x)),
    ];
  }

  /// The runs of every line whose text contains [needle], in reading order.
  List<PdfRun> lineContaining(String needle) {
    for (final List<PdfRun> line in lines) {
      if (line.any((PdfRun run) => run.text.contains(needle))) return line;
    }
    return const <PdfRun>[];
  }

  /// Every line's text, left to right.
  List<String> get lineTexts => <String>[
        for (final List<PdfRun> line in lines)
          line.map((PdfRun run) => run.text).join(' '),
      ];
}

/// Parses [bytes] as a PDF and returns where its text is drawn.
PdfInspection inspectPdf(Uint8List bytes) {
  final _PdfFile file = _PdfFile(bytes);

  final List<PdfRun> runs = <PdfRun>[];
  final StringBuffer content = StringBuffer();
  int pageNumber = 0;

  for (final int page in file.objectsOfType('/Page')) {
    pageNumber++;
    final _PdfDict dict = file.dictOf(page);
    final double pageWidth = dict.mediaBoxWidth ?? 595.276;
    final double pageHeight = dict.mediaBoxHeight ?? 841.89;

    final Map<String, _PdfFont> fonts = <String, _PdfFont>{
      for (final MapEntry<String, int> entry in dict.fonts.entries)
        entry.key: file.font(entry.value),
    };

    for (final Uint8List stream in file.contentStreams(dict)) {
      content.write(latin1.decode(stream, allowInvalid: true));
      runs.addAll(
        _readContent(
          stream,
          fonts,
          page: pageNumber,
          width: pageWidth,
          height: pageHeight,
        ),
      );
    }
  }

  return PdfInspection(
    runs: runs,
    pageCount: pageNumber,
    width: 595.276,
    height: 841.89,
    content: content.toString(),
    images: file.imageSizes,
  );
}

// --- Content stream ----------------------------------------------------------

/// Walks the drawing operators and records every text run's position and size.
///
/// Only the operators the renderer actually emits for text are interpreted;
/// anything else is skipped, because the question here is where text landed, not
/// how the page was painted.
List<PdfRun> _readContent(
  Uint8List content,
  Map<String, _PdfFont> fonts, {
  required int page,
  required double width,
  required double height,
}) {
  final String source = latin1.decode(content, allowInvalid: true);
  final List<_Token> tokens = _tokenize(source);

  final List<PdfRun> runs = <PdfRun>[];

  // The graphics state stack, and the current transform. Everything the
  // renderer emits here is a translation, but the maths is kept general so a
  // scaled page would still be read correctly.
  final List<List<double>> stack = <List<double>>[];
  List<double> ctm = <double>[1, 0, 0, 1, 0, 0];

  List<double> textMatrix = <double>[1, 0, 0, 1, 0, 0];
  _PdfFont? font;
  double fontSize = 0;

  for (int i = 0; i < tokens.length; i++) {
    final _Token token = tokens[i];
    if (token.isOperand) continue;

    switch (token.value) {
      case 'q':
        stack.add(List<double>.of(ctm));
      case 'Q':
        if (stack.isNotEmpty) ctm = stack.removeLast();
      case 'cm':
        final List<double> m = _numbers(tokens, i, 6);
        if (m.length == 6) ctm = _multiply(m, ctm);
      case 'BT':
        textMatrix = <double>[1, 0, 0, 1, 0, 0];
      case 'Tf':
        final List<_Token> operands = _operands(tokens, i);
        if (operands.length >= 2) {
          // The operator names the resource as `/F6`; the resource dictionary
          // keys it as `F6`.
          font = fonts[operands[operands.length - 2].value.replaceFirst('/', '')];
          fontSize = double.tryParse(operands.last.value) ?? 0;
        }
      case 'Td' || 'TD':
        final List<double> m = _numbers(tokens, i, 2);
        if (m.length == 2) {
          textMatrix = _multiply(
            <double>[1, 0, 0, 1, m[0], m[1]],
            textMatrix,
          );
        }
      case 'Tm':
        final List<double> m = _numbers(tokens, i, 6);
        if (m.length == 6) textMatrix = m;
      case 'TJ' || 'Tj':
        if (font == null) break;
        final String? hex = _stringOperand(tokens, i);
        if (hex == null) break;

        final List<int> codes = _hexCodes(hex);
        final String text = font.decode(codes);
        final double runWidth =
            font.widthOf(codes) / 1000 * fontSize;

        // The run's origin in user space, and the scale it is drawn at.
        final List<double> full = _multiply(textMatrix, ctm);
        runs.add(
          PdfRun(
            page: page,
            x: full[4],
            y: full[5],
            width: runWidth * full[0].abs(),
            text: text,
          ),
        );
      case _:
        break;
    }
  }

  return runs;
}

/// Splits a content stream into operators and operands.
List<_Token> _tokenize(String source) {
  final List<_Token> out = <_Token>[];
  final StringBuffer word = StringBuffer();

  void flush() {
    if (word.isEmpty) return;
    final String value = word.toString();
    out.add(
      _Token(
        value,
        isOperand: _looksNumeric(value) || value.startsWith('/'),
      ),
    );
    word.clear();
  }

  for (int i = 0; i < source.length; i++) {
    final String ch = source[i];
    if (ch == '<' || ch == '[' || ch == '(') {
      flush();
      // The renderer only emits hex strings and arrays; a literal string would
      // need escape handling that nothing here produces.
      final String close = ch == '<' ? '>' : (ch == '[' ? ']' : ')');
      final int start = i + 1;
      int end = source.indexOf(close, start);
      if (end < 0) end = source.length;
      out.add(_Token(source.substring(start, end), isOperand: true));
      i = end;
      continue;
    }
    if (ch == '>' || ch == ']' || ch == ')') {
      flush();
      continue;
    }
    if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
      flush();
      continue;
    }
    word.write(ch);
  }
  flush();
  return out;
}

bool _looksNumeric(String value) {
  if (value.isEmpty) return false;
  final String first = value[0];
  return first == '-' || first == '+' || first == '.' || _isDigit(first);
}

bool _isDigit(String ch) => ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

/// The operands immediately before the operator at [index].
List<_Token> _operands(List<_Token> tokens, int index) {
  final List<_Token> out = <_Token>[];
  for (int i = index - 1; i >= 0 && tokens[i].isOperand; i--) {
    out.insert(0, tokens[i]);
  }
  return out;
}

List<double> _numbers(List<_Token> tokens, int index, int count) {
  final List<_Token> operands = _operands(tokens, index);
  if (operands.length < count) return const <double>[];
  return <double>[
    for (final _Token token in operands.skip(operands.length - count))
      double.tryParse(token.value) ?? 0,
  ];
}

/// The hex the text-showing operand holds, for `TJ` and `Tj`.
///
/// `TJ` takes an array of strings and adjustments, and the tokenizer hands the
/// array over whole — so the hex strings inside it are collected here and the
/// numbers between them ignored. A `Tj` takes the string directly.
String? _stringOperand(List<_Token> tokens, int index) {
  for (int i = index - 1; i >= 0 && tokens[i].isOperand; i--) {
    final String value = tokens[i].value;
    final Iterable<RegExpMatch> inner =
        RegExp(r'<([0-9A-Fa-f]*)>').allMatches(value);
    if (inner.isNotEmpty) {
      return inner.map((RegExpMatch m) => m.group(1)!).join();
    }
    if (value.length >= 2 && value.codeUnits.every(_isHexDigit)) return value;
  }
  return null;
}

bool _isHexDigit(int code) {
  return (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x46) ||
      (code >= 0x61 && code <= 0x66);
}

List<int> _hexCodes(String hex) {
  final List<int> out = <int>[];
  for (int i = 0; i + 3 < hex.length; i += 4) {
    out.add(int.parse(hex.substring(i, i + 4), radix: 16));
  }
  return out;
}

/// [a] then [b]: the matrix product, PDF order.
List<double> _multiply(List<double> a, List<double> b) {
  return <double>[
    a[0] * b[0] + a[1] * b[2],
    a[0] * b[1] + a[1] * b[3],
    a[2] * b[0] + a[3] * b[2],
    a[2] * b[1] + a[3] * b[3],
    a[4] * b[0] + a[5] * b[2] + b[4],
    a[4] * b[1] + a[5] * b[3] + b[5],
  ];
}

class _Token {
  const _Token(this.value, {required this.isOperand});

  final String value;
  final bool isOperand;
}

// --- File structure ----------------------------------------------------------

/// A font as the PDF describes it: how to read its codes, and how wide they are.
class _PdfFont {
  _PdfFont(this._toUnicode, this._widths, this._defaultWidth);

  final Map<int, String> _toUnicode;
  final Map<int, double> _widths;
  final double _defaultWidth;

  String decode(List<int> codes) {
    final StringBuffer out = StringBuffer();
    for (final int code in codes) {
      out.write(_toUnicode[code] ?? '');
    }
    return out.toString();
  }

  double widthOf(List<int> codes) {
    double total = 0;
    for (final int code in codes) {
      total += _widths[code] ?? _defaultWidth;
    }
    return total;
  }
}

class _PdfDict {
  const _PdfDict(this.raw);

  final String raw;

  Map<String, int> get fonts {
    final int at = raw.indexOf('/Font');
    if (at < 0) return const <String, int>{};
    final String slice = raw.substring(at);
    return <String, int>{
      for (final RegExpMatch match
          in RegExp(r'/(F\d+)\s+(\d+)\s+0\s+R').allMatches(slice))
        match.group(1)!: int.parse(match.group(2)!),
    };
  }

  List<int> get contents {
    final RegExpMatch? single =
        RegExp(r'/Contents\s+(\d+)\s+0\s+R').firstMatch(raw);
    if (single != null) return <int>[int.parse(single.group(1)!)];
    final RegExpMatch? many =
        RegExp(r'/Contents\s*\[([^\]]*)\]').firstMatch(raw);
    if (many == null) return const <int>[];
    return <int>[
      for (final RegExpMatch match
          in RegExp(r'(\d+)\s+0\s+R').allMatches(many.group(1)!))
        int.parse(match.group(1)!),
    ];
  }

  double? get mediaBoxWidth {
    final RegExpMatch? match =
        RegExp(r'/MediaBox\s*\[([^\]]*)\]').firstMatch(raw);
    if (match == null) return null;
    final List<double> values = <double>[
      for (final String part in match.group(1)!.trim().split(RegExp(r'\s+')))
        double.tryParse(part) ?? 0,
    ];
    if (values.length != 4) return null;
    return values[2] - values[0];
  }

  double? get mediaBoxHeight {
    final RegExpMatch? match =
        RegExp(r'/MediaBox\s*\[([^\]]*)\]').firstMatch(raw);
    if (match == null) return null;
    final List<double> values = <double>[
      for (final String part in match.group(1)!.trim().split(RegExp(r'\s+')))
        double.tryParse(part) ?? 0,
    ];
    if (values.length != 4) return null;
    return values[3] - values[1];
  }
}

/// Enough of the PDF container to find the pages and read their text.
class _PdfFile {
  _PdfFile(this._bytes) {
    for (final RegExpMatch match
        in RegExp(r'(\d+)\s+0\s+obj').allMatches(latin1.decode(
      _bytes,
      allowInvalid: true,
    ))) {
      _objects[int.parse(match.group(1)!)] = match.end;
    }
  }

  final Uint8List _bytes;
  final Map<int, int> _objects = <int, int>{};
  final Map<int, _PdfDict> _dicts = <int, _PdfDict>{};
  final Map<int, _PdfFont> _fonts = <int, _PdfFont>{};

  String get _text => latin1.decode(_bytes, allowInvalid: true);

  int _endOf(int object) {
    final int at = _text.indexOf('endobj', _objects[object]!);
    return at < 0 ? _text.length : at;
  }

  /// The object's dictionary, with nested dictionaries balanced.
  _PdfDict dictOf(int object) {
    final _PdfDict? cached = _dicts[object];
    if (cached != null) return cached;

    final String source = _text;
    int at = _objects[object]!;
    while (at < source.length && source[at] != '<') {
      at++;
    }
    int depth = 0;
    int end = at;
    for (; end < source.length - 1; end++) {
      if (source[end] == '<' && source[end + 1] == '<') {
        depth++;
        end++;
      } else if (source[end] == '>' && source[end + 1] == '>') {
        depth--;
        end++;
        if (depth == 0) break;
      }
    }
    final _PdfDict dict = _PdfDict(source.substring(at, end + 1));
    _dicts[object] = dict;
    return dict;
  }

  /// Every object whose dictionary names [type].
  List<int> objectsOfType(String type) {
    final List<int> out = <int>[];
    for (final int object in _objects.keys.toList()..sort()) {
      final String head = _text.substring(
        _objects[object]!,
        _endOf(object).clamp(_objects[object]!, _text.length),
      );
      // `/Type/Pages` contains `/Type/Page`, and the page tree is not a page.
      if (type == '/Page' && head.contains('/Type/Pages')) continue;
      if (head.contains('/Type$type')) out.add(object);
    }
    return out;
  }

  /// The text of an object that is an array, such as a font's width table.
  ///
  /// `/W [0 10 0 R]` points at an array object rather than a stream, and reading
  /// it as a stream picks up whichever stream happens to follow it in the file —
  /// which is how a width table silently becomes nonsense.
  String array(int object) {
    final String source = _text;
    int at = _objects[object]!;
    while (at < source.length && source[at] != '[') {
      at++;
    }
    int depth = 0;
    int end = at;
    for (; end < source.length; end++) {
      if (source[end] == '[') {
        depth++;
      } else if (source[end] == ']') {
        depth--;
        if (depth == 0) break;
      }
    }
    return source.substring(at, end + 1);
  }

  /// The decoded bytes of an object's stream.
  Uint8List stream(int object) {
    final int at = _text.indexOf('stream', _objects[object]!);
    if (at < 0) return Uint8List(0);
    int start = at + 'stream'.length;
    if (_text[start] == '\r') start++;
    if (_text[start] == '\n') start++;
    final int end = _text.indexOf('endstream', start);
    final Uint8List raw =
        Uint8List.sublistView(_bytes, start, end < 0 ? _bytes.length : end);
    final String dict = _text.substring(_objects[object]!, at);
    if (dict.contains('/FlateDecode')) {
      return Uint8List.fromList(ZLibDecoder().convert(raw));
    }
    return raw;
  }

  /// Every embedded image's pixel size.
  ///
  /// Images are `/Subtype/Image`, not `/Type/Image` — the resource dictionary
  /// keys them by subtype.
  List<List<int>> get imageSizes {
    final List<List<int>> out = <List<int>>[];
    for (final int object in _objects.keys.toList()..sort()) {
      final int end = _endOf(object).clamp(_objects[object]!, _text.length);
      final String head = _text.substring(_objects[object]!, end);
      if (!head.contains('/Subtype/Image')) continue;
      final RegExpMatch? w = RegExp(r'/Width\s+(\d+)').firstMatch(head);
      final RegExpMatch? h = RegExp(r'/Height\s+(\d+)').firstMatch(head);
      if (w != null && h != null) {
        out.add(<int>[int.parse(w.group(1)!), int.parse(h.group(1)!)]);
      }
    }
    return out;
  }

  List<Uint8List> contentStreams(_PdfDict dict) => <Uint8List>[
        for (final int object in dict.contents) stream(object),
      ];

  _PdfFont font(int object) {
    final _PdfFont? cached = _fonts[object];
    if (cached != null) return cached;

    final _PdfDict dict = dictOf(object);
    final Map<int, String> toUnicode = <int, String>{};

    final RegExpMatch? cmapRef =
        RegExp(r'/ToUnicode\s+(\d+)\s+0\s+R').firstMatch(dict.raw);
    if (cmapRef != null) {
      final String cmap = latin1.decode(
        stream(int.parse(cmapRef.group(1)!)),
        allowInvalid: true,
      );
      for (final RegExpMatch match
          in RegExp(r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]+)>')
              .allMatches(cmap)) {
        final int code = int.parse(match.group(1)!, radix: 16);
        final String target = match.group(2)!;
        final StringBuffer text = StringBuffer();
        for (int i = 0; i + 3 < target.length; i += 4) {
          text.writeCharCode(int.parse(target.substring(i, i + 4), radix: 16));
        }
        toUnicode[code] = text.toString();
      }
    }

    // Widths are published as `[startCid <array>]`, the array holding one width
    // per code point from that start.
    final Map<int, double> widths = <int, double>{};
    double defaultWidth = 1000;
    final RegExpMatch? dw =
        RegExp(r'/DW\s+([\d.]+)').firstMatch(dict.raw);
    if (dw != null) defaultWidth = double.tryParse(dw.group(1)!) ?? 1000;

    final RegExpMatch? wRef =
        RegExp(r'/W\s*\[\s*(\d+)\s+(\d+)\s+0\s+R').firstMatch(dict.raw);
    if (wRef != null) {
      final int firstCid = int.parse(wRef.group(1)!);
      final List<String> parts = array(int.parse(wRef.group(2)!))
          .replaceAll(RegExp(r'[\[\]]'), ' ')
          .trim()
          .split(RegExp(r'\s+'));
      for (int i = 0; i < parts.length; i++) {
        final double? width = double.tryParse(parts[i]);
        if (width != null) widths[firstCid + i] = width;
      }
    }

    final _PdfFont parsed = _PdfFont(toUnicode, widths, defaultWidth);
    _fonts[object] = parsed;
    return parsed;
  }
}

/// Writes the runs of a document to a file, for a person to read.
Future<void> dumpRuns(String path, PdfInspection inspection) async {
  final StringBuffer out = StringBuffer();
  for (final PdfRun run in inspection.runs) {
    out.writeln(run);
  }
  await File(path).writeAsString(out.toString(), flush: true);
}
