import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/app_card.dart';
import 'package:dhimmah/core/widgets/hero_amount.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Rules from the design direction that a machine can check.
///
/// Most of that document is judgement and belongs in review, not in a test. The
/// rules below are structural, though: they are exactly the ones a later change
/// can quietly break while every other test still passes.
///
/// §25 — one primary visual focus per screen. The focus figure is [HeroAmount],
/// and a screen with two of them has no focus at all.
/// §30 — one primary action per screen: the [FilledButton]. Everything else is
/// secondary or tertiary.
/// §42 — remove what adds no value. On one screen, a fact is stated once.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  /// Every destination the bottom bar can reach.
  const List<String> destinations = <String>[
    'الرئيسية',
    'السجل',
    'الأشخاص',
    'التزامات',
    'المزيد',
  ];

  Future<({Person ahmed, Person khalid})> pumpSeeded(
    WidgetTester tester,
  ) async {
    final ({Person ahmed, Person khalid}) people = await seedLedger(db);
    await pumpDhimmah(tester, db: db);
    return people;
  }

  Future<void> openDestination(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openPerson(WidgetTester tester, Person person) async {
    await openDestination(tester, 'الأشخاص');
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text(person.name),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('no destination has two focus figures or two primary actions',
      (WidgetTester tester) async {
    await pumpSeeded(tester);

    // Guards the loop below against passing because nothing rendered: the
    // dashboard is the screen this rule matters most on, and it must have its
    // one figure.
    expect(find.byType(HeroAmount), findsOneWidget);

    for (final String label in destinations) {
      await openDestination(tester, label);

      expect(
        tester.widgetList(find.byType(HeroAmount)).length,
        lessThanOrEqualTo(1),
        reason: '$label shows more than one focus figure, so nothing is the focus',
      );
      expect(
        tester.widgetList(find.byType(FilledButton)).length,
        lessThanOrEqualTo(1),
        reason: '$label offers more than one primary action',
      );
    }
  });

  testWidgets('the person page leads with one balance', (WidgetTester tester) async {
    final ({Person ahmed, Person khalid}) people = await pumpSeeded(tester);
    await openPerson(tester, people.ahmed);

    // The headline fact. Two figures would mean the page has no focus.
    expect(find.byType(HeroAmount), findsOneWidget);

    // The name is the first thing read, at the size a name deserves.
    final Finder cardName = find.descendant(
      of: find.byType(AppCard),
      matching: find.text(people.ahmed.name),
    );
    expect(cardName, findsOneWidget);
    expect(
      tester.widget<Text>(cardName).style?.fontSize,
      greaterThanOrEqualTo(20),
    );

    // At rest the app bar is blank, because the card already says the name; it
    // only fills in as the card scrolls away.
    final Finder barName = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(people.ahmed.name),
    );
    expect(barName, findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: barName, matching: find.byType(Opacity)).first,
          )
          .opacity,
      0,
    );
  });

  testWidgets('the person page counts the debts once, in the list',
      (WidgetTester tester) async {
    final ({Person ahmed, Person khalid}) people = await pumpSeeded(tester);
    await openPerson(tester, people.ahmed);

    // Ahmed holds two debts. The list controls say so; the header card must not
    // say it a second time in different words.
    expect(find.text('سجلان'), findsOneWidget);
    expect(find.text('دينان'), findsNothing);
  });

  testWidgets('the person page offers one primary action', (WidgetTester tester) async {
    final ({Person ahmed, Person khalid}) people = await pumpSeeded(tester);
    await openPerson(tester, people.ahmed);

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text('إضافة دين'), findsOneWidget);
  });

  testWidgets('the dashboard hero states a magnitude, with the direction in words',
      (WidgetTester tester) async {
    // Ahmed is owed 15,000 and owes 23,000, so the seeded net is on the "you
    // owe" side. Pairing that sentence with a minus sign would read as a double
    // negative, so the direction belongs to the words and the number stays a
    // magnitude — the same way the person page states it.
    await pumpSeeded(tester);

    expect(find.text('عليك'), findsOneWidget);

    final Iterable<Text> parts = tester.widgetList<Text>(
      find.descendant(of: find.byType(HeroAmount), matching: find.byType(Text)),
    );
    expect(parts.first.data, '₹');
  });

  testWidgets('a negative focus figure still leads with its sign',
      (WidgetTester tester) async {
    // No screen passes a signed figure today, but HeroAmount is a money widget
    // and has to place the sign where the shared formatter does — before the
    // symbol, so `−₹ 39,200` and not "rupees, minus thirty-nine thousand".
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: AppFormattingScope(
          formatting: AppFormatting(
            language: AppLanguage.arabic,
            numerals: NumeralsStyle.latin,
            defaultCurrency: AppCurrency.inr,
            localizations: l10n,
          ),
          child: const Scaffold(
            body: HeroAmount(
              Money(-3920000, AppCurrency.inr),
              animate: false,
            ),
          ),
        ),
      ),
    );

    final Iterable<Text> parts = tester.widgetList<Text>(
      find.descendant(of: find.byType(HeroAmount), matching: find.byType(Text)),
    );
    expect(parts.first.data, '−');
    expect(parts.elementAt(1).data, '₹');
  });
}
