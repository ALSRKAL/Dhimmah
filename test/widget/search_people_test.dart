import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Searching a person's name finds the person.
///
/// On the device, searching "Ahmed" — the exact name of an existing person —
/// returned only his two debts. A person with no records was unfindable here
/// even though the screen's own promise is "search names, obligations and
/// notes" and the People tab lists them.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await seedLedger(db, extraCurrency: AppCurrency.inr);
    // A person with no records at all — the case the device exposed.
    await buildService(db).createPerson(const PersonDraft(name: 'سارة الغامدي'));
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

  testWidgets('a person with no debts is still findable by name',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.byIcon(Icons.search_outlined));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'سارة');
    await settle(tester);

    expect(find.text('الأشخاص · 1'), findsOneWidget,
        reason: 'the people group must exist in the results');
    expect(find.text('سارة الغامدي'), findsWidgets);
  });

  group('a name is found however it is typed', () {
    Future<void> search(WidgetTester tester, String query) async {
      await pumpDhimmah(tester, db: db);
      await settle(tester);
      await tester.tap(find.byIcon(Icons.search_outlined));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, query);
      await settle(tester);
    }

    testWidgets('without the hamza it was saved with',
        (WidgetTester tester) async {
      // Saved as «محمد أحمد عبدالرحمن»; typed the way most keyboards type it.
      await search(tester, 'احمد');

      expect(find.text('الأشخاص · 1'), findsOneWidget);
      expect(find.text('محمد أحمد عبدالرحمن'), findsWidgets);
    });

    testWidgets('with heh for teh marbuta, and with vowel marks',
        (WidgetTester tester) async {
      await search(tester, 'سَاره');

      expect(find.text('الأشخاص · 1'), findsOneWidget);
      expect(find.text('سارة الغامدي'), findsWidgets);
    });

    testWidgets('a phone number typed in Arabic digits',
        (WidgetTester tester) async {
      // The number is stored as +967 771 234 567.
      await search(tester, '٧٧١');

      expect(find.text('الأشخاص · 1'), findsOneWidget);
      expect(find.text('محمد أحمد عبدالرحمن'), findsWidgets);
    });
  });
}
