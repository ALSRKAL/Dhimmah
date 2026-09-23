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
    required this.amountMinor,
    required this.balanceAfterMinor,
    required this.currency,
    this.note,
  });

  final DateTime date;
  final StatementEntryKind kind;
  final int amountMinor;

  /// The running balance immediately after this entry — the column that makes a
  /// statement legible, because it shows the total shrinking.
  final int balanceAfterMinor;

  final AppCurrency currency;
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
    required this.documentId,
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

  /// Short identifier repeated in the footer, for spotting a specific copy.
  final String documentId;

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

  final List<StatementDebtLine> debts;
  final List<StatementEntry> entries;
  final StatementOptions options;
  final String? notes;

  Money get total => Money(totalMinor, currency);
  Money get paid => Money(paidMinor, currency);
  Money get remaining => Money(remainingMinor, currency);

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
/// Entries are produced oldest-first with a running balance, so the table reads
/// as the story of the debt: it started at the principal, and each payment brought
/// the balance down. No line is invented — every row corresponds to a stored
/// record.
List<StatementEntry> buildStatementEntries({
  required List<Debt> debts,
  required List<Payment> payments,
  required AppCurrency currency,
}) {
  final List<Debt> relevant = <Debt>[
    for (final Debt debt in debts)
      if (debt.currency == currency) debt,
  ]..sort((Debt a, Debt b) => a.issuedAt.compareTo(b.issuedAt));

  final List<StatementEntry> entries = <StatementEntry>[];
  int running = 0;

  for (final Debt debt in relevant) {
    running += debt.principalMinor;
    entries.add(
      StatementEntry(
        date: debt.issuedAt,
        kind: StatementEntryKind.debtCreated,
        amountMinor: debt.principalMinor,
        balanceAfterMinor: running,
        currency: currency,
        note: debt.title.trim().isEmpty ? null : debt.title.trim(),
      ),
    );
  }

  final Set<String> debtIds = <String>{
    for (final Debt debt in relevant) debt.id,
  };
  final List<Payment> relevantPayments = <Payment>[
    for (final Payment payment in payments)
      if (payment.debtId != null && debtIds.contains(payment.debtId))
        payment,
  ]..sort((Payment a, Payment b) => a.paidAt.compareTo(b.paidAt));

  for (final Payment payment in relevantPayments) {
    running -= payment.amountMinor;
    if (running < 0) running = 0;
    entries.add(
      StatementEntry(
        date: payment.paidAt,
        kind: StatementEntryKind.payment,
        amountMinor: payment.amountMinor,
        balanceAfterMinor: running,
        currency: currency,
        note: payment.note,
      ),
    );
  }

  return entries;
}
