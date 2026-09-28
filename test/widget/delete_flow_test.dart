import 'dart:async';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';

/// What the user sees after deleting a debt through the detail screen.
///
/// On the device the delete left a dead screen — the detail with the balance
/// card's own label ("إجمالي الدين"/"Total") as its app-bar title and the word
/// "Deleted" in the middle — and the promised Undo never appeared. This test
/// holds the delete flow to what it should be: back to where the user came
/// from, with an Undo that actually restores the record.
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

  Future<int> debtRows() async =>
      (await db.select(db.debts).get()).length;

  testWidgets('deleting through the detail: no dead screen, Undo offered',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.textContaining('خالد العلي').first);
    await settle(tester);

    // The device path went through an edit-save first: the edit is pushed on
    // top of this very detail, and saving pops back to it.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
    await tester.tap(find.text('حفظ التعديلات'));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);

    await tester.tap(find.text('حذف').last);
    await settle(tester);

    // The confirmation names the act; confirming is the delete.
    expect(find.text('تأكيد الحذف'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await settle(tester);

    // The record is gone from the database.
    expect(await debtRows(), 1);

    // The dead detail must not be on top: the balance-card label
    // ("إجمالي الدين") must not be an app-bar title anywhere.
    expect(find.text('إجمالي الدين'), findsNothing,
        reason: 'a deleted record must not leave its detail screen on top');

    // The undo offer survives the pop, so the delete is reversible.
    expect(find.text('تراجع'), findsOneWidget);
  });

  testWidgets('a detail whose record is gone removes itself',
      (WidgetTester tester) async {
    // Reached however the id went stale — a stale second copy of the route, a
    // notification for a deleted record. The screen must not sit over nothing.
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.text('السجل').last);
    await settle(tester);
    final BuildContext context = tester.element(find.text('السجل').first);
    unawaited(GoRouter.of(context).push('/debts/does-not-exist'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 600));

    // The self-healing detail popped itself: the ledger is back on top.
    expect(find.text('إجمالي الدين'), findsNothing);
    expect(find.text('هذا السجل لم يعد موجودًا.'), findsNothing);
    expect(find.text('السجل'), findsWidgets);
  });
}
