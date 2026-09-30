import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:dhimmah/features/people/person_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Editing a debt must change the debt it opened, and nothing else.
///
/// This file exists because it once did not: the form read the amount, the note,
/// the dates and the title back out of the stored record and never read the
/// person, so every save wrote `personId: null`. The record stayed in the
/// database and vanished from the page it was recorded on, which is the worst
/// kind of bug in a ledger: silent, and about the wrong number.
///
/// So every test here ends the same way — the record is still there, it is still
/// the same record, and it says what the user just told it.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String personName = 'محمد أحمد عبدالرحمن';
  const String secondName = 'خالد العلي';
  const String debtTitle = 'قرض سيارة';

  late String personId;
  late String secondPersonId;

  Future<void> seed(WidgetTester tester) async {
    final Person person = await buildService(db).createPerson(
      const PersonDraft(name: personName),
    );
    final Person second = await buildService(db).createPerson(
      const PersonDraft(name: secondName),
    );
    personId = person.id;
    secondPersonId = second.id;
    await buildService(db).createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: debtTitle,
        principalMinor: 1000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(dateOnly(DateTime.now()), -10),
        note: 'ملاحظة قديمة',
      ),
    );
    await pumpDhimmah(tester, db: db);
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Ledger → the row → edit.
  Future<void> openEditForm(WidgetTester tester) async {
    await tester.tap(find.text('السجل').last);
    await settle(tester);
    // The row's sub-line reads "title · due", so the title is matched inside it.
    await tester.tap(find.textContaining(debtTitle).first);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
  }

  /// Scrolls the form until [target] exists.
  ///
  /// The form is one lazy list, so a field below the fold is not in the tree
  /// until it is scrolled to — the same thing a thumb does.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (int i = 0; i < 12 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await settle(tester);
    }
    expect(target, findsWidgets, reason: 'the field should be reachable');
    // Built is not the same as on the glass: finish with the framework's own
    // scroll-into-view so taps land and text entry has a focusable field.
    await tester.ensureVisible(target.first);
    await settle(tester);
  }

  Future<void> fillField(
    WidgetTester tester,
    String label,
    String value,
  ) async {
    final Finder field = find.widgetWithText(AppTextField, label);
    await reveal(tester, field);
    await tester.enterText(
      find.descendant(of: field, matching: find.byType(TextFormField)),
      value,
    );
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('حفظ التعديلات'));
    await settle(tester);
  }

  Future<void> typeAmount(WidgetTester tester, String amount) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextFormField),
      ),
      amount,
    );
    await settle(tester);
  }

  Future<Debt> reloaded() async {
    final DebtRow row = (await db.debtsDao.getAll()).single;
    return (await buildService(db).debts.getById(row.id))!;
  }

  group('editing one field at a time', () {
    testWidgets('the amount', (WidgetTester tester) async {
      await seed(tester);
      await openEditForm(tester);
      await typeAmount(tester, '20000');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.principalMinor, 2000000);
      expect(after.personIds, <String>[personId], reason: 'still the same person');
      expect(after.title, debtTitle, reason: 'the other fields are untouched');
    });

    testWidgets('the description and the note', (WidgetTester tester) async {
      await seed(tester);
      await openEditForm(tester);

      // The optional fields are already showing: the record uses them, and the
      // disclosure opens itself rather than hiding something it holds.
      await fillField(tester, 'الوصف · اختياري', 'قرض جديد');
      await fillField(tester, 'ملاحظات · اختياري', 'ملاحظة جديدة');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.title, 'قرض جديد');
      expect(after.note, 'ملاحظة جديدة');
      expect(after.principalMinor, 1000000);
      expect(after.personIds, <String>[personId]);
    });

    testWidgets('the side of the ledger', (WidgetTester tester) async {
      await seed(tester);
      await openEditForm(tester);

      await tester.tap(find.text('لي').last);
      await settle(tester);
      await save(tester);

      final Debt after = await reloaded();
      expect(after.direction, DebtDirection.owedToMe);
      expect(after.personIds, <String>[personId]);
      // The user is told where the record went, so a save that moves a record
      // out of the list it was opened from does not read as a deletion.
      expect(find.textContaining('انتقل الدين إلى'), findsOneWidget);
    });

    testWidgets('the people, adding one', (WidgetTester tester) async {
      await seed(tester);
      await openEditForm(tester);

      // The person the record is with is shown, not left blank — the bug this
      // file was written for.
      expect(find.widgetWithText(InputChip, personName), findsOneWidget);

      // The form scrolls; bring the control onto the glass first, the way a
      // user does after the description field moved it down.
      await reveal(tester, find.text('إضافة شخص'));
      await tester.tap(find.text('إضافة شخص'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text(secondName),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);
      await save(tester);

      expect(
        (await reloaded()).personIds,
        <String>[personId, secondPersonId],
        reason: 'the existing person is kept and the new one added',
      );

      // And the pair survives a second edit of something else entirely.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await settle(tester);
      await typeAmount(tester, '30000');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.personIds, <String>[personId, secondPersonId]);
      expect(after.principalMinor, 3000000);
    });

    testWidgets('nothing at all', (WidgetTester tester) async {
      await seed(tester);
      final DebtRow before = (await db.debtsDao.getAll()).single;

      await openEditForm(tester);
      await save(tester);

      final DebtRow after = (await db.debtsDao.getAll()).single;
      expect(after.id, before.id);
      expect(after.personId, before.personId);
      expect(after.principalMinor, before.principalMinor);
      expect(after.createdAt, before.createdAt, reason: 'the same record');
      expect(await db.debtsDao.participantsFor(after.id), <String>[personId]);
    });
  });

  group('edits that used to break something else', () {
    testWidgets('a debt with a payment keeps its history',
        (WidgetTester tester) async {
      await seed(tester);
      final DebtRow debt = (await db.debtsDao.getAll()).single;
      await buildService(db).recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 250000, paidAt: dateOnly(DateTime.now())),
      );
      await settle(tester);

      await openEditForm(tester);
      await typeAmount(tester, '40000');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.id, debt.id);
      expect(after.principalMinor, 4000000);
      expect(
        (await buildService(db).payments.forDebt(debt.id)),
        hasLength(1),
        reason: 'editing the debt must not touch its payments',
      );
      // And the balance is recomputed from the payment that still exists.
      expect(find.textContaining('37,500'), findsWidgets);
    });

    testWidgets('a settled debt stays settled', (WidgetTester tester) async {
      await seed(tester);
      final DebtRow debt = (await db.debtsDao.getAll()).single;
      await buildService(db).recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1000000, paidAt: dateOnly(DateTime.now())),
      );
      expect((await reloaded()).closedAt, isNotNull);

      await openEditForm(tester);
      await fillField(tester, 'الوصف · اختياري', 'قرض سيارة ٢');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.title, 'قرض سيارة ٢');
      expect(after.closedAt, isNotNull, reason: 'fully paid is still fully paid');
      expect(after.personIds, <String>[personId]);
    });

    testWidgets('a late debt keeps its due date', (WidgetTester tester) async {
      await seed(tester);
      final DebtRow debt = (await db.debtsDao.getAll()).single;
      await buildService(db).updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[personId],
          title: debtTitle,
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: addDays(dateOnly(DateTime.now()), -10),
          dueAt: addDays(dateOnly(DateTime.now()), -4),
        ),
      );
      await settle(tester);

      await openEditForm(tester);
      await typeAmount(tester, '11000');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.dueAt, addDays(dateOnly(DateTime.now()), -4));
      expect(after.personIds, <String>[personId]);
    });

    testWidgets('a repeating debt keeps the end of its series',
        (WidgetTester tester) async {
      await seed(tester);
      final DebtRow debt = (await db.debtsDao.getAll()).single;
      final DateTime today = dateOnly(DateTime.now());
      final DateTime end = addDays(today, 200);
      // Set outside the form, which has no field for it: a restored backup
      // can carry one.
      await buildService(db).updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[personId],
          title: debtTitle,
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -10),
          dueAt: addDays(today, 20),
          recurrence: RecurrenceFrequency.monthly,
          recurrenceEndAt: end,
        ),
      );
      await settle(tester);

      await openEditForm(tester);
      await typeAmount(tester, '12000');
      await save(tester);

      final Debt after = await reloaded();
      expect(after.principalMinor, 1200000);
      expect(after.recurrence, RecurrenceFrequency.monthly);
      expect(
        after.recurrenceEndAt,
        end,
        reason: 'an edit that did not touch the series must not erase its end',
      );
    });
  });

  group('after the edit', () {
    testWidgets('the debt is on the person’s page and in the ledger',
        (WidgetTester tester) async {
      await seed(tester);
      await openEditForm(tester);
      await typeAmount(tester, '20000');
      await save(tester);

      // Back on the record, with the new amount, then back to the shell.
      expect(find.textContaining('20,000'), findsWidgets);
      await tester.tap(find.byType(BackButton));
      await settle(tester);

      // And on the person's page, where it used to disappear from.
      await tester.tap(find.text('الأشخاص').last);
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeopleScreen),
          matching: find.text(personName),
        ),
      );
      await settle(tester);
      expect(find.textContaining(debtTitle), findsWidgets);
      expect(find.textContaining('20,000'), findsWidgets);
    });

    testWidgets('a restart shows the edited record', (WidgetTester tester) async {
      await seed(tester);
      await openEditForm(tester);
      await typeAmount(tester, '33000');
      await save(tester);

      // A second launch over the same database: the tree is torn down first so
      // the app really does start from scratch, and nothing is carried in
      // memory between the two — this reads what was actually written.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpDhimmah(tester, db: db);
      await settle(tester);
      await tester.tap(find.text('السجل').last);
      await settle(tester);

      expect(find.textContaining(debtTitle), findsWidgets);
      expect(find.textContaining('33,000'), findsWidgets);

      final Debt after = await reloaded();
      expect(after.principalMinor, 3300000);
      expect(after.personIds, <String>[personId]);
    });
  });
}
