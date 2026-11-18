import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/brand/brand_mark.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/pdf/statement_document.dart';
import '../../core/pdf/statement_models.dart';
import '../../core/utils/dates.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/debt_enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// Builds and writes a person's debt statement.
///
/// The service owns three things the template should not have to know: which
/// records belong in a statement, which of the person's currencies it is about,
/// and what the file is called.
class StatementService {
  StatementService({
    required this.localizations,
    required this.formatting,
  });

  final AppLocalizations localizations;

  /// The document's figures, dates and language — the resolved one, so a
  /// statement is written in the language the screen that shared it is in.
  final AppFormatting formatting;

  /// Cached so a second statement in the same session does not re-read the font.
  static ByteData? _regularFontCache;
  static ByteData? _semiBoldFontCache;
  static BrandMark? _markCache;

  static const String _regularFontPath =
      'assets/fonts/IBMPlexSansArabic-Regular.ttf';
  static const String _semiBoldFontPath =
      'assets/fonts/IBMPlexSansArabic-SemiBold.ttf';

  /// Assembles the statement for [ledger] in [currency].
  ///
  /// Everything is derived from the stored records: the totals are the same
  /// arithmetic the app shows on screen, and the history is the payments that
  /// actually exist. Nothing is estimated or filled in.
  StatementData buildData({
    required PersonLedger ledger,
    required List<Payment> payments,
    required AppCurrency currency,
    required DateTime now,
    StatementOptions options = const StatementOptions(),
  }) {
    // The records this statement covers: the person's debts in the currency
    // being stated, narrowed to what the options ask for. One line each,
    // counted once. A record they share with other people is still a record
    // between the two of them as far as this statement is concerned, so it is
    // printed and totalled like any other; the other people on it are not this
    // statement's business and are not named.
    //
    // Everything below — the totals, the status, the history — is derived from
    // this list and nothing else, so a debt that is left out is left out of
    // every figure too. A statement can never show a total that includes a row
    // it did not print.
    final bool bounded = options.hasPeriod;
    final DateTime? start = bounded ? dateOnly(options.periodFrom!) : null;
    final DateTime? end = bounded ? dateOnly(options.periodTo!) : null;

    final List<DebtView> inCurrency = debtsInScope(
      ledger: ledger,
      currency: currency,
      options: options,
    );

    // A period asks a second question of the scope: was this debt part of the
    // account inside those days? A debt opened after the period is not, and a
    // debt settled before it is not either. The screen's current scope is the
    // starting point, but its settled test is today's: a debt settled after the
    // period was still open when the period ended, and belongs on the page with
    // the figure it held then.
    final List<DebtView> base =
        bounded && options.scope == StatementScope.openOnly
            ? debtsInScope(
                ledger: ledger,
                currency: currency,
                options: options.copyWith(scope: StatementScope.all),
              )
            : inCurrency;

    // The history is built from every debt that could matter inside the period,
    // including one settled today, so its payments up to the period's end are
    // applied. Without a period this is exactly the list it always was.
    final List<Debt> historyDebts = <Debt>[
      for (final DebtView view in bounded ? base : inCurrency) view.debt,
    ];

    // The movements inside the stated period, plus the balance the period
    // opens with and the per-debt position at its end. Without a period this is
    // every movement and no opening balance — the document the app has always
    // printed.
    final StatementHistory history = buildStatementHistory(
      debts: historyDebts,
      payments: payments,
      currency: currency,
      from: bounded ? options.periodFrom : null,
      to: bounded ? options.periodTo : null,
    );

    // The debts this document is about. With a period it is the debts that had
    // a balance on at least one of its days: opened inside it, or already open
    // when it began. A debt settled before it, or opened after it, has no
    // figure on a page about those days.
    final List<DebtView> covered = !bounded
        ? inCurrency
        : base.where((DebtView view) {
            final DateTime issued = dateOnly(view.debt.issuedAt);
            if (issued.isAfter(end!)) return false;
            if (options.scope != StatementScope.openOnly) return true;
            if (!issued.isBefore(start!)) return true;
            return (history.remainingAtStart[view.debt.id] ?? 0) > 0;
          }).toList();

    final ({int settled, int archived}) hidden = _hiddenCounts(
      ledger: ledger,
      currency: currency,
      options: options,
      covered: bounded ? covered : null,
    );

    final int total = covered.fold<int>(
      0,
      (int sum, DebtView view) => sum + view.debt.principalMinor,
    );
    // A period's figures are the ones the same pass just worked out for its
    // last day. Without a period the current values are what the document has
    // always printed and are used unchanged.
    final int paid = covered.fold<int>(
      0,
      (int sum, DebtView view) => sum +
          (bounded ? (history.paidAtEnd[view.debt.id] ?? 0) : view.paidMinor),
    );
    final int remaining = covered.fold<int>(
      0,
      (int sum, DebtView view) => sum +
          (bounded
              ? (history.remainingAtEnd[view.debt.id] ?? 0)
              : view.remainingMinor),
    );

    // A status is a fact about today, and a period has none: the model carries
    // the neutral state and the document leaves the badge and column out. The
    // next due date is the same kind of fact and is left null for a period.
    final DebtLifecycleStatus status = bounded
        ? DebtLifecycleStatus.active
        : _worstStatus(covered);

    final DebtView? nextDue = bounded ? null : _earliestOpenDue(covered);
    final DateTime? dueAt = nextDue?.debt.dueAt;
    final String? dueTitle = nextDue?.debt.title.trim();

    return StatementData(
      documentNumber: _documentNumber(ledger.person.id, now),
      generatedAt: now,
      language: formatting.language,
      personName: ledger.person.name,
      phone: ledger.person.phone,
      currency: currency,
      totalMinor: total,
      paidMinor: paid,
      remainingMinor: remaining,
      status: status,
      dueAt: dueAt,
      // Named only when there is more than one debt to tell apart: on a
      // statement of one debt the date can only be that debt's.
      dueDebtTitle:
          covered.length > 1 && dueTitle != null && dueTitle.isNotEmpty
              ? dueTitle
              : null,
      debts: <StatementDebtLine>[
        for (final DebtView view in covered)
          StatementDebtLine(
            title: view.debt.title,
            direction: view.debt.direction,
            principal: view.principal,
            paid: bounded
                ? Money(history.paidAtEnd[view.debt.id] ?? 0, currency)
                : view.paid,
            remaining: bounded
                ? Money(history.remainingAtEnd[view.debt.id] ?? 0, currency)
                : view.remaining,
            status: view.status,
            dueAt: view.debt.dueAt,
            note: view.debt.note,
          ),
      ],
      entries: history.entries,
      options: options,
      notes: options.includeNotes
          ? _collectedNotes(covered)
          : null,
      hiddenSettledCount: hidden.settled,
      hiddenArchivedCount: hidden.archived,
      periodFrom: options.hasPeriod ? options.periodFrom : null,
      periodTo: options.hasPeriod ? options.periodTo : null,
      openingBalanceMinor: history.openingMinor,
      // Null without a period: the document then closes on its last printed
      // movement, exactly as it did before periods were offered.
      closingBalanceMinor: options.hasPeriod ? history.closingMinor : null,
    );
  }

  /// How many records the scope left out, counting against [covered] when a
  /// period decides inclusion rather than today's state.
  static ({int settled, int archived}) _hiddenCounts({
    required PersonLedger ledger,
    required AppCurrency currency,
    required StatementOptions options,
    required List<DebtView>? covered,
  }) {
    if (covered == null) {
      return hiddenCounts(
        ledger: ledger,
        currency: currency,
        options: options,
      );
    }
    final Set<String> shown = <String>{
      for (final DebtView view in covered) view.debt.id,
    };
    int settled = 0;
    int archived = 0;
    for (final DebtView view in ledger.debts) {
      if (view.currency != currency || shown.contains(view.debt.id)) continue;
      if (view.debt.isArchived) {
        archived++;
      } else if (view.isSettled) {
        settled++;
      }
    }
    return (settled: settled, archived: archived);
  }

  /// How many of the person's debts in [currency] the scope leaves out, by why.
  ///
  /// An archived debt that is also settled is one hidden record, not two: it is
  /// counted as archived, since that is the option that would bring it back.
  static ({int settled, int archived}) hiddenCounts({
    required PersonLedger ledger,
    required AppCurrency currency,
    required StatementOptions options,
  }) {
    final Set<String> shown = <String>{
      for (final DebtView view in debtsInScope(
        ledger: ledger,
        currency: currency,
        options: options,
      ))
        view.debt.id,
    };
    int settled = 0;
    int archived = 0;
    for (final DebtView view in ledger.debts) {
      if (view.currency != currency || shown.contains(view.debt.id)) continue;
      if (view.debt.isArchived) {
        archived++;
      } else if (view.isSettled) {
        settled++;
      }
    }
    return (settled: settled, archived: archived);
  }

  /// The debts of [ledger] in [currency] that [options] put on a statement.
  ///
  /// The one place the scope is decided. The rules, in order:
  ///
  ///  1. Only the currency being stated.
  ///  2. [StatementScope.selected] means exactly the ticked debts, and stops
  ///     there: ticking a settled or an archived debt is the user asking for
  ///     it, so the two rules below do not apply.
  ///  3. An archived debt is left out unless [StatementOptions.includeArchived].
  ///  4. Under [StatementScope.openOnly] a settled debt is left out.
  ///
  /// Reads the ledger it is given and returns a new list; it writes nothing.
  static List<DebtView> debtsInScope({
    required PersonLedger ledger,
    required AppCurrency currency,
    required StatementOptions options,
  }) {
    final Iterable<DebtView> inCurrency = ledger.debts.where(
      (DebtView view) => view.currency == currency,
    );
    if (options.scope == StatementScope.selected) {
      return inCurrency
          .where(
            (DebtView view) => options.selectedDebtIds.contains(view.debt.id),
          )
          .toList();
    }
    return inCurrency.where((DebtView view) {
      if (view.debt.isArchived && !options.includeArchived) return false;
      if (options.scope == StatementScope.openOnly && view.isSettled) {
        return false;
      }
      return true;
    }).toList();
  }

  /// The currencies a statement can be made in under [options], so the caller
  /// can offer a choice when there is more than one.
  ///
  /// Follows the same scope as the document: a currency whose every debt is
  /// left out is not offered, because choosing it would produce an empty page.
  static List<AppCurrency> currenciesFor(
    PersonLedger ledger, {
    StatementOptions options = const StatementOptions(),
  }) {
    final Set<AppCurrency> all = <AppCurrency>{
      for (final DebtView view in ledger.debts) view.currency,
    };
    final List<AppCurrency> unique = <AppCurrency>[
      for (final AppCurrency currency in all)
        if (debtsInScope(
          ledger: ledger,
          currency: currency,
          options: options,
        ).isNotEmpty)
          currency,
    ]..sort((AppCurrency a, AppCurrency b) => a.code.compareTo(b.code));
    return unique;
  }

  /// Every currency this person has a debt in, whatever its state.
  ///
  /// What tells "this person has nothing at all" apart from "nothing matches
  /// what the statement is set to show".
  static List<AppCurrency> allCurrenciesFor(PersonLedger ledger) =>
      currenciesFor(
        ledger,
        options: const StatementOptions(
          scope: StatementScope.all,
          includeArchived: true,
        ),
      );

  /// Renders the statement to a PDF file and returns its path.
  ///
  /// Written into the app's own documents directory, not a temporary one: the
  /// sheet offers "save a copy", and a temp file can be swept away while the user
  /// is still deciding.
  Future<File> render(StatementData data) async {
    final StatementDocument document = StatementDocument(
      data: data,
      localizations: localizations,
      formatting: formatting,
      regularFont: await _regularFont(),
      semiBoldFont: await _semiBoldFont(),
      mark: await _mark(),
    );

    final Uint8List bytes = await document.build().save();
    final Directory directory = await _outputDirectory();
    final File file = File(p.join(directory.path, data.fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// The parts of the payment [payment] belongs to, among [personPayments].
  ///
  /// A payment recorded from a person's page against several debts is written
  /// as one row per debt, in one transaction. Nothing stored joins them, but
  /// they share what the transaction gave them: the person, the moment they
  /// were written (to the millisecond), the day paid and the currency. That is
  /// the group. A payment recorded on one debt is a group of one.
  ///
  /// [payment] is always in the result, first if it is alone. The rest are in
  /// the order they were written. Pure: reads the list it is given.
  static List<Payment> paymentGroupOf(
    Payment payment,
    Iterable<Payment> personPayments,
  ) {
    if (payment.personId == null || payment.debtId == null) {
      return <Payment>[payment];
    }
    final List<Payment> group = <Payment>[
      for (final Payment other in personPayments)
        if (other.debtId != null &&
            other.personId == payment.personId &&
            other.createdAt == payment.createdAt &&
            other.paidAt == payment.paidAt &&
            other.currency == payment.currency)
          other,
    ];
    if (!group.any((Payment other) => other.id == payment.id)) {
      group.add(payment);
    }
    group.sort((Payment a, Payment b) => a.id.compareTo(b.id));
    return group;
  }

  /// Assembles the receipt for a payment: one part, or every part of a payment
  /// that was spread over several debts.
  ///
  /// [parts] pairs each payment row with the debt it was applied to, as that
  /// debt stands now. Read from stored records: nothing is written and no
  /// receipt number is kept. The same payment issued in the same minute gets
  /// the same number; issued again later it gets a later one.
  ///
  /// The payment's note is printed only with [includeNote]: a note is often
  /// the user's own reminder, and a receipt is handed to the other party. When
  /// the parts of a split payment carry different notes — one was edited
  /// afterwards — none is printed, rather than one picked at random.
  ReceiptData buildReceipt({
    required List<({DebtView view, Payment payment})> parts,
    required String personName,
    required DateTime now,
    String issuerName = '',
    bool includeNote = false,
  }) {
    assert(parts.isNotEmpty, 'a receipt needs a payment');
    String two(int value) => value.toString().padLeft(2, '0');
    final String day =
        '${now.year.toString().padLeft(4, '0')}${two(now.month)}${two(now.day)}';
    final Payment first = parts.first.payment;
    final AppCurrency currency = first.currency;
    final int total = parts.fold<int>(
      0,
      (int sum, ({DebtView view, Payment payment}) part) =>
          sum + part.payment.amountMinor,
    );
    final int remaining = parts.fold<int>(
      0,
      (int sum, ({DebtView view, Payment payment}) part) =>
          sum + part.view.remainingMinor,
    );
    final Set<String> notes = <String>{
      for (final ({DebtView view, Payment payment}) part in parts)
        part.payment.note?.trim() ?? '',
    };
    final String? note =
        includeNote && notes.length == 1 && notes.single.isNotEmpty
            ? notes.single
            : null;
    String titleOf(DebtView view) {
      final String title = view.debt.title.trim();
      return title.isEmpty ? localizations.reportUntitledDebt : title;
    }

    final String singleTitle = parts.first.view.debt.title.trim();
    return ReceiptData(
      // From the first part's id, so every part of one payment gives the same
      // number however the receipt was opened.
      number: 'RCP-$day-${two(now.hour)}${two(now.minute)}-'
          '${StatementData.stableCode(first.id)}',
      issuedAt: now,
      language: formatting.language,
      personName: personName,
      issuerName: issuerName,
      direction: parts.first.view.debt.direction,
      amount: Money(total, currency),
      paidAt: first.paidAt,
      remainingNow: Money(remaining, currency),
      debtTitle: parts.length == 1 && singleTitle.isNotEmpty ? singleTitle : null,
      note: note,
      lines: parts.length < 2
          ? const <ReceiptLine>[]
          : <ReceiptLine>[
              for (final ({DebtView view, Payment payment}) part in parts)
                ReceiptLine(
                  debtTitle: titleOf(part.view),
                  amount: Money(part.payment.amountMinor, currency),
                  remainingNow: part.view.remaining,
                ),
            ],
    );
  }

  /// Renders a receipt to a PDF file and returns it.
  ///
  /// Into the same folder as statements, so the same clean-up removes it.
  Future<File> renderReceipt(ReceiptData data) async {
    final Uint8List bytes = await ReceiptDocument(
      data: data,
      localizations: localizations,
      formatting: formatting,
      regularFont: await _regularFont(),
      semiBoldFont: await _semiBoldFont(),
      mark: await _mark(),
    ).build().save();
    final Directory directory = await _outputDirectory();
    final File file = File(p.join(directory.path, data.fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// The folder, inside the app's documents directory, that generated
  /// statements are written to. Nothing else is ever put in it.
  static const String generatedFolder = 'statements';

  /// Deletes generated statement files, and returns how many it removed.
  ///
  /// A statement is written to a file so it can be shared, and that file used
  /// to stay for good: a name and a balance, in plain sight of anything that
  /// can read the app's storage, long after the debt was settled — and still
  /// there after the user chose "delete all data". With [olderThan], only files
  /// last written before that long ago are removed, which is what start-up
  /// asks for so a document being shared right now is left alone; without it,
  /// every one is removed.
  ///
  /// What it may touch is deliberately narrow, because this is a delete and the
  /// same directory tree holds the ledger:
  ///
  ///  * only the [generatedFolder] directly under [root] — never [root] itself,
  ///    where the database lives, and never the backups folder beside it;
  ///  * only regular files whose name ends in `.pdf`, one level deep, links
  ///    not followed;
  ///  * the folder itself is left in place.
  ///
  /// It never throws. A file that cannot be removed is skipped: failing to tidy
  /// up must not become a reason the app does not start, or a reason the user
  /// cannot clear their data.
  ///
  /// [root] is the documents directory; it is a parameter so a test can point
  /// this at a directory of its own and prove what is left standing.
  static Future<int> purgeGenerated({
    Duration? olderThan,
    Directory? root,
    DateTime? now,
  }) async {
    int removed = 0;
    try {
      final Directory base = root ?? await getApplicationDocumentsDirectory();
      final Directory statements =
          Directory(p.join(base.path, generatedFolder));
      if (!await statements.exists()) return 0;
      final DateTime? cutoff =
          olderThan == null ? null : (now ?? DateTime.now()).subtract(olderThan);
      await for (final FileSystemEntity entity
          in statements.list(followLinks: false)) {
        if (entity is! File) continue;
        if (p.extension(entity.path).toLowerCase() != '.pdf') continue;
        try {
          if (cutoff != null &&
              !(await entity.lastModified()).isBefore(cutoff)) {
            continue;
          }
          await entity.delete();
          removed++;
        } on Object {
          // One stubborn file is not a reason to leave the rest.
        }
      }
    } on Object {
      // No documents directory, no permission, a folder that vanished mid-way:
      // nothing was promised, so nothing is reported.
    }
    return removed;
  }

  /// A directory that survives for as long as the app is installed.
  Future<Directory> _outputDirectory() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory statements = Directory(p.join(base.path, generatedFolder));
    if (!await statements.exists()) {
      await statements.create(recursive: true);
    }
    return statements;
  }

  static Future<ByteData> _regularFont() async =>
      _regularFontCache ??= await rootBundle.load(_regularFontPath);

  static Future<ByteData> _semiBoldFont() async =>
      _semiBoldFontCache ??= await rootBundle.load(_semiBoldFontPath);

  /// The brand mark, from the same master the launcher icons are built from.
  static Future<BrandMark> _mark() async =>
      _markCache ??= await BrandMark.load();

  /// `DHM-20261113-1438-4821`: the day and minute it was issued, then a stable
  /// code for the person.
  ///
  /// It used to be the year and the code, so every statement a person was sent
  /// in a year carried the same number, and a number quoted back in a
  /// conversation could mean any of them. The moment makes it the number of
  /// this document; nothing is stored to keep it unique.
  String _documentNumber(String personId, DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final String code = StatementData.stableCode(personId);
    final String day =
        '${now.year.toString().padLeft(4, '0')}${two(now.month)}${two(now.day)}';
    return 'DHM-$day-${two(now.hour)}${two(now.minute)}-$code';
  }

  /// The most demanding status among the debts shown.
  static DebtLifecycleStatus _worstStatus(List<DebtView> views) {
    if (views.isEmpty) return DebtLifecycleStatus.active;
    // A statement of nothing but archived debts — possible when they were
    // ticked by hand — is archived, not "paid": the loop below skips them and
    // would otherwise leave the starting value standing.
    if (views.every((DebtView view) => view.debt.isArchived)) {
      return DebtLifecycleStatus.archived;
    }
    DebtLifecycleStatus worst = DebtLifecycleStatus.paid;
    for (final DebtView view in views) {
      if (view.debt.isArchived) continue;
      if (view.status.urgency > worst.urgency) worst = view.status;
    }
    return worst;
  }

  /// The open debt that falls due first, or null when none has a date.
  static DebtView? _earliestOpenDue(List<DebtView> views) {
    DebtView? earliest;
    for (final DebtView view in views) {
      if (!view.isOpen) continue;
      final DateTime? due = view.debt.dueAt;
      if (due == null) continue;
      if (earliest == null || due.isBefore(earliest.debt.dueAt!)) {
        earliest = view;
      }
    }
    return earliest;
  }

  /// Notes from the debts, joined so one block carries them all.
  static String? _collectedNotes(List<DebtView> views) {
    final List<String> notes = <String>[];
    for (final DebtView view in views) {
      final String? note = view.debt.note?.trim();
      if (note == null || note.isEmpty) continue;
      final String label = view.debt.title.trim();
      notes.add(label.isEmpty ? note : '$label: $note');
    }
    if (notes.isEmpty) return null;
    return notes.join('\n');
  }
}
