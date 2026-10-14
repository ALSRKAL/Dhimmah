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
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Upgrading the app must not harm an existing ledger.
///
/// This file simulates a phone that recorded its data with the old build — one
/// shared row naming two people with a partial payment on it, plus an ordinary
/// single debt — and then opened it with the new code. It pins the promises a
/// Play update makes to that user:
///
/// * every row and every payment survives, with the same amounts;
/// * the ledger totals do not jump: the old row still counts once;
/// * new payments on the old row are refused without writing anything;
/// * the manual split loses no money: the payments before and after add up to
///   the same figure, and the single debt is untouched throughout.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;

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

  /// The old build's rows, written the way the old build wrote them.
  Future<({Debt shared, Debt single})> oldPhone() async {
    final Person ahmed =
        await service.createPerson(const PersonDraft(name: 'أحمد'));
    final Person ali = await service.createPerson(const PersonDraft(name: 'علي'));
    final Debt shared = await createLegacySharedDebt(
      service,
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id, ali.id],
        title: 'سلفة قديمة',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
    await recordLegacyPayment(
      service,
      shared,
      amountMinor: 50000,
      paidAt: today,
    );
    final List<Debt> single = await service.createDebts(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id],
        title: 'سلفة مفردة',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
    return (shared: shared, single: single.single);
  }

  Future<List<DebtView>> views() =>
      queries.watchDebtViews(dueSoonWindowDays: 7, asOf: today).first;

  test('the old rows open with the same amounts', () async {
    final ({Debt shared, Debt single}) phone = await oldPhone();

    expect(await db.debtsDao.getAll(), hasLength(2));
    final Debt shared = (await service.debts.getById(phone.shared.id))!;
    expect(shared.personIds, hasLength(2));
    expect(shared.principalMinor, 150000);
    final List<Payment> history =
        await service.payments.forDebt(phone.shared.id);
    expect(history, hasLength(1));
    expect(history.single.amountMinor, 50000);

    final List<DebtView> all = await views();
    expect(all, hasLength(2));
    expect(
      all.firstWhere((DebtView v) => v.debt.id == phone.shared.id)
          .remainingMinor,
      100000,
    );
  });

  test('the totals do not jump after the update', () async {
    await oldPhone();

    int ledgerRemaining = 0;
    for (final DebtView v in await views()) {
      ledgerRemaining += v.remainingMinor;
    }
    // The old row still counts once (100,000 left of 150,000) beside the
    // single 100,000: 200,000 — not a figure multiplied by the headcount.
    expect(ledgerRemaining, 200000);
  });

  test('new payments on the old row are refused and write nothing', () async {
    final ({Debt shared, Debt single}) phone = await oldPhone();
    final int paymentsBefore = (await service.payments.getAll()).length;

    await expectLater(
      () => service.recordPayment(
        phone.shared.id,
        PaymentDraft(amountMinor: 100000, paidAt: today),
      ),
      throwsA(isA<SharedDebtPaymentBlockedException>()),
    );

    expect((await service.payments.getAll()).length, paymentsBefore);
    expect(
      (await views())
          .firstWhere((DebtView v) => v.debt.id == phone.shared.id)
          .remainingMinor,
      100000,
    );
  });

  test('the manual split loses no money and touches nothing else', () async {
    final ({Debt shared, Debt single}) phone = await oldPhone();
    Future<int> paidSum() async => (await service.payments.getAll())
        .fold<int>(0, (int sum, Payment p) => sum + p.amountMinor);
    final int paidBefore = await paidSum();

    final List<Debt> split = await service.splitSharedDebt(phone.shared.id);

    // No payment lost, none invented, none moved off its row.
    expect(await paidSum(), paidBefore);
    expect(await service.payments.forDebt(phone.shared.id), hasLength(1));
    expect(split, hasLength(2));
    expect(split.first.id, phone.shared.id);
    for (final Debt single in split.skip(1)) {
      expect(await service.payments.forDebt(single.id), isEmpty);
    }

    // The single debt never flinched: same id, same amount, still open.
    final Debt untouched = (await service.debts.getById(phone.single.id))!;
    expect(untouched.principalMinor, 100000);
    expect(
      (await views())
          .firstWhere((DebtView v) => v.debt.id == phone.single.id)
          .remainingMinor,
      100000,
    );
  });

  test('the backup format did not move under the old files', () {
    expect(BackupFormat.currentFormatVersion, 1);
  });
}
