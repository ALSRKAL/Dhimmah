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

/// One debt per person — as each of them sees it.
///
/// Naming three people when recording a debt creates three independent
/// records, one per participant, each with the full amount. What each of their
/// pages shows is that person's own record: the ordinary row, the ordinary
/// hero figure and no indication that anyone else was named alongside them.
/// There is no "shared" heading, badge, banner or note anywhere, and no page
/// names another participant.
///
/// Settling one record leaves the others alone: a full payment from one
/// participant's page used to zero everyone at once, which is the bug this
/// file pins shut at the widget level.
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
  late String ahmedDebtId;
  late String khalidDebtId;
  late String maryamDebtId;

  /// 1,500 owed by three people — one independent record apiece.
  Future<void> seed(WidgetTester tester) async {
    final LedgerService service = buildService(db);
    ahmed = await service.createPerson(const PersonDraft(name: first));
    khalid = await service.createPerson(const PersonDraft(name: second));
    maryam = await service.createPerson(const PersonDraft(name: third));
    final List<Debt> created = await service.createDebts(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id, khalid.id, maryam.id],
        title: debtTitle,
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: dateOnly(DateTime.now()),
      ),
    );
    String idFor(String personId) => created
        .firstWhere((Debt d) => d.personIds.single == personId)
        .id;
    ahmedDebtId = idFor(ahmed.id);
    khalidDebtId = idFor(khalid.id);
    maryamDebtId = idFor(maryam.id);
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

  testWidgets('every participant sees only their own record, and none of the others',
      (WidgetTester tester) async {
    await seed(tester);

    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);

      // The record is here, as one of this person's own debts: the ordinary row
      // with the ordinary title, and the figure stated for the record.
      expect(
        find.text(debtTitle),
        findsOneWidget,
        reason: '$name should see their own record itself',
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

  testWidgets('each page states its own record, and the ledger holds all three',
      (WidgetTester tester) async {
    await seed(tester);

    // The dashboard: three independent records of 1,500 — 4,500 in total.
    expect(find.textContaining('1,500'), findsWidgets);
    expect(find.textContaining('4,500'), findsWidgets);

    // Each page states the same 1,500 for its own record.
    for (final String name in <String>[first, second, third]) {
      await openPerson(tester, name);
      expect(find.textContaining('1,500'), findsWidgets);
      await back(tester);
    }

    expect(await db.debtsDao.getAll(), hasLength(3),
        reason: 'one debt per person');
    for (final Debt record in await buildService(db).debts.getAll()) {
      expect(record.principalMinor, 150000);
      expect(record.personIds, hasLength(1));
    }
  });

  testWidgets('a payment settles only its own record',
      (WidgetTester tester) async {
    await seed(tester);

    await buildService(db).recordPayment(
      ahmedDebtId,
      PaymentDraft(amountMinor: 50000, paidAt: dateOnly(DateTime.now())),
    );
    await settle(tester);

    // Ahmed's page: 500 paid off his own record, 1,000 left.
    await openPerson(tester, first);
    expect(
      find.textContaining('1,000'),
      findsWidgets,
      reason: 'Ahmed sees the 500 paid off his own record',
    );
    await back(tester);

    // Everyone else still owes the full 1,500.
    for (final String name in <String>[second, third]) {
      await openPerson(tester, name);
      expect(
        find.textContaining('1,500'),
        findsWidgets,
        reason: '$name still owes the full amount',
      );
      await back(tester);
    }

    expect(
      await db.debtsDao.getPaymentsForDebt(ahmedDebtId),
      hasLength(1),
      reason: 'a payment belongs to the record, not to a person on it',
    );
    expect(await db.debtsDao.getPaymentsForDebt(khalidDebtId), isEmpty);
    expect(await db.debtsDao.getPaymentsForDebt(maryamDebtId), isEmpty);
  });

  testWidgets('a full payment settles only its own record',
      (WidgetTester tester) async {
    await seed(tester);

    await buildService(db).recordPayment(
      ahmedDebtId,
      PaymentDraft(amountMinor: 150000, paidAt: dateOnly(DateTime.now())),
    );
    await settle(tester);

    final LedgerService service = buildService(db);
    expect((await service.debts.getById(ahmedDebtId))!.closedAt, isNotNull);
    expect((await service.debts.getById(khalidDebtId))!.closedAt, isNull);
    expect((await service.debts.getById(maryamDebtId))!.closedAt, isNull);

    // The others still see their open 1,500.
    for (final String name in <String>[second, third]) {
      await openPerson(tester, name);
      expect(find.textContaining('1,500'), findsWidgets);
      await back(tester);
    }
  });

  testWidgets('editing from one participant’s page edits only that record',
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
    expect(find.widgetWithText(InputChip, second), findsNothing);
    expect(find.widgetWithText(InputChip, third), findsNothing);

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

    // Still three records, same ids, new amount on Ahmed's only.
    expect(await db.debtsDao.getAll(), hasLength(3));
    final LedgerService service = buildService(db);
    expect((await service.debts.getById(ahmedDebtId))!.principalMinor, 200000);
    expect((await service.debts.getById(khalidDebtId))!.principalMinor, 150000);
    expect((await service.debts.getById(maryamDebtId))!.principalMinor, 150000);

    await openPerson(tester, first);
    expect(find.textContaining('2,000'), findsWidgets);
    await back(tester);

    for (final String name in <String>[second, third]) {
      await openPerson(tester, name);
      expect(find.textContaining('1,500'), findsWidgets);
      expect(find.textContaining('2,000'), findsNothing);
      await back(tester);
    }
  });

  testWidgets('removing one person leaves everyone else’s record alone',
      (WidgetTester tester) async {
    await seed(tester);

    await buildService(db).deletePerson(khalid.id);
    await settle(tester);

    // The rows stay: Khalid's keeps its money but names nobody, the rest are
    // untouched.
    expect(await db.debtsDao.getAll(), hasLength(3),
        reason: 'the records stay');
    expect(
      (await buildService(db).debts.getById(ahmedDebtId))!.personIds,
      <String>[ahmed.id],
    );
    expect(
      (await buildService(db).debts.getById(maryamDebtId))!.personIds,
      <String>[maryam.id],
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

    final LedgerService service = buildService(db);
    for (final Debt record in await service.debts.getAll()) {
      expect(record.personIds, hasLength(1));
    }
  });
}
