import 'package:meta/meta.dart';

import '../entities/ledger_views.dart';
import '../enums/debt_enums.dart';

/// Decides which of a person's debts a payment is applied to, and how much of it
/// each one takes.
///
/// A pure function over views: no database, no clock, no widgets. That is the
/// point — the preview in the payment sheet and the write in `LedgerService` both
/// call this, so what the user is shown cannot be different from what is
/// recorded. A second implementation for either side would be free to disagree,
/// and the disagreement would only be visible after the money was written.
///
/// It answers one question for every debt it is handed, including the ones it
/// applies nothing to, so a sheet can render the whole list from the plan in
/// plan order without a lookup — and without rows jumping about as the user
/// excludes them.
abstract final class PaymentAllocator {
  const PaymentAllocator._();

  /// The most that can be applied, given whatever the user has left selected.
  ///
  /// This is the ceiling the amount field enforces. It is deliberately the sum
  /// of what is *still owed*, never the principals: paying more than a debt owes
  /// would file a payment larger than the debt and leave the user reading a
  /// figure nothing explains.
  static int capacityMinor(
    Iterable<DebtView> openDebts, {
    Set<String> excludedDebtIds = const <String>{},
  }) {
    int total = 0;
    for (final DebtView view in openDebts) {
      if (excludedDebtIds.contains(view.debt.id)) continue;
      total += view.remainingMinor;
    }
    return total;
  }

  /// The plan for [amountMinor], one entry per debt passed in, in the order the
  /// money reaches them.
  ///
  /// [amountMinor] is consumed from the first debt onward and stops when it runs
  /// out; no debt is ever allocated more than it still owes. An excluded debt
  /// takes nothing, and its share flows to the ones after it.
  static List<DebtAllocation> plan({
    required List<DebtView> openDebts,
    required int amountMinor,
    PaymentAllocationOrder order = PaymentAllocationOrder.mostUrgent,
    Set<String> excludedDebtIds = const <String>{},
  }) {
    final List<DebtView> ordered = orderDebts(openDebts, order);
    int left = amountMinor < 0 ? 0 : amountMinor;
    final List<DebtAllocation> out = <DebtAllocation>[];

    for (final DebtView view in ordered) {
      final int remaining = view.remainingMinor;
      final bool excluded = excludedDebtIds.contains(view.debt.id);
      // A debt can owe nothing at all — a settled one the caller did not filter,
      // or a principal of zero. It takes nothing; `remaining` is never negative,
      // because `DebtCalculator.remainingOf` already clamps it.
      final int take = excluded || remaining <= 0
          ? 0
          : (left < remaining ? left : remaining);
      left -= take;
      out.add(
        DebtAllocation(
          debtId: view.debt.id,
          allocatedMinor: take,
          remainingBeforeMinor: remaining,
          remainingAfterMinor: remaining - take,
          excluded: excluded,
        ),
      );
    }
    return out;
  }

  /// The debts in the order the plan will walk them.
  ///
  /// Exposed because the sheet shows excluded debts in their rightful place
  /// rather than in a separate list at the bottom, and it needs the same order
  /// to do that.
  static List<DebtView> orderDebts(
    List<DebtView> debts,
    PaymentAllocationOrder order,
  ) {
    final List<DebtView> out = List<DebtView>.of(debts);
    out.sort(
      (DebtView a, DebtView b) => order == PaymentAllocationOrder.oldestFirst
          ? _compareOldest(a, b)
          : _compareMostUrgent(a, b),
    );
    return out;
  }

  /// Due date first, undated last — the same doctrine the lists use, where
  /// "someday" never outranks "Tuesday". Two equally urgent debts fall back to
  /// the older one, so a record with no due date is still settled in the order
  /// it was incurred.
  static int _compareMostUrgent(DebtView a, DebtView b) {
    final DateTime? aDue = a.debt.dueAt;
    final DateTime? bDue = b.debt.dueAt;
    if (aDue != null && bDue != null) {
      final int byDue = aDue.compareTo(bDue);
      if (byDue != 0) return byDue;
    } else if (aDue != null) {
      return -1;
    } else if (bDue != null) {
      return 1;
    }
    return _compareOldest(a, b);
  }

  /// The day the debt was incurred, then when it was written down, then its id.
  ///
  /// The last two are not decoration: without a total order, two identical
  /// records could come out either way round between the preview and the write
  /// that follows it, and the split the user approved would not be the split
  /// that was saved.
  static int _compareOldest(DebtView a, DebtView b) {
    final int byIssued = a.debt.issuedAt.compareTo(b.debt.issuedAt);
    if (byIssued != 0) return byIssued;
    final int byCreated = a.debt.createdAt.compareTo(b.debt.createdAt);
    if (byCreated != 0) return byCreated;
    return a.debt.id.compareTo(b.debt.id);
  }
}

/// What one debt receives from a payment, and where that leaves it.
@immutable
class DebtAllocation {
  const DebtAllocation({
    required this.debtId,
    required this.allocatedMinor,
    required this.remainingBeforeMinor,
    required this.remainingAfterMinor,
    this.excluded = false,
  });

  final String debtId;

  /// What this debt takes from the payment. Zero when the money ran out before
  /// reaching it, or when the user left it out.
  final int allocatedMinor;

  final int remainingBeforeMinor;
  final int remainingAfterMinor;

  /// The user took this debt out of the plan.
  final bool excluded;

  /// This payment is the one that clears the debt.
  bool get willSettle => allocatedMinor > 0 && remainingAfterMinor <= 0;

  /// Left alone: the money did not reach it, or the user said not to.
  bool get isUntouched => allocatedMinor == 0;

  @override
  bool operator ==(Object other) =>
      other is DebtAllocation &&
      other.debtId == debtId &&
      other.allocatedMinor == allocatedMinor &&
      other.remainingBeforeMinor == remainingBeforeMinor &&
      other.remainingAfterMinor == remainingAfterMinor &&
      other.excluded == excluded;

  @override
  int get hashCode => Object.hash(
        debtId,
        allocatedMinor,
        remainingBeforeMinor,
        remainingAfterMinor,
        excluded,
      );
}
