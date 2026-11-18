import 'package:dhimmah/core/widgets/motion.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The people list appearing.
///
/// The same rule the ledger follows: the first rows arrive once, a few
/// milliseconds apart, so the eye is led down the list; a row scrolled away and
/// back does not arrive again, and with the system's remove-animations on the
/// rows are simply there.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await seedLedger(db);
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

  Future<void> openPeople(WidgetTester tester) async {
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder rowOpacities() => find.descendant(
        of: find.byType(ArrivingRow),
        matching: find.byType(Opacity),
      );

  testWidgets('the rows arrive once and stop', (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await openPeople(tester);

    final List<ArrivingRow> during =
        tester.widgetList<ArrivingRow>(find.byType(ArrivingRow)).toList();
    expect(during, isNotEmpty);
    expect(
      during.any((ArrivingRow row) => row.animate),
      isTrue,
      reason: 'the list starts arriving',
    );
    expect(rowOpacities(), findsWidgets);

    await settle(tester);
    final List<ArrivingRow> after =
        tester.widgetList<ArrivingRow>(find.byType(ArrivingRow)).toList();
    expect(
      after.every((ArrivingRow row) => !row.animate),
      isTrue,
      reason: 'once is enough: a rebuild must not re-run the arrival',
    );
    expect(rowOpacities(), findsNothing);
  });

  testWidgets('with "remove animations" on, the rows are simply there',
      (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await pumpDhimmah(tester, db: db);
    await openPeople(tester);

    expect(find.byType(ArrivingRow), findsWidgets);
    expect(
      rowOpacities(),
      findsNothing,
      reason: 'no faded row and no waiting when motion is switched off',
    );
  });
}
