import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/features/debts/debt_list.dart';
import 'package:dhimmah/features/shell/add_action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What is in front, and what a thumb actually reaches.
///
/// The shell's add button is a sibling of each tab's navigator, not a child of
/// it, so a modal sheet opened *from inside a tab* renders underneath the button
/// — and under nothing that stops a tap, because the sheet's barrier lives in
/// the tab's navigator while the button is painted after the whole body
/// (the mechanism is documented on `showAppSheet`). Two sheets on the ledger tab
/// were opened that way: the filter sheet, whose bottom edge carries Apply and
/// Reset, and the row-actions menu, whose last row is Delete — so a tap on the
/// last row opened the add sheet on top of the sheet the user was reading.
///
/// This is the guard. It taps where the button is and asks what happened, which
/// is the defect itself rather than a proxy for it. Both call sites now ask for
/// the root navigator, as `showAppSheet`'s own doc says a sheet with a bottom
/// action must.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Future<void> openLedger(WidgetTester tester) async {
    // A phone, not the 800-wide test default. Material 3 caps a bottom sheet at
    // 640 wide, so at 800 the sheet is centred with an 80px gutter each side and
    // the corner add button never overlaps it — which would make every
    // assertion below pass without testing anything.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await seedLedger(db);
    await pumpDhimmah(tester, db: db);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('السجل').last);
    await tester.pumpAndSettle();
  }

  /// A tap where the shell's add button is. Not `tester.tap`, which warns when
  /// the target is covered — the whole point here is that it is covered.
  Future<void> tapAddButton(WidgetTester tester) async {
    await tester.tapAt(tester.getRect(find.byType(FloatingActionButton)).center);
    await tester.pumpAndSettle();
  }

  /// The button really does sit over the sheet, so the taps below mean
  /// something. If a future layout moves it clear of the sheet this fails, and
  /// the two guards below should be re-read rather than trusted.
  void expectButtonOverlaps(WidgetTester tester, Finder sheet) {
    final Rect button = tester.getRect(find.byType(FloatingActionButton));
    final Rect front = tester.getRect(sheet);
    expect(
      button.overlaps(front),
      isTrue,
      reason: 'the add button is expected to sit inside the sheet it covers '
          '(button $button, sheet $front) — if it no longer does, this test is '
          'no longer about a real overlap',
    );
  }

  testWidgets('the filter sheet is not reachable past the add button',
      (WidgetTester tester) async {
    await openLedger(tester);
    await tester.tap(find.text('الفلاتر').last);
    await tester.pumpAndSettle();
    expect(find.byType(DebtFilterSheet), findsOneWidget);
    // Both controls are on the sheet, and both live along its bottom edge.
    expect(find.text('تطبيق'), findsOneWidget);
    expect(find.text('إعادة تعيين'), findsOneWidget);
    expectButtonOverlaps(tester, find.byType(BottomSheet));

    await tapAddButton(tester);

    expect(
      find.byType(AddActionSheet),
      findsNothing,
      reason: 'the add button took a tap that belonged to the sheet above it',
    );
  });

  testWidgets('the row menu is not reachable past the add button',
      (WidgetTester tester) async {
    await openLedger(tester);
    // A row leads with the person's name, which is what a long press lands on.
    await tester.longPress(find.text('محمد أحمد عبدالرحمن').first);
    await tester.pumpAndSettle();
    expect(find.text('حذف'), findsWidgets, reason: 'the row menu is open');
    expectButtonOverlaps(tester, find.byType(BottomSheet));

    await tapAddButton(tester);

    expect(
      find.byType(AddActionSheet),
      findsNothing,
      reason: 'the add button took a tap from the row menu',
    );
  });

  testWidgets('and the button still works once nothing is in front',
      (WidgetTester tester) async {
    // The other half of the guard: the fix must not have disabled the button.
    // Without this, both assertions above could pass for the wrong reason.
    await openLedger(tester);
    await tapAddButton(tester);
    expect(find.byType(AddActionSheet), findsOneWidget);
  });
}
