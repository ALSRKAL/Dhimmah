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
    // Every record this person is on, in the currency being stated — one line
    // each, counted once. A record they share with other people is still a
    // record between the two of them as far as this statement is concerned, so
    // it is printed and totalled like any other; the other people on it are not
    // this statement's business and are not named.
    final List<DebtView> inCurrency = <DebtView>[
      for (final DebtView view in ledger.debts)
        if (view.currency == currency) view,
    ];

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

    final DateTime? dueAt = _earliestOpenDue(inCurrency);

    final List<Debt> debts = <Debt>[
      for (final DebtView view in inCurrency) view.debt,
    ];

    return StatementData(
      documentNumber: _documentNumber(ledger.person.id, now),
      documentId: StatementData.stableCode(
        '${ledger.person.id}-$currency-${toIsoDate(now)}',
        length: 6,
      ),
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
    );
  }

  /// The currencies this person has debts in, so the caller can offer a choice
  /// when there is more than one.
  static List<AppCurrency> currenciesFor(PersonLedger ledger) {
    final List<AppCurrency> currencies = <AppCurrency>[
      for (final DebtView view in ledger.debts)
        if (!view.debt.isArchived) view.currency,
    ];
    final List<AppCurrency> unique = <AppCurrency>{
      ...currencies,
    }.toList()
      ..sort((AppCurrency a, AppCurrency b) => a.code.compareTo(b.code));
    return unique;
  }

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

  /// `DHM-2026-4821`: the year, then a stable code for the person.
  String _documentNumber(String personId, DateTime now) {
    final String code = StatementData.stableCode(personId);
    return 'DHM-${now.year}-$code';
  }

  /// The most demanding status among the debts shown.
  static DebtLifecycleStatus _worstStatus(List<DebtView> views) {
    if (views.isEmpty) return DebtLifecycleStatus.active;
    DebtLifecycleStatus worst = DebtLifecycleStatus.paid;
    for (final DebtView view in views) {
      if (view.debt.isArchived) continue;
      if (view.status.urgency > worst.urgency) worst = view.status;
    }
    return worst;
  }

  /// The earliest due date still outstanding.
  static DateTime? _earliestOpenDue(List<DebtView> views) {
    DateTime? earliest;
    for (final DebtView view in views) {
      if (!view.isOpen) continue;
      final DateTime? due = view.debt.dueAt;
      if (due == null) continue;
      if (earliest == null || due.isBefore(earliest)) earliest = due;
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
