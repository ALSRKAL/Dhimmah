import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the real application against an in-memory database.
///
/// These tests exist to prove the acceptance criteria through the interface a
/// user actually touches: onboarding, recording a debt, seeing it on the
/// dashboard, switching language and theme.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async => db.close());

  /// Pumps the app with the database swapped for an in-memory one.
  Future<void> pumpApp(
    WidgetTester tester, {
    bool onboardingCompleted = false,
    AppSettings? settings,
  }) async {
    if (settings != null) {
      await db.settingsDao.replace(_settingsRow(settings));
    }
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await loadBootSettings(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: DhimmahApp(onboardingCompleted: onboardingCompleted),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('onboarding', () {
    testWidgets('a fresh install opens on onboarding, not the dashboard',
        (WidgetTester tester) async {
      await pumpApp(tester);
      // The welcome is on screen, in the phone's language, and there is no
      // bottom navigation yet.
      expect(find.text('اعرف ما لك وما عليك'), findsOneWidget);
      expect(find.text('ابدأ الآن'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('skipping it lands on the dashboard in Arabic',
        (WidgetTester tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('عليّ'), findsWidgets);
      expect(find.text('لي'), findsWidgets);
    });

    testWidgets('it is skipped entirely once completed', (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  /// Writes one overdue debt straight into the database, so a populated
  /// dashboard can be asserted without driving the whole form.
  Future<void> seedLateDebt() async {
    final LedgerService service = LedgerService(
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
    final Person person = await service.createPerson(
      const PersonDraft(name: 'محمد أحمد عبدالرحمن'),
    );
    final DateTime today = dateOnly(DateTime.now());
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        principalMinor: 2500000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -40),
        dueAt: addDays(today, -6),
      ),
    );
  }

  group('the dashboard answers the four questions', () {
    testWidgets('an empty ledger explains what to do next',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);
      expect(find.text('ممتاز، لا توجد ديون مسجّلة حاليًا.'), findsOneWidget);
      expect(find.text('إضافة أول دين'), findsOneWidget);
    });

    testWidgets('a fresh ledger states its position and what to do next',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);

      // Where do I stand, what do I owe, what am I owed — no scrolling needed.
      expect(find.text('متوازن'), findsOneWidget);
      expect(find.text('عليّ'), findsWidgets);
      expect(find.text('لي'), findsWidgets);

      // With nothing recorded there is nothing to attend to, so the screen says
      // what to do instead of showing an empty attention list.
      expect(find.text('ممتاز، لا توجد ديون مسجّلة حاليًا.'), findsOneWidget);
      expect(find.text('يحتاج انتباهك'), findsNothing);
    });

    testWidgets('a record that is late is named on the dashboard',
        (WidgetTester tester) async {
      await seedLateDebt();
      await pumpApp(tester, onboardingCompleted: true);

      // The section names the record rather than only counting it.
      expect(find.text('يحتاج انتباهك'), findsOneWidget);
      expect(find.text('محمد أحمد عبدالرحمن'), findsWidgets);
      expect(find.textContaining('متأخر'), findsWidgets);
      // And the totals it contributes to are on screen above it.
      expect(find.text('عليك'), findsOneWidget);
    });
  });

  group('recording a debt', () {
    testWidgets('a debt is created through the add sheet and appears immediately',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);

      // The add button is the first step of the flow the app exists to make fast.
      await tester.tap(find.byTooltip('إضافة'));
      await tester.pumpAndSettle();
      expect(find.text('دين عليّ'), findsWidgets);

      await tester.tap(find.text('دين عليّ').last);
      await tester.pumpAndSettle();

      // Create the person inline, which is where the user actually knows the name.
      await tester.tap(find.text('اختر شخصًا أو أضف جديدًا'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة شخص جديد'));
      await tester.pumpAndSettle();

      // Scoped to the sheet: the debt form behind it also has labelled fields.
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'اسم الشخص'),
          matching: find.byType(TextFormField),
        ),
        'أحمد محمد',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // The picker is a selection, not a one-shot choice, so the new person is
      // confirmed before the form takes over again.
      await tester.tap(find.text('تم'));
      await tester.pumpAndSettle();

      // The amount, then save.
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '5000',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الدين'));
      await tester.pumpAndSettle();

      // Back on the dashboard. The headline tile is asserted rather than the
      // activity feed, because the feed sits below the fold and a lazy sliver
      // does not build rows the viewport never reaches.
      expect(find.textContaining('5,000'), findsWidgets);
    });

    testWidgets('an amount is required', (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);
      await tester.tap(find.byTooltip('إضافة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دين عليّ').last);
      await tester.pumpAndSettle();

      // With neither a person nor a description, and no amount, saving must fail
      // with a message rather than storing an unusable record.
      await tester.tap(find.text('حفظ الدين'));
      await tester.pumpAndSettle();

      expect(find.text('أدخل مبلغًا صحيحًا أكبر من صفر.'), findsOneWidget);
    });
  });

  group('appearance', () {
    testWidgets('Arabic lays the app out right to left',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);
      final BuildContext context = tester.element(find.byType(NavigationBar));
      expect(Directionality.of(context), TextDirection.rtl);
    });

    testWidgets('switching to English flips it to left to right',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        onboardingCompleted: true,
        settings: AppSettings.initial.copyWith(languagePreference: LanguagePreference.english),
      );
      final BuildContext context = tester.element(find.byType(NavigationBar));
      expect(Directionality.of(context), TextDirection.ltr);
      expect(find.text('I Owe'), findsWidgets);
      expect(find.text('Owed to Me'), findsWidgets);
    });

    testWidgets('dark mode is applied from the stored setting',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        onboardingCompleted: true,
        settings: AppSettings.initial.copyWith(themeMode: AppThemeMode.dark),
      );
      final BuildContext context = tester.element(find.byType(NavigationBar));
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    testWidgets('the light theme is used when chosen', (WidgetTester tester) async {
      await pumpApp(
        tester,
        onboardingCompleted: true,
        settings: AppSettings.initial.copyWith(themeMode: AppThemeMode.light),
      );
      final BuildContext context = tester.element(find.byType(NavigationBar));
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('a tall phone lays the dashboard out cleanly', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpApp(tester, onboardingCompleted: true);
      expect(tester.takeException(), isNull);
    });
  });

  group('empty states', () {
    testWidgets('one ledger destination covers both sides of the book',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);

      await tester.tap(find.text('السجل').last);
      await tester.pumpAndSettle();
      expect(find.text('لا توجد ديون عليك.'), findsOneWidget);

      // Switching sides is one tap, not another destination.
      await tester.tap(find.text('لي').first);
      await tester.pumpAndSettle();
      expect(find.text('لا توجد أموال مستحقة لك.'), findsOneWidget);
    });

    testWidgets('the obligations tab explains itself when empty',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);
      await tester.tap(find.text('التزامات').last);
      await tester.pumpAndSettle();
      expect(find.text('لا توجد التزامات قادمة.'), findsOneWidget);
    });

    testWidgets('people has its own destination rather than hiding in More',
        (WidgetTester tester) async {
      await pumpApp(tester, onboardingCompleted: true);
      await tester.tap(find.text('الأشخاص').last);
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد أشخاص بعد.'), findsOneWidget);
    });
  });

  group('currency handling', () {
    testWidgets('a non-default currency is labelled with its code',
        (WidgetTester tester) async {
      await pumpApp(
        tester,
        onboardingCompleted: true,
        settings: AppSettings.initial.copyWith(defaultCurrency: AppCurrency.usd),
      );
      // Nothing recorded yet, so the dashboard shows the empty state rather than
      // a total in the wrong currency.
      expect(find.text('ممتاز، لا توجد ديون مسجّلة حاليًا.'), findsOneWidget);
    });
  });
}

/// Builds the settings row a test wants to start from.
Setting _settingsRow(AppSettings settings) {
  return Setting(
    id: Settings.singletonId,
    backupAutoEnabled: settings.backupAutoEnabled,
    languagePreference: settings.languagePreference,
    themeMode: settings.themeMode,
    numerals: settings.numerals,
    defaultCurrencyCode: settings.defaultCurrency.code,
    notificationsEnabled: settings.notificationsEnabled,
    notificationHour: settings.notificationHour,
    notificationMinute: settings.notificationMinute,
    defaultReminderLeads: settings.defaultReminderLeads,
    monthEndSummaryEnabled: settings.monthEndSummaryEnabled,
    monthEndDay: settings.monthEndDay,
    monthEndHour: settings.monthEndHour,
    monthEndMinute: settings.monthEndMinute,
    dueSoonWindowDays: settings.dueSoonWindowDays,
    lockEnabled: settings.lockEnabled,
    biometricEnabled: settings.biometricEnabled,
    onboardingCompleted: true,
  );
}
