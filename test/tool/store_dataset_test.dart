import 'dart:ui' show Locale;

import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/database/daos/debts_dao.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/store_demo_seed.dart';

/// The store dataset, held to the contract the listing is built on.
///
/// The screenshots are photographs of this ledger, so this is where the claims
/// the listing makes about its own numbers are checked: the flagship record
/// reads 1,500 borrowed, 500 repaid and 1,000 still owed in the currency the
/// listing is photographed in; one record belongs to two people and is listed
/// on both their pages; the month has a paid period and an open one; and no
/// amount anywhere renders as rupees.
///
///   flutter test test/tool/store_dataset_test.dart
void main() {
  /// Seeds a fresh in-memory ledger and asserts the whole contract.
  ///
  /// [principal], [paid] and [remaining] are the exact strings the screens will
  /// draw for the flagship record — written out rather than computed, so a
  /// change to either the dataset or the money formatter has to be looked at.
  Future<void> expectsListing({
    required AppLanguage language,
    required AppCurrency currency,
    required int principalMinor,
    required int paidMinor,
    required String principal,
    required String paid,
    required String remaining,
  }) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);
    await seedStoreDemoData(db, language: language, currency: currency);
    final StoreCopy copy = StoreCopy.forLanguage(language);

    // --- The people ---------------------------------------------------------
    expect(await db.peopleDao.getAll(), hasLength(5),
        reason: 'the listing shows a directory of five people');

    // --- The debts ----------------------------------------------------------
    final List<DebtRow> debts = await db.debtsDao.getAll();
    expect(debts, hasLength(8), reason: 'eight records, varied in every way a '
        'record can vary: overdue, settled, undated, two-person');
    expect(
      debts.every((DebtRow debt) => debt.currencyCode == currency.code),
      isTrue,
      reason: 'every record is written in the ledger’s own currency',
    );

    final Map<String, DebtPaymentTotals> totals = <String, DebtPaymentTotals>{
      for (final DebtPaymentTotals total in await db.debtsDao.paymentTotalsByDebt())
        total.debtId: total,
    };

    final DebtRow flagship =
        debts.singleWhere((DebtRow debt) => debt.title == copy.advanceTitle);
    expect(flagship.principalMinor, principalMinor);
    expect(totals[flagship.id]?.paidMinor, paidMinor);
    expect(principalMinor, paidMinor * 3,
        reason: 'the story is 1,500 borrowed, 500 repaid, 1,000 left');

    final AppFormatting formatting = AppFormatting(
      language: language,
      numerals: NumeralsStyle.latin,
      defaultCurrency: currency,
      localizations: lookupAppLocalizations(Locale(language.code)),
    );
    String draw(int minor) => _plain(formatting.amount(Money(minor, currency)));
    expect(draw(flagship.principalMinor), principal);
    expect(draw(totals[flagship.id]!.paidMinor), paid);
    expect(draw(flagship.principalMinor - totals[flagship.id]!.paidMinor), remaining);

    // --- One record, two people --------------------------------------------
    final DebtRow shared =
        debts.singleWhere((DebtRow debt) => debt.title == copy.sharedExpensesTitle);
    final List<String> participants = await db.debtsDao.participantsFor(shared.id);
    expect(participants, hasLength(2));
    // Each of the two reads it as an ordinary record of their own, and nobody
    // else's page lists it.
    final List<String> everyone = (await db.peopleDao.getAll())
        .map((PersonRow person) => person.id)
        .toList();
    for (final String personId in everyone) {
      final bool listed = (await db.debtsDao.getForPerson(personId))
          .any((DebtRow debt) => debt.id == shared.id);
      expect(listed, participants.contains(personId),
          reason: 'a record is on the page of each of its people and no one '
              'else’s');
    }

    // --- The recurring month ------------------------------------------------
    final List<ObligationRow> obligations = await db.obligationsDao.getAll();
    expect(obligations, hasLength(4));
    expect(
      obligations.every(
          (ObligationRow row) => row.frequency == RecurrenceFrequency.monthly),
      isTrue,
    );
    expect(obligations.every((ObligationRow row) => row.currencyCode == currency.code),
        isTrue);

    final ObligationRepositoryImpl repository = ObligationRepositoryImpl(db);
    int paidPeriods = 0;
    int openPeriods = 0;
    for (final ObligationRow row in obligations) {
      for (final ObligationOccurrence occurrence
          in await repository.occurrencesFor(row.id)) {
        occurrence.isPaid ? paidPeriods++ : openPeriods++;
      }
    }
    expect(paidPeriods, greaterThan(0),
        reason: 'a paid period gives the screen a history');
    expect(openPeriods, greaterThan(0),
        reason: 'an open period gives it something to do');

    // --- Reminders ----------------------------------------------------------
    expect(await db.remindersDao.getAll(), hasLength(3));
    expect(await db.remindersDao.getOpen(), isNotEmpty);

    // --- The money the listing shows ---------------------------------------
    final AppSettings settings = await SettingsRepositoryImpl(db).get();
    expect(settings.languagePreference, LanguagePreference.of(language));
    expect(settings.defaultCurrency, currency);

    final List<String> rendered = <String>[
      for (final DebtRow debt in debts)
        formatting.amount(Money(debt.principalMinor, currency)),
      for (final PaymentRow payment in await db.debtsDao.getAllPayments())
        formatting.amount(Money(payment.amountMinor, currency)),
      for (final ObligationRow row in obligations)
        formatting.amount(Money(row.amountMinor, currency)),
    ];
    expect(rendered, isNotEmpty);
    for (final String text in rendered) {
      for (final String banned in <String>['₹', 'INR', 'Indian Rupee']) {
        expect(text.contains(banned), isFalse,
            reason: 'the listing is never photographed with $banned in it, '
                'and "$text" carries it');
      }
    }
    expect(rendered.every((String text) => text.contains(currency.symbol)), isTrue,
        reason: 'every amount is drawn in the listing’s own currency');
  }

  test('the English listing is a dollar ledger', () async {
    await expectsListing(
      language: AppLanguage.english,
      currency: AppCurrency.usd,
      principalMinor: 150000,
      paidMinor: 50000,
      principal: r'$ 1,500',
      paid: r'$ 500',
      remaining: r'$ 1,000',
    );
  });

  test('the Arabic listing is a Yemeni riyal ledger', () async {
    await expectsListing(
      language: AppLanguage.arabic,
      currency: AppCurrency.yer,
      principalMinor: 37500000,
      paidMinor: 12500000,
      principal: '﷼ 375,000',
      paid: '﷼ 125,000',
      remaining: '﷼ 250,000',
    );
  });
}

/// An amount as a reader sees it: the bidi isolates and the non-breaking space
/// that keep it one unit on screen are not part of the number.
String _plain(String text) => text
    .replaceAll('\u2066', '')
    .replaceAll('\u2069', '')
    .replaceAll('\u00A0', ' ');
