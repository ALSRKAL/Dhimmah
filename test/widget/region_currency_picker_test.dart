import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// The currency of the place the phone is in, offered first wherever a currency
/// is picked — worked out from the phone's time zone and languages, with no
/// location permission.
///
/// Every test phone here is Arabic set to Yemen (`ar_YE`), so with no time zone
/// to read the suggestion is the Yemeni rial.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String mark = 'مقترحة حسب منطقتك';

  Future<AppSettings> stored() => SettingsRepositoryImpl(db).get();

  /// A phone whose time zone the app has read, as it does at start-up.
  Future<NotificationService> phoneIn(String zone) async {
    final NotificationService service = NotificationService(
      gateway: FakeNotificationGateway(timezone: zone),
    );
    await service.initialize(
      localizations: lookupAppLocalizations(const Locale('ar')),
    );
    return service;
  }

  Future<void> firstRun(
    WidgetTester tester, {
    NotificationService? notifications,
  }) async {
    await pumpDhimmah(
      tester,
      db: db,
      onboardingCompleted: false,
      notificationService: notifications,
    );
    await tester.pumpAndSettle();
  }

  Future<void> toCurrencyStep(WidgetTester tester) async {
    await tester.tap(find.text('ابدأ الآن'));
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).last).dy;

  group('the first run', () {
    testWidgets('offers it first, marked, and already chosen', (
      WidgetTester tester,
    ) async {
      await firstRun(tester);
      await toCurrencyStep(tester);

      expect(find.text(mark), findsOneWidget);
      expect(
        top(tester, 'ريال يمني'),
        lessThan(top(tester, 'روبية هندية')),
        reason: 'the suggestion comes before the usual first currency',
      );

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ليس الآن'));
      await tester.pumpAndSettle();
      expect(
        (await stored()).defaultCurrency,
        AppCurrency.yer,
        reason: 'nothing else was picked, so the suggestion is the default',
      );
    });

    testWidgets('where the phone is decides over how it is set up', (
      WidgetTester tester,
    ) async {
      // A phone set up in Yemeni Arabic, in Dubai.
      await firstRun(tester, notifications: await phoneIn('Asia/Dubai'));
      await toCurrencyStep(tester);
      expect(top(tester, 'درهم إماراتي'), lessThan(top(tester, 'ريال يمني')));

      // Skipping on the currency step keeps what is already chosen.
      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();
      expect((await stored()).defaultCurrency, AppCurrency.aed);
    });

    testWidgets('a choice of another currency is what is stored', (
      WidgetTester tester,
    ) async {
      await firstRun(tester);
      await toCurrencyStep(tester);
      // Further down the list, where a person scrolls to it.
      await tester.ensureVisible(find.text('يورو'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('يورو'));
      await tester.pump();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ليس الآن'));
      await tester.pumpAndSettle();
      expect((await stored()).defaultCurrency, AppCurrency.eur);
    });

    testWidgets('a place Dhimmah has no currency for suggests nothing', (
      WidgetTester tester,
    ) async {
      await firstRun(tester, notifications: await phoneIn('Africa/Cairo'));
      await toCurrencyStep(tester);
      expect(find.text(mark), findsNothing);
      expect(top(tester, 'روبية هندية'), lessThan(top(tester, 'ريال يمني')));
    });

    testWidgets('the mark fits a small phone with large text', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await firstRun(tester);
      await toCurrencyStep(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(mark), findsOneWidget);
      expect(find.text('التالي').hitTestable(), findsOneWidget);
    });
  });

  group('afterwards', () {
    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    testWidgets('settings offer it first, and leave the default alone', (
      WidgetTester tester,
    ) async {
      await pumpDhimmah(
        tester,
        db: db,
        settings: AppSettings.initial.copyWith(
          defaultCurrency: AppCurrency.usd,
        ),
      );
      await settle(tester);
      expect(
        (await stored()).defaultCurrency,
        AppCurrency.usd,
        reason: 'a stored choice is never replaced by a suggestion',
      );

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await settle(tester);
      await tester.tap(find.text('العملة الافتراضية'));
      await settle(tester);

      expect(find.text('YER · ﷼ · $mark'), findsOneWidget);
      expect(top(tester, 'ريال يمني'), lessThan(top(tester, 'دولار أمريكي')));

      // Closing the sheet without a choice changes nothing.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect((await stored()).defaultCurrency, AppCurrency.usd);
    });

    testWidgets('the suggestion follows the phone to another country', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway =
          FakeNotificationGateway(timezone: 'Asia/Aden');
      final NotificationService service = NotificationService(gateway: gateway);
      await service.initialize(
        localizations: lookupAppLocalizations(const Locale('ar')),
      );
      final ProviderContainer container = await pumpDhimmah(
        tester,
        db: db,
        notificationService: service,
      );
      await settle(tester);
      expect(container.read(regionCurrencyProvider), AppCurrency.yer);

      // Landed in London while the app was in the background.
      gateway.timezone = 'Europe/London';
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await settle(tester);

      expect(container.read(regionCurrencyProvider), AppCurrency.gbp);
      expect(
        (await stored()).defaultCurrency,
        AppCurrency.inr,
        reason: 'the stored default does not travel with the phone',
      );
    });

    testWidgets('a record’s currency list offers it first, marked', (
      WidgetTester tester,
    ) async {
      AppCurrency? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: CurrencyField(
              value: AppCurrency.inr,
              suggested: AppCurrency.yer,
              onChanged: (AppCurrency currency) => picked = currency,
            ),
          ),
        ),
      );
      await tester.tap(find.text('INR · ₹'));
      await tester.pumpAndSettle();

      expect(find.text(mark), findsOneWidget);
      expect(top(tester, 'YER · ﷼'), lessThan(top(tester, 'INR · ₹')));

      await tester.tap(find.text('YER · ﷼'));
      await tester.pumpAndSettle();
      expect(picked, AppCurrency.yer);
    });

    testWidgets('with no suggestion, the list is as it always was', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: CurrencyField(
              value: AppCurrency.usd,
              onChanged: (AppCurrency _) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text(r'USD · $'));
      await tester.pumpAndSettle();
      expect(find.text(mark), findsNothing);
      expect(top(tester, 'INR · ₹'), lessThan(top(tester, 'YER · ﷼')));
    });
  });
}
