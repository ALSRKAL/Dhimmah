import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Which currencies the budget card is allowed to offer.
///
/// The list is what the chip strip is built from, and each chip is a promise
/// that something is behind it. The card's rule is that only currencies that go
/// *into* the budget qualify, and the two sides of the budget reach that rule by
/// different roads:
///
/// * **Commitments** are filtered by the query that feeds them —
///   `obligationInstancesProvider` calls `watchObligationInstances` without
///   `includeArchived`, which defaults to false — so an archived commitment
///   never arrives here and needs no guard.
/// * **Income** is *not*: `incomeListProvider` deliberately carries archived
///   records, because the management sheet has to offer one back when it was set
///   aside by mistake. So this file is where archiving an income has to stop
///   counting, and the archiving it does is real — through the service, into the
///   database, read back out.
void main() {
  late AppDatabase db;
  late LedgerService service;

  setUp(() {
    db = AppDatabase.memory();
    service = buildService(db);
  });
  tearDown(() async => db.close());

  ProviderContainer build() {
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// The list as the card reads it, once the streams have answered.
  ///
  /// Both of its sources are stream providers, so a bare read would judge a list
  /// that is empty only because it is early. The subscription is opened first so
  /// the provider is alive across the two waits rather than rebuilt by them.
  Future<List<AppCurrency>> offered(ProviderContainer container) async {
    final ProviderSubscription<List<AppCurrency>> subscription =
        container.listen(budgetCurrenciesProvider, (_, _) {});
    await container.read(incomeListProvider.future);
    await container.read(obligationInstancesProvider.future);
    final List<AppCurrency> currencies = subscription.read();
    subscription.close();
    return currencies;
  }

  Future<Income> addIncome(AppCurrency currency) => service.createIncome(
        IncomeDraft(
          name: 'دخل',
          amountMinor: 500000,
          currency: currency,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(2026, 6),
        ),
      );

  Future<void> addCommitment(AppCurrency currency) async {
    await service.createObligation(
      ObligationDraft(
        name: 'إيجار',
        category: ObligationCategory.housing,
        amountMinor: 400000,
        currency: currency,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 6),
      ),
    );
    await service.ensureOccurrences();
  }

  test('a live income brings its currency to the card', () async {
    await addIncome(AppCurrency.usd);

    final List<AppCurrency> list = await offered(build());

    expect(list, contains(AppCurrency.usd));
    expect(list, contains(AppCurrency.inr),
        reason: 'the default is always offered, even with nothing recorded');
  });

  test('a currency left with only an archived income is not offered', () async {
    final Income usd = await addIncome(AppCurrency.usd);
    await service.setIncomeArchived(usd.id, true);

    final List<AppCurrency> list = await offered(build());

    // The chip would open a card with no figures on it, because
    // `watchMonthlyBudget` reads income with `includeArchived: false` — this
    // source is worth nothing in every month, not just the current one.
    expect(list, isNot(contains(AppCurrency.usd)));
    expect(list, <AppCurrency>[AppCurrency.inr]);
  });

  test('restoring the income offers its currency again', () async {
    final Income usd = await addIncome(AppCurrency.usd);
    await service.setIncomeArchived(usd.id, true);
    await service.setIncomeArchived(usd.id, false);

    expect(await offered(build()), contains(AppCurrency.usd));
  });

  test('archiving an income does not take away a currency the '
      'commitments still use', () async {
    final Income usd = await addIncome(AppCurrency.usd);
    await addCommitment(AppCurrency.usd);
    await service.setIncomeArchived(usd.id, true);

    final List<AppCurrency> list = await offered(build());

    // The guard is on the income loop alone. A filter applied to the list as a
    // whole would drop the currency a commitment is still spending in, and the
    // card would show that currency's figures under no chip at all.
    expect(list, contains(AppCurrency.usd));
  });

  test('a currency with a commitment in it is offered without any income',
      () async {
    await addCommitment(AppCurrency.sar);

    final List<AppCurrency> list = await offered(build());

    expect(list, contains(AppCurrency.sar));
  });
}
