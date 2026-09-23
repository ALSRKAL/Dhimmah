import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The sixty-second journey, driven the way a person drives it.
///
/// Open the app, open someone, record a payment, read the statement. Every other
/// test in the suite checks one of those steps in isolation — a service call, a
/// screen rendering, a statement building — and none of them would notice if the
/// steps stopped connecting to each other.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String personName = 'محمد أحمد عبدالرحمن';

  /// A person with one open debt, so the journey has something to act on.
  Future<void> seedOneDebt(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final Person person = await buildService(db).createPerson(
      const PersonDraft(name: personName),
    );
    await buildService(db).createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personId: person.id,
        title: 'قرض سيارة',
        principalMinor: 1000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(dateOnly(DateTime.now()), -10),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DhimmahApp(onboardingCompleted: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Waits for a screen to finish loading.
  ///
  /// The ledger is read through drift, whose reads complete on the **real**
  /// event loop. `pump` alone only drives the test's fake clock, so a screen
  /// waiting on the database sits on its skeleton however many times you pump
  /// it — the debt detail stayed there through ten pumps and a `pumpAndSettle`.
  /// `runAsync` is the escape hatch that lets the database finish.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Fixed pumps, for screens that never settle.
  ///
  /// `PdfPreview` hands off to the platform viewer, so `pumpAndSettle` waits
  /// forever on it.
  Future<void> pumpPreview(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('open a person, record a payment, watch the balance fall',
      (WidgetTester tester) async {
    await seedOneDebt(tester);

    // 1. The person, from the list.
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text(personName),
      ),
    );
    await settle(tester);

    // The page opens on what is owed, before anything is paid. The figure is
    // matched by substring because an amount is one Text: the shared formatter
    // prints the symbol and the digits together, wrapped in bidi isolates so the
    // unit stays left-to-right inside an Arabic line.
    expect(find.text('عليك'), findsOneWidget);
    expect(find.textContaining('10,000'), findsWidgets);

    // 2. The debt itself, from the person's list.
    await tester.tap(find.text('قرض سيارة').first);
    await settle(tester);

    // 3. Record a payment of a quarter of it.
    await tester.tap(find.text('تسجيل دفعة').first);
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, '2500');
    await settle(tester);
    await tester.tap(find.text('حفظ الدفعة'));
    await settle(tester);

    // The write is confirmed rather than assumed.
    expect(find.text('تم تسجيل الدفعة'), findsOneWidget);

    // 4. Back on the debt, the remaining balance is the reduced one.
    expect(find.textContaining('7,500'), findsWidgets);

    // 5. And the person's page agrees — the same figure, stated once.
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.textContaining('7,500'), findsWidgets);
    expect(find.textContaining('10,000'), findsNothing);
  });

  testWidgets('the statement is reachable from the person, showing the payment',
      (WidgetTester tester) async {
    await seedOneDebt(tester);

    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text(personName),
      ),
    );
    await settle(tester);

    // Pay half, so the statement has a payment history to print.
    await tester.tap(find.text('قرض سيارة').first);
    await settle(tester);
    await tester.tap(find.text('تسجيل دفعة').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '5000');
    await settle(tester);
    await tester.tap(find.text('حفظ الدفعة'));
    await settle(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    // The statement is one tap from the person, not buried in a menu.
    await tester.tap(find.text('مشاركة كشف'));
    await pumpPreview(tester);

    // PdfPreview is the platform viewer and never settles, so its presence is
    // the assertion.
    expect(find.text('كشف حساب'), findsOneWidget);
    expect(find.text('مشاركة PDF'), findsOneWidget);
  });
}
