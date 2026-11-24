import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The English direction choice at the narrowest ordinary phone.
///
/// The description made "Owed to me · I'll get it" two lines inside one segment
/// at 360 and 1.0. The short label is the name alone; this checks the painted
/// label, not the translation file.
void main() {
  late AppDatabase db;

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

  testWidgets('the English direction choice is one line at 360',
      (WidgetTester tester) async {
    await seedLedger(db);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(
        languagePreference: LanguagePreference.english,
      ),
    );
    await settle(tester);
    await tester.tap(find.text('People').last);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text('خالد العلي'),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Add a debt'));
    await settle(tester);

    final Finder segments = find.byType(SegmentedButton<DebtDirection>);
    expect(segments, findsOneWidget);
    for (final String label in <String>['I owe', 'To me']) {
      final Finder text = find.descendant(
        of: segments,
        matching: find.text(label),
      );
      expect(text, findsOneWidget, reason: 'the short "$label" segment');
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: '"$label" wrapped');
      expect(
        paragraph.size.height,
        lessThanOrEqualTo(30),
        reason: '"$label" is taller than one line: ${paragraph.size}',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
