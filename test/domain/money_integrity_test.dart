import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/utils/money_input.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/amount_rules.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What Dhimmah refuses to store, and why.
///
/// A personal ledger is only worth keeping if a number on screen is true. Two
/// classes of write used to be accepted that made a number untrue:
///
/// * A zero or negative amount. A negative *payment* is the worse of the two —
///   it is subtracted from what was paid, so the remaining balance *grows*, and
///   the user is shown a debt larger than the one they started with.
/// * A currency correction that left the payments behind. A payment is recorded
///   in the debt's currency and inherits it, so retagging the debt from rupees
///   to dollars while its payments stayed rupees meant rupee minor units were
///   summed and reported as dollars.
///
/// The service is the only writer, so the rule lives there and these tests call
/// it the way a screen would.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  final DateTime today = dateOnly(DateTime.now());

  /// A person every record in this file is with.
  ///
  /// A debt has to name somebody, so these tests — which are about amounts —
  /// create one person and reuse it rather than testing that rule again.
  late String personId;
  setUp(() async {
    personId = (await buildService(db).createPerson(
      const PersonDraft(name: 'أحمد'),
    ))
        .id;
  });

  Future<Debt> aDebt(
    LedgerService service, {
    int principalMinor = 100000,
    AppCurrency currency = AppCurrency.inr,
  }) =>
      service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[personId],
          title: 'قرض سيارة',
          principalMinor: principalMinor,
          currency: currency,
          issuedAt: today,
        ),
      );

  group('an amount that cannot be money is refused', () {
    test('a debt principal of zero, negative, or absurd is rejected', () async {
      final LedgerService service = buildService(db);

      for (final int bad in <int>[0, -1, -50000, AmountRules.maxMinor + 1]) {
        await expectLater(
          () => service.createDebt(
            DebtDraft(
              direction: DebtDirection.iOwe,
              personIds: <String>[personId],
              title: 'bad',
              principalMinor: bad,
              currency: AppCurrency.inr,
              issuedAt: today,
            ),
          ),
          throwsA(isA<InvalidAmountException>()),
          reason: 'a principal of $bad is not an amount of money',
        );
      }

      // The valid boundary is still accepted, ceiling included.
      expect(await aDebt(service), isA<Debt>());
      expect(
        await aDebt(service, principalMinor: AmountRules.maxMinor),
        isA<Debt>(),
      );
    });

    test('a payment of zero or negative is rejected', () async {
      final LedgerService service = buildService(db);
      final Debt debt = await aDebt(service);

      for (final int bad in <int>[0, -1, -10000]) {
        await expectLater(
          () => service.recordPayment(
            debt.id,
            PaymentDraft(amountMinor: bad, paidAt: today),
          ),
          throwsA(isA<InvalidAmountException>()),
          reason: 'a payment of $bad is not an amount of money',
        );
      }
    });

    test('an editing pass cannot slip an invalid amount past the guard', () async {
      final LedgerService service = buildService(db);
      final Debt debt = await aDebt(service);
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 30000, paidAt: today),
      );

      await expectLater(
        () => service.updateDebt(
          debt.id,
          DebtDraft(
            direction: DebtDirection.iOwe,
            personIds: <String>[personId],
            title: 'قرض سيارة',
            principalMinor: -1,
            currency: AppCurrency.inr,
            issuedAt: today,
          ),
        ),
        throwsA(isA<InvalidAmountException>()),
      );
      await expectLater(
        () => service.updatePayment(
          payment.id,
          PaymentDraft(amountMinor: 0, paidAt: today),
        ),
        throwsA(isA<InvalidAmountException>()),
      );
    });

    test('an obligation amount of zero or negative is rejected', () async {
      final LedgerService service = buildService(db);

      for (final int bad in <int>[0, -1000]) {
        await expectLater(
          () => service.createObligation(
            ObligationDraft(
              name: 'فاتورة الإنترنت',
              category: ObligationCategory.telecom,
              amountMinor: bad,
              currency: AppCurrency.inr,
              frequency: RecurrenceFrequency.monthly,
              startAt: today,
              dayOfMonth: 5,
            ),
          ),
          throwsA(isA<InvalidAmountException>()),
        );
      }
    });

    test('the form and the service ask the same rule', () {
      // One source of truth: the message a user sees and the write the database
      // accepts can never disagree about what a valid amount is.
      for (final int value in <int>[
        -1,
        0,
        1,
        AmountRules.maxMinor,
        AmountRules.maxMinor + 1,
      ]) {
        expect(
          isAmountWithinRange(value),
          AmountRules.isValid(value),
          reason: 'the input helper disagrees with the domain rule at $value',
        );
      }
    });
  });

  group('a currency correction carries the payments with it', () {
    test('payments are retagged so units are never mixed', () async {
      final LedgerService service = buildService(db);
      final Debt debt = await aDebt(service); // INR
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 30000, paidAt: today),
      );

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[personId],
          title: 'قرض سيارة',
          principalMinor: 100000,
          currency: AppCurrency.usd,
          issuedAt: today,
        ),
      );

      final Debt updated = (await service.debts.getById(debt.id))!;
      final List<Payment> payments = await service.payments.forDebt(debt.id);

      expect(updated.currency, AppCurrency.usd);
      expect(
        payments.map((Payment p) => p.currency).toSet(),
        <AppCurrency>{AppCurrency.usd},
        reason: 'a payment left in the old currency would be summed as though '
            'its minor units were the new one',
      );
      // The amount itself is not converted — there is no exchange rate, and
      // inventing one would be worse than a number the user typed.
      expect(DebtCalculator.totalPaid(payments), 30000);
    });

    test('a payment recorded after the edit is already in the new currency', () async {
      final LedgerService service = buildService(db);
      final Debt debt = await aDebt(service, currency: AppCurrency.sar);

      // The draft has no currency: it is the debt's, by construction.
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 20000, paidAt: today),
      );

      expect(payment.currency, AppCurrency.sar);
    });

    test('an unchanged currency leaves payments untouched', () async {
      final LedgerService service = buildService(db);
      final Debt debt = await aDebt(service);
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 30000, paidAt: today),
      );

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[personId],
          title: 'قرض سيارة',
          principalMinor: 200000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      final Payment after = (await service.payments.getById(payment.id))!;
      expect(after.currency, AppCurrency.inr);
      expect(after.amountMinor, 30000);
    });
  });
}
