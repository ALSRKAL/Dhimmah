import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/debts/payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What dragging a debt row sideways does.
///
/// Two actions, and both already exist elsewhere: a payment, which opens the
/// same sheet the debt's page opens, and archiving, which is the menu's own
/// call and reversible for six seconds. No swipe writes anything by itself, and
/// a settled debt never offers a payment it cannot take.
void main() {
  late AppDatabase db;
  late ({Person ahmed, Person khalid}) people;
  late LedgerService service;

  setUp(() async {
    db = AppDatabase.memory();
    people = await seedLedger(db);
    service = buildService(db);
    // A debt paid in full, so the ledger has one row with nothing left to pay.
    final Debt settledDebt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[people.khalid.id],
        title: 'دين مسدَّد',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: addDays(dateOnly(DateTime.now()), -20),
      ),
    );
    await service.recordPayment(
      settledDebt.id,
      PaymentDraft(
        amountMinor: 100000,
        paidAt: dateOnly(DateTime.now()),
      ),
    );
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> openLedger(WidgetTester tester) async {
    await settle(tester);
    await tester.tap(find.text('السجل').last);
    await settle(tester);
  }

  Future<DebtRow?> debtTitled(String title) async {
    final List<DebtRow> rows = await db.select(db.debts).get();
    for (final DebtRow row in rows) {
      if (row.title == title) return row;
    }
    return null;
  }

  group('in Arabic, where the reading start is the right edge', () {
    testWidgets('swiping toward the start opens the payment sheet',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openLedger(tester);
      final int paymentsBefore = (await db.select(db.payments).get()).length;

      // startToEnd in a right-to-left layout is a leftward drag.
      await tester.drag(find.textContaining('قرض سيارة'), const Offset(-400, 0));
      await settle(tester);

      expect(find.byType(PaymentSheet), findsOneWidget);
      expect(
        (await db.select(db.payments).get()).length,
        paymentsBefore,
        reason: 'the swipe opens the sheet; it writes nothing itself',
      );
    });

    testWidgets('swiping the other way archives, and undo restores',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openLedger(tester);
      // `سلفة` is money owed to the user; the ledger opens on the other side.
      await tester.tap(find.text('لي'));
      await settle(tester);

      await tester.drag(find.textContaining('سلفة'), const Offset(400, 0));
      await settle(tester);

      expect((await debtTitled('سلفة'))?.archivedAt, isNotNull);
      expect(find.text('تمت الأرشفة'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);

      await tester.tap(find.text('تراجع'));
      await settle(tester);
      expect((await debtTitled('سلفة'))?.archivedAt, isNull);
    });

    testWidgets('a settled debt does not offer a payment',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await openLedger(tester);
      await tester.tap(find.text('لي'));
      await settle(tester);

      // The settled record is the third row; on the test screen it starts
      // below the fold, and a lazy list builds only what is visible.
      await tester.scrollUntilVisible(
        find.textContaining('دين مسدَّد'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settle(tester);

      final Finder row = find.textContaining('دين مسدَّد');
      final Dismissible dismissal = tester.widget<Dismissible>(
        find.ancestor(of: row, matching: find.byType(Dismissible)).first,
      );
      expect(
        dismissal.direction,
        DismissDirection.endToStart,
        reason: 'only the archive direction is offered',
      );

      await tester.drag(row, const Offset(-400, 0));
      await settle(tester);
      expect(find.byType(PaymentSheet), findsNothing);
    });
  });

  group('in English, the same two meanings the other way round', () {
    testWidgets('a rightward drag records a payment', (WidgetTester tester) async {
      await pumpDhimmah(
        tester,
        db: db,
        settings: AppSettings.initial.copyWith(
          languagePreference: LanguagePreference.of(AppLanguage.english),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('Ledger').last);
      await settle(tester);

      await tester.drag(find.textContaining('قرض سيارة'), const Offset(400, 0));
      await settle(tester);
      expect(find.byType(PaymentSheet), findsOneWidget);
    });
  });

  testWidgets('with "remove animations" on, a swipe does not animate',
      (WidgetTester tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpDhimmah(tester, db: db);
    await openLedger(tester);

    final Dismissible row = tester.widget<Dismissible>(
      find.ancestor(
        of: find.textContaining('قرض سيارة'),
        matching: find.byType(Dismissible),
      ).first,
    );
    expect(row.movementDuration, Duration.zero);
    expect(row.resizeDuration, Duration.zero);
  });
}
