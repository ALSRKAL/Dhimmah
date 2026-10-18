import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/share/share_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// What leaves the app when a record is shared.
///
/// The text is the one thing a user sends to someone who has none of the app's
/// context — no colour, no screen, no balance above it — so the numbers have to
/// be stated rather than implied, and the currency has to travel with every
/// amount. None of this is covered by the screen that offers the button, because
/// the screen hands the string straight to the system share sheet.
void main() {
  // The summary prints a date, and `DateFormat` refuses an uninitialised
  // locale: the app does this in `main`, so a test of the text has to as well.
  setUpAll(() => initializeDateFormatting('ar'));

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  final AppFormatting formatting = AppFormatting(
    language: AppLanguage.arabic,
    numerals: NumeralsStyle.latin,
    defaultCurrency: AppCurrency.inr,
    localizations: l10n,
  );
  final ShareService service = ShareService(
    localizations: l10n,
    formatting: formatting,
  );

  final DateTime today = dateOnly(DateTime(2026, 9, 15));

  DebtView view({
    required int principalMinor,
    required int paidMinor,
    DateTime? dueAt,
    DebtDirection direction = DebtDirection.iOwe,
    List<Person> participants = const <Person>[],
    String title = 'كهرباء',
  }) =>
      DebtView(
        debt: Debt(
          id: 'd1',
          personIds: <String>[
            for (final Person person in participants) person.id,
          ],
          direction: direction,
          title: title,
          principalMinor: principalMinor,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -10),
          dueAt: dueAt,
          createdAt: addDays(today, -10),
          updatedAt: addDays(today, -10),
        ),
        paidMinor: paidMinor,
        remainingMinor: principalMinor - paidMinor,
        status: DebtLifecycleStatus.active,
        paymentCount: paidMinor > 0 ? 1 : 0,
        participants: participants,
      );

  Person person(String name) => Person(
        id: 'p1',
        name: name,
        colorIndex: 0,
        createdAt: today,
        updatedAt: today,
      );

  test('the summary states every amount with its currency', () {
    final String text = service.debtSummary(
      view(
        principalMinor: 250000,
        paidMinor: 50000,
        dueAt: addDays(today, 5),
        participants: <Person>[person('أحمد')],
      ),
    );

    expect(text, contains('أحمد'));
    expect(text, contains('INR'), reason: 'the receiver has no other context');
    expect(text, contains('2,500'), reason: 'the total');
    expect(text, contains('500'), reason: 'what has been paid');
    expect(text, contains('2,000'), reason: 'what is left, and the reason it is sent');
    expect(text, contains(l10n.shareFooter));
    expect(text, contains(l10n.shareLineDirectionIOwe));
  });

  test('a direction that is the other way says so', () {
    final String text = service.debtSummary(
      view(
        principalMinor: 100000,
        paidMinor: 0,
        direction: DebtDirection.owedToMe,
        participants: <Person>[person('خالد')],
      ),
    );
    expect(text, contains(l10n.shareLineDirectionOwedToMe));
    expect(text, isNot(contains(l10n.shareLineDirectionIOwe)));
  });

  test('a record with no due date leaves the line out rather than inventing one',
      () {
    final String withDue = service.debtSummary(
      view(
        principalMinor: 100000,
        paidMinor: 0,
        dueAt: addDays(today, 5),
        participants: <Person>[person('أحمد')],
      ),
    );
    final String withoutDue = service.debtSummary(
      view(
        principalMinor: 100000,
        paidMinor: 0,
        participants: <Person>[person('أحمد')],
      ),
    );
    expect(withDue, contains('موعد الاستحقاق'));
    expect(
      withoutDue,
      isNot(contains('موعد الاستحقاق')),
      reason: 'a record with no date says nothing about a date',
    );
    expect(withoutDue.length, lessThan(withDue.length));
    expect(withoutDue, contains('المتبقي'));
  });

  test('a record with nobody on it shares without a name line', () {
    // A record from before people were required, with no title either: the
    // summary must not open on a blank line.
    final String text = service.debtSummary(
      view(principalMinor: 100000, paidMinor: 0, title: ''),
    );
    expect(text.startsWith(l10n.shareLineDirectionIOwe), isTrue,
        reason: 'the direction leads when there is no name to lead with');
    expect(text, isNot(startsWith('\n')));

    // With a title but no people, the title is what the record is called.
    final String titled = service.debtSummary(
      view(principalMinor: 100000, paidMinor: 0),
    );
    expect(titled, contains('كهرباء'));
  });

  test('a payment summary carries the note when there is one', () {
    final DebtView target = view(
      principalMinor: 250000,
      paidMinor: 50000,
      participants: <Person>[person('أحمد')],
    );
    final Payment payment = Payment(
      id: 'pay1',
      debtId: 'd1',
      personId: 'p1',
      amountMinor: 50000,
      currency: AppCurrency.inr,
      paidAt: today,
      note: 'حوالة',
      createdAt: today,
    );

    final String text = service.paymentSummary(view: target, payment: payment);
    expect(text, contains('أحمد'));
    expect(text, contains('500'));
    expect(text, contains('حوالة'));
    expect(text, contains('2,000'), reason: 'what is still owed after it');

    final String withoutNote = service.paymentSummary(
      view: target,
      payment: payment.copyWith(note: '   '),
    );
    expect(withoutNote, isNot(contains('حوالة')));
    expect(
      withoutNote,
      isNot(contains('\n\n\n')),
      reason: 'a blank note leaves no empty paragraph behind',
    );
  });
}
