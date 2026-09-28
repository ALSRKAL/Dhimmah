import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The forms' pinned Save must rise above the keyboard, not hide behind it.
///
/// On the Note 20 the person form's Save button sat under the open IME: the
/// screenshot shows the keyboard covering the bottom half with no Save visible,
/// and taps on the button's coordinates landed on the keyboard. This test fakes
/// the IME inset and measures where the button actually renders.
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

  testWidgets('the person form Save lifts above a faked keyboard',
      (WidgetTester tester) async {
    await seedLedger(db, extraCurrency: AppCurrency.inr);
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    // People tab → the add sheet → the new-person form.
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.tap(find.text('شخص جديد'));
    await settle(tester);

    // The IME the device showed: an inset covering the bottom of the screen.
    const double imeHeight = 300;
    tester.view.viewInsets = const FakeViewPadding(bottom: imeHeight);
    tester.view.padding = FakeViewPadding.zero;
    await tester.pump();
    await settle(tester);

    final Finder save = find.text('حفظ');
    expect(save, findsOneWidget);
    final double saveTop = tester.getTopRight(save).dy;
    final double screenBottom = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;
    final double logicalIme = imeHeight / tester.view.devicePixelRatio;
    // The button must sit above the keyboard line, not behind it.
    expect(
      saveTop,
      lessThan(screenBottom - logicalIme),
      reason: 'the pinned Save renders behind the open keyboard',
    );
  });
}
