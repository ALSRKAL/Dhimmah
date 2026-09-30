/// Arabic contextual shaping.
///
/// The PDF library Dhimmah uses lays text out glyph by glyph and does **not**
/// apply the font's OpenType features, so Arabic handed to it raw comes out as
/// disconnected letters — the single most obvious sign of a document that was not
/// built for this script. This file does the shaping the renderer cannot: each
/// letter is replaced by the form it takes in context, and the obligatory
/// lam-alef ligatures are resolved.
///
/// The output is Unicode Arabic Presentation Forms (U+FB50–U+FEFF), which the
/// bundled IBM Plex Sans Arabic covers for every form the language needs.
///
/// Everything here is a pure function over code points, so it is fully testable
/// without a renderer.
library;

/// A letter and the four shapes it can take.
///
/// A form is `null` when the letter never takes it — `ا`, `د`, `ر`, `و` and `ز`
/// never join to the following letter, which is what stops Arabic from becoming
/// one long ribbon.
class _LetterForms {
  const _LetterForms(this.isolated, this.finalForm, this.initial, this.medial);

  final int isolated;
  final int finalForm;
  final int? initial;
  final int? medial;
}

/// Letters that take a final form but never an initial or medial one.
const List<int> _nonJoiningAfter = <int>[
  0x0622, // آ
  0x0623, // أ
  0x0624, // ؤ
  0x0625, // إ
  0x0627, // ا
  0x0629, // ة
  0x062F, // د
  0x0630, // ذ
  0x0631, // ر
  0x0632, // ز
  0x0648, // و
  0x0621, // ء
];

/// The contextual forms of every letter that shapes.
///
/// A letter may join the one before it and/or the one after it; the four forms
/// are the combinations of those two facts.
const Map<int, _LetterForms> _forms = <int, _LetterForms>{
  // Alef family: joins only to the preceding letter.
  0x0622: _LetterForms(0xFE81, 0xFE82, null, null), // آ
  0x0623: _LetterForms(0xFE83, 0xFE84, null, null), // أ
  0x0624: _LetterForms(0xFE85, 0xFE86, null, null), // ؤ
  0x0625: _LetterForms(0xFE87, 0xFE88, null, null), // إ
  0x0626: _LetterForms(0xFE89, 0xFE8A, 0xFE8B, 0xFE8C), // ئ
  0x0627: _LetterForms(0xFE8D, 0xFE8E, null, null), // ا
  0x0628: _LetterForms(0xFE8F, 0xFE90, 0xFE91, 0xFE92), // ب
  0x0629: _LetterForms(0xFE93, 0xFE94, null, null), // ة
  0x062A: _LetterForms(0xFE95, 0xFE96, 0xFE97, 0xFE98), // ت
  0x062B: _LetterForms(0xFE99, 0xFE9A, 0xFE9B, 0xFE9C), // ث
  0x062C: _LetterForms(0xFE9D, 0xFE9E, 0xFE9F, 0xFEA0), // ج
  0x062D: _LetterForms(0xFEA1, 0xFEA2, 0xFEA3, 0xFEA4), // ح
  0x062E: _LetterForms(0xFEA5, 0xFEA6, 0xFEA7, 0xFEA8), // خ
  0x062F: _LetterForms(0xFEA9, 0xFEAA, null, null), // د
  0x0630: _LetterForms(0xFEAB, 0xFEAC, null, null), // ذ
  0x0631: _LetterForms(0xFEAD, 0xFEAE, null, null), // ر
  0x0632: _LetterForms(0xFEAF, 0xFEB0, null, null), // ز
  0x0633: _LetterForms(0xFEB1, 0xFEB2, 0xFEB3, 0xFEB4), // س
  0x0634: _LetterForms(0xFEB5, 0xFEB6, 0xFEB7, 0xFEB8), // ش
  0x0635: _LetterForms(0xFEB9, 0xFEBA, 0xFEBB, 0xFEBC), // ص
  0x0636: _LetterForms(0xFEBD, 0xFEBE, 0xFEBF, 0xFEC0), // ض
  0x0637: _LetterForms(0xFEC1, 0xFEC2, 0xFEC3, 0xFEC4), // ط
  0x0638: _LetterForms(0xFEC5, 0xFEC6, 0xFEC7, 0xFEC8), // ظ
  0x0639: _LetterForms(0xFEC9, 0xFECA, 0xFECB, 0xFECC), // ع
  0x063A: _LetterForms(0xFECD, 0xFECE, 0xFECF, 0xFED0), // غ
  0x0641: _LetterForms(0xFED1, 0xFED2, 0xFED3, 0xFED4), // ف
  0x0642: _LetterForms(0xFED5, 0xFED6, 0xFED7, 0xFED8), // ق
  0x0643: _LetterForms(0xFED9, 0xFEDA, 0xFEDB, 0xFEDC), // ك
  0x0644: _LetterForms(0xFEDD, 0xFEDE, 0xFEDF, 0xFEE0), // ل
  0x0645: _LetterForms(0xFEE1, 0xFEE2, 0xFEE3, 0xFEE4), // م
  0x0646: _LetterForms(0xFEE5, 0xFEE6, 0xFEE7, 0xFEE8), // ن
  0x0647: _LetterForms(0xFEE9, 0xFEEA, 0xFEEB, 0xFEEC), // ه
  0x0648: _LetterForms(0xFEED, 0xFEEE, null, null), // و
  0x0649: _LetterForms(0xFEEF, 0xFEF0, 0xFBE8, 0xFBE9), // ى
  0x064A: _LetterForms(0xFEF1, 0xFEF2, 0xFEF3, 0xFEF4), // ي
  0x0621: _LetterForms(0xFE80, 0xFE80, null, null), // ء
};

/// Lam followed by an alef becomes a single obligatory ligature, not two letters.
const Map<int, int> _lamAlefIsolated = <int, int>{
  0x0622: 0xFEF5, // لآ
  0x0623: 0xFEF7, // لأ
  0x0625: 0xFEF9, // لإ
  0x0627: 0xFEFB, // لا
};

const Map<int, int> _lamAlefFinal = <int, int>{
  0x0622: 0xFEF6,
  0x0623: 0xFEF8,
  0x0625: 0xFEFA,
  0x0627: 0xFEFC,
};

/// Harakat and other combining marks.
///
/// They attach to the letter before them and must not interrupt the joining
/// analysis, or a word with a shadda in the middle would break in two.
bool isCombiningMark(int code) {
  return (code >= 0x064B && code <= 0x065F) || // tanween, harakat, sukun
      code == 0x0670 || // dagger alef
      (code >= 0x06D6 && code <= 0x06ED) || // Quranic marks
      (code >= 0xFC5E && code <= 0xFC63) || // shadda + vowel ligatures
      code == 0x200D || // zero width joiner
      code == 0x200C; // zero width non-joiner
}

/// Tatweel: a stretch that visually joins like a letter but carries no sound.
bool _isTatweel(int code) => code == 0x0640;

bool _joinsForward(int code) {
  if (_isTatweel(code)) return true;
  final _LetterForms? forms = _forms[code];
  if (forms == null) return false;
  return forms.initial != null;
}

/// Whether a letter accepts a join from the letter before it.
///
/// Every letter does but the hamza written on the line, which stands alone on
/// both sides. The letter before it therefore ends its word: «شيء» is a sheen,
/// a final yeh and a hamza, not a medial yeh reaching for a hamza that does not
/// join — which is how it printed while only the first letter was asked.
bool _joinsBackward(int code) => code != 0x0621;

bool _canShape(int code) => _forms.containsKey(code) || _isTatweel(code);

/// Shapes [input] into Arabic Presentation Forms.
///
/// Non-Arabic characters pass through untouched, so a string like
/// `المتبقي: ₹ 15,000` keeps its digits, punctuation and currency sign exactly
/// as written — only the Arabic letters change.
String shapeArabic(String input) {
  if (input.isEmpty) return input;

  final List<int> codes = input.runes.toList();
  final List<int> out = <int>[];
  int index = 0;

  while (index < codes.length) {
    final int code = codes[index];

    // Lam followed by an alef collapses into one glyph — with a vowel on the
    // lam too: «أولًا» and «سجلًا» are written with the ligature, the tanween
    // above it. Only a real mark is looked past; a zero-width non-joiner is
    // there to stop the ligature.
    if (code == 0x0644) {
      int alef = index + 1;
      while (alef < codes.length &&
          isCombiningMark(codes[alef]) &&
          codes[alef] != 0x200C &&
          codes[alef] != 0x200D) {
        alef++;
      }
      if (alef < codes.length && _lamAlefFinal.containsKey(codes[alef])) {
        // The ligature has two forms and the choice is the same question every
        // other letter answers: does the letter *before* it join forward? A lam
        // after an alef, a waw or a dal is not connected to it, so the ligature
        // stands alone — which is what «الاستحقاق» and «الأول» need. Asking only
        // whether a previous letter exists picked the connected form and gave
        // those words a tail that joins nothing.
        final int? previous = _previousShapingCode(codes, index);
        final bool joinsBefore = previous != null && _joinsForward(previous);
        out.add(
          (joinsBefore ? _lamAlefFinal : _lamAlefIsolated)[codes[alef]]!,
        );
        // The lam's marks are drawn on the ligature, after it.
        out.addAll(codes.sublist(index + 1, alef));
        index = alef + 1;
        continue;
      }
    }

    if (!_canShape(code)) {
      out.add(code);
      index++;
      continue;
    }

    if (_isTatweel(code)) {
      out.add(code);
      index++;
      continue;
    }

    final int? previous = _previousShapingCode(codes, index);
    final int? next = _nextShapingCode(codes, index);

    // A join takes two letters: the first has to join forward and the second
    // has to accept it.
    final bool connectsBefore = previous != null &&
        _joinsForward(previous) &&
        _joinsBackward(code);
    final bool connectsAfter =
        next != null && _joinsForward(code) && _joinsBackward(next);

    final _LetterForms forms = _forms[code]!;
    final int shaped;
    if (connectsBefore && connectsAfter && forms.medial != null) {
      shaped = forms.medial!;
    } else if (connectsBefore) {
      shaped = forms.finalForm;
    } else if (connectsAfter && forms.initial != null) {
      shaped = forms.initial!;
    } else {
      shaped = forms.isolated;
    }
    out.add(shaped);
    index++;
  }

  return String.fromCharCodes(out);
}

/// The nearest preceding code point that participates in shaping, skipping
/// combining marks.
int? _previousShapingCode(List<int> codes, int index) {
  for (int i = index - 1; i >= 0; i--) {
    if (isCombiningMark(codes[i])) continue;
    return _canShape(codes[i]) ? codes[i] : null;
  }
  return null;
}

/// The nearest following code point that participates in shaping, skipping
/// combining marks.
int? _nextShapingCode(List<int> codes, int index) {
  for (int i = index + 1; i < codes.length; i++) {
    if (isCombiningMark(codes[i])) continue;
    return _canShape(codes[i]) ? codes[i] : null;
  }
  return null;
}

/// Whether [input] contains Arabic letters.
///
/// Recognises both the original letters and the presentation forms shaping
/// produces, so it still answers correctly if it is called after [shapeArabic].
bool containsArabic(String input) {
  for (final int code in input.runes) {
    if (_forms.containsKey(code)) return true;
    if (code >= 0xFB50 && code <= 0xFEFF) return true;
  }
  return false;
}

/// The letters that never join forward, exposed for the tests that pin the
/// joining rules.
List<int> get nonJoiningLetters => _nonJoiningAfter;
