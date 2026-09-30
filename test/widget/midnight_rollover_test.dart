import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The app moves to the new day at midnight, not at the next resume.
///
/// "Today" was re-read only when the app came back from the background, so a
/// dashboard left open overnight still called yesterday's deadline "due today"
/// and counted it as due soon rather than late.
void main() {
  late AppDatabase db;

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('a deadline due today is late once midnight passes',
      (WidgetTester tester) async {
    DateTime now = DateTime(2026, 10, 1, 23, 59);

    final LedgerService service = buildService(db);
    final Person person =
        await service.createPerson(const PersonDraft(name: 'سالم الحربي'));
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'إيجار المحل',
        principalMinor: 250000,
        currency: AppCurrency.inr,
        issuedAt: DateTime(2026, 9),
        dueAt: DateTime(2026, 10),
      ),
    );

    await pumpDhimmah(tester, db: db, clock: () => now);
    await settle(tester);

    expect(find.text('${l10n.dashboardDueSoon} '), findsOneWidget,
        reason: 'before midnight it is due today, which is due soon');
    expect(find.text('${l10n.dashboardOverdue} '), findsNothing);

    // Midnight passes with the app on screen and nothing touched.
    now = DateTime(2026, 10, 2, 0, 0, 2);
    await tester.pump(const Duration(minutes: 1, seconds: 2));
    await settle(tester);

    expect(find.text('${l10n.dashboardOverdue} '), findsOneWidget,
        reason: 'the deadline was yesterday');
    expect(find.text('${l10n.dashboardDueSoon} '), findsNothing);
  });
}
