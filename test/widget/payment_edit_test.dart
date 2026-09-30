import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/debts/payment_sheet.dart' as sheet;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Correcting a payment corrects that payment, and the amount on screen is the
/// amount that is saved.
///
/// Both were broken. "Edit" on a payment opened the sheet for a *new* payment,
/// so saving a correction added a second payment beside the wrong one; and
/// "pay in full" changed the number the sheet would save without changing the
/// number in the field, so a user who had typed 2,500 saw 2,500 and saved the
/// whole balance.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String personName = 'محمد أحمد عبدالرحمن';
  const String debtTitle = 'قرض سيارة';

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// A 10,000 debt with [paidMinor] already paid, and the app on the ledger.
  Future<String> seed(WidgetTester tester, {required int paidMinor}) async {
    final LedgerService service = buildService(db);
    final DateTime today = dateOnly(DateTime.now());
    final Person person = await service.createPerson(
      const PersonDraft(name: personName),
    );
    final Debt debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: debtTitle,
        principalMinor: 1000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -10),
      ),
    );
    if (paidMinor > 0) {
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: paidMinor, paidAt: addDays(today, -2)),
      );
    }
    await pumpDhimmah(tester, db: db);
    return debt.id;
  }

  Future<void> openDebt(WidgetTester tester) async {
    await tester.tap(find.text('السجل').last);
    await settle(tester);
    await tester.tap(find.textContaining(debtTitle).first);
    await settle(tester);
  }

  /// The payment row's actions → edit.
  Future<void> openCorrection(WidgetTester tester) async {
    // The history sits below the fold on a test-sized screen, under the bar
    // that holds the record button.
    await tester.ensureVisible(find.byType(sheet.PaymentRow).first);
    await settle(tester);
    await tester.tap(find.byType(sheet.PaymentRow).first);
    await settle(tester);
    await tester.tap(find.text('تعديل').last);
    await settle(tester);
  }

  Finder amountInput() => find.descendant(
        of: find.byType(AmountField),
        matching: find.byType(TextFormField),
      );

  String amountText(WidgetTester tester) =>
      tester.widget<TextFormField>(amountInput()).controller!.text;

  /// Every payment stored against the debt, smallest first.
  Future<List<int>> storedAmounts(String debtId) async {
    final List<int> amounts = <int>[
      for (final PaymentRow row in await db.debtsDao.getPaymentsForDebt(debtId))
        row.amountMinor,
    ];
    return amounts..sort();
  }

  testWidgets('editing a payment corrects it instead of adding another',
      (WidgetTester tester) async {
    final String debtId = await seed(tester, paidMinor: 500000);
    await openDebt(tester);
    await openCorrection(tester);

    // The sheet is the correction, opened on the payment being corrected.
    expect(find.text('تعديل الدفعة'), findsOneWidget);
    expect(amountText(tester), '5000.00');

    await tester.enterText(amountInput(), '2500');
    await settle(tester);
    await tester.tap(find.text('حفظ الدفعة'));
    await settle(tester);

    expect(await storedAmounts(debtId), <int>[250000],
        reason: 'one payment, now of 2,500 — not 5,000 and 2,500');
    // And the history the user is looking at says the same.
    expect(find.byType(sheet.PaymentRow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(sheet.PaymentRow),
        matching: find.textContaining('2,500'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a correction of a settled debt is not called an overpayment',
      (WidgetTester tester) async {
    final String debtId = await seed(tester, paidMinor: 1000000);
    await openDebt(tester);
    await openCorrection(tester);

    // The full 10,000 is what this payment covers; keeping it is not "more
    // than what remains".
    expect(find.textContaining('المبلغ أكبر من المتبقي'), findsNothing);
    expect(amountText(tester), '10000.00');

    await tester.enterText(amountInput(), '9000');
    await settle(tester);
    await tester.tap(find.text('حفظ الدفعة'));
    await settle(tester);

    expect(await storedAmounts(debtId), <int>[900000]);
    final DebtRow row = (await db.debtsDao.getById(debtId))!;
    expect(row.closedAt, isNull, reason: '1,000 is open again');
  });

  testWidgets('pay in full writes the amount it will save into the field',
      (WidgetTester tester) async {
    final String debtId = await seed(tester, paidMinor: 250000);
    await openDebt(tester);

    // The bottom button, not a payment row: both read «تسجيل دفعة».
    await tester.tap(
      find.ancestor(
        of: find.text('تسجيل دفعة'),
        matching: find.byWidgetPredicate((Widget w) => w is FilledButton),
      ),
    );
    await settle(tester);
    await tester.enterText(amountInput(), '1000');
    await settle(tester);

    await tester.tap(find.text('سداد كامل المتبقي'));
    await settle(tester);

    // What the field says is what is saved.
    expect(amountText(tester), '7500.00');
    await tester.tap(find.text('حفظ الدفعة'));
    await settle(tester);

    expect(await storedAmounts(debtId), <int>[250000, 750000]);
    final DebtRow row = (await db.debtsDao.getById(debtId))!;
    expect(row.closedAt, isNotNull);
  });
}
