import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/debts/person_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The person payment sheet under a thumb.
///
/// Everything here is about the four things a hand does on this sheet: reads why
/// one record is above another, taps a row rather than a checkbox, presses a
/// shortcut and sees it stay pressed, and types with the keyboard over the lower
/// half of the phone. A preview that cannot be read while the keyboard is up is
/// a preview the user approves blind.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late Person ahmed;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    db = AppDatabase.memory();
    service = buildService(db);
    ahmed = await service.createPerson(const PersonDraft(name: 'أحمد'));
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<Debt> debt({
    required String title,
    required int rupees,
    DateTime? dueAt,
    DateTime? issuedAt,
  }) =>
      service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: title,
          principalMinor: rupees * 100,
          currency: AppCurrency.inr,
          issuedAt: issuedAt ?? today,
          dueAt: dueAt,
        ),
      );

  /// The person's page is still behind the sheet and lists the same records, so
  /// every row lookup is scoped to the sheet itself.
  Finder inSheet(Finder matching) => find.descendant(
        of: find.byType(PersonPaymentSheet),
        matching: matching,
      );

  Future<void> openSheet(WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.text('أحمد').first);
    await settle(tester);
    await tester.tap(find.text('تسجيل دفعة').first);
    await settle(tester);
  }

  group('every row says what it is ordered by', () {
    testWidgets('a record with a due date shows the date',
        (WidgetTester tester) async {
      await debt(title: 'العطر', rupees: 300, dueAt: addDays(today, 2));
      await openSheet(tester);

      expect(inSheet(find.text('العطر')), findsOneWidget);
      expect(inSheet(find.textContaining('بلا تاريخ')), findsNothing);
    });

    testWidgets('a record with no due date says when it was added',
        (WidgetTester tester) async {
      // The rule orders by this day, so without it the row had no visible
      // reason to be where it is.
      await debt(title: 'العطر', rupees: 300);
      await openSheet(tester);

      expect(inSheet(find.textContaining('أُضيف في')), findsOneWidget);
      expect(inSheet(find.textContaining('بلا تاريخ')), findsNothing);
    });
  });

  group('the row is the target', () {
    testWidgets('tapping the title toggles the record, not just the checkbox',
        (WidgetTester tester) async {
      await debt(title: 'العطر', rupees: 300, dueAt: addDays(today, 1));
      await openSheet(tester);

      expect(inSheet(find.textContaining('مستثنى')), findsNothing);
      await tester.tap(inSheet(find.text('العطر')));
      await settle(tester);
      expect(inSheet(find.textContaining('مستثنى')), findsOneWidget,
          reason: 'the whole row is the switch');

      await tester.tap(inSheet(find.text('العطر')));
      await settle(tester);
      expect(inSheet(find.textContaining('مستثنى')), findsNothing);
    });
  });

  group('a shortcut shows that it is the one in force', () {
    testWidgets('pressing 50% lights it, and typing over it puts it out',
        (WidgetTester tester) async {
      await debt(title: 'العطر', rupees: 300, dueAt: addDays(today, 1));
      await openSheet(tester);

      bool chipSelected(String label) => tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: inSheet(find.text(label)),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected;

      expect(chipSelected('50%'), isFalse);

      await tester.tap(find.text('50%'));
      await settle(tester);
      expect(chipSelected('50%'), isTrue);
      expect(chipSelected('25%'), isFalse);

      await tester.tap(find.text('25%'));
      await settle(tester);
      expect(chipSelected('25%'), isTrue);
      expect(chipSelected('50%'), isFalse);

      // A number that is not the shortcut's is not the shortcut.
      await tester.enterText(find.byType(AmountField), '111');
      await settle(tester);
      expect(chipSelected('25%'), isFalse);
      expect(chipSelected('50%'), isFalse);
    });

    testWidgets('pay all is lit only while the field holds the whole balance',
        (WidgetTester tester) async {
      await debt(title: 'العطر', rupees: 300, dueAt: addDays(today, 1));
      await openSheet(tester);

      await tester.tap(find.text('سداد الكل'));
      await settle(tester);
      final ChoiceChip all = tester.widget<ChoiceChip>(
        find.ancestor(
          of: inSheet(find.text('سداد الكل')),
          matching: find.byType(ChoiceChip),
        ),
      );
      expect(all.selected, isTrue);
    });
  });

  group('with the keyboard up', () {
    /// Seventeen open debts: a list longer than the sheet, so the body has to
    /// scroll inside it, and the amount field and the save button have to stay
    /// where a thumb can reach them.
    Future<void> seedSeventeen() async {
      for (int i = 1; i <= 17; i++) {
        await debt(
          title: 'دين رقم $i',
          rupees: 100 + i,
          dueAt: addDays(today, i),
        );
      }
    }

    Future<void> openKeyboard(WidgetTester tester) async {
      const double imeHeight = 300;
      tester.view.viewInsets = const FakeViewPadding(bottom: imeHeight);
      tester.view.padding = FakeViewPadding.zero;
      await tester.pump();
      await settle(tester);
    }

    /// Where the keyboard's top edge is, in the same global coordinates the
    /// widget rects are measured in.
    ///
    /// Not `MediaQuery.of` from inside the sheet: a modal sheet is laid out
    /// against its own height, so the MediaQuery down there reports the sheet's
    /// box rather than the window's, and comparing a global position against it
    /// compares two different spaces.
    double keyboardTop(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio - 300;

    testWidgets('the amount field and the save button stay above the keyboard',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seedSeventeen();
      await openSheet(tester);
      await openKeyboard(tester);

      // Tapping the field is what opens the keyboard on a device.
      await tester.tap(find.byType(AmountField));
      await settle(tester);

      final double line = keyboardTop(tester);
      expect(
        tester.getBottomLeft(find.byType(AmountField)).dy,
        lessThan(line),
        reason: 'the amount field is behind the keyboard',
      );
      expect(
        tester.getBottomLeft(find.text('حفظ الدفعة')).dy,
        lessThanOrEqualTo(line),
        reason: 'the save button is behind the keyboard',
      );
      // And the field still answers: what is typed is what the sheet holds.
      await tester.enterText(find.byType(AmountField), '250');
      await settle(tester);
      expect(
        tester.widget<AmountField>(find.byType(AmountField)).controller!.text,
        '250',
      );
      expect(find.text('حفظ الدفعة'), findsOneWidget);
    });

    testWidgets('the list scrolls inside the sheet and the save bar does not move',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await seedSeventeen();
      await openSheet(tester);
      await openKeyboard(tester);

      final ScrollableState scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(PersonPaymentSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        scroll.position.maxScrollExtent,
        greaterThan(1000),
        reason: 'seventeen records are far taller than the sheet',
      );

      // The pinned bar and the amount field keep their places; the body is what
      // moves. The keyboard leaves the body a short window — the sheet's header
      // and the pinned save take their share above the keyboard line — so the
      // first record sits just below the fold until the body is scrolled. That
      // is the trade the pinned save makes, and it is stated here rather than
      // discovered on a phone.
      final double barBefore =
          tester.getBottomLeft(find.text('حفظ الدفعة')).dy;
      expect(
        barBefore,
        lessThanOrEqualTo(keyboardTop(tester)),
        reason: 'the pinned save renders behind the keyboard',
      );
      final Rect viewport = tester.getRect(
        find
            .descendant(
              of: find.byType(PersonPaymentSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester.getTopLeft(inSheet(find.text('دين رقم 1'))).dy,
        greaterThan(viewport.bottom),
        reason: 'the first record starts below the fold the pinned bar leaves',
      );

      // A finger on the exposed part of the body — not on a row that is still
      // below the fold, and not on the text field, which has a drag gesture of
      // its own for selecting text.
      await tester.dragFrom(
        Offset(viewport.center.dx, viewport.top + 30),
        const Offset(0, -260),
      );
      await settle(tester);
      expect(
        scroll.position.pixels,
        greaterThan(200),
        reason: 'a finger on the body scrolls the body',
      );
      expect(
        tester.getBottomLeft(find.text('حفظ الدفعة')).dy,
        barBefore,
        reason: 'the save bar is pinned: scrolling the list must not move it',
      );

      for (int i = 0;
          i < 12 &&
              tester.getTopLeft(inSheet(find.text('دين رقم 17'))).dy >
                  viewport.bottom;
          i++) {
        await tester.dragFrom(
          Offset(viewport.center.dx, viewport.top + 30),
          const Offset(0, -260),
        );
        await settle(tester);
      }
      expect(
        tester.getTopLeft(inSheet(find.text('دين رقم 17'))).dy,
        lessThan(viewport.bottom),
        reason: 'the last record is reachable with the keyboard up',
      );
      expect(find.text('حفظ الدفعة'), findsOneWidget);
    });
  });
}
