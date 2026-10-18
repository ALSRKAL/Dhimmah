import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/app_card.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/amount_rules.dart';
import 'package:dhimmah/features/debts/person_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The screens at the corner of every constraint at once.
///
/// A 320-wide phone with the text at 1.5×, a person named with eighty
/// characters, a record titled with eighty more, and the largest figure the app
/// can hold — 1,000,000,000.00, fourteen glyphs wide. Each of those is survivable
/// alone and they are what a real phone actually has: the people who enlarge
/// their text are the same people who type long names, and the amounts grow.
///
/// Nothing here asserts a pixel. It asserts that the framework's own layout
/// engine found nothing to complain about, which is the only definition of "it
/// fits" that does not need updating every time the design moves — and that the
/// screen really did draw its content, so a screen that failed to build cannot
/// pass by being empty.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late Person ahmed;

  final DateTime today = dateOnly(DateTime.now());

  /// Wide enough to break a row, short enough to be a name somebody types.
  final String longName =
      'أحمد محمد عبد الرحمن الشريف الحسيني الطيباني الجابري اليمني';
  final String longTitle =
      'قرض السيارة الجديدة بالتقسيط الشهري على خمس سنوات كاملة مع الفوائد';
  setUp(() async {
    db = AppDatabase.memory();
    service = buildService(db);
    ahmed = await service.createPerson(PersonDraft(name: longName, phone: '+967 771 234 567'));

    // The widest figure the app can display, in the record that will be on the
    // person's page and in the payment sheet's preview.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: longTitle,
        principalMinor: AmountRules.maxMinor,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 3),
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id],
        title: longTitle,
        principalMinor: 9999999999,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -30),
        dueAt: addDays(today, -2),
      ),
    );

    await service.createObligation(
      ObligationDraft(
        name: longTitle,
        category: ObligationCategory.other,
        amountMinor: AmountRules.maxMinor,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        dayOfMonth: 1,
      ),
    );
    await service.createIncome(
      IncomeDraft(
        name: longTitle,
        amountMinor: AmountRules.maxMinor,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        dayOfMonth: 1,
      ),
    );
    await service.ensureOccurrences();
  });
  tearDown(() async => db.close());

  /// A 320×640 phone, text at 1.5×, in [language].
  Future<void> pumpCorner(
    WidgetTester tester, {
    required bool english,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpDhimmah(
      tester,
      db: db,
      settings: english
          ? AppSettings.initial
              .copyWith(languagePreference: LanguagePreference.english)
          : null,
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The framework reports an overflow or a paint failure as an exception on
  /// the test, and this turns it into the failure it is — with the widget that
  /// overflowed named, because "it did not fit" is not a bug report anyone can
  /// act on. The tree is only rendered into the message when something is
  /// actually wrong.
  void expectFits(WidgetTester tester, String screen) {
    final Object? exception = tester.takeException();
    final String detail = exception is FlutterError
        ? exception.diagnostics
            .map((DiagnosticsNode node) => node.toString())
            .join('\n')
        : '$exception';
    expect(exception, isNull, reason: '$screen did not fit:\n$detail');
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Runs the four screens the amounts and names really appear on.
  Future<void> walkTheScreens(
    WidgetTester tester, {
    required bool english,
    required String peopleTab,
    required String obligationsTab,
    required String recordPayment,
    required String incomeSheetTitle,
  }) async {
    // The dashboard, which sums the whole ledger into one row per currency.
    expectFits(tester, 'the dashboard');

    await tester.tap(find.text(peopleTab).last);
    await settle(tester);
    expectFits(tester, 'the people list');
    // The person's name is theirs whichever language the app is in, so the
    // same name finds them on both runs.
    expect(find.textContaining('أحمد'), findsWidgets,
        reason: 'the person is listed, however the name is truncated');

    await tester.tap(find.textContaining('أحمد').first);
    await settle(tester);
    expectFits(tester, 'the person\'s page');
    expect(find.textContaining(recordPayment), findsWidgets);

    // The payment sheet, with the widest amount on screen as the preview.
    await tester.tap(find.textContaining(recordPayment).first);
    await settle(tester);
    expectFits(tester, 'the payment sheet');
    await tester.enterText(find.byType(EditableText).first, '1000000000');
    await settle(tester);
    expectFits(tester, 'the payment sheet with the largest amount typed');
    expect(find.textContaining('1,000,000,000'), findsWidgets,
        reason: 'the figure is on screen, and it is the split preview saying it');

    // Closed the way the sheet closes itself, rather than by guessing at a
    // barrier that a full-height sheet may not leave any of.
    Navigator.of(tester.element(find.byType(PersonPaymentSheet))).pop();
    await settle(tester);
    expect(find.byType(PersonPaymentSheet), findsNothing);

    // The person's page is a full-screen route, so the tab bar is not on it.
    // Back to the shell the way the user goes back.
    for (int i = 0; i < 3 && find.byType(NavigationBar).evaluate().isEmpty; i++) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }
    expect(find.byType(NavigationBar), findsOneWidget);

    // The commitments screen, which is the budget card and the longest titles.
    await tester.tap(find.text(obligationsTab).last);
    await settle(tester);
    expectFits(tester, 'the commitments screen');

    // The budget card is the first card on the screen, and the whole card is
    // the way into the income sheet — the same tap a user makes.
    expect(find.byType(AppCard), findsWidgets);
    await tester.tap(find.byType(AppCard).first);
    await settle(tester);
    expectFits(tester, 'the income sheet');
    expect(find.textContaining(incomeSheetTitle), findsWidgets);
  }

  group('Arabic, right to left', () {
    testWidgets('the screens fit at 320 wide with the text at 1.5x',
        (WidgetTester tester) async {
      await pumpCorner(tester, english: false);
      await walkTheScreens(
        tester,
        english: false,
        peopleTab: 'الأشخاص',
        obligationsTab: 'التزامات',
        recordPayment: 'تسجيل دفعة',
        incomeSheetTitle: 'مصادر الدخل',
      );
    });
  });

  group('English, left to right', () {
    testWidgets('the screens fit at 320 wide with the text at 1.5x',
        (WidgetTester tester) async {
      await pumpCorner(tester, english: true);
      await walkTheScreens(
        tester,
        english: true,
        peopleTab: 'People',
        obligationsTab: 'Obligations',
        recordPayment: 'Record a payment',
        incomeSheetTitle: 'Income sources',
      );
    });
  });

  testWidgets('the debt form fits with the longest title and the truest figure',
      (WidgetTester tester) async {
    await pumpCorner(tester, english: false);
    await settle(tester);

    // Reached from the person's own page, which is the route that carries the
    // action bar this test also covers.
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.textContaining('أحمد').first);
    await settle(tester);
    await tester.tap(find.text('إضافة دين'));
    await settle(tester);
    expectFits(tester, 'the debt form');

    // The title is as long as a title gets.
    await tester.enterText(find.byType(TextFormField).first, longTitle);
    await settle(tester);
    expectFits(tester, 'the debt form with an eighty-character title');

    // And the widest figure the form can hold.
    await tester.enterText(
      find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextFormField),
      ),
      '1000000000',
    );
    await settle(tester);
    expectFits(tester, 'the debt form with the largest amount');
    expect(find.text('1000000000'), findsOneWidget);
  });
}
