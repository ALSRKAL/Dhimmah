import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Layout resilience.
///
/// A financial app is read by people who enlarge their text, and a number that
/// overflows its row is a number that cannot be read at all. These pump the real
/// screens at the two text scales that break layouts most often and fail on any
/// overflow the framework reports.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  /// Fails the test on any render overflow in the tree.
  void expectNoOverflow(WidgetTester tester) {
    final Object? exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: 'layout overflowed: $exception',
    );
  }

  Future<void> pumpAt(
    WidgetTester tester,
    double textScale, {
    bool seed = true,
    AppCurrency currency = AppCurrency.inr,
  }) async {
    if (seed) await seedLedger(db, extraCurrency: currency);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpDhimmah(tester, db: db);
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('the app survives large text', () {
    for (final double scale in <double>[1.0, 1.3, 1.5]) {
      testWidgets('dashboard at ${scale}x', (WidgetTester tester) async {
        await pumpAt(tester, scale);
        expectNoOverflow(tester);
        expect(find.byType(NavigationBar), findsOneWidget);
      });

      testWidgets('ledger at ${scale}x', (WidgetTester tester) async {
        await pumpAt(tester, scale);
        await tester.tap(find.text('السجل').last);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });

      testWidgets('people at ${scale}x', (WidgetTester tester) async {
        await pumpAt(tester, scale);
        await tester.tap(find.text('الأشخاص').last);
        await tester.pumpAndSettle();
        expectNoOverflow(tester);
      });
    }

    testWidgets('a long Arabic name does not overflow its row',
        (WidgetTester tester) async {
      // The seed already uses a five-part name; this checks it survives at the
      // largest scale without the row breaking.
      await pumpAt(tester, 1.5);
      await tester.tap(find.text('الأشخاص').last);
      await tester.pumpAndSettle();
      expectNoOverflow(tester);
      expect(find.textContaining('محمد'), findsWidgets);
    });
  });

  group('both scripts lay out in their own direction', () {
    testWidgets('Arabic is right to left', (WidgetTester tester) async {
      await pumpAt(tester, 1.0);
      final BuildContext context = tester.element(find.byType(NavigationBar));
      expect(Directionality.of(context), TextDirection.rtl);
    });

    testWidgets('English is left to right', (WidgetTester tester) async {
      await seedLedger(db);
      await pumpDhimmah(
        tester,
        db: db,
        settings: AppSettings.initial.copyWith(language: AppLanguage.english),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final BuildContext context = tester.element(find.byType(NavigationBar));
      expect(Directionality.of(context), TextDirection.ltr);
      expect(find.text('Ledger'), findsWidgets);
      expectNoOverflow(tester);
    });
  });

  group('one add button, never two', () {
    // The shell owns the add button for its five destinations, and a screen that
    // also declares one draws a second button on top of the first. It has
    // happened twice; this is the guard.
    for (final String tab in <String>['الرئيسية', 'السجل', 'الأشخاص', 'التزامات', 'المزيد']) {
      testWidgets('$tab has exactly one', (WidgetTester tester) async {
        await pumpAt(tester, 1.0);
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(
          find.byType(FloatingActionButton),
          findsOneWidget,
          reason: '$tab must rely on the shell\'s add button',
        );
        expectNoOverflow(tester);
      });
    }
  });

  group('the add button offers what the current screen is about', () {
    testWidgets('the people tab can add a person', (WidgetTester tester) async {
      await pumpAt(tester, 1.0);
      await tester.tap(find.text('الأشخاص').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('شخص جديد'), findsOneWidget);
    });

    testWidgets('the ledger tab does not', (WidgetTester tester) async {
      await pumpAt(tester, 1.0);
      await tester.tap(find.text('السجل').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // The four record kinds, and no person option crowding them.
      expect(find.text('دين عليّ'), findsWidgets);
      expect(find.text('شخص جديد'), findsNothing);
    });
  });

  group('the smallest screen', () {
    testWidgets('a 360-wide phone shows the position and what needs attention',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpAt(tester, 1.0);

      // The four answers sit above the fold: where I stand, the two sides, and
      // what is late.
      expect(find.text('ذِمّة'), findsOneWidget);
      expect(find.text('يحتاج انتباهك'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}
