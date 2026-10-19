import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/app_card.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The budget card and the income list, read the way a person reads them.
///
/// Three questions, and each is one somebody actually asks of this screen: how
/// do I change my salary, what does it mean that the month spends more than I
/// earn, and what happens when there is nothing to spend it on. The answers have
/// to be on the glass, not in the model.
void main() {
  late AppDatabase db;
  late LedgerService service;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> addIncome(
    int amountMinor, {
    String name = 'راتب شهري',
  }) async {
    service = buildService(db);
    await service.createIncome(
      IncomeDraft(
        name: name,
        amountMinor: amountMinor,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        dayOfMonth: 1,
      ),
    );
  }

  Future<void> addCommitment(int amountMinor) async {
    service = buildService(db);
    await service.createObligation(
      ObligationDraft(
        name: 'إيجار',
        category: ObligationCategory.housing,
        amountMinor: amountMinor,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
      ),
    );
    await service.ensureOccurrences();
  }

  /// The commitments tab, where the budget card lives.
  Future<void> openCommitments(WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('التزامات').last);
    await settle(tester);
  }

  /// The card is taller than the gap above the navigation bar on a short
  /// screen, so its own centre can sit behind the bar; its top edge is always
  /// the part a thumb reaches first.
  Future<void> tapCard(WidgetTester tester) async {
    final Rect card = tester.getRect(find.byType(AppCard).first);
    await tester.tapAt(Offset(card.center.dx, card.top + 12));
    await settle(tester);
  }

  group('the card says where the month stands', () {
    testWidgets('an income with nothing due says the whole of it is available',
        (WidgetTester tester) async {
      await addIncome(500000);
      await openCommitments(tester);

      // Not "0% of your income goes to commitments" — a percentage of nothing
      // is not a fact about this month.
      expect(find.textContaining('كامل دخلك متاح'), findsOneWidget);
      expect(find.textContaining('0%'), findsNothing);
      expect(find.textContaining('إجمالي الدخل'), findsOneWidget);
    });

    testWidgets('spending more than the income states the overage, not a minus',
        (WidgetTester tester) async {
      await addIncome(100000);
      await addCommitment(150000);
      await openCommitments(tester);

      // The label names the case and the figure under it is the amount over —
      // a positive number. «المتبقي من الدخل −₹500» would read as a balance
      // below zero, and it puts a minus sign at the start of an amount, which is
      // the one thing the two scripts lay out differently.
      expect(find.textContaining('تجاوز الدخل بـ'), findsOneWidget);
      expect(find.textContaining('المتبقي من الدخل'), findsNothing);
      expect(
        find.textContaining('−'),
        findsNothing,
        reason: 'no sign is drawn: the words carry it',
      );
      final Finder card = find.byType(AppCard).first;
      expect(
        find.descendant(of: card, matching: find.textContaining('500')),
        findsWidgets,
        reason: 'the overage is 500 on screen, as a plain amount',
      );
      // And the warning colour is the one the app uses for money gone wrong.
      final Text headline = tester.widget<Text>(
        find
            .descendant(of: card, matching: find.text('تجاوز الدخل بـ'))
            .first,
      );
      expect(headline.maxLines, 2, reason: 'the phrase may wrap, not clip');
    });

    testWidgets('a month that is merely committed still reads as remaining',
        (WidgetTester tester) async {
      await addIncome(500000);
      await addCommitment(100000);
      await openCommitments(tester);

      expect(find.textContaining('المتبقي من الدخل'), findsOneWidget);
      expect(find.textContaining('تجاوز الدخل بـ'), findsNothing);
      expect(find.textContaining('%'), findsWidgets,
          reason: 'the share of the income is still stated');
    });

    testWidgets('the card says it opens the income list',
        (WidgetTester tester) async {
      await addIncome(500000);
      await openCommitments(tester);

      // A card that opens something without saying so is a feature only its
      // author knows about.
      expect(find.textContaining('إدارة الدخل'), findsOneWidget);
    });
  });

  group('editing a source of income', () {
    testWidgets('one tap on the source opens it prefilled, and saving keeps '
        'the same record', (WidgetTester tester) async {
      await addIncome(500000);
      await openCommitments(tester);
      await tapCard(tester);

      // The sheet lists the source; tapping it opens the form it was written
      // with.
      expect(find.textContaining('مصادر الدخل'), findsOneWidget);
      await tester.tap(find.text('راتب شهري'));
      await settle(tester);

      expect(find.textContaining('تعديل الدخل'), findsOneWidget,
          reason: 'the form replaced the list inside the same sheet, and says '
              'which of the two things it is doing');
      final EditableText name = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(name.controller.text, 'راتب شهري', reason: 'the name came with it');
      expect(
        find.textContaining('5000'),
        findsWidgets,
        reason: 'and so did the amount: 500,000 minor units is 5,000',
      );

      // The change a person actually makes: the salary went up.
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '6000',
      );
      await settle(tester);
      await tester.tap(find.text('حفظ التعديلات'));
      await settle(tester);

      final List<Income> stored = await buildService(db).incomes.getAll();
      expect(stored, hasLength(1), reason: 'edited, never duplicated');
      expect(stored.single.name, 'راتب شهري');
      expect(stored.single.amountMinor, 600000);
    });

    testWidgets('cancelling an edit leaves the record alone',
        (WidgetTester tester) async {
      await addIncome(500000);
      await openCommitments(tester);
      await tapCard(tester);
      await tester.tap(find.text('راتب شهري'));
      await settle(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '9000',
      );
      await settle(tester);
      await tester.tap(find.text('إلغاء'));
      await settle(tester);

      final List<Income> stored = await buildService(db).incomes.getAll();
      expect(stored.single.amountMinor, 500000,
          reason: 'nothing was written by walking away');
    });
  });
}
