import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The obligations list must say when something is late.
///
/// On the device an obligation three days overdue rendered as "Next due
/// 27 September" with no state at all — the dashboard and the detail both
/// flagged it, the list it lives in did not.
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

  testWidgets('an overdue obligation carries its state on the list',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.text('التزامات').last);
    await settle(tester);

    // The seeded bill was due on the 5th of this month.
    expect(find.text('فاتورة الإنترنت'), findsOneWidget);
    // The chip says by how much, and the line under the name says when it
    // was due — not "next due" over a date in the past.
    expect(find.textContaining('متأخر'), findsOneWidget,
        reason: 'the list must mark a late obligation, not only its detail');
    expect(find.textContaining('كان مستحقًا في'), findsOneWidget);
    expect(find.textContaining('الاستحقاق القادم'), findsNothing);
  });

  testWidgets('the detail of a late obligation says the same thing',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('التزامات').last);
    await settle(tester);

    await tester.tap(find.text('فاتورة الإنترنت'));
    await settle(tester);

    expect(find.textContaining('كان مستحقًا في'), findsOneWidget);
    // The late period's chip names the delay, as on the list.
    expect(find.textContaining('متأخر'), findsWidgets);
    // Skipping is a named button, not a bare icon.
    expect(find.text('تخطي الدورة'), findsOneWidget);
  });
}
