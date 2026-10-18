import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// A second tap while the first write is still in flight.
///
/// Both sheets disable their save button while `busy`, and both of them rely on
/// a rebuild to do it: the flag is set inside the handler, and the button only
/// learns about it on the next frame. Two taps dispatched before that frame —
/// which is what a doubly-delivered touch event, an accessibility auto-click, or
/// simply a test does — reach the *old* widget and run the handler twice, and
/// `recordPersonPayment` and `createIncome` are not idempotent: the second run
/// writes a second record.
///
/// The fix is the same in both places — the handler checks the flag itself, so
/// the guard does not depend on a frame having been drawn — and these are the
/// tests that hold it there.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late Person ahmed;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    db = AppDatabase.memory();
    service = buildService(db);
    ahmed = await service.createPerson(const PersonDraft(name: 'أحمد'));
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> openLedger(WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
  }

  group('the income form', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.text('التزامات').last);
      await settle(tester);
      // The budget card's own add button opens the sheet…
      await tester.tap(find.text('إضافة دخل').first);
      await settle(tester);
      // …and the sheet's is the one drawn on top of it.
      await tester.tap(find.text('إضافة دخل').last);
      await settle(tester);
    }

    testWidgets('a fast double tap on save records one income, not two',
        (WidgetTester tester) async {
      await openLedger(tester);
      await openForm(tester);

      await tester.enterText(find.byType(AppTextField).first, 'راتب');
      await tester.enterText(find.byType(AmountField), '3000');
      await tester.pump();

      // No pump between the two: the button was never rebuilt with `busy` set,
      // so nothing but the handler itself can refuse the second tap.
      await tester.tap(find.text('حفظ'));
      await tester.tap(find.text('حفظ'));
      await settle(tester);

      expect(
        await service.incomes.getAll(includeArchived: true),
        hasLength(1),
        reason: 'a double tap is one intention and must be one record',
      );
    });

    testWidgets('one tap still records the income', (WidgetTester tester) async {
      await openLedger(tester);
      await openForm(tester);

      await tester.enterText(find.byType(AppTextField).first, 'راتب');
      await tester.enterText(find.byType(AmountField), '3000');
      await tester.pump();

      await tester.tap(find.text('حفظ'));
      await settle(tester);

      final List<Income> written = await service.incomes.getAll();
      expect(written, hasLength(1));
      expect(written.single.name, 'راتب');
      expect(written.single.amountMinor, 300000);
      expect(written.single.currency, AppCurrency.inr);
    });
  });

  group('the person payment sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.text('الأشخاص').last);
      await settle(tester);
      await tester.tap(find.text('أحمد').first);
      await settle(tester);
      await tester.tap(find.text('تسجيل دفعة').first);
      await settle(tester);
    }

    Future<void> seedDebt() => service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            personIds: <String>[ahmed.id],
            title: 'كهرباء',
            principalMinor: 150000,
            currency: AppCurrency.inr,
            issuedAt: today,
            dueAt: addDays(today, 3),
          ),
        );

    Future<int> paidTotal() async {
      final List<Debt> debts = await service.debts.forPerson(ahmed.id);
      int total = 0;
      for (final Debt debt in debts) {
        for (final Payment payment in await service.payments.forDebt(debt.id)) {
          total += payment.amountMinor;
        }
      }
      return total;
    }

    testWidgets('a fast double tap on save writes one split, not two',
        (WidgetTester tester) async {
      await seedDebt();
      await openLedger(tester);
      await openSheet(tester);

      await tester.enterText(find.byType(AmountField), '500');
      await tester.pump();

      // No pump between the two taps: see the note at the top of the file.
      await tester.tap(find.text('حفظ الدفعة'));
      await tester.tap(find.text('حفظ الدفعة'));
      await settle(tester);

      expect(
        await paidTotal(),
        50000,
        reason: 'the money left the ledger once, not twice',
      );
    });
  });
}
