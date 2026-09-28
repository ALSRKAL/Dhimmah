import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../entities/debt.dart';
import '../entities/ledger_views.dart';
import '../entities/payment.dart';
import '../entities/person.dart';
import '../enums/debt_enums.dart';

/// All debt arithmetic for Dhimmah.
///
/// Pure functions over entities: no database, no widgets, no clock of its own —
/// the current date is always passed in. That is what makes every rule here
/// directly testable and keeps the numbers identical everywhere they appear.
abstract final class DebtCalculator {
  const DebtCalculator._();

  /// Works out where a debt stands today.
  ///
  /// Order matters. An archived record reports [DebtLifecycleStatus.archived]
  /// because that was the user's explicit choice, and a settled record reports
  /// [DebtLifecycleStatus.paid] before any date-based reasoning — a paid debt is
  /// never "late".
  static DebtLifecycleStatus resolveStatus({
    required Debt debt,
    required int remainingMinor,
    required DateTime asOf,
    required int dueSoonWindowDays,
  }) {
    if (debt.isArchived) return DebtLifecycleStatus.archived;
    if (remainingMinor <= 0) return DebtLifecycleStatus.paid;

    final DateTime? due = debt.dueAt;
    if (due == null) return DebtLifecycleStatus.active;

    final int days = daysBetween(asOf, due);
    if (days < 0) return DebtLifecycleStatus.overdue;
    if (days == 0) return DebtLifecycleStatus.dueToday;
    if (days <= dueSoonWindowDays) return DebtLifecycleStatus.dueSoon;
    return DebtLifecycleStatus.upcoming;
  }

  /// What a debt's payment history amounts to.
  ///
  /// A list of payments is one way to describe this, and a `SUM … GROUP BY` over
  /// the payments table is another. Both produce this, and [_viewOf] turns either
  /// into a [DebtView], so a screen that reads the whole table and a screen that
  /// asks the database to add it up cannot disagree about a balance.
  static PaymentTotals totalsOf(List<Payment> payments) => PaymentTotals(
        paidMinor: totalPaid(payments),
        count: payments.length,
        lastPaidAt: _latestPaymentDate(payments),
      );

  /// Builds the render-ready view of a single debt from its payment history.
  static DebtView buildView({
    required Debt debt,
    required List<Payment> payments,
    required DateTime asOf,
    required int dueSoonWindowDays,
    List<Person> participants = const <Person>[],
  }) =>
      buildViewFromTotals(
        debt: debt,
        totals: totalsOf(payments),
        asOf: asOf,
        dueSoonWindowDays: dueSoonWindowDays,
        participants: participants,
      );

  /// The same view, from totals the database has already summed.
  ///
  /// This exists because loading every payment row to add up four numbers is the
  /// difference between a screen that opens and one that does not: at 10,000
  /// payments, `GROUP BY` in SQLite took 20 ms where loading and summing in Dart
  /// took 499 ms.
  static DebtView buildViewFromTotals({
    required Debt debt,
    required PaymentTotals totals,
    required DateTime asOf,
    required int dueSoonWindowDays,
    List<Person> participants = const <Person>[],
  }) {
    final int remaining = remainingOf(debt.principalMinor, totals.paidMinor);
    return DebtView(
      debt: debt,
      participants: participants,
      paidMinor: totals.paidMinor,
      remainingMinor: remaining,
      paymentCount: totals.count,
      lastPaymentAt: totals.lastPaidAt,
      status: resolveStatus(
        debt: debt,
        remainingMinor: remaining,
        asOf: asOf,
        dueSoonWindowDays: dueSoonWindowDays,
      ),
    );
  }

  /// Sum of every payment applied to a debt.
  static int totalPaid(List<Payment> payments) {
    int total = 0;
    for (final Payment payment in payments) {
      total += payment.amountMinor;
    }
    return total;
  }

  /// What is left after [paidMinor], never below zero.
  ///
  /// Overpaying settles a debt; it does not create a negative balance the user
  /// would have to interpret.
  static int remainingOf(int principalMinor, int paidMinor) {
    final int remaining = principalMinor - paidMinor;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether settling this payment would close the debt.
  static bool wouldSettle({
    required int principalMinor,
    required int paidMinor,
    required int newPaymentMinor,
  }) =>
      paidMinor + newPaymentMinor >= principalMinor;

  static DateTime? _latestPaymentDate(List<Payment> payments) {
    DateTime? latest;
    for (final Payment payment in payments) {
      if (latest == null || payment.paidAt.isAfter(latest)) {
        latest = payment.paidAt;
      }
    }
    return latest;
  }

  /// Groups outstanding balances by currency. Currencies never cross-add.
  ///
  /// Each view contributes its amount exactly once, whoever the record is with:
  /// the caller passes the records, never one entry per participant, so a record
  /// linked to three people cannot become three times its value.
  static List<CurrencyTotals> totalsByCurrency(
    Iterable<DebtView> views, {
    required DateTime asOf,
    required int dueSoonWindowDays,
  }) {
    final Map<AppCurrency, _TotalsAccumulator> buckets =
        <AppCurrency, _TotalsAccumulator>{};

    for (final DebtView view in views) {
      if (!view.isOpen) continue;
      final _TotalsAccumulator bucket = buckets.putIfAbsent(
        view.currency,
        () => _TotalsAccumulator(view.currency),
      );
      final int remaining = view.remainingMinor;
      if (view.debt.direction.isIOwe) {
        bucket.iOweMinor += remaining;
        bucket.iOweCount += 1;
      } else {
        bucket.owedToMeMinor += remaining;
        bucket.owedToMeCount += 1;
      }
      if (view.status == DebtLifecycleStatus.overdue) {
        bucket.overdueMinor += remaining;
      } else if (view.status == DebtLifecycleStatus.dueSoon ||
          view.status == DebtLifecycleStatus.dueToday) {
        bucket.dueSoonMinor += remaining;
      }
    }

    final List<CurrencyTotals> out = buckets.values
        .map((_TotalsAccumulator a) => a.build())
        .toList();
    out.sort((CurrencyTotals a, CurrencyTotals b) {
      final int byCount = b.totalCount.compareTo(a.totalCount);
      if (byCount != 0) return byCount;
      return b.iOweMinor.compareTo(a.iOweMinor);
    });
    return out;
  }

  /// Chooses which currency the dashboard leads with: the one the user records
  /// in most, falling back to their default currency.
  static AppCurrency primaryCurrency(
    List<CurrencyTotals> totals,
    AppCurrency fallback,
  ) {
    if (totals.isEmpty) return fallback;
    for (final CurrencyTotals t in totals) {
      if (t.currency == fallback && !t.isEmpty) return fallback;
    }
    return totals.first.currency;
  }

  /// Whether a view passes a filter facet.
  static bool matchesFilter(
    DebtView view,
    DebtFilter filter, {
    required int dueSoonWindowDays,
  }) {
    final bool archived = view.debt.isArchived;
    return switch (filter) {
      DebtFilter.all => !archived,
      DebtFilter.active => view.isOpen,
      DebtFilter.partiallyPaid => view.isPartiallyPaid && !archived,
      DebtFilter.unpaid => view.paidMinor == 0 && view.isOpen,
      DebtFilter.paid => view.isSettled && !archived,
      DebtFilter.overdue => view.status == DebtLifecycleStatus.overdue,
      DebtFilter.dueSoon =>
        view.status == DebtLifecycleStatus.dueSoon ||
            view.status == DebtLifecycleStatus.dueToday,
      DebtFilter.archived => archived,
    };
  }

  /// Orders views for display. Records without a due date always sort last when
  /// ordering by date, because "someday" is not more urgent than "Tuesday".
  static List<DebtView> sort(
    List<DebtView> views,
    DebtSortOrder order, {
    required DateTime asOf,
  }) {
    final List<DebtView> out = List<DebtView>.of(views);
    switch (order) {
      case DebtSortOrder.dueDateSoonest:
        out.sort((a, b) => _compareDue(a, b, asOf, ascending: true));
      case DebtSortOrder.dueDateLatest:
        out.sort((a, b) => _compareDue(a, b, asOf, ascending: false));
      case DebtSortOrder.amountHighest:
        out.sort((a, b) => b.remainingMinor.compareTo(a.remainingMinor));
      case DebtSortOrder.amountLowest:
        out.sort((a, b) => a.remainingMinor.compareTo(b.remainingMinor));
      case DebtSortOrder.recentlyAdded:
        out.sort((a, b) => b.debt.createdAt.compareTo(a.debt.createdAt));
      case DebtSortOrder.oldestAdded:
        out.sort((a, b) => a.debt.createdAt.compareTo(b.debt.createdAt));
      case DebtSortOrder.nameAscending:
        out.sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return out;
  }

  /// View ordering used by the dashboard's "upcoming" list: most urgent first,
  /// using status urgency rather than the raw date so a paid record can never
  /// float to the top.
  static List<DebtView> sortByUrgency(List<DebtView> views) {
    final List<DebtView> out = views.where((DebtView v) => v.isOpen).toList()
      ..sort((a, b) {
        final int byUrgency = b.status.urgency.compareTo(a.status.urgency);
        if (byUrgency != 0) return byUrgency;
        final DateTime? aDue = a.debt.dueAt;
        final DateTime? bDue = b.debt.dueAt;
        if (aDue == null && bDue == null) return 0;
        if (aDue == null) return 1;
        if (bDue == null) return -1;
        return aDue.compareTo(bDue);
      });
    return out;
  }

  static int _compareDue(
    DebtView a,
    DebtView b,
    DateTime asOf, {
    required bool ascending,
  }) {
    final DateTime? aDue = a.debt.dueAt;
    final DateTime? bDue = b.debt.dueAt;
    if (aDue == null && bDue == null) {
      return b.debt.createdAt.compareTo(a.debt.createdAt);
    }
    if (aDue == null) return 1;
    if (bDue == null) return -1;
    return ascending ? aDue.compareTo(bDue) : bDue.compareTo(aDue);
  }
}

/// The sum of a debt's payments, however it was arrived at.
@immutable
class PaymentTotals {
  const PaymentTotals({
    required this.paidMinor,
    required this.count,
    this.lastPaidAt,
  });

  const PaymentTotals.none()
      : paidMinor = 0,
        count = 0,
        lastPaidAt = null;

  final int paidMinor;
  final int count;
  final DateTime? lastPaidAt;
}

/// Mutable accumulator kept private so [CurrencyTotals] can stay immutable.
class _TotalsAccumulator {
  _TotalsAccumulator(this.currency);

  final AppCurrency currency;
  int iOweMinor = 0;
  int owedToMeMinor = 0;
  int dueSoonMinor = 0;
  int overdueMinor = 0;
  int iOweCount = 0;
  int owedToMeCount = 0;

  CurrencyTotals build() => CurrencyTotals(
        currency: currency,
        iOweMinor: iOweMinor,
        owedToMeMinor: owedToMeMinor,
        dueSoonMinor: dueSoonMinor,
        overdueMinor: overdueMinor,
        iOweCount: iOweCount,
        owedToMeCount: owedToMeCount,
      );
}
