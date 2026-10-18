import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The person-level payment sheet.
///
/// Everything here turns on one promise: the split the sheet draws is the split
/// that gets written. It is drawn by the same function the service calls, over
/// the same live debts, so a preview that drifts from the write is the single
/// failure this design exists to prevent. Where a case can be proved by saving
/// and reading the balances back, it is — that is the assertion a pretty preview
/// cannot satisfy on its own.
///
/// Amounts are in minor units, which is what the ledger stores; the amount
/// *field* takes major units, which is what a person types.
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

  /// A debt of [rupees] rupees, due [dueInDays] from today.
  Future<Debt> debt({
    required String title,
    required int rupees,
    required int dueInDays,
  }) {
    return service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: title,
        principalMinor: rupees * 100,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, dueInDays),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// The app on the ledger, with the sheet open over it.
  Future<void> openSheet(WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.text('أحمد').first);
    await settle(tester);
    await tester.tap(find.text('تسجيل دفعة').first);
    await settle(tester);
  }

  /// The outstanding balance of each debt, by title, read the ordinary way.
  Future<Map<String, int>> balances() async {
    final List<Debt> debts = await service.debts.forPerson(ahmed.id);
    final Map<String, int> out = <String, int>{};
    for (final Debt debt in debts) {
      final int paid = (await service.payments.forDebt(debt.id))
          .fold<int>(0, (int sum, Payment payment) => sum + payment.amountMinor);
      out[debt.title] =
          (debt.principalMinor - paid).clamp(0, debt.principalMinor);
    }
    return out;
  }

  Future<void> enterAmount(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(AmountField), text);
    await tester.pump();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<AmountField>(find.byType(AmountField)).controller!.text;

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester);
  }

  testWidgets('the preview marks what this payment clears',
      (WidgetTester tester) async {
    await debt(title: 'الأول', rupees: 1000, dueInDays: 1);
    await debt(title: 'الثاني', rupees: 2000, dueInDays: 30);
    await openSheet(tester);

    // Nothing entered: nothing is marked as settled.
    expect(find.text('يُسدَّد بالكامل'), findsNothing);

    await enterAmount(tester, '1500');

    // 1,500 clears the 1,000 and leaves 500 of the 2,000 — one settled row and
    // one partly paid row.
    expect(find.text('يُسدَّد بالكامل'), findsOneWidget);
    expect(find.textContaining('يتبقى'), findsOneWidget);
  });

  testWidgets('the impact summary counts what is cleared and what changes',
      (WidgetTester tester) async {
    await debt(title: 'أول', rupees: 1000, dueInDays: 1);
    await debt(title: 'ثاني', rupees: 2000, dueInDays: 2);
    await openSheet(tester);

    await enterAmount(tester, '1500');
    expect(find.textContaining('سيُسدَّد دين واحد'), findsOneWidget);
    expect(find.textContaining('ويتغيّر دين آخر'), findsOneWidget);

    await enterAmount(tester, '3000');
    expect(find.textContaining('سيُسدَّد دينان'), findsOneWidget);
    expect(find.textContaining('ويتغيّر'), findsNothing);
  });

  testWidgets('a shortcut fills the field, and the field is what is saved',
      (WidgetTester tester) async {
    await debt(title: 'أول', rupees: 1000, dueInDays: 1);
    await debt(title: 'ثاني', rupees: 3000, dueInDays: 2);
    await openSheet(tester);

    // Nothing is prefilled: a sheet opened by accident holds no amount.
    expect(fieldText(tester), isEmpty);

    await tap(tester, 'سداد الكل');
    expect(fieldText(tester), '4000.00');

    await tap(tester, '50%');
    expect(fieldText(tester), '2000.00');

    await tap(tester, '25%');
    expect(fieldText(tester), '1000.00');
  });

  testWidgets('saving writes the split the preview showed',
      (WidgetTester tester) async {
    await debt(title: 'الأول', rupees: 1000, dueInDays: 1);
    await debt(title: 'الثاني', rupees: 2000, dueInDays: 2);
    await openSheet(tester);

    await enterAmount(tester, '1500');
    await tap(tester, 'حفظ الدفعة');

    expect(
      await balances(),
      <String, int>{'الأول': 0, 'الثاني': 150000},
      reason: 'the 1,000 is cleared and 500 comes off the second',
    );
  });

  testWidgets('saving closes the debt it cleared',
      (WidgetTester tester) async {
    final Debt only = await debt(title: 'وحيد', rupees: 1200, dueInDays: 1);
    await openSheet(tester);

    await tap(tester, 'سداد الكل');
    await tap(tester, 'حفظ الدفعة');

    expect((await service.debts.getById(only.id))!.closedAt, isNotNull);
  });

  testWidgets('nothing is saved while the field is empty',
      (WidgetTester tester) async {
    await debt(title: 'وحيد', rupees: 1000, dueInDays: 1);
    await openSheet(tester);

    await tap(tester, 'حفظ الدفعة');

    expect(await service.payments.getAll(), isEmpty);
    expect(await balances(), <String, int>{'وحيد': 100000});
  });

  testWidgets('the most urgent debt is settled first',
      (WidgetTester tester) async {
    await debt(title: 'متأخر', rupees: 1000, dueInDays: -5);
    await debt(title: 'بعيد', rupees: 1000, dueInDays: 40);
    await openSheet(tester);

    expect(find.text('الأكثر إلحاحاً'), findsOneWidget);
    await enterAmount(tester, '1000');
    await tap(tester, 'حفظ الدفعة');

    expect(
      await balances(),
      <String, int>{'متأخر': 0, 'بعيد': 100000},
      reason: 'the late one is what 1,000 settles',
    );
  });

  testWidgets('swapping the rule is offered, and the write follows it',
      (WidgetTester tester) async {
    await debt(title: 'أ', rupees: 1000, dueInDays: 10);
    await debt(title: 'ب', rupees: 1000, dueInDays: 20);
    await openSheet(tester);

    await tap(tester, 'الأكثر إلحاحاً');
    expect(find.text('الأقدم أولاً'), findsOneWidget);

    await enterAmount(tester, '1000');
    await tap(tester, 'حفظ الدفعة');

    // Exactly one debt was settled and exactly one payment was written, whichever
    // the rule picked between two records issued on the same day.
    final Map<String, int> after = await balances();
    expect(after.values.where((int value) => value == 0), hasLength(1));
    expect(await service.payments.getAll(), hasLength(1));
  });

  testWidgets('unchecking a debt moves its share to the next one',
      (WidgetTester tester) async {
    await debt(title: 'الأول', rupees: 1000, dueInDays: 1);
    await debt(title: 'الثاني', rupees: 2000, dueInDays: 2);
    await openSheet(tester);

    await enterAmount(tester, '1500');
    expect(find.text('يُسدَّد بالكامل'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    // The first debt is out, so all 1,500 lands on the second and nothing is
    // cleared.
    expect(find.text('مستثنى'), findsOneWidget);
    expect(find.text('يُسدَّد بالكامل'), findsNothing);
    expect(find.textContaining('يتبقى'), findsOneWidget);
  });

  testWidgets('an excluded debt is still excluded when the payment is saved',
      (WidgetTester tester) async {
    await debt(title: 'الأول', rupees: 1000, dueInDays: 1);
    await debt(title: 'الثاني', rupees: 2000, dueInDays: 2);
    await openSheet(tester);

    await enterAmount(tester, '1500');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tap(tester, 'حفظ الدفعة');

    expect(
      <String, int>{'الأول': 100000, 'الثاني': 50000},
      await balances(),
      reason: 'the untouched debt was left alone entirely',
    );
  });

  testWidgets('the undo takes the whole split back in one tap',
      (WidgetTester tester) async {
    await debt(title: 'الأول', rupees: 1000, dueInDays: 1);
    await debt(title: 'الثاني', rupees: 2000, dueInDays: 2);
    await openSheet(tester);

    await enterAmount(tester, '1500');
    await tap(tester, 'حفظ الدفعة');
    expect(
      await balances(),
      <String, int>{'الأول': 0, 'الثاني': 150000},
    );

    await tap(tester, 'تراجع');

    expect(
      <String, int>{'الأول': 100000, 'الثاني': 200000},
      await balances(),
    );
    expect(await service.payments.getAll(), isEmpty);
  });

  testWidgets('a legacy shared record is named, and left out of the split',
      (WidgetTester tester) async {
    final Person khalid =
        await service.createPerson(const PersonDraft(name: 'خالد'));
    await createLegacySharedDebt(
      service,
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id, khalid.id],
        title: 'مشترك',
        principalMinor: 500000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
    await debt(title: 'عادي', rupees: 1000, dueInDays: 1);
    await openSheet(tester);

    // A payment on a shared record settles everybody at once, so it cannot take
    // part — and the sheet says so rather than quietly settling less than the
    // person's whole balance.
    expect(find.textContaining('دين مشترك قديم'), findsOneWidget);
    expect(find.textContaining('تحويل إلى ديون مستقلة'), findsOneWidget);
    expect(find.text('يُسدَّد بالكامل'), findsNothing);
  });

  testWidgets('an amount beyond what is owed is not written',
      (WidgetTester tester) async {
    await debt(title: 'وحيد', rupees: 1000, dueInDays: 1);
    await openSheet(tester);

    await enterAmount(tester, '5000');
    await tap(tester, 'حفظ الدفعة');

    // Nothing is saved for a figure the field would not accept. The alternative
    // — writing a payment larger than the debt — leaves the user reading a
    // number nothing on the screen explains.
    expect(await service.payments.getAll(), isEmpty);
    expect(await balances(), <String, int>{'وحيد': 100000});
  });
}
