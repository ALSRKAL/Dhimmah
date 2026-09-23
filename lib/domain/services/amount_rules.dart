/// The rules an amount must satisfy before Dhimmah will store it.
///
/// Kept in the domain, not in a widget, because a rule enforced only by a form
/// is not enforced: the form is one caller of many, and the database has no
/// opinion. Both the form and the service ask this one object, so a message the
/// user sees and a write the database accepts can never disagree.
abstract final class AmountRules {
  const AmountRules._();

  /// Ceiling for a single amount: one billion major units.
  ///
  /// Not a business rule so much as a guard against a slipped finger producing a
  /// number that makes every total on every screen meaningless, and against the
  /// overflow that would follow when totals are summed.
  static const int maxMinor = 1000000000 * 100;

  /// A debt, a payment or an obligation is a positive amount of money.
  ///
  /// Zero is not a debt. A negative amount is not a debt either — and a negative
  /// *payment* is worse than meaningless: subtracting it from what was paid
  /// makes the remaining balance grow, so a slip of the minus sign would show a
  /// balance that is simply untrue.
  static bool isValid(int minorUnits) =>
      minorUnits > 0 && minorUnits <= maxMinor;
}

/// Thrown when a write is asked to store an amount that cannot be money.
///
/// The screens validate first and show a message in the user's language, so this
/// is a last line of defence rather than an everyday path. It exists so that a
/// caller which forgets to validate fails loudly instead of quietly writing a
/// figure that corrupts every total derived from it.
class InvalidAmountException implements Exception {
  const InvalidAmountException(this.reason, this.minorUnits);

  final String reason;
  final int minorUnits;

  @override
  String toString() =>
      'InvalidAmountException($reason, $minorUnits minor units)';
}
