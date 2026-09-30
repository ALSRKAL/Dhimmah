import 'arabic_shaper.dart';

export 'arabic_shaper.dart' show containsArabic, isCombiningMark, shapeArabic;

/// The shadda, which doubles the letter it sits on.
const int _shadda = 0x0651;

/// A shadda and a vowel written as one of the legacy presentation ligatures.
bool _isShaddaLigature(int code) => code >= 0xFC5E && code <= 0xFC63;

bool _isShadda(int code) => code == _shadda || _isShaddaLigature(code);

/// The vowels written under a letter: kasra and kasratan.
bool _isBelowVowel(int code) => code == 0x0650 || code == 0x064D;

/// The vowels written over a letter that a shadda can carry: fathatan,
/// dammatan, fatha, damma and the dagger alef.
bool _isAboveVowel(int code) =>
    code == 0x064B ||
    code == 0x064C ||
    code == 0x064E ||
    code == 0x064F ||
    code == 0x0670;

/// Keeps only the marks the page can draw where they belong.
///
/// The renderer positions no marks: each is drawn where the bundled font's
/// outline puts it, and in that font every mark sits above the letter until
/// positioning moves it. Two cases come out wrong, and are rewritten here:
///
///  * **A shadda with a vowel.** The renderer's own bidirectional pass joins
///    the pair into one of the legacy ligatures U+FC5E–U+FC63, and the font has
///    none of them, so «دفعة مسدَّدة» printed a box where «دَّ» was. Splitting
///    the ligature back into two marks, as this file used to, only handed the
///    renderer the pair to join again. The shadda is kept and the vowel
///    dropped: «مسدّدة», which is how the word is usually written.
///  * **A kasra or kasratan.** It is drawn over the letter, where it reads as a
///    fatha, so «مِن» would print as «مَن». It is dropped, which leaves the word
///    unvowelled rather than wrong.
///
/// Every other mark is drawn as written.
String drawableMarks(String input) {
  final List<int> codes = input.runes.toList(growable: false);
  if (!codes.any((int code) => _isShadda(code) || _isBelowVowel(code))) {
    return input;
  }
  final List<int> out = <int>[];
  int start = 0;
  while (start < codes.length) {
    // One letter and the marks written on it.
    int end = start + 1;
    while (end < codes.length && isCombiningMark(codes[end])) {
      end++;
    }
    final List<int> cluster = codes.sublist(start, end);
    final bool doubled = cluster.any(_isShadda);
    bool shaddaWritten = false;
    for (final int code in cluster) {
      if (_isBelowVowel(code)) continue;
      if (doubled && _isAboveVowel(code)) continue;
      if (_isShadda(code)) {
        if (!shaddaWritten) out.add(_shadda);
        shaddaWritten = true;
        continue;
      }
      out.add(code);
    }
    start = end;
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

/// Prepares one string, or one word, for the page.
///
/// Shaping is done here, in **logical order**: the letters are replaced by the
/// contextual forms the renderer cannot work out for itself, the marks it
/// cannot draw are dealt with ([drawableMarks]), and nothing is moved.
///
/// Ordering is not done on a whole string. A line is broken first, in logical
/// order, and only then are its words put in drawing order
/// ([visualWordOrder]) and each word's letters reversed ([reversedArabicWord]),
/// so the width that is measured and the width that is drawn belong to the
/// same text. Reordering a whole string before breaking it — which is what
/// this file once did — measured one string and drew another: a 22-character
/// Arabic title measured 122pt in logical order and drew at 92pt shaped, so a
/// cell that looked like it had room to spare pushed its last word past the
/// margin.
///
/// The text in the file is presentation forms rather than logical Arabic, so
/// copying a line out of a statement and pasting it elsewhere gives the shaped
/// letters. That is the trade the renderer's font model forces: it draws glyph
/// by glyph and applies no OpenType features.
String pdfText(String logical) {
  if (logical.isEmpty) return logical;
  final String plain = _stripBidiControls(logical);
  final String canonical = drawableMarks(plain);
  return containsArabic(canonical) ? shapeArabic(canonical) : canonical;
}

/// Punctuation that can sit in or beside an Arabic word without changing how
/// it is ordered or drawn: none of it mirrors, none of it belongs to a number,
/// and the renderer draws each as written. The ellipsis is not one of them —
/// the renderer prints «…» as three full stops.
const Set<int> _plainPunctuation = <int>{
  0x0021, // !
  0x0022, // "
  0x0027, // '
  0x002C, // ,
  0x002D, // -
  0x002E, // .
  0x003A, // :
  0x003B, // ;
  0x003F, // ?
  0x00B7, // ·
  0x060C, // ،
  0x061B, // ؛
  0x061F, // ؟
  0x06D4, // ۔
};

/// A code point of the Arabic [shapeArabic] shapes: the letters of the Arabic
/// alphabet, the tatweel, the marks, and the presentation forms it produces.
///
/// The letters other languages add — Persian «گ», «پ», «ی», Urdu's — are left
/// out, and so are the digits and the ornate parentheses: the renderer shapes
/// and orders those itself, better than handing it a guess would.
bool _isShapedArabic(int code) =>
    (code >= 0x0621 && code <= 0x063A) ||
    (code >= 0x0640 && code <= 0x065F) ||
    code == 0x0670 ||
    (code >= 0xFE70 && code <= 0xFEFC);

/// One Arabic word in the order it is drawn, or null when the renderer has to
/// order it.
///
/// [shaped] is a word as [pdfText] returns it. Made of Arabic letters, their
/// marks and plain punctuation, it is drawn right to left by reversing it,
/// marks included: that is the order the renderer's own bidirectional pass
/// gives such a word. What differs is where the word lands. Handed over already
/// reversed, with no direction to resolve, it is placed by its advance, like
/// any word; handed over as right-to-left, it is placed by its ink and moves
/// inside its own box, so the colon of «سلفة شخصية:» pushed the next word a
/// point away. A digit, a Latin letter, a bracket or a letter [shapeArabic]
/// does not know makes a word something the renderer has to order, and it is
/// left to it.
String? reversedArabicWord(String shaped) {
  bool arabic = false;
  for (final int code in shaped.runes) {
    if (_isShapedArabic(code)) {
      arabic = true;
    } else if (!_plainPunctuation.contains(code)) {
      return null;
    }
  }
  if (!arabic) return null;
  return String.fromCharCodes(shaped.runes.toList(growable: false).reversed);
}

/// The right-to-left mark. The renderer's bidirectional pass takes it out of
/// what it draws.
const int _rightToLeftMark = 0x200F;

/// An Arabic-script letter, as written or as a presentation form: a character
/// that is strong right-to-left.
bool _isArabicLetter(int code) =>
    (code >= 0x0620 && code <= 0x064A) ||
    (code >= 0x066E && code <= 0x066F) ||
    (code >= 0x0671 && code <= 0x06D3) ||
    code == 0x06D5 ||
    (code >= 0x06EE && code <= 0x06EF) ||
    (code >= 0x06FA && code <= 0x06FF) ||
    (code >= 0x0750 && code <= 0x077F) ||
    (code >= 0xFB50 && code <= 0xFD3D) ||
    (code >= 0xFD50 && code <= 0xFDFF) ||
    (code >= 0xFE70 && code <= 0xFEFC);

/// [shaped], safe to hand to the renderer as right-to-left text.
///
/// The renderer's bidirectional pass throws when a paragraph opens with a
/// letter that comes apart into several — «لا» and the other lam-alefs, or an
/// «أ» or «ؤ» carrying a vowel — so a statement for «لانا», or with a debt
/// called «لابتوب», could not be generated at all. Run over every Arabic
/// string the app has and each of its words, 58 threw, every one on its first
/// letter. A line that opens with an Arabic letter is therefore given a
/// right-to-left mark to start with, and none of them throws. The mark is
/// strong right-to-left, like the letter it goes before, so the line's
/// direction is unchanged; and the pass removes it, so nothing is drawn for it.
String rightToLeftParagraphs(String shaped) {
  bool opensWithArabic(String line) =>
      line.isNotEmpty && _isArabicLetter(line.runes.first);

  final List<String> lines = shaped.split('\n');
  if (!lines.any(opensWithArabic)) return shaped;
  return <String>[
    for (final String line in lines)
      opensWithArabic(line)
          ? '${String.fromCharCode(_rightToLeftMark)}$line'
          : line,
  ].join('\n');
}

/// Which way a word runs, for [visualWordOrder].
enum _WordDirection { rtl, ltr, neutral }

final RegExp _latinOrDigit = RegExp(r'[\p{L}\p{Nd}]', unicode: true);
final RegExp _latinLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _currencySign = RegExp(r'^\p{Sc}+$', unicode: true);

_WordDirection _classify(String word) {
  if (containsArabic(word)) return _WordDirection.rtl;
  if (_latinOrDigit.hasMatch(word)) return _WordDirection.ltr;
  return _WordDirection.neutral;
}

/// Whether a run of [words] reads right to left: the way its first letter
/// does, digits not deciding, or [fallback] when it has no letter at all.
bool readsRightToLeft(List<String> words, {required bool fallback}) {
  for (final String word in words) {
    final _WordDirection direction = _classify(word);
    if (direction == _WordDirection.rtl) return true;
    if (direction == _WordDirection.ltr && _latinLetter.hasMatch(word)) {
      return false;
    }
  }
  return fallback;
}

/// The words of one line, in the order they are drawn from left to right.
///
/// [words] are in reading order and already shaped. The line runs the way its
/// first letter does (digits do not decide, as in the Unicode bidirectional
/// algorithm), or [fallbackRightToLeft] when it has none. A right-to-left line
/// is drawn from the right, so its words come out reversed, except for a run of
/// left-to-right words inside it — a number, a Latin name — which keeps its own
/// order; a left-to-right line keeps its order except inside a run of
/// right-to-left words. A mark between two words takes their direction when
/// they agree and the line's when they do not, and a currency sign stays with
/// the number beside it, so «₹ 45,500» is never split from its amount.
///
/// This is the algorithm at the level of whole words, which is all one line of
/// a statement needs: each word is then drawn on its own, its letters ordered
/// by [reversedArabicWord] or, when that cannot, by the renderer.
///
/// A line broken out of a longer paragraph runs the way the paragraph does, so
/// [rightToLeft] can be given, from [readsRightToLeft] over the whole of it.
List<String> visualWordOrder(
  List<String> words, {
  required bool fallbackRightToLeft,
  bool? rightToLeft,
}) {
  final List<_WordDirection> strong = words.map(_classify).toList();
  final bool lineRightToLeft = rightToLeft ??
      readsRightToLeft(words, fallback: fallbackRightToLeft);
  final _WordDirection base =
      lineRightToLeft ? _WordDirection.rtl : _WordDirection.ltr;

  _WordDirection? nearest(int from, int step) {
    for (int i = from + step; i >= 0 && i < words.length; i += step) {
      if (strong[i] != _WordDirection.neutral) return strong[i];
    }
    return null;
  }

  final List<_WordDirection> resolved = <_WordDirection>[
    for (int i = 0; i < words.length; i++)
      if (strong[i] != _WordDirection.neutral)
        strong[i]
      else if (_currencySign.hasMatch(words[i]) &&
          (nearest(i, -1) == _WordDirection.ltr ||
              nearest(i, 1) == _WordDirection.ltr))
        _WordDirection.ltr
      else if (nearest(i, -1) != null && nearest(i, -1) == nearest(i, 1))
        nearest(i, -1)!
      else
        base,
  ];

  // Runs of words going the same way, each kept together.
  final List<List<String>> runs = <List<String>>[];
  final List<_WordDirection> runDirections = <_WordDirection>[];
  for (int i = 0; i < words.length; i++) {
    if (runs.isEmpty || runDirections.last != resolved[i]) {
      runs.add(<String>[]);
      runDirections.add(resolved[i]);
    }
    runs.last.add(words[i]);
  }

  final Iterable<int> order = lineRightToLeft
      ? List<int>.generate(runs.length, (int i) => runs.length - 1 - i)
      : List<int>.generate(runs.length, (int i) => i);
  return <String>[
    for (final int run in order)
      ...(runDirections[run] == _WordDirection.rtl
          ? runs[run].reversed
          : runs[run]),
  ];
}
