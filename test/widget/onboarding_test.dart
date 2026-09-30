import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/onboarding/onboarding_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// First run, driven the way a person drives it.
///
/// The complaint this answers: onboarding opened in Arabic on every phone and
/// asked for the language four screens in. It now opens in the phone's own
/// language from the very first frame, offers the other one on every step, and
/// is three steps long.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Future<AppSettings> stored() => SettingsRepositoryImpl(db).get();

  void onPhone(WidgetTester tester, List<Locale> locales) {
    tester.platformDispatcher.localesTestValue = locales;
  }

  TextDirection directionOf(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(OnboardingScreen)));

  Future<void> start(
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

  /// The system back gesture, as the platform delivers it.
  Future<void> systemBack(WidgetTester tester) async {
    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.navigation.name,
      message,
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  group('it opens in the phone’s language', () {
    testWidgets('on the very first frame, before anything has been read back', (
      WidgetTester tester,
    ) async {
      onPhone(tester, const <Locale>[Locale('en', 'US')]);
      final ProviderContainer container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await loadBootSettings(container);

      // One frame and no more: this is what a phone draws first.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DhimmahApp(onboardingCompleted: false),
        ),
      );

      expect(directionOf(tester), TextDirection.ltr);
      expect(
        find.text("Know what you owe. Know what you're owed."),
        findsOneWidget,
      );
      expect(
        find.text('اعرف ما لك وما عليك'),
        findsNothing,
        reason: 'not a single Arabic frame on an English phone',
      );
    });

    testWidgets('an Arabic phone opens in Arabic, right to left', (
      WidgetTester tester,
    ) async {
      await start(tester);
      expect(directionOf(tester), TextDirection.rtl);
      expect(find.text('اعرف ما لك وما عليك'), findsOneWidget);
      expect(find.text('ما لك وما عليك في دفتر واحد'), findsOneWidget);
      // The other language is offered by its own name.
      expect(find.text('English'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a French phone with Arabic second opens in Arabic', (
      WidgetTester tester,
    ) async {
      onPhone(tester, const <Locale>[Locale('fr', 'FR'), Locale('ar', 'EG')]);
      await start(tester);
      expect(directionOf(tester), TextDirection.rtl);
    });

    testWidgets('a phone in neither language opens in English', (
      WidgetTester tester,
    ) async {
      onPhone(tester, const <Locale>[Locale('hi', 'IN')]);
      await start(tester);
      expect(directionOf(tester), TextDirection.ltr);
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });
  });

  group('the language switch', () {
    testWidgets(
      'switches at once, and switching back follows the phone again',
      (WidgetTester tester) async {
        await start(tester);

        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(directionOf(tester), TextDirection.ltr);
        expect(find.text('Get started'), findsOneWidget);
        expect((await stored()).languagePreference, LanguagePreference.english);

        await tester.tap(find.text('العربية'));
        await tester.pumpAndSettle();
        expect(directionOf(tester), TextDirection.rtl);
        expect(
          (await stored()).languagePreference,
          LanguagePreference.system,
          reason:
              'coming back to the phone’s own language is “follow the '
              'phone”, not Arabic pinned for ever',
        );
      },
    );

    testWidgets('on an English phone, choosing Arabic is a real choice', (
      WidgetTester tester,
    ) async {
      onPhone(tester, const <Locale>[Locale('en', 'GB')]);
      await start(tester);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(directionOf(tester), TextDirection.rtl);
      expect((await stored()).languagePreference, LanguagePreference.arabic);
    });

    testWidgets('is offered on every step, and keeps the step', (
      WidgetTester tester,
    ) async {
      await start(tester);
      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      expect(find.text('عملتك الافتراضية'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your default currency'),
        findsOneWidget,
        reason: 'the same step, in the other language',
      );
    });
  });

  group('the three steps', () {
    testWidgets('welcome, currency, reminders — and the choices are kept', (
      WidgetTester tester,
    ) async {
      await start(tester);

      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دولار أمريكي'));
      await tester.pump();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      // The reminders step states what reminders will actually do.
      expect(find.text('لا يفوتك أي موعد'), findsOneWidget);
      expect(find.text('التذكير: قبل يوم'), findsOneWidget);
      expect(find.text('ملخص نهاية الشهر'), findsOneWidget);

      await tester.tap(find.text('ليس الآن'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      final AppSettings settings = await stored();
      expect(settings.onboardingCompleted, isTrue);
      expect(settings.defaultCurrency, AppCurrency.usd);
      expect(
        settings.notificationsEnabled,
        isFalse,
        reason: '“Not now” is an answer, and the answer was no',
      );
      expect(settings.languagePreference, LanguagePreference.system);
    });

    testWidgets('the steps say where the person is', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await start(tester);
      expect(find.bySemanticsLabel('الخطوة 1 من 3'), findsOneWidget);

      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('الخطوة 2 من 3'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('back walks back through the steps instead of leaving', (
      WidgetTester tester,
    ) async {
      await start(tester);
      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      expect(find.text('عملتك الافتراضية'), findsOneWidget);

      await systemBack(tester);
      expect(find.text('اعرف ما لك وما عليك'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('السابق'));
      await tester.pumpAndSettle();
      expect(find.text('اعرف ما لك وما عليك'), findsOneWidget);
    });

    testWidgets('Skip is not offered twice on the last step', (
      WidgetTester tester,
    ) async {
      await start(tester);
      expect(find.text('تخطي'), findsOneWidget);
      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('تخطي').hitTestable(), findsNothing);
      expect(find.text('ليس الآن'), findsOneWidget);
    });
  });

  group('reminders record what the phone actually allows', () {
    Future<NotificationService> platform({required bool allows}) async {
      final NotificationService service = NotificationService(
        gateway: FakeNotificationGateway(enabled: allows),
      );
      await service.initialize(
        localizations: lookupAppLocalizations(const Locale('ar')),
      );
      return service;
    }

    Future<void> toLastStep(WidgetTester tester) async {
      await tester.tap(find.text('ابدأ الآن'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
    }

    testWidgets('turning them on asks, and a yes is stored as on', (
      WidgetTester tester,
    ) async {
      await start(tester, notifications: await platform(allows: true));
      await toLastStep(tester);
      await tester.tap(find.text('تفعيل التذكيرات'));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect((await stored()).notificationsEnabled, isTrue);
    });

    testWidgets('a refusal is stored as off, and the person is told', (
      WidgetTester tester,
    ) async {
      await start(tester, notifications: await platform(allows: false));
      await toLastStep(tester);
      await tester.tap(find.text('تفعيل التذكيرات'));
      await tester.pumpAndSettle();

      expect((await stored()).notificationsEnabled, isFalse);
      expect(
        find.text('لم يتم منح الإذن. يمكنك تفعيله من الإعدادات.'),
        findsOneWidget,
      );
    });

    testWidgets('Skip raises no dialog and keeps what the phone allows', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      final NotificationService service = NotificationService(gateway: gateway);
      await service.initialize(
        localizations: lookupAppLocalizations(const Locale('ar')),
      );
      await start(tester, notifications: service);

      await tester.tap(find.text('تخطي'));
      await tester.pumpAndSettle();

      expect(gateway.permissionRequests, 0);
      expect((await stored()).notificationsEnabled, isTrue);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('it fits a small phone with large text', () {
    for (final double scale in <double>[1.0, 1.5]) {
      for (final Locale phone in const <Locale>[Locale('ar'), Locale('en')]) {
        testWidgets(
          'every step at ${scale}x on a 360×640 ${phone.languageCode} phone',
          (WidgetTester tester) async {
            tester.view.physicalSize = const Size(360, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            onPhone(tester, <Locale>[phone]);

            await start(tester);
            final bool arabic = phone.languageCode == 'ar';
            final List<String> actions = arabic
                ? <String>['ابدأ الآن', 'التالي', 'تفعيل التذكيرات']
                : <String>['Get started', 'Next', 'Turn on reminders'];

            for (int step = 0; step < actions.length; step++) {
              expect(
                tester.takeException(),
                isNull,
                reason: 'step ${step + 1} overflowed',
              );
              // The way forward is on screen and can be tapped without scrolling.
              expect(
                find.text(actions[step]).hitTestable(),
                findsOneWidget,
                reason: 'step ${step + 1} hid its action',
              );
              if (step < actions.length - 1) {
                await tester.tap(find.text(actions[step]));
                await tester.pumpAndSettle();
              }
            }
          },
        );
      }
    }
  });
}
