import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../entities/obligation.dart';
import '../enums/obligation_enums.dart';

/// Which obligation periods count towards a month's total, for one currency.
///
/// One rule, read by both the monthly report and the obligations screen's budget
/// card, because the alternative is the failure this class exists to prevent:
/// two readers deciding separately is how "the month's commitments" comes to
/// mean two different numbers on two screens that show them side by side.
///
/// The rule, and why each part of it is there:
///
/// * **Only commitments in this currency.** Adding 5,000 ﷼ to $500 produces a
///   number that is not money.
/// * **Never a period the user skipped, and never a cancelled one.** A skipped
///   period is "not applicable this time"; counting it reported a rent the user
///   had said was not owed.
/// * **For a commitment in the archive, what was paid stays counted, and the
///   unpaid periods from the day it was archived onwards do not.** Archiving
///   says "I have set this aside", so its future is not a commitment — but the
///   money already spent is history and removing it would rewrite the month.
class ObligationPeriodRule {
  ObligationPeriodRule(List<Obligation> obligations, AppCurrency currency)
      : _archivedOn = <String, DateTime?>{
          for (final Obligation obligation in obligations)
            if (obligation.currency == currency)
              // A timestamp, so the day is taken on the phone's own clock.
              obligation.id: obligation.archivedAt == null
                  ? null
                  : dateOnly(obligation.archivedAt!.toLocal()),
        };

  /// Commitments in the wanted currency, with the day each was archived.
  ///
  /// Membership of this map is the currency test: a commitment absent from it is
  /// in another currency, or does not exist.
  final Map<String, DateTime?> _archivedOn;

  bool isDue(ObligationOccurrence occurrence) {
    if (!_archivedOn.containsKey(occurrence.obligationId)) return false;
    if (occurrence.status == ObligationStatus.cancelled ||
        occurrence.status == ObligationStatus.skipped) {
      return false;
    }
    final DateTime? archivedOn = _archivedOn[occurrence.obligationId];
    if (archivedOn != null &&
        !occurrence.isPaid &&
        !occurrence.dueAt.isBefore(archivedOn)) {
      return false;
    }
    return true;
  }
}
