import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One record, several people — as each of them sees it.
///
/// A debt linked to three people is one record, and every one of them is linked
/// to the whole of it. What each of their pages shows is that person's side of
/// the record: one of their own debts, in full, with the ordinary row, the
/// ordinary hero figure and no indication that anyone else is on it. There is no
/// "shared" heading, badge, banner or note anywhere, and no page names another
/// participant.
///
/// The amounts are pinned here as well as in `test/data/multi_person_debt_test`,
/// because the failure this guards against is a display regression: the record
/// shown three times as 1,500 and totalled as 4,500.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String debtTitle = 'فاتورة العشاء';
  const String first = 'محمد أحمد عبدالرحمن';
  const String second = 'خالد العلي';
  const String third = 'مريم الحسن';

  late Person ahmed;
  late Person khalid;
  late Person maryam;
  late String debtId;

  /// 1,500 owed to three people at once — one record.
  Future<void> seed(WidgetTester tester) async {
    final LedgerService service = buildService(db);
    ahmed = await service.createPerson(const PersonDraft(name: first));
    khalid = await service.createPerson(const PersonDraft(name: second));
    maryam = await service.createPerson(const PersonDraft(name: third));
    final Debt debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id, khalid.id, maryam.id],
        title: debtTitle,
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: dateOnly(DateTime.now()),
      ),
    );
    debtId = debt.id;
    await pumpDhimmah(tester, db: db);
  }

  /// Waits for a screen to finish loading. Drift reads complete on the real
  /// event loop, which `pump` alone never advances.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Opens someone's page from the people list.
  ///
  /// Any page pushed before this one is dismissed first, so a test that has been
  /// through a detail screen or a form starts from the same place every time.
  Future<void> openPerson(WidgetTester tester, String name) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((Route<dynamic> route) => route.isFirst);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text(name),
      ),
    );
    await settle(tester);
  }

  /// Leaves a pushed page.
  ///
  /// `tester.pageBack()` looks for a button tooltipped "Back", and this app is
  /// in Arabic, so the pop is done through the navigator the route lives on.
  /// The root navigator's first route is the shell itself, which is where a
  /// test needs to be to open someone else.
  Future<void> back(WidgetTester tester) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((Route<dynamic> route) => route.isFirst);
    await settle(tester);
  }

  /// Every name on the record except [keep], which the page belongs to.
  List<String> others(String keep) => <String>[
        for (final String name in <String>[first, second, third])
          if (name != keep) name,
      ];

  testWidgets('every participant sees the record, and none of the others',
      (WidgetTester tester) async {
    await seed(tester);

    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);

      // The record is here, as one of this person's own debts: the ordinary row
      // with the ordinary title, and the figure stated for the record.
      expect(
        find.text(debtTitle),
        findsOneWidget,
        reason: '$name should see the record itself',
      );
      expect(
        find.textContaining('1,500'),
        findsWidgets,
        reason: '$name should see the record’s amount',
      );

      // Nobody else on the record is named anywhere on this page, and nothing
      // calls the record shared.
      for (final String other in others(name)) {
        expect(
          find.textContaining(other),
          findsNothing,
          reason: '$name’s page must not name $other',
        );
      }
      expect(
        find.textContaining('مشترك'),
        findsNothing,
        reason: 'the interface has no shared-debt vocabulary left',
      );

      // The row's action sheet reads the same way: about this person's record,
      // not about everyone it is linked to.
      await tester.longPress(find.text(debtTitle).first);
      await settle(tester);
      expect(find.text(debtTitle), findsWidgets, reason: 'the sheet names it');
      for (final String other in others(name)) {
        expect(
          find.textContaining(other),
          findsNothing,
          reason: '$name’s action sheet must not name $other',
        );
      }

      await back(tester);
    }
  });

  testWidgets('no page and no total multiplies the record',
      (WidgetTester tester) async {
    await seed(tester);

    // The dashboard: one record, so 1,500 — never three times it.
    expect(find.textContaining('1,500'), findsWidgets);
    expect(find.textContaining('4,500'), findsNothing);

    // Each page states the same 1,500, and none of them states 4,500.
    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);
      expect(find.textContaining('1,500'), findsWidgets);
      expect(find.textContaining('4,500'), findsNothing);
      await back(tester);
    }

    expect(await db.debtsDao.getAll(), hasLength(1),
        reason: 'one debt, whatever the page count');
    final Debt record = (await buildService(db).debts.getById(debtId))!;
    expect(record.principalMinor, 150000);
    expect(record.personIds, <String>[ahmed.id, khalid.id, maryam.id]);
  });

  testWidgets('one payment is one payment: the record falls for all of them',
      (WidgetTester tester) async {
    await seed(tester);

    await buildService(db).recordPayment(
      debtId,
      PaymentDraft(amountMinor: 50000, paidAt: dateOnly(DateTime.now())),
    );
    await settle(tester);

    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);
      expect(
        find.textContaining('1,000'),
        findsWidgets,
        reason: '$name sees the same 500 paid off the same record',
      );
      await back(tester);
    }

    expect(
      await db.debtsDao.getPaymentsForDebt(debtId),
      hasLength(1),
      reason: 'a payment belongs to the record, not to a person on it',
    );
  });

  testWidgets('editing from one participant’s page edits the one record',
      (WidgetTester tester) async {
    await seed(tester);
    await openPerson(tester, first);

    // The record → edit, from the page it was opened on.
    await tester.tap(find.text(debtTitle).first);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);

    // The form knows who the record is with, and says so rather than asking.
    expect(find.widgetWithText(InputChip, first), findsOneWidget);
    expect(find.widgetWithText(InputChip, second), findsOneWidget);
    expect(find.widgetWithText(InputChip, third), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextFormField),
      ),
      '2000',
    );
    await settle(tester);
    await tester.tap(find.text('حفظ التعديلات'));
    await settle(tester);

    // Still one record, same id, same three people, new amount.
    expect(await db.debtsDao.getAll(), hasLength(1));
    final Debt record = (await buildService(db).debts.getById(debtId))!;
    expect(record.id, debtId, reason: 'edited, not recreated');
    expect(record.principalMinor, 200000);
    expect(
      await db.debtsDao.participantsFor(debtId),
      <String>[ahmed.id, khalid.id, maryam.id],
    );

    // And every page shows the new amount, because there is one record.
    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);
      expect(find.textContaining('2,000'), findsWidgets);
      await back(tester);
    }
  });

  testWidgets('unlinking one person leaves the record for the rest',
      (WidgetTester tester) async {
    await seed(tester);

    await buildService(db).deletePerson(khalid.id);
    await settle(tester);

    expect(await db.debtsDao.getAll(), hasLength(1), reason: 'the record stays');
    expect(
      await db.debtsDao.participantsFor(debtId),
      <String>[ahmed.id, maryam.id],
    );

    await openPerson(tester, first);
    expect(find.text(debtTitle), findsOneWidget);
    expect(find.textContaining('1,500'), findsWidgets);
    expect(find.textContaining(second), findsNothing);
  });

  testWidgets('the pages read the same after a restart',
      (WidgetTester tester) async {
    await seed(tester);

    // A full restart: the tree goes away and the app is built again, so nothing
    // on screen can be carrying this from the previous session.
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    await pumpDhimmah(tester, db: db);

    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);
      expect(find.text(debtTitle), findsOneWidget);
      expect(find.textContaining('1,500'), findsWidgets);
      expect(find.textContaining('مشترك'), findsNothing);
      await back(tester);
    }

    expect(await db.debtsDao.participantsFor(debtId), hasLength(3));
  });
}
