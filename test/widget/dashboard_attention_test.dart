import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The attention figures equal the items under them — obligations included.
///
/// On the device an overdue rent bill sat under a "late" figure that did not
/// count it, because the figure came from debt totals while the list mixed
/// debts and obligations.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await seedLedger(db, extraCurrency: AppCurrency.inr);
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('the late figure sums debts and obligations together',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    // Late: قرض سيارة ₹23,000 + فاتورة الإنترنت ₹1,200 = ₹24,200.
    // Due soon: سلفة ₹15,000.
    expect(find.textContaining('24,200'), findsOneWidget,
        reason: 'the late figure must include the late obligation');
    expect(find.textContaining('15,000'), findsWidgets);
  });
}
