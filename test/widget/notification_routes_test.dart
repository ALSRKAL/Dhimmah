import 'dart:async';
import 'dart:io';

import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/debts/debt_detail_screen.dart';
import 'package:dhimmah/features/reports/reports_screen.dart';
import 'package:dhimmah/features/settings/backup_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';
import '../support/fake_backup_location.dart';
import '../support/fake_file_gateway.dart';
import '../support/fake_notification_gateway.dart';

/// Where a tapped notification leads, and what an unknown location shows.
void main() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  /// Lets drift's reads, which complete on the real event loop, finish.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  group('a payload names its page', () {
    test('a month-end summary opens the month it is about', () {
      expect(
        AppRoutes.forNotificationPayload('report:2026-09'),
        '/reports?month=2026-09',
      );
      expect(AppRoutes.monthFromKey('2026-09'), DateTime(2026, 9));
    });

    test('a malformed month still opens the report, on today', () {
      expect(AppRoutes.forNotificationPayload('report:soon'), AppRoutes.reports);
      expect(AppRoutes.monthFromKey('2026-13'), isNull);
      expect(AppRoutes.monthFromKey(null), isNull);
    });

    test('the backup alert opens the backup screen', () {
      expect(
        AppRoutes.forNotificationPayload('backup:problem'),
        AppRoutes.backup,
      );
    });

    test('a payload that names nothing opens nothing', () {
      expect(AppRoutes.forNotificationPayload('elsewhere:1'), isNull);
      expect(AppRoutes.forNotificationPayload('no-separator'), isNull);
    });
  });

  group('tapping a notification', () {
    late AppDatabase db;
    late Directory dir;
    late FakeNotificationGateway platform;
    late NotificationService notifications;

    setUp(() async {
      db = AppDatabase.memory();
      dir = await Directory.systemTemp.createTemp('dhimmah-routes');
      platform = FakeNotificationGateway();
      notifications = NotificationService(gateway: platform);
      await notifications.initialize(localizations: l10n);
    });
    tearDown(() async {
      await db.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<void> pump(WidgetTester tester) => pumpDhimmah(
          tester,
          db: db,
          notificationService: notifications,
          backupDirectory: dir,
          backupFolders: FakeBackupLocationRepository(),
          fileGateway: FakeFileGateway(),
        );

    testWidgets('twice opens the record once', (WidgetTester tester) async {
      final Person person = await buildService(db).createPerson(
        const PersonDraft(name: 'أحمد'),
      );
      final Debt debt = await buildService(db).createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'قرض',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: dateOnly(DateTime.now()),
        ),
      );
      await pump(tester);

      platform.tap('debt:${debt.id}');
      await settle(tester);
      platform.tap('debt:${debt.id}');
      await settle(tester);

      expect(
        find.byType(DebtDetailScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'one page, so one back press returns to where the user was',
      );
    });

    testWidgets('the summary opens its month, and the alert its screen',
        (WidgetTester tester) async {
      await pump(tester);

      platform.tap('report:2026-09');
      await settle(tester);
      expect(
        tester.widget<ReportsScreen>(find.byType(ReportsScreen)).initialMonth,
        DateTime(2026, 9),
      );

      platform.tap('backup:problem');
      await settle(tester);
      expect(find.byType(BackupScreen), findsOneWidget);
    });
  });

  testWidgets('an unknown location says so in the app language, with a way home',
      (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);
    await pumpDhimmah(tester, db: db);

    unawaited(
      GoRouter.of(tester.element(find.byType(NavigationBar))).push('/nowhere'),
    );
    await settle(tester);

    expect(find.text(l10n.recordGone), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);

    await tester.tap(find.text(l10n.navHome));
    await settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(l10n.recordGone), findsNothing);
  });
}
