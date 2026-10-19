import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The report speaks about one currency, and only that currency.
///
/// The insight line above the grid used to count every debt in the ledger. On a
/// ledger with two currencies that meant a report for ₹ could announce debts
/// that are only late in $ — a number that is wrong in a way the screen cannot
/// show, because the debts it counted are not on the screen. The counts are now
/// scoped to the currency being reported, which is what the rest of the report
/// already did with its money.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  /// The ledger reads through drift, whose futures complete on the real event
  /// loop, so `pump` alone leaves the screen on its skeleton.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Seed the standard ledger (one late ₹ debt, one ₹ debt due soon, one $ debt
  /// that is not late) and then make the *dollar* side late as well.
  ///
  /// The divergence is the point: two debts are late ledger-wide, one of them in
  /// the currency the report opens on.
  Future<void> seedDivergentLedger(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await seedLedger(db);
    await buildService(db).createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[(await buildService(db).people.getAll()).first.id],
        title: 'US loan',
        principalMinor: 90000,
        currency: AppCurrency.usd,
        issuedAt: addDays(dateOnly(DateTime.now()), -40),
        dueAt: addDays(dateOnly(DateTime.now()), -12),
      ),
    );

    await pumpDhimmah(tester, db: db);
  }

  testWidgets('the late count on the report counts only its own currency',
      (WidgetTester tester) async {
    await seedDivergentLedger(tester);

    // The report lives behind the "more" tab.
    await tester.tap(find.text('المزيد').last);
    await settle(tester);
    await tester.tap(find.text('التقارير').first);
    await settle(tester);

    expect(find.byType(ReportsScreen), findsOneWidget);
    // Sanity: the report really is showing rupees, the currency with one late
    // debt, and not dollars, which also has one.
    expect(find.text('INR'), findsWidgets);

    expect(
      find.text('دين واحد متأخر يحتاج متابعة.'),
      findsOneWidget,
      reason: 'one late debt in the currency on screen',
    );
    expect(
      find.text('دينان متأخران يحتاجان متابعة.'),
      findsNothing,
      reason: 'that is the ledger-wide count: one of those two is in dollars, '
          'and a report for rupees must not count it',
    );
  });
}
