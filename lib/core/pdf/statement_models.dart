import 'package:meta/meta.dart';

import '../../domain/entities/debt.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/preference_enums.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../utils/dates.dart';

/// Which of a person's debts a statement covers.
enum StatementScope {
  /// Only what is still outstanding: settled debts are left out.
  ///
  /// The default, because a statement is sent to say what remains, and a list
  /// of debts closed last year is noise to the person reading it.
  openOnly,

  /// Every debt, settled ones included.
  all,

  /// Exactly the debts the user ticked, whatever state they are in.
  selected,
}

/// Which records and which optional blocks a statement includes.
///
/// The defaults are the privacy-safe ones: a document is often sent to the very
/// person the debt is with, so nothing is added unless it helps them read it.
///
/// Held by the screen for as long as it is open and never stored: nothing here
/// is written to the database, so choosing what a statement shows cannot change
/// a record.
@immutable
class StatementOptions {
  const StatementOptions({
    this.includePayments = true,
    this.includePhone = false,
    this.includeNotes = false,
    this.includeDebtBreakdown = true,
    this.scope = StatementScope.openOnly,
    this.includeArchived = false,
    this.selectedDebtIds = const <String>{},
    this.issuerName = '',
    this.periodFrom,
    this.periodTo,
  });

  /// The payment history table.
  final bool includePayments;

  /// The person's phone number, which the recipient usually already knows.
  final bool includePhone;

  /// Per-debt notes. Off by default: a note is often the user's own reminder,
  /// not something meant for the other party.
  final bool includeNotes;

  /// One line per debt, shown when a person has more than one.
  final bool includeDebtBreakdown;

  /// Which debts the statement covers.
  final StatementScope scope;

  /// Whether archived debts may appear.
  ///
  /// Off by default: archiving is how the user puts a record out of sight, and
  /// a document sent to someone else is the last place it should resurface. A
  /// debt ticked by hand under [StatementScope.selected] is shown regardless —
  /// ticking it is the user saying so.
  final bool includeArchived;

  /// The debts to print under [StatementScope.selected]; ignored otherwise.
  final Set<String> selectedDebtIds;

  /// Who the statement is from, as the user typed it; empty to leave it off.
  ///
  /// The page names the person it is about and, without this, nobody else: a
  /// statement forwarded once no longer says whose records it is. Typed on the
  /// screen and kept only while it is open — the app stores no name for its
  /// own user, and adding one is a schema change this does not make.
  final String issuerName;

  /// The first day the statement covers, or null for the whole history.
  ///
  /// A statement with a period prints only the movements inside it, and states
  /// the balance the account opened the period with. Both ends are inclusive
  /// calendar days. The two fields are set together; [hasPeriod] is the one
  /// question the rest of the code asks.
  final DateTime? periodFrom;

  /// The last day the statement covers, or null for the whole history.
  final DateTime? periodTo;

  /// Whether these options state a bounded period.
  bool get hasPeriod => periodFrom != null && periodTo != null;

  StatementOptions copyWith({
    bool? includePayments,
    bool? includePhone,
    bool? includeNotes,
    bool? includeDebtBreakdown,
    StatementScope? scope,
    bool? includeArchived,
    Set<String>? selectedDebtIds,
    String? issuerName,
    Object? periodFrom = _unsetPeriod,
    Object? periodTo = _unsetPeriod,
  }) {
    return StatementOptions(
      includePayments: includePayments ?? this.includePayments,
      includePhone: includePhone ?? this.includePhone,
      includeNotes: includeNotes ?? this.includeNotes,
      includeDebtBreakdown: includeDebtBreakdown ?? this.includeDebtBreakdown,
      scope: scope ?? this.scope,
      includeArchived: includeArchived ?? this.includeArchived,
      selectedDebtIds: selectedDebtIds ?? this.selectedDebtIds,
      issuerName: issuerName ?? this.issuerName,
      // Sentinels, so the period can be cleared as well as replaced: passing
      // null was indistinguishable from leaving the field alone.
      periodFrom: identical(periodFrom, _unsetPeriod)
          ? this.periodFrom
          : periodFrom as DateTime?,
      periodTo: identical(periodTo, _unsetPeriod)
          ? this.periodTo
          : periodTo as DateTime?,
    );
  }

  /// Whether any option could change the document.
  bool get isDefault =>
      includePayments &&
      !includePhone &&
      !includeNotes &&
      includeDebtBreakdown &&
      scope == StatementScope.openOnly &&
      !includeArchived &&
      selectedDebtIds.isEmpty &&
      issuerName.trim().isEmpty &&
      !hasPeriod;

  /// Compared by value: the preview is keyed on these, and two sets of options
  /// that print the same document must not rebuild it.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatementOptions &&
          other.includePayments == includePayments &&
          other.includePhone == includePhone &&
          other.includeNotes == includeNotes &&
          other.includeDebtBreakdown == includeDebtBreakdown &&
          other.scope == scope &&
          other.includeArchived == includeArchived &&
          other.issuerName == issuerName &&
          other.periodFrom == periodFrom &&
          other.periodTo == periodTo &&
          other.selectedDebtIds.length == selectedDebtIds.length &&
          other.selectedDebtIds.containsAll(selectedDebtIds);

  @override
  int get hashCode => Object.hash(
        includePayments,
        includePhone,
        includeNotes,
        includeDebtBreakdown,
        scope,
        includeArchived,
        issuerName,
        periodFrom,
        periodTo,
        Object.hashAllUnordered(selectedDebtIds),
      );
}

const Object _unsetPeriod = Object();

/// One line of the payment history table.
@immutable
class StatementEntry {
  const StatementEntry({
    required this.date,
    required this.kind,
    required this.direction,
    required this.amountMinor,
    required this.balanceAfterMinor,
    required this.currency,
    this.balanceDirection,
    this.debtTitle,
    this.note,
  });

  final DateTime date;
  final StatementEntryKind kind;

  /// The side of the debt this line belongs to: money lent or borrowed, and a
  /// payment received or made.
  final DebtDirection direction;

  final int amountMinor;

  /// The balance immediately after this entry — the column that makes a
  /// statement legible, because it shows the total shrinking.
  ///
  /// Always a size: which way it points is [balanceDirection]. A statement can
  /// hold money owed both ways, and adding the two sides together, as this
  /// column used to, gave a figure that was neither.
  final int balanceAfterMinor;

  /// Who the balance favours after this entry, or null when it is even.
  final DebtDirection? balanceDirection;

  final AppCurrency currency;

  /// The debt this line belongs to, for a statement that covers several.
  final String? debtTitle;

  /// The payment's own note.
  final String? note;

  Money get amount => Money(amountMinor, currency);
  Money get balanceAfter => Money(balanceAfterMinor, currency);
}

/// What produced a history line.
enum StatementEntryKind {
  /// The debt was recorded.
  debtCreated,

  /// A payment was received or made.
  payment,

  /// The debt was recorded as settled.
  settled,
}

/// One debt inside a person's statement.
@immutable
class StatementDebtLine {
  const StatementDebtLine({
    required this.title,
    required this.direction,
    required this.principal,
    required this.paid,
    required this.remaining,
    required this.status,
    this.dueAt,
    this.note,
  });

  final String title;
  final DebtDirection direction;
  final Money principal;
  final Money paid;
  final Money remaining;
  final DebtLifecycleStatus status;
  final DateTime? dueAt;
  final String? note;
}

/// Everything a statement needs, already resolved.
///
/// The document template reads this and nothing else, so the same template can
/// render a person's statement or, later, a single debt's without touching the
/// layout code.
@immutable
class StatementData {
  const StatementData({
    required this.documentNumber,
    required this.generatedAt,
    required this.language,
    required this.personName,
    required this.phone,
    required this.currency,
    required this.totalMinor,
    required this.paidMinor,
    required this.remainingMinor,
    required this.status,
    required this.debts,
    required this.entries,
    required this.options,
    this.dueAt,
    this.dueDebtTitle,
    this.notes,
    this.hiddenSettledCount = 0,
    this.hiddenArchivedCount = 0,
    this.periodFrom,
    this.periodTo,
    this.openingBalanceMinor = 0,
    this.closingBalanceMinor,
  });

  /// Human-readable number, stable for a given person and day.
  final String documentNumber;

  final DateTime generatedAt;
  final AppLanguage language;
  final String personName;
  final String? phone;

  /// The currency the totals are in. A person can hold debts in several, in
  /// which case one statement is produced per currency.
  final AppCurrency currency;

  final int totalMinor;
  final int paidMinor;
  final int remainingMinor;
  final DebtLifecycleStatus status;

  /// The earliest due date still outstanding, when there is one.
  final DateTime? dueAt;

  /// The title of the debt [dueAt] belongs to, when it has one.
  ///
  /// A date alone does not say which debt falls due on a statement that covers
  /// several, and the reader is usually the person who has to pay it.
  final String? dueDebtTitle;

  /// Every record this statement covers, one line each, and what the totals are
  /// the sum of.
  final List<StatementDebtLine> debts;

  final List<StatementEntry> entries;
  final StatementOptions options;
  final String? notes;

  /// Settled debts in this currency that the scope left out.
  ///
  /// Printed on the document, so a filtered statement never reads as the whole
  /// account: the person receiving it can see that something was not shown.
  final int hiddenSettledCount;

  /// Archived debts in this currency that the scope left out.
  ///
  /// For the screen only, and deliberately **not** printed: archiving is the
  /// user's own filing, and a document that told its reader "two archived debts
  /// not shown" would be telling them about records the user put away.
  final int hiddenArchivedCount;

  /// The first day the movements cover, or null for the whole history.
  final DateTime? periodFrom;

  /// The last day the movements cover, or null for the whole history.
  final DateTime? periodTo;

  /// Whether the document states a bounded period.
  bool get hasPeriod => periodFrom != null && periodTo != null;

  /// The signed balance the account opened the period with.
  ///
  /// Positive means the user was owed on balance. Zero without a period, and
  /// zero for a period that starts before the first record.
  final int openingBalanceMinor;

  /// The signed balance at the end of the stated period.
  ///
  /// Null without a period, where the closing figure is the running balance of
  /// the last printed movement — the behaviour the document had before periods
  /// existed.
  final int? closingBalanceMinor;

  Money get total => Money(totalMinor, currency);
  Money get paid => Money(paidMinor, currency);
  Money get remaining => Money(remainingMinor, currency);

  /// Whether the statement holds money owed both ways.
  ///
  /// Its total, paid and remaining figures then add two sides together and
  /// mean nothing on their own, so the document states each side and the
  /// difference instead, as the person's page does.
  bool get isMixed =>
      debts.any((StatementDebtLine line) => line.direction.isIOwe) &&
      debts.any((StatementDebtLine line) => !line.direction.isIOwe);

  /// The one side every debt is on, or null when there are none or both.
  DebtDirection? get direction =>
      debts.isEmpty || isMixed ? null : debts.first.direction;

  /// Still owed to the user, over the debts covered.
  Money get owedToMe => Money(_remainingOn(owedToMe: true), currency);

  /// Still owed by the user, over the debts covered.
  Money get iOwe => Money(_remainingOn(owedToMe: false), currency);

  /// The two sides set against each other: positive when the user is owed.
  Money get net =>
      Money(owedToMe.minorUnits - iOwe.minorUnits, currency);

  int _remainingOn({required bool owedToMe}) => debts
      .where((StatementDebtLine line) => line.direction.isIOwe != owedToMe)
      .fold<int>(
        0,
        (int sum, StatementDebtLine line) => sum + line.remaining.minorUnits,
      );

  /// The filename a shared copy gets.
  ///
  /// Built from the person's name and the date so a folder of statements stays
  /// readable, and sanitised because names contain spaces, dots and slashes.
  String get fileName {
    final String safeName = sanitiseFileName(personName);
    final String date =
        '${generatedAt.year.toString().padLeft(4, '0')}-'
        '${generatedAt.month.toString().padLeft(2, '0')}-'
        '${generatedAt.day.toString().padLeft(2, '0')}';
    return 'Dhimmah_${safeName}_$date.pdf';
  }

  /// The document title shown at the top of the sheet and in the share dialog.
  String get title => 'Dhimmah · $personName';

  /// Replaces anything that would be awkward or illegal in a filename.
  ///
  /// Keeps Arabic letters — modern filesystems handle them — and drops the
  /// separators and control characters that would break a path.
  static String sanitiseFileName(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.trim().runes) {
      final String character = String.fromCharCode(rune);
      if (RegExp(r'[\\/:*?"<>|\x00-\x1F]').hasMatch(character)) {
        buffer.write('_');
        continue;
      }
      if (character == ' ') {
        buffer.write('_');
        continue;
      }
      buffer.write(character);
    }
    final String cleaned = buffer.toString().replaceAll(RegExp(r'_+'), '_');
    final String trimmed = cleaned.replaceAll(RegExp(r'^_|_$'), '');
    return trimmed.isEmpty ? 'Statement' : trimmed;
  }

  /// A stable, short code for the document number.
  ///
  /// A hash rather than a counter: the same person always gets the same code, so
  /// a number quoted in a conversation still refers to the same statement, and no
  /// state has to be stored to keep it unique.
  static String stableCode(String seed, {int length = 4}) {
    int hash = 0x811C9DC5;
    for (final int unit in seed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final String digits = (hash % 100000000).toString().padLeft(length, '0');
    return digits.substring(0, length);
  }
}

/// Everything a receipt for one payment needs, already resolved.
///
/// A receipt is the smallest document the app makes: one payment, who it was
/// between, and what it leaves on the debt. Like a statement it is read from
/// stored records and writes nothing — it has no number in the database, so its
/// number is derived from the payment and the moment it was issued.
@immutable
class ReceiptData {
  const ReceiptData({
    required this.number,
    required this.issuedAt,
    required this.language,
    required this.personName,
    required this.direction,
    required this.amount,
    required this.paidAt,
    required this.remainingNow,
    this.issuerName = '',
    this.debtTitle,
    this.note,
    this.lines = const <ReceiptLine>[],
  });

  final String number;
  final DateTime issuedAt;
  final AppLanguage language;

  /// The other party to the debt.
  final String personName;

  /// Who is issuing the receipt, as typed; empty to leave it off.
  final String issuerName;

  /// The side the debt is on, which decides which way the money moved.
  final DebtDirection direction;

  final Money amount;
  final DateTime paidAt;

  /// What the debt still has on it at the moment the receipt is issued.
  ///
  /// "Now", not "after this payment": a receipt can be issued for an old
  /// payment with later ones after it, and the balance straight after that one
  /// is no longer what anyone owes.
  final Money remainingNow;

  final String? debtTitle;
  final String? note;

  /// Where the money went, one line per debt, when one payment was spread over
  /// several. Empty for a payment on a single debt, which [debtTitle] names.
  ///
  /// [amount] is then the total and [remainingNow] the sum left on those debts:
  /// the receipt is for the money that changed hands, not for one share of it.
  final List<ReceiptLine> lines;

  /// Whether this receipt covers a payment spread over several debts.
  bool get isSplit => lines.length > 1;

  /// Whether the user received this payment, rather than made it.
  ///
  /// A debt owed to the user is paid *to* the user: the document is a receipt.
  /// A debt the user owes is paid *by* the user: it is a payment voucher.
  bool get isReceived => !direction.isIOwe;

  /// The filename a shared copy gets.
  String get fileName {
    final String safeName = StatementData.sanitiseFileName(personName);
    final String date =
        '${paidAt.year.toString().padLeft(4, '0')}-'
        '${paidAt.month.toString().padLeft(2, '0')}-'
        '${paidAt.day.toString().padLeft(2, '0')}';
    return 'Dhimmah_Receipt_${safeName}_$date.pdf';
  }
}

/// One debt's share of a payment that was spread over several.
@immutable
class ReceiptLine {
  const ReceiptLine({
    required this.debtTitle,
    required this.amount,
    required this.remainingNow,
  });

  final String debtTitle;
  final Money amount;
  final Money remainingNow;
}

/// The movement history of an account, with the balance either side of it.
@immutable
class StatementHistory {
  const StatementHistory({
    required this.entries,
    required this.openingMinor,
    required this.closingMinor,
  });

  /// The movements to print, oldest first.
  final List<StatementEntry> entries;

  /// The signed balance before the first printed movement.
  ///
  /// Positive means the user was owed. Zero for an unbounded history, and for
  /// a period that begins before the first record.
  final int openingMinor;

  /// The signed balance after the last printed movement.
  final int closingMinor;
}

/// Builds the statement's history from real records.
///
/// One list, oldest first, with a running balance, so the table reads as the
/// story of the account: each debt raises the balance on its own side and each
/// payment brings its debt down. No line is invented — every row corresponds to
/// a stored record.
///
/// With [from] and [to] the printed movements are bounded to those calendar
/// days, both inclusive. Everything before [from] still counts: it is applied
/// first and its result is the opening balance, so the first printed row starts
/// from what the account actually held that morning. Movements after [to] are
/// not applied at all, which is what makes the closing figure the balance at
/// the end of the period rather than today's.
///
/// Two things this used to get wrong. It listed every debt first and every
/// payment after, whatever their dates, so a debt recorded in August sat above
/// a payment made in June and the balance column passed through figures the
/// account never had. And it added money owed to the user and money the user
/// owes into one total. The balance is now the two sides set against each
/// other, and each debt stops at zero, as it does on the debt's own page.
StatementHistory buildStatementHistory({
  required List<Debt> debts,
  required List<Payment> payments,
  required AppCurrency currency,
  DateTime? from,
  DateTime? to,
}) {
  final bool bounded = from != null && to != null;
  final DateTime? start = bounded ? dateOnly(from) : null;
  final DateTime? end = bounded ? dateOnly(to) : null;

  final Map<String, Debt> byId = <String, Debt>{
    for (final Debt debt in debts)
      if (debt.currency == currency) debt.id: debt,
  };

  // Every event, then one ordering: by date, a debt before a payment on the
  // same day, and otherwise the order the records came in.
  final List<_HistoryEvent> events = <_HistoryEvent>[
    for (final Debt debt in byId.values) _HistoryEvent(debt, null),
    for (final Payment payment in payments)
      if (payment.debtId != null && byId.containsKey(payment.debtId))
        _HistoryEvent(byId[payment.debtId]!, payment),
  ];
  final Map<_HistoryEvent, int> arrival = <_HistoryEvent, int>{
    for (int i = 0; i < events.length; i++) events[i]: i,
  };
  events.sort((_HistoryEvent a, _HistoryEvent b) {
    final int byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final int byKind = a.rank.compareTo(b.rank);
    if (byKind != 0) return byKind;
    return arrival[a]!.compareTo(arrival[b]!);
  });

  final Map<String, int> remaining = <String, int>{};
  int position() {
    int owedToMe = 0;
    int iOwe = 0;
    for (final MapEntry<String, int> entry in remaining.entries) {
      if (byId[entry.key]!.direction.isIOwe) {
        iOwe += entry.value;
      } else {
        owedToMe += entry.value;
      }
    }
    return owedToMe - iOwe;
  }

  int opening = 0;
  final List<StatementEntry> entries = <StatementEntry>[];
  for (final _HistoryEvent event in events) {
    final DateTime day = dateOnly(event.date);
    if (bounded) {
      // After the period, nothing is applied: the closing balance is the one
      // the account held when the period ended, not the one it holds now.
      if (day.isAfter(end!)) continue;
      // Before it, the event is still applied, and the position it leaves is
      // the balance the period opens with.
      if (day.isBefore(start!)) {
        _apply(event, remaining);
        opening = position();
        continue;
      }
    }

    _apply(event, remaining);
    final int balance = position();
    final Debt debt = event.debt;
    final Payment? payment = event.payment;
    final String title = debt.title.trim();
    entries.add(
      StatementEntry(
        date: event.date,
        kind: payment == null
            ? StatementEntryKind.debtCreated
            : StatementEntryKind.payment,
        direction: debt.direction,
        amountMinor: payment?.amountMinor ?? debt.principalMinor,
        balanceAfterMinor: balance.abs(),
        balanceDirection: balance == 0
            ? null
            : (balance > 0 ? DebtDirection.owedToMe : DebtDirection.iOwe),
        currency: currency,
        debtTitle: title.isEmpty ? null : title,
        note: payment?.note,
      ),
    );
  }
  return StatementHistory(
    entries: entries,
    openingMinor: opening,
    // Wanted even for an unbounded history: the document still falls back to
    // the last printed row without a period, but callers can ask where the
    // account ended up either way.
    closingMinor: entries.isEmpty
        ? opening
        : position(),
  );
}

/// The unbounded history, as the statement printed it before periods existed.
List<StatementEntry> buildStatementEntries({
  required List<Debt> debts,
  required List<Payment> payments,
  required AppCurrency currency,
}) =>
    buildStatementHistory(
      debts: debts,
      payments: payments,
      currency: currency,
    ).entries;

/// Applies [event] to the per-debt remaining balances.
void _apply(_HistoryEvent event, Map<String, int> remaining) {
  final Debt debt = event.debt;
  final Payment? payment = event.payment;
  if (payment == null) {
    remaining[debt.id] = debt.principalMinor;
  } else {
    final int left = (remaining[debt.id] ?? 0) - payment.amountMinor;
    remaining[debt.id] = left < 0 ? 0 : left;
  }
}

/// A debt being recorded, or a payment on it: one row of the history.
class _HistoryEvent {
  _HistoryEvent(this.debt, this.payment);

  final Debt debt;

  /// Null for the debt's own opening row.
  final Payment? payment;

  DateTime get date => payment?.paidAt ?? debt.issuedAt;

  /// A debt comes before a payment made on the same day.
  int get rank => payment == null ? 0 : 1;
}
