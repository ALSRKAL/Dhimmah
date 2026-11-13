import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/settings_tile.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/income_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:dhimmah/features/debts/receipt_screen.dart';
import 'package:dhimmah/features/people/statement_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

/// The statement screen's composition and options.
///
/// The document itself is verified by rasterising real files; this checks the
/// screen around it: that the preview is present, the privacy defaults are
/// right, and the options actually change what is produced.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late Person person;

  setUp(() async {
    db = AppDatabase.memory();
    service = LedgerService(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      incomes: IncomeRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
      settings: SettingsRepositoryImpl(db),
      notifications: NotificationService(),
      localizations: () => lookupAppLocalizations(const Locale('ar')),
      composer: () => NotificationComposer(
        localizations: lookupAppLocalizations(const Locale('ar')),
        formatting: AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: lookupAppLocalizations(const Locale('ar')),
        ),
      ),
      clock: DateTime.now,
    );

    person = await service.createPerson(
      PersonDraft(name: 'أحمد محمد', phone: '+967 771 234 567'),
    );
    final DateTime today = dateOnly(DateTime.now());
    final Debt debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'سلفة',
        principalMinor: 2500000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -30),
        dueAt: addDays(today, 10),
        note: 'ملاحظة خاصة بالمستخدم',
      ),
    );
    await service.recordPayment(
      debt.id,
      PaymentDraft(amountMinor: 500000, paidAt: addDays(today, -5)),
    );
  });

  tearDown(() async => db.close());

  /// The app installs this above every route, in `MaterialApp.builder`; the
  /// sheets this screen opens read amounts through it.
  Widget withFormatting(BuildContext context, Widget? child) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppFormattingScope(
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> pumpStatement(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The palette is a theme extension, so the app theme has to be present.
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: withFormatting,
          home: StatementScreen(personId: person.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('opens with a preview and the share action', (WidgetTester tester) async {
    await pumpStatement(tester);

    expect(find.text('كشف حساب'), findsOneWidget);
    // The preview is the platform PDF viewer, so its presence is the assertion.
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.text('مشاركة PDF'), findsOneWidget);
  });

  testWidgets('the options sheet opens and the notes option is off by default',
      (WidgetTester tester) async {
    await pumpStatement(tester);

    await tester.tap(find.byTooltip('خيارات الكشف'));
    // The preview keeps re-rendering in a test environment, so the tree never
    // goes quiet; fixed frames are enough to see the sheet appear.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('خيارات الكشف'), findsWidgets);
    // A statement is usually sent to the person it is about, so nothing that is
    // the user's own reminder travels by default.
    final Switch notes = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SettingsSwitchTile, 'الملاحظات'),
        matching: find.byType(Switch),
      ),
    );
    expect(notes.value, isFalse);

    final Switch phone = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SettingsSwitchTile, 'رقم الهاتف'),
        matching: find.byType(Switch),
      ),
    );
    expect(phone.value, isFalse);

    // The payment history is on: it is the point of a statement.
    final Switch payments = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SettingsSwitchTile, 'تفاصيل الدفعات'),
        matching: find.byType(Switch),
      ),
    );
    expect(payments.value, isTrue);
  });

  testWidgets('turning an option on is applied', (WidgetTester tester) async {
    await pumpStatement(tester);

    await tester.tap(find.byTooltip('خيارات الكشف'));
    // The preview keeps re-rendering in a test environment, so the tree never
    // goes quiet; fixed frames are enough to see the sheet appear.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final Finder notesSwitch = find.descendant(
      of: find.widgetWithText(SettingsSwitchTile, 'الملاحظات'),
      matching: find.byType(Switch),
    );
    // The sheet scrolls, and in a test window the last option starts below the
    // fold; on a phone it is reachable without scrolling.
    await tester.ensureVisible(notesSwitch);
    await tester.pump();
    await tester.tap(notesSwitch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.widget<Switch>(notesSwitch).value,
      isTrue,
      reason: 'the toggle itself should take effect immediately',
    );

    await tester.tap(find.text('تطبيق'));
    // The preview keeps re-rendering in a test environment, so the tree never
    // goes quiet; fixed frames are enough to see the sheet appear.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Re-opening shows the choice was kept.
    await tester.tap(find.byTooltip('خيارات الكشف'));
    // The preview keeps re-rendering in a test environment, so the tree never
    // goes quiet; fixed frames are enough to see the sheet appear.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final Switch notes = tester.widget<Switch>(
      find.descendant(
        of: find.widgetWithText(SettingsSwitchTile, 'الملاحظات'),
        matching: find.byType(Switch),
      ),
    );
    expect(notes.value, isTrue);
  });

  Future<void> pumpFor(
    WidgetTester tester,
    String personId, {
    String? debtId,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: withFormatting,
          home: StatementScreen(personId: personId, initialDebtId: debtId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// A second person, with one debt paid off in full.
  Future<({Person person, Debt debt})> personWithSettledDebt() async {
    final Person other = await service.createPerson(
      const PersonDraft(name: 'خالد'),
    );
    final DateTime today = dateOnly(DateTime.now());
    final Debt paidOff = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[other.id],
        title: 'فاتورة قديمة',
        principalMinor: 900000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -40),
      ),
    );
    await service.recordPayment(
      paidOff.id,
      PaymentDraft(amountMinor: 900000, paidAt: addDays(today, -3)),
    );
    return (person: other, debt: paidOff);
  }

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;

  testWidgets('what the statement covers is chosen beside the document',
      (WidgetTester tester) async {
    await pumpStatement(tester);

    // Not behind the options sheet: a settled debt on a statement is the first
    // thing a user wants to change.
    expect(find.widgetWithText(ChoiceChip, 'الكل'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'اختيار…'), findsOneWidget);
    expect(
      chipSelected(tester, 'المفتوحة'),
      isTrue,
      reason: 'a statement opens on what is still outstanding',
    );
  });

  testWidgets('a settled debt is left out, said so, and one tap brings it back',
      (WidgetTester tester) async {
    final DateTime today = dateOnly(DateTime.now());
    final Debt paidOff = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'دين قديم',
        principalMinor: 400000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -90),
      ),
    );
    await service.recordPayment(
      paidOff.id,
      PaymentDraft(amountMinor: 400000, paidAt: addDays(today, -60)),
    );

    await pumpStatement(tester);

    expect(find.text('دين مسدَّد واحد غير معروض'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);

    await tester.tap(find.text('إظهار'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('دين مسدَّد واحد غير معروض'), findsNothing);
    expect(chipSelected(tester, 'الكل'), isTrue);
  });

  testWidgets('every debt settled: an explanation and a way to show them',
      (WidgetTester tester) async {
    final ({Person person, Debt debt}) other = await personWithSettledDebt();
    await pumpFor(tester, other.person.id);

    // Not the "no debts" message — this person has one — and not a blank page.
    expect(find.text('لا ديون مفتوحة'), findsOneWidget);
    expect(find.text('لا توجد ديون مرتبطة بهذا الشخص.'), findsNothing);
    expect(find.byType(PdfPreview), findsNothing);

    await tester.tap(find.text('إظهار المسدَّدة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.text('لا ديون مفتوحة'), findsNothing);
  });

  testWidgets('opened from a debt, the statement is about that debt',
      (WidgetTester tester) async {
    final ({Person person, Debt debt}) other = await personWithSettledDebt();
    await pumpFor(tester, other.person.id, debtId: other.debt.id);

    // The debt is settled, and it was asked for by name: it is shown.
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(chipSelected(tester, 'اختيار…'), isTrue);
  });

  testWidgets('choosing by hand lists the debts and waits for a tick',
      (WidgetTester tester) async {
    await pumpStatement(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'اختيار…'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('اختر الديون'), findsOneWidget);
    final Finder row = find.widgetWithText(CheckboxListTile, 'سلفة');
    expect(row, findsOneWidget);
    final Finder apply = find.widgetWithText(FilledButton, 'تطبيق');
    expect(
      tester.widget<FilledButton>(apply).onPressed,
      isNull,
      reason: 'nothing ticked is not a statement',
    );

    await tester.tap(row);
    await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);

    await tester.tap(apply);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(chipSelected(tester, 'اختيار…'), isTrue);
    expect(find.byType(PdfPreview), findsOneWidget);
  });

  testWidgets('a payment has a receipt, named for which way the money moved',
      (WidgetTester tester) async {
    final DateTime today = dateOnly(DateTime.now());

    Future<void> pumpReceipt(DebtDirection direction) async {
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: direction,
          personIds: <String>[person.id],
          title: 'فاتورة',
          principalMinor: 900000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -20),
        ),
      );
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 300000, paidAt: addDays(today, -2)),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: withFormatting,
            home: ReceiptScreen(
              view: DebtCalculator.buildView(
                debt: debt,
                payments: <Payment>[payment],
                participants: <Person>[person],
                asOf: today,
                dueSoonWindowDays: 7,
              ),
              payment: payment,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Owed to the user: the user received it.
    await pumpReceipt(DebtDirection.owedToMe);
    expect(find.text('سند قبض'), findsOneWidget);
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.text('مشاركة PDF'), findsOneWidget);
    expect(find.byTooltip('اسم المُصدر'), findsOneWidget);

    // Owed by the user: the user paid it.
    await pumpReceipt(DebtDirection.iOwe);
    expect(find.text('سند دفع'), findsOneWidget);
    expect(find.text('سند قبض'), findsNothing);
  });

  testWidgets('a person with no debts gets an explanation, not a blank document',
      (WidgetTester tester) async {
    final Person empty = await service.createPerson(
      const PersonDraft(name: 'خالد'),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: withFormatting,
          home: StatementScreen(personId: empty.id),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('لا توجد ديون مرتبطة بهذا الشخص.'), findsOneWidget);
    expect(find.byType(PdfPreview), findsNothing);
  });
}
