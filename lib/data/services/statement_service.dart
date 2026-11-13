import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/brand/brand_mark.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/pdf/statement_document.dart';
import '../../core/pdf/statement_models.dart';
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
    final List<DebtView> inCurrency = debtsInScope(
      ledger: ledger,
      currency: currency,
      options: options,
    );
    final ({int settled, int archived}) hidden = hiddenCounts(
      ledger: ledger,
      currency: currency,
      options: options,
    );

    final int total = inCurrency.fold<int>(
      0,
      (int sum, DebtView view) => sum + view.debt.principalMinor,
    );
    final int paid = inCurrency.fold<int>(
      0,
      (int sum, DebtView view) => sum + view.paidMinor,
    );
    final int remaining = inCurrency.fold<int>(
      0,
      (int sum, DebtView view) => sum + view.remainingMinor,
    );

    // The statement speaks for the whole account, so its status is the most
    // demanding one among the debts it covers: a settled debt and a late one
    // together are not "paid".
    final DebtLifecycleStatus status = _worstStatus(inCurrency);

    final DebtView? nextDue = _earliestOpenDue(inCurrency);
    final DateTime? dueAt = nextDue?.debt.dueAt;
    final String? dueTitle = nextDue?.debt.title.trim();

    final List<Debt> debts = <Debt>[
      for (final DebtView view in inCurrency) view.debt,
    ];

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
          inCurrency.length > 1 && dueTitle != null && dueTitle.isNotEmpty
              ? dueTitle
              : null,
      debts: <StatementDebtLine>[
        for (final DebtView view in inCurrency)
          StatementDebtLine(
            title: view.debt.title,
            direction: view.debt.direction,
            principal: view.principal,
            paid: view.paid,
            remaining: view.remaining,
            status: view.status,
            dueAt: view.debt.dueAt,
            note: view.debt.note,
          ),
      ],
      entries: buildStatementEntries(
        debts: debts,
        payments: payments,
        currency: currency,
      ),
      options: options,
      notes: options.includeNotes
          ? _collectedNotes(inCurrency)
          : null,
      hiddenSettledCount: hidden.settled,
      hiddenArchivedCount: hidden.archived,
    );
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

  /// A directory that survives for as long as the app is installed.
  Future<Directory> _outputDirectory() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory statements = Directory(p.join(base.path, 'statements'));
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
