import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The attention figures sum everything that needs attention.
///
/// On the device an overdue rent bill sat under a "late" figure that did not
/// count it, because the figure came from debt totals while the list mixed
/// debts and obligations. Later the figures were summed from the dashboard's
/// display lists, which stop at six debts and four periods.
void main() {
  late AppDatabase db;

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    db = AppDatabase.memory();
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

  /// The amount printed beside [label] in the line above the list.
  Finder figure(String label, String amount) => find.descendant(
        of: find
            .ancestor(of: find.text('$label '), matching: find.byType(Row))
            .first,
        matching: find.textContaining(amount),
      );

  testWidgets('the late figure sums debts and obligations together',
      (WidgetTester tester) async {
    await seedLedger(db, extraCurrency: AppCurrency.inr);
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    // Late: قرض سيارة ₹23,000 + فاتورة الإنترنت ₹1,200 = ₹24,200.
    // Due soon: سلفة ₹15,000.
    expect(find.textContaining('24,200'), findsOneWidget,
        reason: 'the late figure must include the late obligation');
    expect(find.textContaining('15,000'), findsWidgets);
  });

  testWidgets('every late debt is in the late figure, not the first six',
      (WidgetTester tester) async {
    final LedgerService service = buildService(db);
    final DateTime today = dateOnly(DateTime.now());
    final Person person =
        await service.createPerson(const PersonDraft(name: 'سالم الحربي'));
    for (int i = 0; i < 7; i++) {
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'دفعة ${i + 1}',
          principalMinor: (1010 + i * 10) * 100,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -40),
          dueAt: addDays(today, -3 - i),
        ),
      );
    }
    // Owed with no deadline, so the balance at the top is a different figure.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'بلا موعد',
        principalMinor: 200000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -10),
      ),
    );

    await pumpDhimmah(tester, db: db);
    await settle(tester);

    // 1,010 + 1,020 + … + 1,070 = 7,280. The first six made 6,210 at most.
    expect(
      figure(l10n.dashboardOverdue, '7,280'),
      findsOneWidget,
      reason: 'the seventh late debt is as late as the other six',
    );
  });

  testWidgets('a commitment behind by three periods is three periods late',
      (WidgetTester tester) async {
    final LedgerService service = buildService(db);
    final DateTime today = dateOnly(DateTime.now());
    // Weekly from twenty days ago: due 20, 13 and 6 days ago, then tomorrow.
    // Nothing else is recorded, so this also checks that a ledger of
    // commitments alone is not shown as empty.
    await service.createObligation(
      ObligationDraft(
        name: 'اشتراك النادي',
        category: ObligationCategory.subscription,
        amountMinor: 123400,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.weekly,
        startAt: addDays(today, -20),
      ),
    );

    await pumpDhimmah(tester, db: db);
    await settle(tester);

    expect(
      find.text(l10n.dashboardEmptyTitle),
      findsNothing,
      reason: 'there is a late commitment to show',
    );
    expect(
      figure(l10n.dashboardOverdue, '3,702'),
      findsOneWidget,
      reason: 'three late periods of ₹1,234, though the row shows one',
    );
    expect(
      figure(l10n.dashboardDueSoon, '1,234'),
      findsOneWidget,
      reason: "tomorrow's period is due soon",
    );
  });
}
