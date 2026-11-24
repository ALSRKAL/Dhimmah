import 'dart:typed_data';

import 'package:dhimmah/core/brand/brand_mark.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/pdf/pdf_text.dart';
import 'package:dhimmah/core/pdf/statement_document.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pdf_inspector.dart';

/// Regressions for the statement defects found on the release-candidate phone.
///
/// Every assertion reads the generated PDF's text positions. A widget tree that
/// looks correct is not enough here: the empty notes box was painted by the
/// paginator while the text inside it moved to another page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ByteData regular;
  late ByteData semiBold;
  late BrandMark mark;
  final DateTime now = DateTime(2026, 11, 24, 14, 36);

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    regular = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    semiBold = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    );
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

  Future<PdfInspection> render(StatementData data) async {
    final Uint8List bytes = await StatementDocument(
      data: data,
      localizations: l10n(data.language),
      formatting: formatting(data.language),
      regularFont: regular,
      semiBoldFont: semiBold,
      mark: mark,
    ).build().save();
    return inspectPdf(bytes);
  }

  String drawnWord(String logicalWord) => containsArabic(logicalWord)
      ? shapeArabic(logicalWord).split('').reversed.join()
      : logicalWord;

  List<PdfRun> lineWithAllWords(PdfInspection page, String phrase) {
    final List<String> wanted = phrase
        .split(' ')
        .map(drawnWord)
        .toList(growable: false);
    for (final List<PdfRun> line in page.lines) {
      final String drawn = line.map((PdfRun run) => run.text).join(' ');
      if (wanted.every(drawn.contains)) return line;
    }
    return const <PdfRun>[];
  }

  StatementDebtLine debtLine(
    String title, {
    DebtDirection direction = DebtDirection.iOwe,
    DateTime? dueAt,
    int principal = 10000,
    int paid = 0,
    int remaining = 10000,
  }) => StatementDebtLine(
    title: title,
    direction: direction,
    principal: Money(principal, AppCurrency.usd),
    paid: Money(paid, AppCurrency.usd),
    remaining: Money(remaining, AppCurrency.usd),
    status: remaining == 0
        ? DebtLifecycleStatus.paid
        : DebtLifecycleStatus.active,
    dueAt: dueAt,
  );

  StatementData statement({
    required AppLanguage language,
    required List<StatementDebtLine> debts,
    List<StatementEntry> entries = const <StatementEntry>[],
    DateTime? dueAt,
    String? dueDebtTitle,
    String? notes,
    int total = 20000,
    int paid = 0,
    int remaining = 20000,
    StatementOptions options = const StatementOptions(
      includePayments: false,
      includeNotes: true,
    ),
  }) => StatementData(
    documentNumber: 'DHM-2026-0008',
    generatedAt: now,
    language: language,
    personName: 'Release regression',
    phone: null,
    currency: AppCurrency.usd,
    totalMinor: total,
    paidMinor: paid,
    remainingMinor: remaining,
    status: DebtLifecycleStatus.active,
    dueAt: dueAt,
    dueDebtTitle: dueDebtTitle,
    debts: debts,
    entries: entries,
    options: options,
    notes: notes,
  );

  group('the narrow Side column', () {
    for (final AppLanguage language in AppLanguage.values) {
      test('every Side cell stays on one line in ${language.code}', () async {
        final AppLocalizations strings = l10n(language);
        final PdfInspection page = await render(
          statement(
            language: language,
            debts: <StatementDebtLine>[
              debtLine('SIDE-A'),
              debtLine('SIDE-B', direction: DebtDirection.owedToMe),
            ],
          ),
        );

        final PdfRun header = page.runs.singleWhere(
          (PdfRun run) => run.text == drawnWord(strings.reportColumnSide),
        );
        const double contentWidth = 595.276 - 38 * 2;
        const double sideWidth = contentWidth * 0.08;
        final double sideLeft = language.isRtl
            ? header.right + 5 - sideWidth
            : header.x - 5;
        final double sideRight = sideLeft + sideWidth;

        for (final StatementDebtLine debt in <StatementDebtLine>[
          debtLine('SIDE-A'),
          debtLine('SIDE-B', direction: DebtDirection.owedToMe),
        ]) {
          final List<PdfRun> row = lineWithAllWords(page, debt.title);
          expect(row, isNotEmpty, reason: '${debt.title} was not printed');
          final String side = debt.direction.isIOwe
              ? strings.reportSideTableOwed
              : strings.reportSideOwes;
          final List<PdfRun> cells = row
              .where((PdfRun run) => run.text == drawnWord(side))
              .toList(growable: false);
          expect(
            cells,
            hasLength(1),
            reason: '${debt.title}: Side must occupy one baseline',
          );
          expect(cells.single.x, greaterThanOrEqualTo(sideLeft - 2));
          expect(cells.single.right, lessThanOrEqualTo(sideRight + 2));
        }
      });
    }
  });

  group('the summary due label', () {
    for (final AppLanguage language in AppLanguage.values) {
      Future<PdfInspection> renderDue(
        DateTime due, {
        bool singleDebt = false,
      }) => render(
        statement(
          language: language,
          debts: <StatementDebtLine>[
            debtLine('DUE-A', dueAt: due),
            if (!singleDebt)
              debtLine(
                'DUE-B',
                dueAt: DateTime(2026, 12, 20),
                principal: 5000,
                remaining: 5000,
              ),
          ],
          dueAt: due,
          dueDebtTitle: singleDebt ? null : 'DUE-A',
          total: singleDebt ? 10000 : 15000,
          remaining: singleDebt ? 10000 : 15000,
        ),
      );

      test('a past due date says Was due in ${language.code}', () async {
        final DateTime due = DateTime(2026, 11, 20);
        final PdfInspection page = await renderDue(due);
        final List<PdfRun> line = lineWithAllWords(
          page,
          l10n(language).reportWasDue,
        );
        expect(line, isNotEmpty);
        expect(
          lineWithAllWords(page, formatting(language).date(due)),
          isNotEmpty,
        );
        if (language == AppLanguage.english) {
          expect(lineWithAllWords(page, 'Next due'), isEmpty);
        }
      });

      test('a future due date says Next due in ${language.code}', () async {
        final DateTime due = DateTime(2026, 12);
        final PdfInspection page = await renderDue(due);
        expect(
          lineWithAllWords(page, l10n(language).reportNextDue),
          isNotEmpty,
        );
        expect(
          lineWithAllWords(page, formatting(language).date(due)),
          isNotEmpty,
        );
        if (language == AppLanguage.english) {
          expect(lineWithAllWords(page, 'Was due'), isEmpty);
        }
      });

      test(
        'a debt due today is not called Was due in ${language.code}',
        () async {
          final DateTime due = DateTime(2026, 11, 24, 1);
          final PdfInspection page = await renderDue(due);
          expect(
            lineWithAllWords(page, l10n(language).reportNextDue),
            isNotEmpty,
          );
          if (language == AppLanguage.english) {
            expect(lineWithAllWords(page, 'Was due'), isEmpty);
          }
        },
      );

      test('a single past debt keeps Due on in ${language.code}', () async {
        final PdfInspection page = await renderDue(
          DateTime(2026, 11, 20),
          singleDebt: true,
        );
        expect(lineWithAllWords(page, l10n(language).detailDueOn), isNotEmpty);
        if (language == AppLanguage.english) {
          expect(lineWithAllWords(page, 'Was due'), isEmpty);
        }
      });
    }
  });

  group('upgrade notes at a page boundary', () {
    const String note = 'دفعة أولى\nباقي 150\nملاحظة الترقية';

    StatementData upgradeStatement(int precedingMovements) {
      final Person person = Person(
        id: '12282025-cfc0-4e7b-9a7f-acde8284cafe',
        name: 'اختبار الترقية',
        colorIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      final Debt debt = Debt(
        id: '6e57471d-9a6c-4ab4-9f28-1852c5292c7c',
        personIds: <String>[person.id],
        direction: DebtDirection.iOwe,
        title: '',
        principalMinor: 20000,
        currency: AppCurrency.usd,
        issuedAt: DateTime(2026, 11, 24, 9),
        dueAt: DateTime(2026, 12),
        createdAt: now,
        updatedAt: now,
      );
      final DebtView view = DebtView(
        debt: debt,
        paidMinor: 5000,
        remainingMinor: 15000,
        status: DebtLifecycleStatus.active,
        paymentCount: 1,
        participants: <Person>[person],
        lastPaymentAt: DateTime(2026, 11, 24, 10),
      );
      final List<Payment> payments = <Payment>[
        for (int i = 0; i < precedingMovements; i++)
          Payment(
            id: 'preceding-$i',
            debtId: debt.id,
            personId: person.id,
            amountMinor: 0,
            currency: AppCurrency.usd,
            paidAt: DateTime(2026, 11, 24, 9, 1, i),
            createdAt: now,
          ),
        Payment(
          id: '1286e3e2-696c-46c9-a9e1-a1fbe99e0e46',
          debtId: debt.id,
          personId: person.id,
          amountMinor: 5000,
          currency: AppCurrency.usd,
          paidAt: DateTime(2026, 11, 24, 10),
          note: note,
          createdAt: now,
        ),
      ];
      final StatementService service = StatementService(
        localizations: l10n(AppLanguage.arabic),
        formatting: formatting(AppLanguage.arabic),
      );
      return service.buildData(
        ledger: PersonLedger(
          person: person,
          debts: <DebtView>[view],
          totals: const <CurrencyTotals>[],
        ),
        payments: payments,
        currency: AppCurrency.usd,
        now: now,
        options: const StatementOptions(includeNotes: true),
      );
    }

    for (int offset = 0; offset <= 15; offset++) {
      test(
        'upgrade notes stay with their heading at offset $offset',
        () async {
          final StatementData data = upgradeStatement(offset);
          expect(data.totalMinor, 20000);
          expect(data.paidMinor, 5000);
          expect(data.remainingMinor, 15000);
          expect(data.notes, note);
          expect(data.entries, hasLength(offset + 2));

          final PdfInspection page = await render(data);
          final List<PdfRun> heading = lineWithAllWords(
            page,
            l10n(AppLanguage.arabic).fieldNote,
          );
          expect(heading, isNotEmpty, reason: 'the Notes heading is missing');
          final PdfRun title = heading.first;
          final List<List<PdfRun>> noteLines = <List<PdfRun>>[];
          for (final String line in note.split('\n')) {
            final List<String> words = line.split(' ').map(drawnWord).toList();
            final List<List<PdfRun>> matches = page.lines
                .where(
                  (List<PdfRun> candidate) =>
                      candidate.first.page == title.page &&
                      candidate.first.y < title.y &&
                      words.every(
                        (String word) => candidate.any(
                          (PdfRun run) => run.text.contains(word),
                        ),
                      ),
                )
                .toList(growable: false);
            expect(
              matches,
              isNotEmpty,
              reason:
                  '"$line" is not below the Notes heading at offset $offset',
            );
            noteLines.add(
              matches.reduce((List<PdfRun> a, List<PdfRun> b) {
                final double ay = a
                    .map((PdfRun run) => run.y)
                    .reduce((double x, double y) => x > y ? x : y);
                final double by = b
                    .map((PdfRun run) => run.y)
                    .reduce((double x, double y) => x > y ? x : y);
                return ay > by ? a : b;
              }),
            );
          }

          final PdfRun first = noteLines[0].reduce(
            (PdfRun a, PdfRun b) => a.y > b.y ? a : b,
          );
          final PdfRun second = noteLines[1].reduce(
            (PdfRun a, PdfRun b) => a.y > b.y ? a : b,
          );
          final PdfRun third = noteLines[2].reduce(
            (PdfRun a, PdfRun b) => a.y > b.y ? a : b,
          );
          expect(first.y, lessThan(title.y));
          expect(first.y, greaterThan(second.y));
          expect(second.y, greaterThan(third.y));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    }
  });
}
