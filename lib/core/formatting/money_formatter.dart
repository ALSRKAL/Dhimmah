import 'package:intl/intl.dart';

import '../../domain/enums/preference_enums.dart';
import '../money/currency.dart';
import '../money/money.dart';

/// Formats money for display.
///
/// Three rules drive everything here:
///
/// * The numeric part is wrapped in Unicode bidi isolates, so `₹ 50,000` renders
///   as one left-to-right unit inside an Arabic paragraph instead of scrambling
///   into `50,000 ₹`.
/// * Digits are transliterated after formatting rather than by asking `intl` for
///   an Arabic locale. `intl` resolves a locale with a `-u-nu-` extension to its
///   fallback data and quietly returns Western digits, so the numeral style is
///   applied here, where it is exact and testable.
/// * A currency whose symbol is shared with another (﷼ means both the Saudi and
///   the Yemeni riyal) is printed with its ISO code, so an amount is never
///   ambiguous.
class MoneyFormatter {
  const MoneyFormatter({
    required this.numerals,
    required this.defaultCurrency,
  });

  final NumeralsStyle numerals;
  final AppCurrency defaultCurrency;

  /// Left-to-right isolate / pop directional isolate.
  static const String _lri = '\u2066';
  static const String _pdi = '\u2069';

  /// Non-breaking space between the symbol and the amount, so a value never
  /// wraps between its symbol and its digits.
  static const String _gap = '\u00A0';

  /// The locale whose grouping and decimal conventions are used.
  ///
  /// Fixed rather than derived from the UI language: `1,234.56` is unambiguous
  /// and identical in both languages, and the only script decision that matters
  /// is which digit glyphs to draw — which [numerals] decides.
  static const String _numericLocale = 'en';

  static const String _westernDigits = '0123456789';
  static const String _arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';

  /// Replaces Western digits with Arabic-Indic ones when the user asked for them.
  String _applyNumerals(String text) {
    if (numerals == NumeralsStyle.latin) return text;
    final StringBuffer buffer = StringBuffer();
    for (final int rune in text.runes) {
      final int index = _westernDigits.indexOf(String.fromCharCode(rune));
      buffer.write(index >= 0 ? _arabicIndicDigits[index] : String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  /// The amount without any currency marker.
  String amount(
    Money money, {
    bool compact = false,
    bool trimZeroDecimals = true,
  }) {
    final String text;
    if (compact) {
      text = NumberFormat.compact(locale: _numericLocale)
          .format(money.asDouble.abs());
    } else {
      final bool isWhole = money.minorUnits % money.currency.minorFactor == 0;
      if (trimZeroDecimals && isWhole) {
        text = NumberFormat.decimalPattern(_numericLocale)
            .format(money.asDouble.abs());
      } else {
        text = NumberFormat.decimalPatternDigits(
          locale: _numericLocale,
          decimalDigits: money.currency.decimals,
        ).format(money.asDouble.abs());
      }
    }
    return _applyNumerals(text);
  }

  /// The amount with its currency symbol.
  ///
  /// [showCode] forces the ISO code as well; currencies with an ambiguous symbol
  /// always get it.
  ///
  /// [isolate] wraps the result in Unicode bidi isolates, which is right on
  /// screen — it keeps `₹ 50,000` as one left-to-right unit inside an Arabic
  /// paragraph. It is wrong in a document: the PDF renderer has no isolate
  /// support and no glyphs for those code points, so they come out as boxes.
  /// Documents pass `false` and get plain, self-contained text.
  String format(
    Money money, {
    bool compact = false,
    bool showCode = false,
    String? prefix,
    bool isolate = true,
  }) {
    final AppCurrency currency = money.currency;
    final String symbol =
        currency.symbolFor(isDefaultCurrency: currency == defaultCurrency);
    final String number = amount(money, compact: compact);

    final StringBuffer body = StringBuffer();
    if (money.isNegative) body.write('−');
    if (prefix != null && prefix.isNotEmpty) {
      body.write(prefix);
      body.write(' ');
    }
    body.write(symbol);
    body.write(_gap);
    body.write(number);
    if (showCode && symbol != currency.code) {
      body.write(_gap);
      body.write(currency.code);
    }
    final String text = body.toString();
    return isolate ? '$_lri$text$_pdi' : text.replaceAll(_gap, ' ');
  }

  /// The ISO code and symbol together, used as a heading for a currency group.
  String currencyLabel(AppCurrency currency) =>
      '${currency.code} '
      '${currency.symbolFor(isDefaultCurrency: currency == defaultCurrency)}';

  /// A net position with an explicit sign, so its direction survives without
  /// colour.
  String formatSigned(Money money, {bool compact = false}) {
    if (money.isZero) return format(money, compact: compact);
    return format(
      money,
      compact: compact,
      prefix: money.isNegative ? '−' : '+',
    );
  }

  /// A percentage as a whole number, e.g. `64%`.
  String percent(double fraction) =>
      '${_applyNumerals(NumberFormat.decimalPattern(_numericLocale).format((fraction * 100).round()))}%';

  /// A plain integer with the chosen digit shapes, used for counters.
  String integer(int value) =>
      _applyNumerals(NumberFormat.decimalPattern(_numericLocale).format(value));
}
