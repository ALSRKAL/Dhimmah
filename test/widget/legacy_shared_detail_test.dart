import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The legacy shared record's own page.
///
/// An old row naming several people refuses payments, says why, and offers the
/// manual split after the user has reviewed its history — unless the record is
/// already settled, in which case there is nothing left to split and the page
/// just keeps the history readable.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String first = 'محمد أحمد عبدالرحمن';
  const String second = 'خالد العلي';

  late Person ahmed;
  late Person khalid;
  late Debt legacy;

  Future<void> seed(WidgetTester tester, {bool settled = false}) async {
    final LedgerService service = buildService(db);
    ahmed = await service.createPerson(const PersonDraft(name: first));
    khalid = await service.createPerson(const PersonDraft(name: second));
    legacy = await createLegacySharedDebt(
      service,
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id, khalid.id],
        title: 'سلفة قديمة',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: dateOnly(DateTime.now()),
      ),
    );
    await recordLegacyPayment(
      service,
      legacy,
      amountMinor: settled ? 150000 : 50000,
      paidAt: dateOnly(DateTime.now()),
    );
    await pumpDhimmah(tester, db: db);
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// People → Ahmed → the legacy row → its page.
  Future<void> openLegacyDetail(WidgetTester tester) async {
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text(first),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('سلفة قديمة').first);
    await settle(tester);
  }

  testWidgets('an open legacy record explains itself and offers the split',
      (WidgetTester tester) async {
    await seed(tester);
    await openLegacyDetail(tester);

    // The notice: why payments are paused and what to do.
    expect(find.text('دين مشترك قديم يحتاج مراجعة'), findsOneWidget);
    expect(find.textContaining('تم إيقاف السداد مؤقتاً'), findsOneWidget);

    // The payment action is replaced by the split — and nothing else pays.
    expect(find.text('تحويل إلى ديون مستقلة'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsNothing);
  });

  testWidgets('splitting from the page leaves independent debts behind',
      (WidgetTester tester) async {
    await seed(tester);
    await openLegacyDetail(tester);

    await tester.tap(find.text('تحويل إلى ديون مستقلة'));
    await settle(tester);
    // The confirmation states that the history stays on the first debt.
    expect(find.textContaining('تبقى الدفعات السابقة'), findsOneWidget);
    await tester.tap(find.text('تحويل إلى ديون مستقلة').last);
    await settle(tester);

    expect(find.text('تم التحويل إلى ديون مستقلة'), findsWidgets);
    final LedgerService service = buildService(db);
    expect((await service.debts.getById(legacy.id))!.personIds,
        <String>[ahmed.id]);
    expect(await db.debtsDao.getAll(), hasLength(2));

    // The notice is gone with the shared shape: the payment action is back.
    expect(find.text('دين مشترك قديم يحتاج مراجعة'), findsNothing);
    expect(find.text('تسجيل دفعة'), findsWidgets);
  });

  testWidgets('a settled legacy record hides the split and keeps history',
      (WidgetTester tester) async {
    await seed(tester, settled: true);
    await openLegacyDetail(tester);

    // The settled notice replaces the split call-to-action.
    expect(find.text('دين مشترك قديم يحتاج مراجعة'), findsOneWidget);
    expect(find.textContaining('مُسدَّد بالكامل'), findsOneWidget);
    expect(find.text('تحويل إلى ديون مستقلة'), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNothing);

    // Its payment history is still listed for review.
    expect(find.textContaining('500'), findsWidgets);
  });
}
