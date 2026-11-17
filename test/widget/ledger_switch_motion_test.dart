import 'package:dhimmah/core/theme/app_spacing.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Turning the ledger over.
///
/// "I owe" and "owed to me" are one list and one filter; switching sides is not
/// a navigation, and a cut made it look like a refresh of the same thing. A
/// short cross-fade says the list turned over. With remove-animations on, it is
/// a cut again.
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

  Future<void> openLedger(WidgetTester tester) async {
    await settle(tester);
    await tester.tap(find.text('السجل').last);
    await settle(tester);
  }

  testWidgets('the two sides cross-fade into one another',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await openLedger(tester);

    final AnimatedSwitcher switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.duration, AppMotion.normal);

    expect(find.textContaining('قرض سيارة'), findsWidgets);
    await tester.tap(find.text('لي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // Both lists are on stage while the fade runs: that is the transition.
    expect(find.textContaining('قرض سيارة'), findsWidgets);
    expect(find.textContaining('سلفة'), findsWidgets);

    await settle(tester);
    expect(
      find.textContaining('قرض سيارة'),
      findsNothing,
      reason: 'the old side is gone once the switch has finished',
    );
    expect(find.textContaining('سلفة'), findsWidgets);
  });

  testWidgets('with "remove animations" on, it is a cut',
      (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpDhimmah(tester, db: db);
    await openLedger(tester);

    final AnimatedSwitcher switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.duration, Duration.zero);

    await tester.tap(find.text('لي'));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('قرض سيارة'),
      findsNothing,
      reason: 'nothing lingers when motion is switched off',
    );
    expect(find.textContaining('سلفة'), findsWidgets);
  });
}
