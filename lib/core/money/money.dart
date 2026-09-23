import 'package:meta/meta.dart';

import 'currency.dart';

/// An exact monetary amount, stored as an integer count of minor units.
///
/// Money is never represented as a double anywhere in Dhimmah: `0.1 + 0.2` must
/// never decide whether a debt is settled. Arithmetic is guarded so that two
/// different currencies cannot be combined by accident.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  /// Signed count of minor units (paise, cents, halalas …).
  final int minorUnits;

  final AppCurrency currency;

  static const Money zeroInr = Money(0, AppCurrency.inr);

  static Money zero(AppCurrency currency) => Money(0, currency);

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;
  bool get isPositive => minorUnits > 0;

  /// Major-unit value. For display and charting only — never for arithmetic
  /// that decides state.
  double get asDouble => minorUnits / currency.minorFactor;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  Money operator -() => Money(-minorUnits, currency);

  Money operator *(int factor) => Money(minorUnits * factor, currency);

  /// Negates when [negate] is true. Useful for turning a direction into a sign.
  Money signed({required bool negate}) =>
      negate ? Money(-minorUnits, currency) : this;

  /// Shifts the amount to [target] currency code without converting value.
  /// This exists so an amount can be re-tagged when the user corrects the
  /// currency of a record; it is never used to "convert".
  Money retag(AppCurrency target) => Money(minorUnits, target);

  /// Ratio of this amount to [other], clamped to `0..1`. Returns 0 when
  /// [other] is zero, which keeps progress bars well behaved.
  double ratioTo(Money other) {
    _assertSameCurrency(other);
    if (other.minorUnits <= 0) return 0;
    return (minorUnits / other.minorUnits).clamp(0.0, 1.0);
  }

  void _assertSameCurrency(Money other) {
    assert(
      currency == other.currency,
      'Refusing to combine ${currency.code} with ${other.currency.code}. '
      'Dhimmah never mixes currencies without an explicit conversion.',
    );
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${currency.code} $minorUnits';
}
