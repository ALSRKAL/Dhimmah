import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/person_avatar.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The avatar carrying a person from the list into their page.
///
/// A picture that flies is a small thing, but two heroes with one tag is not:
/// Flutter throws, and it throws in the middle of a navigation the user made.
/// The tag is therefore passed in by the two screens that mean the transition,
/// never derived inside the avatar.
void main() {
  late AppDatabase db;
  late ({Person ahmed, Person khalid}) people;

  setUp(() async {
    db = AppDatabase.memory();
    people = await seedLedger(db);
  });
  tearDown(() async => db.close());

  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  final Person fixture = Person(
    id: 'p1',
    name: 'أحمد محمد',
    colorIndex: 0,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('an avatar without a tag is not a hero',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(PersonAvatar.of(fixture)));
    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('a tagged avatar is one, with the tag it was given',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(PersonAvatar.of(fixture, heroTag: 'person-avatar:${fixture.id}')),
    );
    final Hero hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, 'person-avatar:${fixture.id}');
  });

  testWidgets('with "remove animations" on, it does not fly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        PersonAvatar.of(fixture, heroTag: 'person-avatar:${fixture.id}'),
        reduceMotion: true,
      ),
    );
    expect(find.byType(Hero), findsNothing);
    expect(find.byType(PersonAvatar), findsOneWidget);
  });

  testWidgets('the list and the person page share exactly one tag',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);

    final String tag = 'person-avatar:${people.ahmed.id}';
    // One hero per person, and no tag twice: Flutter would throw on the second
    // one the moment a navigation started.
    final List<Object> tags = tester
        .widgetList<Hero>(find.byType(Hero))
        .map((Hero hero) => hero.tag)
        .toList();
    expect(tags, isNotEmpty);
    expect(tags, contains(tag));
    expect(
      tags.toSet().length,
      tags.length,
      reason: 'a tag may appear once on a screen',
    );

    await tester.tap(find.text('محمد أحمد عبدالرحمن').first);
    await settle(tester);

    // The header carries the same tag the row did, and it is the only one on
    // the page — the row avatars below are deliberately not heroes.
    final List<Hero> pageHeroes =
        tester.widgetList<Hero>(find.byType(Hero)).toList();
    expect(pageHeroes, hasLength(1));
    expect(
      pageHeroes.single.tag,
      tag,
      reason: "the person page must carry the row's tag into its header",
    );
  });
}
