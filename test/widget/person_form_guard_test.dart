import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Leaving the person form with typed text must ask first.
///
/// On the device the person form exited silently and discarded the drafts,
/// while the debt form raised the same confirmation for the same situation —
/// two answers to one question, in one app.
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

  testWidgets('a dirty person form asks before it discards',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.tap(find.text('شخص جديد'));
    await settle(tester);

    // Type a name, then try to leave through the app bar's back arrow.
    await tester.enterText(find.byType(TextField).first, 'اسم غير محفوظ');
    await settle(tester);
    await tester.tap(find.byTooltip('رجوع'));
    await settle(tester);

    expect(find.text('تغييرات غير محفوظة'), findsOneWidget,
        reason: 'leaving a dirty person form must not be silent');

    // Leaving for real discards: no person is created.
    await tester.tap(find.text('خروج بدون حفظ'));
    await settle(tester);
    expect(find.text('اسم غير محفوظ'), findsNothing);
    expect((await db.select(db.people).get()).length, 2,
        reason: 'the seeded two people, nothing more');
  });
}
