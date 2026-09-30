import 'package:meta/meta.dart';

import '../../domain/entities/debt.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/preference_enums.dart';
import '../money/currency.dart';
import '../money/money.dart';

/// Which optional blocks a statement includes.
///
/// The defaults are the privacy-safe ones: a document is often sent to the very
/// person the debt is with, so nothing is added unless it helps them read it.
@immutable
class StatementOptions {
  const StatementOptions({
    this.includePayments = true,
    this.includePhone = false,
    this.includeNotes = false,
    this.includeDebtBreakdown = true,
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

  StatementOptions copyWith({
    bool? includePayments,
    bool? includePhone,
    bool? includeNotes,
    bool? includeDebtBreakdown,
  }) {
    return StatementOptions(
      includePayments: includePayments ?? this.includePayments,
      includePhone: includePhone ?? this.includePhone,
      includeNotes: includeNotes ?? this.includeNotes,
      includeDebtBreakdown: includeDebtBreakdown ?? this.includeDebtBreakdown,
    );
  }

  /// Whether any option could change the document.
  bool get isDefault =>
      includePayments && !includePhone && !includeNotes && includeDebtBreakdown;
}

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
    this.notes,
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

  /// Every record this statement covers, one line each, and what the totals are
  /// the sum of.
  final List<StatementDebtLine> debts;

  final List<StatementEntry> entries;
  final StatementOptions options;
  final String? notes;

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

/// Builds the statement's history from real records.
///
/// One list, oldest first, with a running balance, so the table reads as the
/// story of the account: each debt raises the balance on its own side and each
/// payment brings its debt down. No line is invented — every row corresponds to
/// a stored record.
///
/// Two things this used to get wrong. It listed every debt first and every
/// payment after, whatever their dates, so a debt recorded in August sat above
/// a payment made in June and the balance column passed through figures the
/// account never had. And it added money owed to the user and money the user
/// owes into one total. The balance is now the two sides set against each
/// other, and each debt stops at zero, as it does on the debt's own page.
List<StatementEntry> buildStatementEntries({
  required List<Debt> debts,
  required List<Payment> payments,
  required AppCurrency currency,
}) {
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

  final List<StatementEntry> entries = <StatementEntry>[];
  for (final _HistoryEvent event in events) {
    final Debt debt = event.debt;
    final Payment? payment = event.payment;
    if (payment == null) {
      remaining[debt.id] = debt.principalMinor;
    } else {
      final int left = (remaining[debt.id] ?? 0) - payment.amountMinor;
      remaining[debt.id] = left < 0 ? 0 : left;
    }
    final int balance = position();
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
  return entries;
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
