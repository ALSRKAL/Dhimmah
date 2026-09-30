import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../entities/ledger_views.dart';
import '../entities/obligation.dart';
import '../enums/debt_enums.dart';

/// Why something is asking for the user's attention.
///
/// Ordered by how much it matters: money already late comes before money due
/// today, which comes before money due this week.
enum AttentionReason { overdue, dueToday, dueSoon }

/// One thing on the dashboard's attention list.
@immutable
class AttentionItem {
  const AttentionItem({
    required this.reason,
    required this.title,
    required this.amountMinor,
    required this.currency,
    required this.dueAt,
    required this.daysUntilDue,
    this.direction,
    this.isObligation = false,
    this.debtId,
    this.obligationId,
    this.overdueTotalMinor,
    this.dueSoonTotalMinor,
  });

  final AttentionReason reason;

  /// The person's name, or the obligation's name.
  final String title;

  final int amountMinor;

  /// Null for an obligation, which carries its own currency.
  final DebtDirection? direction;

  final AppCurrency currency;
  final DateTime dueAt;

  /// Negative when late.
  final int daysUntilDue;

  final bool isObligation;
  final String? debtId;
  final String? obligationId;

  /// What this row adds to the section's "late" figure, when that is not
  /// simply [amountMinor].
  ///
  /// A commitment is one row, its oldest unpaid period, but every late period
  /// is money that is late: rent three months behind is three rents, not one.
  /// Null means the row stands for exactly [amountMinor] under its [reason].
  final int? overdueTotalMinor;

  /// The same for the "due soon" figure, which includes today.
  final int? dueSoonTotalMinor;

  bool get isLate => daysUntilDue < 0;

  /// The outstanding amount, ready to display.
  Money get money => Money(amountMinor, currency);

  /// A stable key for list animations and navigation.
  String get key => debtId ?? obligationId ?? '$title-$dueAt';
}

/// Derives what needs attention from the records.
///
/// Pure: given the current debts, obligations and a date, it returns the list.
/// Nothing is invented — every entry corresponds to a record the user entered,
/// and an item disappears the moment it is settled. That is what keeps the
/// section trustworthy: if it says something is late, it is late.
abstract final class AttentionList {
  const AttentionList._();

  /// The window, in days, inside which something counts as "due soon".
  static const int defaultWindowDays = 7;

  /// Builds the list, most urgent first.
  ///
  /// [limit] caps the returned rows; null returns everything, which is what the
  /// section's totals need — they must sum every item, not only the five that
  /// fit on the screen.
  static List<AttentionItem> build({
    required List<DebtView> debts,
    required List<ObligationInstance> obligations,
    required DateTime asOf,
    int windowDays = defaultWindowDays,
    int? limit = 5,
  }) {
    final List<AttentionItem> items = <AttentionItem>[];

    for (final DebtView view in debts) {
      if (!view.isOpen) continue;
      final DateTime? due = view.debt.dueAt;
      if (due == null) continue;
      final AttentionReason? reason = _reasonFor(due, asOf, windowDays);
      if (reason == null) continue;
      items.add(
        AttentionItem(
          reason: reason,
          title: view.displayName,
          amountMinor: view.remainingMinor,
          direction: view.debt.direction,
          currency: view.currency,
          dueAt: due,
          daysUntilDue: daysBetween(asOf, due),
          debtId: view.debt.id,
        ),
      );
    }

    // One row per commitment, not one per unpaid period. A weekly bill can have
    // two periods inside the window, and two identical rows would read as a bug
    // rather than as two things to pay. The oldest period is the one to act on.
    //
    // The row's figures still count every period: each late one under "late",
    // each one due inside the window under "due soon".
    final Map<String, ObligationInstance> oldestPeriod =
        <String, ObligationInstance>{};
    final Map<String, int> overdueById = <String, int>{};
    final Map<String, int> dueSoonById = <String, int>{};
    for (final ObligationInstance instance in obligations) {
      if (!instance.occurrence.isPayable) continue;
      final String id = instance.obligation.id;
      final ObligationInstance? current = oldestPeriod[id];
      if (current == null ||
          instance.occurrence.dueAt.isBefore(current.occurrence.dueAt)) {
        oldestPeriod[id] = instance;
      }
      final AttentionReason? reason =
          _reasonFor(instance.occurrence.dueAt, asOf, windowDays);
      if (reason == null) continue;
      final Map<String, int> bucket =
          reason == AttentionReason.overdue ? overdueById : dueSoonById;
      bucket[id] = (bucket[id] ?? 0) + instance.occurrence.amountMinor;
    }

    for (final ObligationInstance instance in oldestPeriod.values) {
      final String id = instance.obligation.id;
      final DateTime due = instance.occurrence.dueAt;
      final AttentionReason? reason = _reasonFor(due, asOf, windowDays);
      if (reason == null) continue;
      items.add(
        AttentionItem(
          reason: reason,
          title: instance.obligation.name,
          amountMinor: instance.occurrence.amountMinor,
          currency: instance.obligation.currency,
          dueAt: due,
          daysUntilDue: daysBetween(asOf, due),
          isObligation: true,
          obligationId: id,
          overdueTotalMinor: overdueById[id] ?? 0,
          dueSoonTotalMinor: dueSoonById[id] ?? 0,
        ),
      );
    }

    items.sort((AttentionItem a, AttentionItem b) {
      final int byReason = a.reason.index.compareTo(b.reason.index);
      if (byReason != 0) return byReason;
      // Within a reason, the oldest deadline is the most pressing.
      return a.dueAt.compareTo(b.dueAt);
    });

    return limit == null ? items : items.take(limit).toList(growable: false);
  }

  /// The section's two figures, taken from the items themselves.
  ///
  /// Summed per currency over every item — including obligations, which the
  /// debt-only totals used to leave out: a late rent bill sat under a "late"
  /// figure that did not count it (measured on the device). A commitment adds
  /// every one of its periods, through [AttentionItem.overdueTotalMinor] and
  /// [AttentionItem.dueSoonTotalMinor].
  static ({int overdueMinor, int dueSoonMinor}) totalsFor(
    List<AttentionItem> items,
    AppCurrency currency,
  ) {
    int overdue = 0;
    int dueSoon = 0;
    for (final AttentionItem item in items) {
      if (item.currency != currency) continue;
      final bool late = item.reason == AttentionReason.overdue;
      overdue += item.overdueTotalMinor ?? (late ? item.amountMinor : 0);
      dueSoon += item.dueSoonTotalMinor ?? (late ? 0 : item.amountMinor);
    }
    return (overdueMinor: overdue, dueSoonMinor: dueSoon);
  }

  /// How many items fall in each reason, for the section's summary line.
  static Map<AttentionReason, int> counts(List<AttentionItem> items) {
    final Map<AttentionReason, int> counts = <AttentionReason, int>{};
    for (final AttentionItem item in items) {
      counts[item.reason] = (counts[item.reason] ?? 0) + 1;
    }
    return counts;
  }

  static AttentionReason? _reasonFor(
    DateTime due,
    DateTime asOf,
    int windowDays,
  ) {
    final int days = daysBetween(asOf, due);
    if (days < 0) return AttentionReason.overdue;
    if (days == 0) return AttentionReason.dueToday;
    if (days <= windowDays) return AttentionReason.dueSoon;
    return null;
  }
}
