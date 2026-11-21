import 'dart:io';

import 'package:dhimmah/core/theme/app_icons.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/features/debts/person_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';
import '../support/fake_backup_location.dart';
import '../support/fake_file_gateway.dart';

/// Every main screen at twice the system text size.
///
/// A financial app is read by people who enlarge their text. The existing
/// resilience tests stop at 1.5; this one takes the phone's own width and the
/// 2.0 setting, and fails on any overflow or exception the framework reports.
/// Amounts are never abbreviated or clipped to make a row fit: the layout
/// bends, the number stays whole.
void main() {
  late AppDatabase db;
  late Directory backups;

  setUp(() async {
    db = AppDatabase.memory();
    backups = await Directory.systemTemp.createTemp('dhimmah-text2');
  });
  tearDown(() async {
    await db.close();
    if (await backups.exists()) await backups.delete(recursive: true);
  });

  void expectNoOverflow(WidgetTester tester, String screen) {
    final Object? exception = tester.takeException();
    expect(exception, isNull, reason: '$screen overflowed: $exception');
  }

  Future<ProviderContainer> openAtTwo(WidgetTester tester) async {
    await seedLedger(db);
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final ProviderContainer container = await pumpDhimmah(
      tester,
      db: db,
      fileGateway: FakeFileGateway(),
      backupDirectory: backups,
      backupFolders: FakeBackupLocationRepository(),
    );
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await settle(tester);
  }

  /// Brings [finder] on screen: at 2.0 the content of a page is taller than the
  /// phone, and a lazy list has not built what is below the fold.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    await tester.scrollUntilVisible(
      finder,
      280,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await settle(tester);
  }

  testWidgets('the five tabs at 2.0', (WidgetTester tester) async {
    await openAtTwo(tester);
    expectNoOverflow(tester, 'dashboard');

    await tapAndSettle(tester, find.text('السجل').last);
    expectNoOverflow(tester, 'ledger');

    await tapAndSettle(tester, find.text('الأشخاص').last);
    expectNoOverflow(tester, 'people');

    await tapAndSettle(tester, find.text('التزامات').last);
    expectNoOverflow(tester, 'obligations');

    await tapAndSettle(tester, find.text('المزيد').last);
    expectNoOverflow(tester, 'more');
  });

  testWidgets('a person, their debt, the forms and the statement at 2.0', (
    WidgetTester tester,
  ) async {
    await openAtTwo(tester);
    await tapAndSettle(tester, find.text('الأشخاص').last);
    await tapAndSettle(tester, find.textContaining('محمد').first);
    expectNoOverflow(tester, 'person page');
    expect(find.text('كشف'), findsOneWidget);
    expect(find.byTooltip('مشاركة كشف'), findsOneWidget);

    final Finder debt = find.textContaining('قرض');
    await reveal(tester, debt);
    await tapAndSettle(tester, debt.first);
    expectNoOverflow(tester, 'debt page');
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();

    final Finder addDebt = find.text('إضافة دين');
    await reveal(tester, addDebt);
    await tapAndSettle(tester, addDebt);
    expectNoOverflow(tester, 'add debt');
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();

    final Finder pay = find.text('تسجيل دفعة');
    await reveal(tester, pay);
    await tapAndSettle(tester, pay);
    expectNoOverflow(tester, 'payment sheet');
    Navigator.of(tester.element(find.byType(PersonPaymentSheet))).pop();
    await tester.pumpAndSettle();

    final Finder statement = find.byIcon(AppIcons.receiptLong);
    await reveal(tester, statement);
    // The statement builds a PDF behind a progress indicator, which keeps the
    // frame clock busy; pump a fixed span instead of waiting to settle.
    await tester.tap(statement.last);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expectNoOverflow(tester, 'statement');
  });

  testWidgets('settings and backup at 2.0', (WidgetTester tester) async {
    await openAtTwo(tester);
    await tapAndSettle(tester, find.text('المزيد').last);
    final Finder settings = find.text('الإعدادات');
    await reveal(tester, settings);
    await tapAndSettle(tester, settings.last);
    expectNoOverflow(tester, 'settings');
    GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();

    final Finder backup = find.text('النسخ الاحتياطي والاستعادة');
    await reveal(tester, backup);
    // The protection card draws a progress indicator until the folder has been
    // read. An indeterminate indicator keeps the frame clock busy, and
    // `pumpAndSettle` cannot let the real file read finish; pump a fixed span
    // and then give the provider its own turn, as the statement test does.
    await tester.tap(backup.last);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expectNoOverflow(tester, 'backup');
  });
}
