import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../enums/debt_enums.dart';
import 'activity_entry.dart';
import 'debt.dart';
import 'obligation.dart';
import 'person.dart';

/// Everything the UI needs to render one debt: the record, how much of it is
/// paid, and where it stands today.
///
/// Produced only by the domain calculators — never assembled in a widget — so a
/// balance shown anywhere in the app comes from the same arithmetic.
@immutable
class DebtView {
  const DebtView({
    required this.debt,
    required this.paidMinor,
    required this.remainingMinor,
    required this.status,
    required this.paymentCount,
    this.person,
    this.lastPaymentAt,
  });

  final Debt debt;
  final Person? person;

  /// Sum of all payments applied to this debt.
  final int paidMinor;

  /// `principal - paid`, floored at zero so an overpayment never shows a
  /// negative balance.
  final int remainingMinor;

  final DebtLifecycleStatus status;
  final int paymentCount;
  final DateTime? lastPaymentAt;

  Money get principal => Money(debt.principalMinor, debt.currency);
  Money get paid => Money(paidMinor, debt.currency);
  Money get remaining => Money(remainingMinor, debt.currency);

  AppCurrency get currency => debt.currency;

  bool get isSettled => remainingMinor <= 0;

  /// Received something, but not everything yet.
  bool get isPartiallyPaid => paidMinor > 0 && remainingMinor > 0;

  /// Whether the user still owes / is owed money on this record.
  bool get isOpen => !isSettled && !debt.isArchived;

  /// Fraction of the principal that has been paid, `0..1`.
  double get progress {
    if (debt.principalMinor <= 0) return isSettled ? 1 : 0;
    return (paidMinor / debt.principalMinor).clamp(0.0, 1.0);
  }

  /// What to call this record in a list: the person's name, or the free-text
  /// title when there is no person.
  String get displayName {
    final Person? p = person;
    if (p != null && p.name.trim().isNotEmpty) return p.name;
    if (debt.title.trim().isNotEmpty) return debt.title;
    return '';
  }

  /// A secondary line for the list row.
  String? get subtitle {
    if (person != null && debt.title.trim().isNotEmpty) return debt.title;
    return null;
  }

  /// Negative when the due date has passed.
  int? daysUntilDue(DateTime asOf) {
    final DateTime? due = debt.dueAt;
    if (due == null) return null;
    return daysBetween(asOf, due);
  }

  /// Days late, or zero when not late.
  int overdueDays(DateTime asOf) {
    final int? days = daysUntilDue(asOf);
    if (days == null || days >= 0) return 0;
    return -days;
  }

  /// Money still outstanding, signed by direction: negative for what the user
  /// owes, positive for what they are owed. This is the value that sums into a
  /// net balance.
  Money get signedRemaining => Money(
        debt.direction.isIOwe ? -remainingMinor : remainingMinor,
        debt.currency,
      );

  /// The outstanding amount attributed to this record for balance maths.
  Money get outstanding => Money(remainingMinor, debt.currency);
}

/// Per-currency totals. Dhimmah reports balances per currency and never adds
/// two currencies into one number.
@immutable
class CurrencyTotals {
  const CurrencyTotals({
    required this.currency,
    required this.iOweMinor,
    required this.owedToMeMinor,
    required this.dueSoonMinor,
    required this.overdueMinor,
    this.iOweCount = 0,
    this.owedToMeCount = 0,
  });

  static CurrencyTotals empty(AppCurrency currency) =>
      CurrencyTotals(currency: currency, iOweMinor: 0, owedToMeMinor: 0, dueSoonMinor: 0, overdueMinor: 0);

  final AppCurrency currency;

  /// Outstanding money the user must pay.
  final int iOweMinor;

  /// Outstanding money the user must receive.
  final int owedToMeMinor;

  /// Outstanding money across both directions falling due inside the
  /// "due soon" window.
  final int dueSoonMinor;

  /// Outstanding money across both directions already past its due date.
  final int overdueMinor;

  final int iOweCount;
  final int owedToMeCount;

  Money get iOwe => Money(iOweMinor, currency);
  Money get owedToMe => Money(owedToMeMinor, currency);
  Money get dueSoon => Money(dueSoonMinor, currency);
  Money get overdue => Money(overdueMinor, currency);

  /// Positive when the user is net owed money.
  Money get net => Money(owedToMeMinor - iOweMinor, currency);

  int get totalCount => iOweCount + owedToMeCount;

  bool get isEmpty =>
      iOweMinor == 0 &&
      owedToMeMinor == 0 &&
      dueSoonMinor == 0 &&
      overdueMinor == 0 &&
      totalCount == 0;
}

/// One person's position across every debt linked to them.
@immutable
class PersonLedger {
  const PersonLedger({
    required this.person,
    required this.debts,
    required this.totals,
  });

  final Person person;
  final List<DebtView> debts;

  /// One entry per currency this person is involved in.
  final List<CurrencyTotals> totals;

  int get openDebtCount => debts.where((DebtView d) => d.isOpen).length;

  CurrencyTotals? totalsFor(AppCurrency currency) {
    for (final CurrencyTotals t in totals) {
      if (t.currency == currency) return t;
    }
    return null;
  }
}

/// A person plus their headline numbers, used by the people lists.
@immutable
class PersonDirectoryEntry {
  const PersonDirectoryEntry({
    required this.person,
    required this.debts,
    required this.totals,
    required this.lastActivityAt,
  });

  final Person person;
  final List<DebtView> debts;
  final List<CurrencyTotals> totals;
  final DateTime lastActivityAt;

  int get openDebtCount => debts.where((DebtView d) => d.isOpen).length;

  /// True when any debt for this person is past due.
  bool get hasOverdue =>
      debts.any((DebtView d) => d.status == DebtLifecycleStatus.overdue);
}

/// Everything the dashboard renders, assembled once per data change.
@immutable
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.totalsByCurrency,
    required this.primaryCurrency,
    required this.upcoming,
    required this.upcomingObligations,
    required this.recentActivity,
    required this.peopleCount,
    required this.openDebtCount,
    required this.hasAnyRecord,
  });

  /// Totals keyed by currency, ordered with [primaryCurrency] first.
  final List<CurrencyTotals> totalsByCurrency;

  /// The currency the headline tiles show: the most-used one, or the user's
  /// default when nothing has been recorded yet.
  final AppCurrency primaryCurrency;

  /// Open debts sorted by how soon they are due.
  final List<DebtView> upcoming;

  /// Obligation periods coming up, soonest first.
  final List<ObligationInstance> upcomingObligations;

  final List<ActivityEntry> recentActivity;
  final int peopleCount;
  final int openDebtCount;

  /// False on a fresh install, which is what triggers the empty state.
  final bool hasAnyRecord;

  CurrencyTotals get primary {
    for (final CurrencyTotals t in totalsByCurrency) {
      if (t.currency == primaryCurrency) return t;
    }
    return CurrencyTotals.empty(primaryCurrency);
  }

  bool get hasMultipleCurrencies => totalsByCurrency.length > 1;
}
