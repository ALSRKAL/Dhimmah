import 'dart:io';

import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/reminders/reminders_screen.dart';
import 'package:dhimmah/features/reports/reports_screen.dart';
import 'package:dhimmah/features/settings/backup_screen.dart';
import 'package:dhimmah/features/settings/settings_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';
import '../support/fake_backup_location.dart';
import '../support/fake_file_gateway.dart';

/// The More tab opens with the month's movement and four working rows.
///
/// The card reads the same report the Reports screen reads — not a second sum
/// computed here — and each row still opens the screen it names.
void main() {
  late AppDatabase db;
  late Directory backups;

  setUp(() async {
    db = AppDatabase.memory();
    backups = await Directory.systemTemp.createTemp('dhimmah-more-screen');
  });
  tearDown(() async {
    await db.close();
    if (await backups.exists()) await backups.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<ProviderContainer> openMore(WidgetTester tester) async {
    await seedLedger(db);
    final ProviderContainer container = await pumpDhimmah(
      tester,
      db: db,
      fileGateway: FakeFileGateway(),
      backupDirectory: backups,
      backupFolders: FakeBackupLocationRepository(),
    );
    await settle(tester);
    await tester.tap(find.text('المزيد').last);
    await settle(tester);
    return container;
  }

  testWidgets('the card shows the month figures from the report provider', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await openMore(tester);

    final DateTime today = dateOnly(DateTime.now());
    final AppCurrency currency = container.read(currenciesInUseProvider).first;
    final MonthlyReport report = await container.read(
      monthlyReportProvider(
        (year: today.year, month: today.month, currency: currency),
      ).future,
    );
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
    final AppFormatting formatting = AppFormatting(
      language: AppLanguage.arabic,
      numerals: NumeralsStyle.latin,
      defaultCurrency: currency,
      localizations: l10n,
    );

    expect(find.text(l10n.reportMonthMovement), findsOneWidget);
    expect(
      find.text(formatting.amount(Money(report.receivedMinor, currency))),
      findsOneWidget,
    );
    expect(
      find.text(formatting.amount(Money(report.paidOutMinor, currency))),
      findsOneWidget,
    );
  });

  testWidgets('each row opens the screen it names', (
    WidgetTester tester,
  ) async {
    await openMore(tester);

    final List<(String, Type, String)> rows = <(String, Type, String)>[
      ('التقارير', ReportsScreen, AppRoutes.reports),
      ('التذكيرات', RemindersScreen, AppRoutes.reminders),
      ('الإعدادات', SettingsScreen, AppRoutes.settings),
      (
        'النسخ الاحتياطي والاستعادة',
        BackupScreen,
        AppRoutes.backup,
      ),
    ];
    for (final (String title, Type screen, String path) in rows) {
      await tester.tap(find.text(title).last);
      await settle(tester);
      expect(find.byType(screen), findsOneWidget, reason: title);
      final BuildContext inside = tester.element(find.byType(screen));
      expect(GoRouterState.of(inside).uri.path, path, reason: title);
      GoRouter.of(inside).pop();
      await settle(tester);
    }
  });
}
