import 'package:flutter/widgets.dart';

/// Which way a piece of typed text runs, decided by its first letter.
///
/// The rule Android's own text fields use: the first letter decides, Arabic or
/// Hebrew running right to left and any other script left to right. Text with
/// no letter at all but with digits (an amount, a phone number, in Western or
/// Arabic-Indic digits) runs left to right, which is how numbers are written
/// in both languages. Anything else, and empty text, takes [fallback]: the
/// direction of the language the app is in.
TextDirection textDirectionOf(String text, {required TextDirection fallback}) {
  bool digits = false;
  for (final int rune in text.runes) {
    final String character = String.fromCharCode(rune);
    if (_letter.hasMatch(character)) {
      return _isRightToLeft(rune) ? TextDirection.rtl : TextDirection.ltr;
    }
    if (!digits && _digit.hasMatch(character)) digits = true;
  }
  return digits ? TextDirection.ltr : fallback;
}

final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);

/// The blocks whose letters are written right to left: Hebrew, Arabic and its
/// extensions, their presentation forms, and the historic right-to-left scripts.
bool _isRightToLeft(int rune) =>
    (rune >= 0x0590 && rune <= 0x08FF) ||
    (rune >= 0xFB1D && rune <= 0xFDFF) ||
    (rune >= 0xFE70 && rune <= 0xFEFF) ||
    (rune >= 0x10800 && rune <= 0x10FFF) ||
    (rune >= 0x1E800 && rune <= 0x1EFFF);

/// Where a tap beside a line of text should leave the caret, or null when the
/// tap landed on the text itself and the framework's choice stands.
///
/// [lineLeft] and [lineRight] are the line's painted extent, [line] its range
/// in the text, and [direction] the paragraph's direction.
///
/// A tap on the empty space beside a line means "carry on from here", so it
/// goes to the line's end. The framework puts it at whichever character is
/// painted nearest, and in text that mixes directions that is often the start
/// or the middle: in «دفعة 500» the empty stretch sits next to the 5, and in
/// "1500" inside a right-to-left field it sits next to the 1. The one exception
/// is the narrow margin before a line that is aligned to its own start, where a
/// tap does mean the start.
TextSelection? caretForTapBesideLine({
  required double tapX,
  required double lineLeft,
  required double lineRight,
  required TextRange line,
  required TextDirection direction,
  required bool alignedToStart,
}) {
  if (tapX >= lineLeft && tapX <= lineRight) return null;
  final bool beforeStart =
      direction == TextDirection.ltr ? tapX < lineLeft : tapX > lineRight;
  if (beforeStart && alignedToStart) {
    return TextSelection.collapsed(offset: line.start);
  }
  return TextSelection.collapsed(
    offset: line.end,
    affinity: TextAffinity.upstream,
  );
}

/// Whether [align] puts a line against the start edge of a paragraph running
/// in [direction].
bool isAlignedToStart(TextAlign align, TextDirection direction) =>
    switch (align) {
      TextAlign.start || TextAlign.justify => true,
      TextAlign.end || TextAlign.center => false,
      TextAlign.left => direction == TextDirection.ltr,
      TextAlign.right => direction == TextDirection.rtl,
    };
