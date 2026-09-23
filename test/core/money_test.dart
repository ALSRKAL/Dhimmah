import 'package:dhimmah/core/formatting/money_formatter.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/utils/money_input.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Money parsing and formatting.
///
/// The parsing tests matter most: this is the only place where what a user types
/// becomes the integer every balance is computed from.
void main() {
  group('parsing typed amounts', () {
    int? parse(String input, [AppCurrency currency = AppCurrency.inr]) =>
        parseAmountToMinor(input, currency);

    test('accepts whole numbers', () {
      expect(parse('5000'), 500000);
      expect(parse('0'), 0);
      expect(parse('1'), 100);
    });

    test('accepts a decimal fraction', () {
      expect(parse('5000.50'), 500050);
      expect(parse('0.99'), 99);
      expect(parse('12.5'), 1250);
    });

    test('accepts the Arabic decimal separator', () {
      expect(parse('5000٫75'), 500075);
    });

    test('accepts Arabic-Indic digits', () {
      expect(parse('٥٠٠٠'), 500000);
      expect(parse('١٢٣٤٫٥'), 123450);
    });

    test('accepts the extended Arabic-Indic digits', () {
      expect(parse('۵۰۰۰'), 500000);
    });

    test('ignores grouping separators', () {
      expect(parse('1,234,567'), 123456700);
      expect(parse('1 234'), 123400);
    });

    test('truncates precision beyond the currency exponent', () {
      expect(parse('10.999'), 1099);
      expect(parse('10.1234'), 1012);
    });

    test('treats a trailing separator as a whole number', () {
      expect(parse('500.'), 50000);
    });

    test('rejects empty and malformed input rather than returning zero', () {
      expect(parse(''), isNull);
      expect(parse('   '), isNull);
      expect(parse('abc'), isNull);
      expect(parse('.'), isNull);
    });

    test('rejects negative amounts', () {
      expect(parse('-500'), isNull);
    });

    test('rejects amounts beyond the supported range', () {
      expect(parse('1000000000000'), isNull);
    });

    test('handles a second separator as a grouping mark', () {
      expect(parse('1.234.567'), 123456700);
    });
  });

  group('formatting for the input field', () {
    test('round-trips through parse', () {
      const int minor = 1234567;
      final String text = formatMinorForInput(minor, AppCurrency.inr);
      expect(text, '12345.67');
      expect(parseAmountToMinor(text, AppCurrency.inr), minor);
    });

    test('pads the fraction to the currency exponent', () {
      expect(formatMinorForInput(500000, AppCurrency.inr), '5000.00');
      expect(formatMinorForInput(5, AppCurrency.inr), '0.05');
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts exactly', () {
      const Money a = Money(1000, AppCurrency.inr);
      const Money b = Money(2345, AppCurrency.inr);
      expect((a + b).minorUnits, 3345);
      expect((b - a).minorUnits, 1345);
    });

    test('never loses a fraction to floating point', () {
      // The reason Money exists: 0.1 + 0.2 must be exactly 0.3.
      const Money tenFils = Money(10, AppCurrency.inr);
      Money total = Money.zero(AppCurrency.inr);
      for (int i = 0; i < 3; i++) {
        total = total + tenFils;
      }
      expect(total.minorUnits, 30);
      expect(total.asDouble, closeTo(0.3, 1e-12));
    });

    test('refuses to combine two currencies', () {
      expect(
        () => const Money(100, AppCurrency.inr) + const Money(100, AppCurrency.usd),
        throwsA(isA<AssertionError>()),
      );
    });

    test('clamps a ratio instead of returning nonsense', () {
      expect(const Money(500, AppCurrency.inr).ratioTo(const Money(1000, AppCurrency.inr)),
          0.5);
      expect(const Money(5000, AppCurrency.inr).ratioTo(const Money(1000, AppCurrency.inr)),
          1.0);
      expect(const Money(500, AppCurrency.inr).ratioTo(const Money(0, AppCurrency.inr)),
          0.0);
    });

    test('compares like a value type', () {
      expect(
        const Money(100, AppCurrency.inr) == const Money(100, AppCurrency.inr),
        isTrue,
      );
      expect(
        const Money(100, AppCurrency.inr) == const Money(100, AppCurrency.usd),
        isFalse,
      );
    });
  });

  group('currency metadata', () {
    test('falls back safely for an unknown code', () {
      expect(AppCurrency.parse('XYZ'), AppCurrency.inr);
      expect(AppCurrency.parse(null, fallback: AppCurrency.usd), AppCurrency.usd);
      expect(AppCurrency.tryParse('SAR'), AppCurrency.sar);
      expect(AppCurrency.tryParse('xyz'), isNull);
    });

    test('marks currencies whose symbol is shared', () {
      // ﷼ means both the Saudi and the Yemeni riyal, so those must be
      // disambiguated with their ISO code.
      expect(AppCurrency.sar.hasAmbiguousSymbol, isTrue);
      expect(AppCurrency.yer.hasAmbiguousSymbol, isTrue);
      expect(AppCurrency.inr.hasAmbiguousSymbol, isFalse);
      expect(AppCurrency.yer.symbolFor(isDefaultCurrency: false), 'YER');
    });
  });

  group('formatting', () {
    MoneyFormatter formatter({
      NumeralsStyle numerals = NumeralsStyle.latin,
    }) =>
        MoneyFormatter(numerals: numerals, defaultCurrency: AppCurrency.inr);

    test('prints the symbol with the amount', () {
      final String text =
          formatter().format(const Money(5000000, AppCurrency.inr));
      expect(text, contains('₹'));
      expect(text, contains('50,000'));
    });

    test('isolates the amount so it stays left-to-right in Arabic', () {
      final String text =
          formatter().format(const Money(5000000, AppCurrency.inr));
      // U+2066 LRI ... U+2069 PDI
      expect(text.startsWith('\u2066'), isTrue);
      expect(text.endsWith('\u2069'), isTrue);
    });

    test('adds the ISO code for a currency with a shared symbol', () {
      final String text =
          formatter().format(const Money(300000, AppCurrency.sar));
      expect(text, contains('SAR'));
    });

    test('omits the fraction when the amount is whole', () {
      final String text =
          formatter().format(const Money(500000, AppCurrency.inr));
      expect(text, isNot(contains('.00')));
    });

    test('keeps the fraction when there is one', () {
      final String text =
          formatter().format(const Money(500050, AppCurrency.inr));
      expect(text, contains('50'));
    });

    test('switches digit glyphs with the numeral style', () {
      final String latin =
          formatter().amount(const Money(123456, AppCurrency.inr));
      final String arabicDigits = formatter(numerals: NumeralsStyle.arabicIndic)
          .amount(const Money(123456, AppCurrency.inr));

      expect(latin, '1,234.56');
      expect(arabicDigits, '١,٢٣٤.٥٦');
    });

    test('keeps the grouping separator readable in Arabic-Indic', () {
      // A comma stays a comma: mixing ٬ with Arabic digits is a typographic
      // choice, not a clarity one, and clarity wins here.
      final String text = formatter(numerals: NumeralsStyle.arabicIndic)
          .format(const Money(5000000, AppCurrency.inr));
      expect(text, contains('٥٠,٠٠٠'));
    });

    test('signs a net position explicitly', () {
      final MoneyFormatter format = formatter();
      expect(
        format.formatSigned(const Money(-5000, AppCurrency.inr)),
        contains('−'),
      );
      expect(
        format.formatSigned(const Money(5000, AppCurrency.inr)),
        contains('+'),
      );
    });
  });
}
