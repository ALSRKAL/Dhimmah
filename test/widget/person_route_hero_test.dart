import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/async_value_view.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/features/people/person_detail_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The avatar's flight needs a destination on the first frame.
///
/// The page used to draw a skeleton while the ledger loaded, so the Hero had
/// nothing to land on: the picture vanished on tap and the header appeared
/// later without any movement. The list now hands the person over, and the
/// header is drawn from them before the ledger arrives. A deep link has no one
/// to hand over and still opens the plain loading page.
void main() {
  final Person fixture = Person(
    id: 'p1',
    name: 'أحمد محمد',
    colorIndex: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// A ledger that never arrives, so the loading state is what the test sees.
  final Stream<PersonLedger?> pending = Stream<PersonLedger?>.multi((_) {});

  Widget host(Widget home) => ProviderScope(
        overrides: [
          personLedgerProvider(fixture.id).overrideWith((Ref ref) => pending),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: AppTheme.light(),
          home: home,
        ),
      );

  testWidgets('a person handed over draws the header at once', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      host(PersonDetailScreen(personId: fixture.id, person: fixture)),
    );
    await tester.pump();

    expect(find.text(fixture.name), findsOneWidget);
    final Hero hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'person-avatar:${fixture.id}');
    expect(find.byType(ListSkeleton), findsOneWidget,
        reason: 'the rest of the page is still loading');
  });

  testWidgets('without a person the page loads as it always did', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(PersonDetailScreen(personId: fixture.id)));
    await tester.pump();

    expect(find.byType(ListSkeleton), findsOneWidget);
    expect(find.byType(Hero), findsNothing,
        reason: 'there is no person to draw, so there is no picture to fly');
  });

  testWidgets('the list passes the person it is showing', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(db.close);
    final ({Person ahmed, Person khalid}) people = await seedLedger(db);

    await pumpDhimmah(tester, db: db);
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.tap(find.text('الأشخاص').last);
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    await tester.tap(find.text(people.ahmed.name).first);
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    final PersonDetailScreen screen =
        tester.widget<PersonDetailScreen>(find.byType(PersonDetailScreen));
    expect(screen.person?.id, people.ahmed.id);
    expect(find.byType(Hero), findsWidgets);
  });
}
