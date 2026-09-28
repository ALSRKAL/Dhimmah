import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// A faster read is only an improvement if it reads the same numbers.
///
/// The ledger's per-debt paid total used to load every payment row and add it up
/// in Dart. It is now a `SUM … GROUP BY`, which took 20 ms where loading and
/// summing took 499 ms at 10,000 payments — both in a debug build, which is where
/// every timing in this project comes from, and therefore pessimistic by roughly
/// an order of magnitude in absolute terms.
///
/// That is exactly the kind of change that silently moves a number, so the SQL
/// total is pinned against the slow path it replaced: no payments, one, several,
/// an overpayment, and payments left in a currency by a correction.
///
/// A second change — windowing the monthly report's payment read — was tried and
/// reverted, because the measurement showed no benefit and the correctness
/// argument turned out to depend on whether a debt had been issued yet.
void main() {
  late AppDatabase db;
  late LedgerQueries queries;
  late LedgerService service;

  setUp(() {
    db = AppDatabase.memory();
    service = buildService(db);
    queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
  });
  tearDown(() async => db.close());

  final DateTime today = dateOnly(DateTime.now());

  /// A person every record in this file is with: a debt has to name somebody,
  /// and these tests are about how the sums are arrived at.
  late String personId;
  setUp(() async {
    personId = (await service.createPerson(const PersonDraft(name: 'أحمد'))).id;
  });

  DebtDraft draft(String title, int principal, {bool usd = false}) => DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[personId],
        title: title,
        principalMinor: principal,
        currency: usd ? AppCurrency.usd : AppCurrency.inr,
        issuedAt: dateOnly(DateTime.now()),
        dueAt: addDays(dateOnly(DateTime.now()), 4),
      );

  group('the SQL sum equals summing in Dart', () {
    test('for a debt with no payments at all', () async {
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[personId],
          title: 'بدون دفعات',
          principalMinor: 500000,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: addDays(today, 3),
        ),
      );
      await expectSameViews(queries, service, today);
    });

    test('for partial payments, a settled debt, and an overpayment', () async {
      final Debt partial = await service.createDebt(draft('جزئي', 1000000));
      await service.recordPayment(
        partial.id,
        PaymentDraft(amountMinor: 250000, paidAt: addDays(today, -5)),
      );

      final Debt settled = await service.createDebt(draft('مسدَّد', 300000));
      await service.recordPayment(
        settled.id,
        PaymentDraft(amountMinor: 300000, paidAt: addDays(today, -2)),
      );

      // Overpaying settles and must not produce a negative total or a negative
      // remaining.
      final Debt overpaid = await service.createDebt(draft('زائد', 100000));
      await service.recordPayment(
        overpaid.id,
        PaymentDraft(amountMinor: 250000, paidAt: addDays(today, -1)),
      );

      // Several payments on one debt, so the aggregate has to sum rather than
      // take the last row.
      final Debt many = await service.createDebt(draft('عدة دفعات', 900000));
      for (final int i in <int>[1, 2, 3, 4]) {
        await service.recordPayment(
          many.id,
          PaymentDraft(amountMinor: 100000, paidAt: addDays(today, -i)),
        );
      }

      await expectSameViews(queries, service, today);
    });

    test('with payments spread far apart in time', () async {
      final Debt debt = await service.createDebt(draft('قديم', 1000000));
      for (final int days in <int>[400, 200, 100, 30, 1]) {
        await service.recordPayment(
          debt.id,
          PaymentDraft(amountMinor: 50000, paidAt: addDays(today, -days)),
        );
      }
      await expectSameViews(queries, service, today);
    });

    test('for a record three people share', () async {
      final Person ali = await service.createPerson(const PersonDraft(name: 'علي'));
      final Person mohammed =
          await service.createPerson(const PersonDraft(name: 'محمد'));
      final Debt shared = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[personId, ali.id, mohammed.id],
          title: 'عشاء',
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      await service.recordPayment(
        shared.id,
        PaymentDraft(amountMinor: 50000, paidAt: addDays(today, -1)),
      );

      await expectSameViews(queries, service, today);

      // One record, three links, one amount.
      final List<DebtView> views = <DebtView>[];
      await for (final List<DebtView> batch in queries.watchDebtViews(
        dueSoonWindowDays: 7,
        asOf: today,
      )) {
        views.addAll(batch);
        break;
      }
      expect(views, hasLength(1));
      expect(views.single.participants, hasLength(3));
      expect(views.single.remainingMinor, 100000);
    });

    test(
      'with payments in other currencies left over from a correction',
      () async {
        final Debt debt = await service.createDebt(draft('عملة', 400000));
        await service.recordPayment(
          debt.id,
          PaymentDraft(amountMinor: 100000, paidAt: addDays(today, -3)),
        );
        // A currency correction retags the payments; the totals must follow.
        await service.updateDebt(debt.id, draft('عملة', 400000, usd: true));
        await service.recordPayment(
          debt.id,
          PaymentDraft(amountMinor: 150000, paidAt: addDays(today, -1)),
        );
        await expectSameViews(queries, service, today);
      },
    );
  });

}

Future<void> expectSameViews(
  LedgerQueries queries,
  LedgerService service,
  DateTime today,
) async {
  final List<DebtView> fromSql = <DebtView>[];
  await for (final List<DebtView> batch in queries.watchDebtViews(
    dueSoonWindowDays: 7,
    asOf: today,
  )) {
    fromSql
      ..clear()
      ..addAll(batch);
    break;
  }

  final List<DebtView> fromRows = <DebtView>[];
  final Map<String, Person> peopleById = <String, Person>{
    for (final Person person in await service.people.getAll()) person.id: person,
  };
  for (final Debt debt in await service.debts.getAll()) {
    fromRows.add(
      DebtCalculator.buildView(
        debt: debt,
        payments: await service.payments.forDebt(debt.id),
        // Resolved the same way the ledger read resolves them, so the two paths
        // are compared on the whole view and not just on its arithmetic.
        participants: <Person>[
          for (final String id in debt.personIds)
            if (peopleById[id] != null) peopleById[id]!,
        ],
        asOf: today,
        dueSoonWindowDays: 7,
      ),
    );
  }

  expect(fromSql.length, fromRows.length);
  for (int i = 0; i < fromSql.length; i++) {
    final DebtView a = fromSql[i];
    final DebtView b = fromRows[i];
    expect(a.debt.id, b.debt.id);
    expect(
      a.paidMinor,
      b.paidMinor,
      reason: 'paid differs for ${a.debt.title}',
    );
    expect(
      a.remainingMinor,
      b.remainingMinor,
      reason: 'remaining differs for ${a.debt.title}',
    );
    expect(
      a.paymentCount,
      b.paymentCount,
      reason: 'count differs for ${a.debt.title}',
    );
    expect(
      a.lastPaymentAt,
      b.lastPaymentAt,
      reason: 'last payment date differs for ${a.debt.title}',
    );
    expect(a.status, b.status, reason: 'status differs for ${a.debt.title}');
    expect(a.isSettled, b.isSettled);
    expect(a.isPartiallyPaid, b.isPartiallyPaid);
    // The people are part of the view: a ledger read and a per-debt read have to
    // agree on who a record is with, in the same order.
    expect(
      a.participants.map((Person p) => p.id),
      b.participants.map((Person p) => p.id),
      reason: 'participants differ for ${a.debt.title}',
    );
  }
}
