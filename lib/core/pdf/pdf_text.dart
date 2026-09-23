import 'arabic_shaper.dart';

export 'arabic_shaper.dart' show containsArabic, shapeArabic;

/// Shadda-and-vowel pairs the Unicode bidirectional algorithm composes into the
/// legacy Arabic presentation ligatures.
///
/// Those code points are optional, and the bundled font has no glyphs for them —
/// so leaving them in prints a box in the middle of a word. They are expanded
/// back into their two marks, which the font does have.
const Map<int, List<int>> _markLigatures = <int, List<int>>{
  0xFC5E: <int>[0x064C, 0x0651], // shadda + dammatan
  0xFC5F: <int>[0x064D, 0x0651], // shadda + kasratan
  0xFC60: <int>[0x064E, 0x0651], // shadda + fatha
  0xFC61: <int>[0x064F, 0x0651], // shadda + damma
  0xFC62: <int>[0x0650, 0x0651], // shadda + kasra
  0xFC63: <int>[0x0670, 0x0651], // shadda + dagger alef
};

/// Replaces the legacy ligatures with the marks they stand for.
String expandMarkLigatures(String input) {
  if (!input.runes.any(_markLigatures.containsKey)) return input;
  final List<int> out = <int>[];
  for (final int code in input.runes) {
    final List<int>? parts = _markLigatures[code];
    if (parts == null) {
      out.add(code);
      continue;
    }
    out.addAll(parts);
  }
  return String.fromCharCodes(out);
}

/// Bidirectional control characters.
///
/// `intl` wraps an Arabic date's numeric runs in U+200F so that a weaker text
/// engine keeps the day, month and year in order. This renderer runs the real
/// bidirectional algorithm and has no glyph for the character — so the control
/// is not a hint here, it is a missing glyph sitting between two digits, and the
/// day comes out printed on top of itself. The algorithm already keeps a numeric
/// run left-to-right inside a right-to-left sentence, so the controls are
/// dropped rather than drawn.
bool _isBidiControl(int code) {
  return code == 0x200E || // left-to-right mark
      code == 0x200F || // right-to-left mark
      code == 0x061C || // Arabic letter mark
      (code >= 0x202A && code <= 0x202E) || // embeddings and overrides
      (code >= 0x2066 && code <= 0x2069); // isolates
}

String _stripBidiControls(String input) {
  if (!input.runes.any(_isBidiControl)) return input;
  return String.fromCharCodes(
    input.runes.where((int code) => !_isBidiControl(code)),
  );
}

/// Prepares one string for the PDF renderer.
///
/// Shaping is the only thing done here, and it is done in **logical order**: the
/// letters are replaced by the contextual forms the renderer cannot work out for
/// itself, and nothing is moved.
///
/// Ordering, line breaking and alignment are the renderer's job, and this is
/// deliberate. It is handed a right-to-left `textDirection`, which makes it
/// apply the Unicode bidirectional algorithm, arrange each line from the reading
/// side, and break lines in logical order. Reordering the string here instead —
/// which is what this file used to do — meant the width that was measured
/// belonged to one string and the width that was drawn to another, and text ran
/// off the page: a 22-character Arabic title measured 122pt in logical order and
/// drew at 92pt shaped, so a cell that looked like it had room to spare pushed
/// its last word past the margin.
///
/// The cost of leaving ordering to the renderer is that the text in the file is
/// presentation forms rather than logical Arabic, so copying a line out of a
/// statement and pasting it elsewhere gives the shaped letters. That was already
/// true of the reordered output, and it is the trade the renderer's font model
/// forces: it draws glyph by glyph and applies no OpenType features.
String pdfText(String logical) {
  if (logical.isEmpty) return logical;
  final String plain = _stripBidiControls(logical);
  final String canonical = expandMarkLigatures(plain);
  return containsArabic(canonical) ? shapeArabic(canonical) : canonical;
}
