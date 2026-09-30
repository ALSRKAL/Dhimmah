import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:dhimmah/features/people/person_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What the debt form asks for, and what it says when the answer is missing.
///
/// Driven through the real app: the fields a user touches, the errors a user
/// reads, and the record that ends up in the database afterwards.
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

  Future<Person> addPerson(String name) =>
      buildService(db).createPerson(PersonDraft(name: name));

  /// Opens the new-debt form with nothing chosen, through the dashboard's own
  /// empty-state action — the path a first debt takes.
  Future<void> openBlankForm(WidgetTester tester) async {
    await settle(tester);
    await tester.tap(find.text('إضافة أول دين'));
    await settle(tester);
  }

  /// Scrolls the form until [target] is on the glass, the way a user does —
  /// the form is longer than one screen and the list builds lazily.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (int i = 0; i < 12 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await settle(tester);
    }
    // Built is not the same as on the glass: finish with the framework's own
    // scroll-into-view so taps land and text entry has a focusable field.
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await settle(tester);
    }
  }

  Future<String> amountText(WidgetTester tester) async {
    final EditableText field = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(EditableText),
      ),
    );
    return field.controller.text;
  }

  group('what is visible without expanding anything', () {
    testWidgets('the description and the amount are in the open form',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      // The amount is a first-class field, never behind the disclosure.
      expect(find.text('المبلغ *'), findsOneWidget);
      // The description sits under it, visible: it used to live inside
      // «خيارات إضافية», where naming the debt took a toggle first.
      expect(find.text('الوصف · اختياري'), findsOneWidget);

      // The disclosure still holds the rest, and still opens.
      expect(find.text('تاريخ الدين'), findsNothing);
      await reveal(tester, find.textContaining('خيارات إضافية'));
      await tester.tap(find.textContaining('خيارات إضافية'));
      await settle(tester);
      expect(find.text('تاريخ الدين'), findsOneWidget);
      expect(find.text('الوصف · اختياري'), findsOneWidget,
          reason: 'the description stays in the open form after expanding');
    });
  });

  group('required fields', () {
    testWidgets('nothing is chosen until the user chooses it', (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      // The three required fields say so before anything is pressed.
      expect(find.text('نوع العملية *'), findsOneWidget);
      expect(find.text('المبلغ *'), findsOneWidget);
      expect(find.text('الأشخاص *'), findsOneWidget);

      // Nothing is selected in the segmented control: neither side is
      // highlighted, so there is no answer the app gave on the user's behalf.
      final SegmentedButton<DebtDirection> control =
          tester.widget<SegmentedButton<DebtDirection>>(
        find.byType(SegmentedButton<DebtDirection>),
      );
      expect(control.selected, isEmpty);
    });

    testWidgets('a save with everything missing names each field',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      // Not a bare "invalid form": the fields themselves carry the message.
      expect(find.text('اختر نوع الدين: عليّ أو لي.'), findsOneWidget);
      expect(find.text('أدخل مبلغًا صحيحًا أكبر من صفر.'), findsOneWidget);
      // The summary counts them, at the top where a scrolled screen can see it.
      expect(find.text('3 حقول مطلوبة لم تكتمل.'), findsOneWidget);
      // The people message sits a screen down; scroll to it as a user would.
      await reveal(tester, find.text('اختر شخصًا واحدًا على الأقل.'));
      expect(find.text('اختر شخصًا واحدًا على الأقل.'), findsOneWidget);

      // Nothing was written.
      expect(await db.debtsDao.getAll(), isEmpty);
    });

    testWidgets('each field clears its own error as it is filled',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      // Back to the top of the form: the segmented control scrolled out of the
      // lazy list while the people section was being reached.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('عليّ').first);
      await settle(tester);
      expect(find.text('اختر نوع الدين: عليّ أو لي.'), findsNothing);
      expect(find.text('أدخل مبلغًا صحيحًا أكبر من صفر.'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '1500',
      );
      await settle(tester);
      expect(find.text('أدخل مبلغًا صحيحًا أكبر من صفر.'), findsNothing);
      expect(find.text('اختر شخصًا واحدًا على الأقل.'), findsOneWidget);
      // The summary was the headline for the refused save; once the user is
      // fixing the fields it steps aside and the remaining field keeps its error.
      expect(find.text('3 حقول مطلوبة لم تكتمل.'), findsNothing);

      // The draft survives every refusal.
      expect(await amountText(tester), '1500');
    });

    testWidgets('a refused save brings the first missing field into view',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      // Scroll away from the required fields, the way someone reading the
      // optional ones would be. The form is a lazy list, so the direction field
      // is not even built once it is far enough up.
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await settle(tester);
      expect(find.text('نوع العملية *'), findsNothing);

      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      // The screen moved back to it, and its message is with it.
      expect(find.text('نوع العملية *'), findsOneWidget);
      final Rect field = tester.getRect(find.text('نوع العملية *'));
      expect(field.top, greaterThanOrEqualTo(0.0));
      expect(field.bottom, lessThanOrEqualTo(600.0));
      expect(find.text('اختر نوع الدين: عليّ أو لي.'), findsOneWidget);
    });

    testWidgets('the acceptance walk-through: refuse, fix, save',
        (WidgetTester tester) async {
      final Person ahmed = await addPerson('أحمد');
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      // Save with nothing: the direction is the first thing named.
      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);
      expect(find.text('اختر نوع الدين: عليّ أو لي.'), findsOneWidget);

      // Choose a side; the others are still missing and still stated.
      // Back to the top first: the direction control scrolled out of the lazy
      // list while the people section was being reached.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('لي').first);
      await settle(tester);
      expect(find.text('اختر نوع الدين: عليّ أو لي.'), findsNothing);
      expect(find.text('أدخل مبلغًا صحيحًا أكبر من صفر.'), findsOneWidget);
      expect(find.text('اختر شخصًا واحدًا على الأقل.'), findsOneWidget);

      // Fill the amount and the person, then save for real.
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '1500',
      );
      await settle(tester);
      await tester.tap(find.text('اختر شخصًا أو أضف جديدًا'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text('أحمد'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);

      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      final DebtRow stored = (await db.debtsDao.getAll()).single;
      expect(stored.direction, DebtDirection.owedToMe);
      expect(stored.principalMinor, 150000);
      expect(await db.debtsDao.participantsFor(stored.id), <String>[ahmed.id]);
    });

    testWidgets('the amount typed before a failed save is still there',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '750',
      );
      await settle(tester);
      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      expect(find.text('اختر نوع الدين: عليّ أو لي.'), findsOneWidget);
      expect(await amountText(tester), '750');
    });
  });

  group('people', () {
    testWidgets('several are chosen, listed, and removable',
        (WidgetTester tester) async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      await tester.tap(find.text('اختر شخصًا أو أضف جديدًا'));
      await settle(tester);
      expect(find.byType(PeoplePickerSheet), findsOneWidget);

      for (final String name in <String>['أحمد', 'علي', 'محمد']) {
        await tester.tap(
          find.descendant(
            of: find.byType(PeoplePickerSheet),
            matching: find.text(name),
          ),
        );
        await settle(tester);
      }
      // The selection is stated in the sheet before it is confirmed.
      expect(find.text('المحددون'), findsOneWidget);
      await tester.tap(find.text('تم'));
      await settle(tester);

      // Three chips on the form, and the same person cannot be added twice.
      expect(find.widgetWithText(InputChip, 'أحمد'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'علي'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'محمد'), findsOneWidget);

      // Removing one leaves the other two.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'علي'),
          matching: find.byTooltip('مسح'),
        ),
      );
      await settle(tester);
      expect(find.widgetWithText(InputChip, 'علي'), findsNothing);

      // Put them back and save: one record, three people.
      await reveal(tester, find.text('إضافة شخص'));
      await tester.tap(find.text('إضافة شخص'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text('علي'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);

      // Back to the top of the form: the segmented control scrolled out of the
      // lazy list while the people section was being reached.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('عليّ').first);
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '1500',
      );
      await settle(tester);
      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      final List<DebtRow> stored = await db.debtsDao.getAll();
      expect(stored, hasLength(1), reason: 'one debt, not one per person');
      // The order is the order they were chosen in: Ali was re-added last.
      expect(
        await db.debtsDao.participantsFor(stored.single.id),
        <String>[ahmed.id, mohammed.id, ali.id],
      );
    });

    testWidgets('the picker finds a name typed without its hamza',
        (WidgetTester tester) async {
      await addPerson('أحمد');
      await addPerson('علي');
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      await tester.tap(find.text('اختر شخصًا أو أضف جديدًا'));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.byType(TextField),
        ),
        'احمد',
      );
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text('أحمد'),
        ),
        findsOneWidget,
        reason: 'it is the same name without the mark over its alef',
      );
      expect(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text('علي'),
        ),
        findsNothing,
      );
    });
  });

  group('adding a debt from a person’s page', () {
    testWidgets('attaches that person without asking again',
        (WidgetTester tester) async {
      final Person ahmed = await addPerson('أحمد');
      await pumpDhimmah(tester, db: db);

      // People → Ahmed → add a debt.
      await tester.tap(find.text('الأشخاص').last);
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeopleScreen),
          matching: find.text('أحمد'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('إضافة دين'));
      await settle(tester);

      // The context is stated, not asked for.
      expect(find.widgetWithText(InputChip, 'الدين مع أحمد'), findsOneWidget);
      expect(find.byType(PeoplePickerSheet), findsNothing);
      expect(find.text('اختر شخصًا أو أضف جديدًا'), findsNothing);

      // Only the amount is left, and the side the user has not chosen yet.
      // Back to the top of the form: the segmented control scrolled out of the
      // lazy list while the people section was being reached.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('عليّ').first);
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '900',
      );
      await settle(tester);
      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      // Saved, and back on the person's page with the debt on it.
      final DebtRow stored = (await db.debtsDao.getAll()).single;
      expect((await db.debtsDao.participantsFor(stored.id)), <String>[ahmed.id]);
      expect(find.text('الدين مع أحمد'), findsNothing);
      expect(find.textContaining('900'), findsWidgets);
    });

    testWidgets('can add more people on request, not by default',
        (WidgetTester tester) async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await pumpDhimmah(tester, db: db);

      await tester.tap(find.text('الأشخاص').last);
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeopleScreen),
          matching: find.text('أحمد'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('إضافة دين'));
      await settle(tester);

      // The second person is one explicit tap away.
      await reveal(tester, find.text('إضافة أشخاص آخرين'));
      await tester.tap(find.text('إضافة أشخاص آخرين'));
      await settle(tester);
      expect(find.byType(PeoplePickerSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text('علي'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);

      // Back to the top first: the direction control scrolled out of the lazy
      // list while the people section was being reached.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('لي').first);
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '600',
      );
      await settle(tester);
      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      final DebtRow stored = (await db.debtsDao.getAll()).single;
      expect(
        await db.debtsDao.participantsFor(stored.id),
        <String>[ahmed.id, ali.id],
      );
      expect(stored.direction, DebtDirection.owedToMe);
    });
  });

  group('leaving with unsaved changes', () {
    testWidgets('is confirmed only when something was typed',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openBlankForm(tester);

      // Nothing touched: back leaves immediately.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text('تغييرات غير محفوظة'), findsNothing);

      await openBlankForm(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '700',
      );
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      expect(find.text('تغييرات غير محفوظة'), findsOneWidget);
      await tester.tap(find.text('متابعة التعديل'));
      await settle(tester);
      // Staying keeps the draft exactly where it was.
      expect(await amountText(tester), '700');
    });
  });
}
