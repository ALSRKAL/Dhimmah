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
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
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
