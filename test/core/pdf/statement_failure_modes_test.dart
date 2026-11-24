import 'dart:typed_data';

import 'package:dhimmah/core/brand/brand_mark.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/pdf/statement_document.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pdf_inspector.dart';

/// Failures a real statement can meet that ordinary documents never do.
///
/// The production limit was twenty pages (`pdf`'s default), and a long history
/// failed the preview and the share together. A long unbroken note failed in a
/// different way: it became one widget taller than a page. These build the
/// document through the service and the real renderer, not through a mock.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ByteData regular;
  late ByteData semiBold;
  late BrandMark mark;

  final DateTime now = DateTime(2026, 11, 24);

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    regular =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    semiBold =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf');
    mark = await BrandMark.load();
  });

  AppLocalizations l10n(AppLanguage language) =>
      lookupAppLocalizations(Locale(language.code));

  AppFormatting formatting(AppLanguage language) => AppFormatting(
        language: language,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.usd,
        localizations: l10n(language),
      );

  Future<Uint8List> render(StatementData data) {
    final AppLanguage language = data.language;
    return StatementDocument(
      data: data,
      localizations: l10n(language),
      formatting: formatting(language),
      regularFont: regular,
      semiBoldFont: semiBold,
      mark: mark,
    ).build().save();
  }

  StatementDebtLine line({
    String title = 'سلفة',
    String? note,
    int principal = 10000,
    int paid = 0,
    int remaining = 10000,
    DebtLifecycleStatus status = DebtLifecycleStatus.active,
    DateTime? dueAt,
  }) =>
      StatementDebtLine(
        title: title,
        direction: DebtDirection.owedToMe,
        principal: Money(principal, AppCurrency.usd),
        paid: Money(paid, AppCurrency.usd),
        remaining: Money(remaining, AppCurrency.usd),
        status: status,
        dueAt: dueAt,
        note: note,
      );

  StatementData data({
    String personName = 'خالد العلي',
    List<StatementDebtLine>? debts,
    List<StatementEntry>? entries,
    String? notes,
    AppLanguage language = AppLanguage.english,
    StatementOptions options = const StatementOptions(includeNotes: true),
    int total = 10000,
    int paid = 0,
    int remaining = 10000,
  }) {
    final List<StatementDebtLine> lines =
        debts ?? <StatementDebtLine>[line()];
    return StatementData(
      documentNumber: 'DHM-2026-0001',
      generatedAt: now,
      language: language,
      personName: personName,
      phone: null,
      currency: AppCurrency.usd,
      totalMinor: total,
      paidMinor: paid,
      remainingMinor: remaining,
      status: DebtLifecycleStatus.active,
      debts: lines,
      entries: entries ?? const <StatementEntry>[],
      options: options,
      notes: notes,
    );
  }

  test('a statement with six hundred debts renders past twenty pages', () async {
    final Person person = Person(
      id: 'person-1',
      name: 'خالد العلي',
      colorIndex: 0,
      createdAt: now,
      updatedAt: now,
    );
    final List<DebtView> views = <DebtView>[
      for (int i = 0; i < 600; i++)
        DebtView(
          debt: Debt(
            id: 'debt-$i',
            personIds: <String>[person.id],
            direction: DebtDirection.owedToMe,
            title: 'سلفة $i',
            principalMinor: 10000,
            currency: AppCurrency.usd,
            issuedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
          paidMinor: 0,
          remainingMinor: 10000,
          status: DebtLifecycleStatus.active,
          paymentCount: 0,
          participants: <Person>[person],
        ),
    ];
    final PersonLedger ledger = PersonLedger(
      person: person,
      debts: views,
      totals: const <CurrencyTotals>[],
    );
    final StatementService service = StatementService(
      localizations: l10n(AppLanguage.english),
      formatting: formatting(AppLanguage.english),
    );
    final StatementData statement = service.buildData(
      ledger: ledger,
      payments: const <Never>[],
      currency: AppCurrency.usd,
      now: now,
    );

    final Uint8List bytes = await render(statement);

    expect(bytes, isNotEmpty);
    expect(inspectPdf(bytes).pageCount, greaterThan(20));
  });

  test('a note, title and name longer than a page are split, not rejected',
      () async {
    const String tail = 'END-MARK';
    final String long = '${List<String>.filled(5000, 'A').join()}$tail';
    final StatementData statement = data(
      personName: long,
      debts: <StatementDebtLine>[
        line(title: long),
        line(),
      ],
      notes: long,
      total: 20000,
      remaining: 20000,
    );

    final Uint8List bytes = await render(statement);
    final PdfInspection inspection = inspectPdf(bytes);

    expect(bytes, isNotEmpty);
    expect(inspection.pageCount, greaterThan(1));
    expect(
      inspection.runs.any((PdfRun run) => run.text.contains(tail)),
      isTrue,
      reason: 'the full value has to survive in the appendix or the note',
    );
  });

  test('unsupported glyphs do not fail the statement', () async {
    final StatementData statement = data(
      personName: 'علی کاظم ۱۲۳ 😀',
      debts: <StatementDebtLine>[
        line(title: 'دین 😀', note: 'یادداشت ۱۲۳ 😀'),
      ],
      notes: 'یادداشت ۱۲۳ 😀',
    );

    final Uint8List bytes = await render(statement);

    expect(bytes, isNotEmpty);
    expect(inspectPdf(bytes).pageCount, greaterThanOrEqualTo(1));
  });

  test('a zero-principal debt still renders', () async {
    final Uint8List bytes = await render(
      data(
        debts: <StatementDebtLine>[
          line(
            title: 'صفر',
            principal: 0,
            remaining: 0,
            status: DebtLifecycleStatus.paid,
          ),
        ],
        total: 0,
        remaining: 0,
      ),
    );
    expect(bytes, isNotEmpty);
  });

  test('a payment larger than the remaining still renders', () async {
    final Uint8List bytes = await render(
      data(
        debts: <StatementDebtLine>[
          line(title: 'دفعة أكبر', paid: 20000, remaining: -10000),
        ],
      ),
    );
    expect(bytes, isNotEmpty);
  });

  test('an empty scope still renders a document', () async {
    final Uint8List bytes = await render(
      data(
        debts: const <StatementDebtLine>[],
        total: 0,
        remaining: 0,
      ),
    );
    expect(bytes, isNotEmpty);
  });

  test('a debt with no title and a person with no name still renders', () async {
    final Uint8List bytes = await render(
      data(
        personName: '',
        debts: <StatementDebtLine>[line(title: '')],
      ),
    );
    expect(bytes, isNotEmpty);
  });

  test('a due date before the issue date still renders', () async {
    final Uint8List bytes = await render(
      data(
        debts: <StatementDebtLine>[line(title: 'تاريخ مقلوب', dueAt: DateTime(2000))],
      ),
    );
    expect(bytes, isNotEmpty);
  });

  test('a movement without a debt still renders', () async {
    final Uint8List bytes = await render(
      data(
        entries: <StatementEntry>[
          StatementEntry(
            date: DateTime(2026, 11),
            kind: StatementEntryKind.payment,
            direction: DebtDirection.owedToMe,
            amountMinor: 1000,
            balanceAfterMinor: 9000,
            currency: AppCurrency.usd,
          ),
        ],
      ),
    );
    expect(bytes, isNotEmpty);
  });
}
