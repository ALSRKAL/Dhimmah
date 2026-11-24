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
  }) => StatementDebtLine(
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
    final List<StatementDebtLine> lines = debts ?? <StatementDebtLine>[line()];
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

  test(
    'a statement with six hundred debts renders past twenty pages',
    () async {
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
    },
  );

  test(
    'a note, title and name longer than a page are split, not rejected',
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
    },
  );

  test('unsupported glyphs do not fail the statement', () async {
    final StatementData statement = data(
      personName: 'علی کاظم ۱۲۳ 😀',
      debts: <StatementDebtLine>[line(title: 'دین 😀', note: 'یادداشت ۱۲۳ 😀')],
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
      data(debts: const <StatementDebtLine>[], total: 0, remaining: 0),
    );
    expect(bytes, isNotEmpty);
  });

  test(
    'a debt with no title and a person with no name still renders',
    () async {
      final Uint8List bytes = await render(
        data(
          personName: '',
          debts: <StatementDebtLine>[line(title: '')],
        ),
      );
      expect(bytes, isNotEmpty);
    },
  );

  test('a due date before the issue date still renders', () async {
    final Uint8List bytes = await render(
      data(
        debts: <StatementDebtLine>[
          line(title: 'تاريخ مقلوب', dueAt: DateTime(2000)),
        ],
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
  group('pathological single-debt notes', () {
    String squash(String value) => value.replaceAll(RegExp(r'\s+'), '');

    String drawn(PdfInspection inspection) =>
        squash(inspection.runs.map((PdfRun run) => run.text).join());

    void expectEveryPart(PdfInspection inspection, String note) {
      final String all = drawn(inspection);
      for (final String line in note.split('\n')) {
        final String trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        final List<int> runes = trimmed.runes.toList(growable: false);
        for (int start = 0; start < runes.length; start += 45) {
          final int end = start + 45 > runes.length ? runes.length : start + 45;
          final String part = String.fromCharCodes(runes.sublist(start, end));
          final String shaped = squash(pdfText(part));
          final String reversed = String.fromCharCodes(
            shaped.runes.toList().reversed,
          );
          expect(
            all,
            anyOf(contains(shaped), contains(reversed)),
            reason: 'the document lost "$part"',
          );
        }
      }
    }

    String numbered(int count, String prefix, int length) {
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < count; i++) {
        buffer.write('$prefix$i');
        if (i != count - 1) buffer.write('\n');
      }
      String value = buffer.toString();
      if (value.length < length) value += 'x' * (length - value.length);
      return value.substring(0, length);
    }

    final String a = numbered(60, 's', 410);
    final String b = numbered(150, 'b', 489);
    final String c = '${'\n' * 496}END-C';
    final String e = numbered(70, 'p', 199);
    final String f = '${List<String>.filled(60, 'سطر').join('\n')}${'س' * 410}'
        .substring(0, 410);

    final Timeout limit = Timeout(const Duration(seconds: 20));

    Future<PdfInspection> renderCase(
      String name, {
      required String debtNote,
      String? paymentNote,
      required bool notesOn,
      required AppLanguage language,
    }) async {
      final StatementData statement = data(
        language: language,
        debts: <StatementDebtLine>[line(note: debtNote)],
        entries: <StatementEntry>[
          if (paymentNote != null)
            StatementEntry(
              date: now,
              kind: StatementEntryKind.payment,
              direction: DebtDirection.owedToMe,
              amountMinor: 1000,
              balanceAfterMinor: 9000,
              currency: AppCurrency.usd,
              note: paymentNote,
            ),
        ],
        notes: notesOn ? <String>[debtNote, ?paymentNote].join('\n') : null,
        options: StatementOptions(includeNotes: notesOn),
        paid: paymentNote == null ? 0 : 1000,
        remaining: paymentNote == null ? 10000 : 9000,
      );
      final Uint8List bytes = await render(statement);
      final PdfInspection inspection = inspectPdf(bytes);
      expect(
        inspection.pageCount,
        lessThan(10),
        reason: '$name stays under ten pages',
      );
      return inspection;
    }

    for (final AppLanguage language in AppLanguage.values) {
      final String suffix = language == AppLanguage.arabic
          ? 'Arabic'
          : 'English';

      test('review case A, 60 short debt-note lines, $suffix', () async {
        final String note = language == AppLanguage.arabic ? f : a;
        final PdfInspection inspection = await renderCase(
          'A $suffix',
          debtNote: note,
          notesOn: true,
          language: language,
        );
        expectEveryPart(inspection, note);
      }, timeout: limit);

      test('review case B, 150 debt-note lines, $suffix', () async {
        final PdfInspection inspection = await renderCase(
          'B $suffix',
          debtNote: b,
          notesOn: true,
          language: language,
        );
        expectEveryPart(inspection, b);
      }, timeout: limit);

      test('review case C, 498 blank debt-note lines, $suffix', () async {
        final PdfInspection inspection = await renderCase(
          'C $suffix',
          debtNote: c,
          notesOn: true,
          language: language,
        );
        expect(drawn(inspection), contains('END-C'));
      }, timeout: limit);

      test('review case D, B with notes off, $suffix', () async {
        await renderCase(
          'D $suffix',
          debtNote: b,
          notesOn: false,
          language: language,
        );
      }, timeout: limit);

      test('review case E, 70 payment-note lines, $suffix', () async {
        final PdfInspection inspection = await renderCase(
          'E $suffix',
          debtNote: '',
          paymentNote: e,
          notesOn: true,
          language: language,
        );
        expectEveryPart(inspection, e);
      }, timeout: limit);

      test('review case F, A in Arabic, $suffix', () async {
        final PdfInspection inspection = await renderCase(
          'F $suffix',
          debtNote: f,
          notesOn: true,
          language: language,
        );
        expectEveryPart(inspection, f);
      }, timeout: limit);
    }

    test('a note of one unbroken run keeps every character', () async {
      final String note = List<String>.filled(500, 'Q').join();
      final PdfInspection inspection = await renderCase(
        'unbroken',
        debtNote: note,
        notesOn: true,
        language: AppLanguage.english,
      );
      final String all = drawn(inspection);
      final int qs = 'Q'.allMatches(all).length;
      expect(qs, greaterThanOrEqualTo(500), reason: 'every Q survives');
    }, timeout: limit);

    test('every field at its UI limit, on one debt', () async {
      final String name = 'N' * 120;
      final String title = 'T' * 120;
      final String debtNote = '${'\n' * 498}DEBT-END';
      final String paymentNote = '${'\n' * 198}PAY-END';
      final String personNote = '${'\n' * 298}PERSON-END';
      final StatementData statement = data(
        personName: name,
        debts: <StatementDebtLine>[line(title: title, note: debtNote)],
        entries: <StatementEntry>[
          StatementEntry(
            date: now,
            kind: StatementEntryKind.payment,
            direction: DebtDirection.owedToMe,
            amountMinor: 1000,
            balanceAfterMinor: 9000,
            currency: AppCurrency.usd,
            note: paymentNote,
          ),
        ],
        notes: <String>[debtNote, personNote, paymentNote].join('\n'),
        paid: 1000,
        remaining: 9000,
      );
      final Uint8List bytes = await render(statement);
      final PdfInspection inspection = inspectPdf(bytes);
      expect(bytes, isNotEmpty);
      final String all = drawn(inspection);
      expect(all, contains('DEBT-END'));
      expect(all, contains('PAY-END'));
      expect(all, contains('PERSON-END'));
      expect(all, contains('N' * 120));
      expect(all, contains('T' * 120));
    }, timeout: limit);
  });
}
