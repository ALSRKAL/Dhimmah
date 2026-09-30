import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_gateway.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// The app follows the phone's language unless the person chose one.
///
/// Three things used to be wrong, and each has a test here:
///
/// * the language was a stored Arabic default, so the phone was never asked;
/// * the first frame was drawn from the defaults before the stored settings
///   were read back, so a person who had chosen English, or dark, saw Arabic,
///   or light, and then watched it change;
/// * a reminder's words were fixed when it was scheduled, so after a change of
///   language the reminders already waiting arrived in the old one.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  Future<AppSettings> stored() => SettingsRepositoryImpl(db).get();

  /// The direction of whatever screen is on top.
  TextDirection direction(WidgetTester tester) =>
      Directionality.of(tester.element(find.byType(Scaffold).last));

  bool isArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  group('the first frame', () {
    testWidgets('is already the language and theme the person left', (
      WidgetTester tester,
    ) async {
      await db.settingsDao.write(
        AppSettings.initial
            .copyWith(
              languagePreference: LanguagePreference.english,
              themeMode: AppThemeMode.dark,
              onboardingCompleted: true,
            )
            .toCompanion(),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await loadBootSettings(container);

      // A single frame on an Arabic phone: nothing has streamed back yet.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DhimmahApp(onboardingCompleted: true),
        ),
      );

      expect(direction(tester), TextDirection.ltr);
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        Brightness.dark,
      );
      // The ledger itself is still loading; the frame around it is not.
      expect(find.text(en.navHome), findsOneWidget);
      expect(find.text(ar.navHome), findsNothing);
    });
  });

  group('following the phone', () {
    testWidgets('a phone switched to English takes the open app with it', (
      WidgetTester tester,
    ) async {
      await pumpDhimmah(tester, db: db);
      await tester.pumpAndSettle();
      expect(direction(tester), TextDirection.rtl);
      expect(find.text('عليّ'), findsWidgets);

      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'US'),
      ];
      await tester.pumpAndSettle();

      expect(direction(tester), TextDirection.ltr);
      expect(find.text('I Owe'), findsWidgets);
      expect(
        (await stored()).languagePreference,
        LanguagePreference.system,
        reason: 'following is not a choice the app makes for the person',
      );
    });

    testWidgets('a chosen language stays when the phone changes', (
      WidgetTester tester,
    ) async {
      await pumpDhimmah(
        tester,
        db: db,
        settings: AppSettings.initial.copyWith(
          languagePreference: LanguagePreference.arabic,
        ),
      );
      await tester.pumpAndSettle();

      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'US'),
      ];
      await tester.pumpAndSettle();

      expect(direction(tester), TextDirection.rtl);
      expect(find.text('عليّ'), findsWidgets);
    });
  });

  group('Settings', () {
    Future<void> openLanguage(WidgetTester tester, AppLocalizations l) async {
      await tester.tap(find.byTooltip(l.settingsTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.settingsLanguage));
      await tester.pumpAndSettle();
    }

    testWidgets('says the language follows the phone, and which one it is', (
      WidgetTester tester,
    ) async {
      await pumpDhimmah(tester, db: db);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(ar.settingsTitle));
      await tester.pumpAndSettle();

      expect(find.text('تتبع لغة جهازك'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('offers the phone, and each language by its own name', (
      WidgetTester tester,
    ) async {
      await pumpDhimmah(tester, db: db);
      await tester.pumpAndSettle();
      await openLanguage(tester, ar);

      expect(find.text('لغة الجهاز'), findsOneWidget);
      expect(find.text('حاليًا: العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      // The name in the current language, under the name in its own.
      expect(find.text('الإنجليزية'), findsOneWidget);
    });

    testWidgets('choosing English pins it; choosing the phone hands it back', (
      WidgetTester tester,
    ) async {
      await pumpDhimmah(tester, db: db);
      await tester.pumpAndSettle();
      await openLanguage(tester, ar);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(direction(tester), TextDirection.ltr);
      expect((await stored()).languagePreference, LanguagePreference.english);
      expect(
        find.text('Follows your phone'),
        findsNothing,
        reason: 'a pinned language is not described as following',
      );

      await tester.tap(find.text('Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Device language'));
      await tester.pumpAndSettle();
      expect(direction(tester), TextDirection.rtl);
      expect((await stored()).languagePreference, LanguagePreference.system);
    });
  });

  group('reminders already waiting', () {
    testWidgets('are re-worded when the phone changes language', (
      WidgetTester tester,
    ) async {
      final FakeNotificationGateway platform = FakeNotificationGateway();
      final NotificationService notifications = NotificationService(
        gateway: platform,
      );
      await notifications.initialize(localizations: ar);

      // A record with a reminder, written before the app opens.
      final LedgerService writer = buildService(db);
      // A Latin name, so every word of the body can be checked: an Arabic name
      // is the person's, and stays Arabic in any language.
      final Person person = await writer.createPerson(
        const PersonDraft(name: 'Ahmed'),
      );
      final DateTime today = dateOnly(DateTime.now());
      await writer.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: addDays(today, 6),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );

      await pumpDhimmah(tester, db: db, notificationService: notifications);
      await tester.pumpAndSettle();
      expect(platform.held, isNotEmpty, reason: 'the app armed its reminders');
      expect(
        platform.held.values.every(
          (FakeScheduledNotification n) => isArabic(n.title),
        ),
        isTrue,
      );
      final Set<int> ids = platform.held.keys.toSet();

      tester.platformDispatcher.localesTestValue = const <Locale>[
        Locale('en', 'US'),
      ];
      await tester.pumpAndSettle();

      expect(
        platform.held.values.every(
          (FakeScheduledNotification n) =>
              !isArabic(n.title) && !isArabic(n.body),
        ),
        isTrue,
        reason:
            'the reminders arrive in the language the app is in now: '
            '${platform.held.values.map((FakeScheduledNotification n) => n.title)}',
      );
      expect(
        platform.held.keys.toSet(),
        ids,
        reason: 're-worded in place — the same reminders, not new ones',
      );
      expect(platform.cancelled, isEmpty);
      expect(
        platform.channels[NotificationTier.now]?.name,
        'Due now',
        reason: 'the channel names in the system settings follow too',
      );
    });
  });
}
