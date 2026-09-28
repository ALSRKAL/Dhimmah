import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The ledger's side headline must be the side the user is looking at.
///
/// Driven on the device during the UX forensic audit: on the owed-to-me side
/// the strip printed the I-owe total — a bare ₹0 — above a list of ₹2,000 in
/// open records, while the dashboard said ₹2,000 for the same side.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('the owed-to-me headline sums the owed-to-me records',
      (WidgetTester tester) async {
    // One owed-to-me debt of ₹1,500 (سلفة) and one I-owe debt of ₹2,300
    // remaining (قرض سيارة after its payment) — different sides, same currency.
    await seedLedger(db, extraCurrency: AppCurrency.inr);
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.text('السجل').last);
    await settle(tester);

    // The I-owe side shows its own total: 35,000,000−12,000,000 = 2,300,000
    // paise = ₹ 23,000. (The rendered string carries bidi isolates, so match
    // the digits.)
    expect(find.textContaining('23,000'), findsWidgets);
    expect(find.textContaining('15,000'), findsNothing);

    // Switch to the owed-to-me side: the headline follows.
    await tester.tap(find.text('لي'));
    await settle(tester);

    expect(find.textContaining('15,000'), findsWidgets);
    expect(find.textContaining('23,000'), findsNothing);
  });
}
