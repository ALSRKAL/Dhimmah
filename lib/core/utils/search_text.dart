import 'money_input.dart';

/// Text folded the way a person searching expects it to match.
///
/// Arabic is written with choices that do not change the word: أحمد and احمد
/// are one name, as are علي and على, فاطمة and فاطمه, and a name typed with
/// its vowel marks or a stretched letter is still the same name. A plain
/// `contains` treated each of those as a different word, so a person saved as
/// «أحمد» could not be found by typing «احمد», which is how most keyboards
/// type it. Digits are folded as well, so a number typed on an Arabic keyboard
/// finds the same number stored in Western digits.
///
/// Both sides of a comparison go through this; see [searchMatches].
String foldForSearch(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in normaliseDigits(input).toLowerCase().runes) {
    if (_isIgnored(rune)) continue;
    buffer.writeCharCode(_letterFor(rune));
  }
  return buffer.toString();
}

/// Whether [text] contains [foldedNeedle], which must already be folded with
/// [foldForSearch] — the needle is folded once per query, not once per row.
bool searchMatches(String? text, String foldedNeedle) {
  if (text == null || text.isEmpty) return false;
  return foldForSearch(text).contains(foldedNeedle);
}

/// Vowel marks, Quranic annotation marks and the tatweel: they change how a
/// word is drawn, never which word it is.
bool _isIgnored(int rune) =>
    (rune >= 0x064B && rune <= 0x065F) || // fathatan … wavy hamza below
    rune == 0x0670 || // superscript alef
    (rune >= 0x06D6 && rune <= 0x06ED) || // Quranic annotation marks
    rune == 0x0640; // tatweel

/// The one letter each written variant is searched as.
int _letterFor(int rune) => switch (rune) {
      0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ → ا
      0x0649 => 0x064A, // ى → ي
      0x0629 => 0x0647, // ة → ه
      _ => rune,
    };
