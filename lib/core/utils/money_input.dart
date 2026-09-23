import '../../domain/services/amount_rules.dart';
import '../money/currency.dart';

/// Parsing and formatting for the amount input.
///
/// Kept away from the widget so the tricky part — accepting both numbering
/// systems and both grouping conventions without ever producing a `double` — can
/// be tested directly. Everything here works in integer minor units.

/// Western digits, Arabic-Indic digits, and the extended Arabic-Indic digits used
/// on Persian and Urdu keyboards.
const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
const String _extendedArabicDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Characters that can only ever mean "decimal point": `.` in the West and `٫`
/// in Arabic.
const String _decimalCharacters = '.٫';

/// Characters that can only ever mean "thousands separator": `,` in the West and
/// `٬` in Arabic, plus the space some locales group with.
const String _groupingCharacters = ',٬\u00A0 ';

/// Converts Arabic-Indic digits to ASCII so one parser handles every keyboard a
/// user might have.
String normaliseDigits(String input) {
  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.runes) {
    final String character = String.fromCharCode(rune);
    final int arabic = _arabicIndicDigits.indexOf(character);
    if (arabic >= 0) {
      buffer.write(arabic);
      continue;
    }
    final int extended = _extendedArabicDigits.indexOf(character);
    if (extended >= 0) {
      buffer.write(extended);
      continue;
    }
    buffer.write(character);
  }
  return buffer.toString();
}

/// How a string's separators should be read.
enum _SeparatorRole {
  /// No separator at all.
  absent,

  /// Exactly one: it marks the fraction.
  decimal,

  /// More than one: they can only be grouping marks.
  grouping,
}

/// Parses typed text into minor units, or null when it is not a usable amount.
///
/// Returns null rather than zero for empty or malformed input, so a form can tell
/// "nothing typed yet" apart from "the user typed zero".
///
/// The separator rule is the load-bearing part. `1.234.567` can only be a grouped
/// integer — reading the first dot as a decimal point would turn a million into
/// one and twenty-three. That kind of silent misreading is exactly what makes a
/// user stop trusting a ledger, so the reading is decided up front from the whole
/// string rather than from whichever character arrived first.
int? parseAmountToMinor(String input, AppCurrency currency) {
  final String normalised = normaliseDigits(input).trim();
  if (normalised.isEmpty) return null;

  int decimalMarkers = 0;
  for (final int rune in normalised.runes) {
    if (_decimalCharacters.contains(String.fromCharCode(rune))) {
      decimalMarkers++;
    }
  }
  final _SeparatorRole role = switch (decimalMarkers) {
    0 => _SeparatorRole.absent,
    1 => _SeparatorRole.decimal,
    _ => _SeparatorRole.grouping,
  };

  final StringBuffer digits = StringBuffer();
  bool seenDecimal = false;
  int decimalsSeen = 0;

  for (final int rune in normalised.runes) {
    final String character = String.fromCharCode(rune);
    if (character == '-') return null; // Amounts are always positive.
    if (RegExp(r'[0-9]').hasMatch(character)) {
      if (seenDecimal) {
        // Extra precision is dropped rather than rounded: the user is still
        // typing, and rounding mid-keystroke invents digits they did not enter.
        if (decimalsSeen >= currency.decimals) continue;
        decimalsSeen++;
      }
      digits.write(character);
      continue;
    }
    if (_groupingCharacters.contains(character)) continue;
    if (_decimalCharacters.contains(character)) {
      if (role == _SeparatorRole.decimal && !seenDecimal) {
        seenDecimal = true;
        digits.write('.');
      }
      continue;
    }
    return null;
  }

  final String cleaned = digits.toString();
  if (cleaned.isEmpty || cleaned == '.') return null;

  final List<String> parts = cleaned.split('.');
  final String whole = parts.first.isEmpty ? '0' : parts.first;
  final String fraction = parts.length > 1 ? parts[1] : '';

  final int? wholeValue = int.tryParse(whole);
  if (wholeValue == null) return null;

  final int fractionValue;
  if (currency.decimals == 0) {
    fractionValue = 0;
  } else {
    final String padded = fraction
        .padRight(currency.decimals, '0')
        .substring(0, currency.decimals);
    fractionValue = int.tryParse(padded.isEmpty ? '0' : padded) ?? 0;
  }

  final int minor = wholeValue * currency.minorFactor + fractionValue;
  if (minor < 0 || minor > maxAmountMinor) return null;
  return minor;
}

/// The largest amount Dhimmah will accept, in minor units.
///
/// The rule itself lives in the domain ([AmountRules]) so the service can enforce
/// the same one; this alias exists because the input helpers read better with it.
const int maxAmountMinor = AmountRules.maxMinor;

/// Renders minor units as an editable string, without a currency symbol.
String formatMinorForInput(int minorUnits, AppCurrency currency) {
  final int whole = minorUnits ~/ currency.minorFactor;
  final int fraction = minorUnits % currency.minorFactor;
  if (currency.decimals == 0) return whole.toString();
  final String fractionText = fraction.toString().padLeft(currency.decimals, '0');
  return '$whole.$fractionText';
}

/// Whether an amount is usable as a record's value.
bool isAmountWithinRange(int minorUnits) => AmountRules.isValid(minorUnits);
