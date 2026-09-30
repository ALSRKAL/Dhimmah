/// The currencies Dhimmah can record.
///
/// A record always carries its own currency and Dhimmah never silently adds two
/// currencies together. Balances are reported per currency until a real
/// conversion layer exists.
enum AppCurrency {
  inr(code: 'INR', symbol: '₹'),
  usd(code: 'USD', symbol: r'$'),
  sar(code: 'SAR', symbol: '﷼'),
  aed(code: 'AED', symbol: 'د.إ'),
  yer(code: 'YER', symbol: '﷼'),
  eur(code: 'EUR', symbol: '€'),
  gbp(code: 'GBP', symbol: '£');

  const AppCurrency({required this.code, required this.symbol});

  /// ISO 4217 alphabetic code.
  final String code;

  /// The glyph shown next to an amount.
  final String symbol;

  /// ISO 4217 exponent: fractional digits in the minor unit.
  ///
  /// Every currency Dhimmah ships with uses two decimals, so the exponent is
  /// fixed here. This is the single place to change if a zero-decimal currency
  /// (JPY, KRW) is ever added.
  int get decimals => 2;

  /// The multiplier between a major unit and its stored minor unit.
  int get minorFactor => 100;

  static AppCurrency? tryParse(String? code) {
    if (code == null) return null;
    final String needle = code.trim().toUpperCase();
    for (final AppCurrency currency in AppCurrency.values) {
      if (currency.code == needle) return currency;
    }
    return null;
  }

  /// Parses a code, falling back to [fallback] when it is unknown.
  static AppCurrency parse(String? code, {AppCurrency fallback = AppCurrency.inr}) {
    return tryParse(code) ?? fallback;
  }

  /// Currencies whose symbol is shared with another currency. The UI shows the
  /// ISO code for these so an amount is never ambiguous.
  bool get hasAmbiguousSymbol =>
      this == AppCurrency.sar || this == AppCurrency.yer;

  /// The code and the symbol together — `INR · ₹` — as the currency settings
  /// state it. One place, so the settings row and its picker cannot disagree.
  String get codeAndSymbol => '$code · $symbol';

  /// The symbol to print when [displayCurrency] is the user's default; a shared
  /// symbol keeps its ISO code so ﷼ never means two different things.
  String symbolFor({required bool isDefaultCurrency}) {
    if (hasAmbiguousSymbol && !isDefaultCurrency) return code;
    return symbol;
  }
}
