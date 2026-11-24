import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// A dashboard row says its state once, and says it whole.
///
/// The absolute date after “11 days late” pushed the line past a 360 phone and
/// made it end in an ellipsis. The relative phrase already says the same thing
/// and the date lives on the record.
void main() {
  setUpAll(() async {
    final FontLoader plex = FontLoader('IBMPlexSansArabic');
    for (final String weight in <String>[
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
    ]) {
      plex.addFont(
        rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'),
      );
    }
    await plex.load();
  });

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

  testWidgets('no attention row is clipped at 360', (WidgetTester tester) async {
    await seedLedger(db);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpDhimmah(tester, db: db);
    await settle(tester);

    final Finder compounds = find.descendant(
      of: find.byType(DashboardScreen),
      matching: find.textContaining(' · '),
    );
    expect(compounds, findsWidgets);
    for (int i = 0; i < compounds.evaluate().length; i++) {
      final Finder text = compounds.at(i);
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'a dashboard line is clipped: "${paragraph.text.toPlainText()}"',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
