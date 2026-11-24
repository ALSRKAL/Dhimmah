import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/record_rows.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// A user's title must not turn the timing around it back to front.
///
/// In English, an Arabic debt title beside "11 days late" without a direction
/// isolate painted as `11 · قرض سيارة days late`. These measure the painted
/// boxes, not the logical string: a correct direction is a visible order.
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

  Future<void> openLedger(
    WidgetTester tester, {
    required String title,
    required AppLanguage language,
  }) async {
    final DateTime today = dateOnly(DateTime.now());
    final seeded = await seedLedger(db);
    await buildService(db).createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[seeded.ahmed.id],
        title: title,
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -20),
        dueAt: addDays(today, -11),
      ),
    );

    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(
        languagePreference: LanguagePreference.of(language),
      ),
    );
    await settle(tester);
    await tester.tap(
      find.text(language == AppLanguage.arabic ? 'السجل' : 'Ledger').last,
    );
    await settle(tester);
  }

  /// The painted box of [needle] inside the row's subtitle.
  Rect paintedPart(WidgetTester tester, String title, String needle) {
    final Finder subtitle = find.descendant(
      of: find.ancestor(
        of: find.textContaining(title),
        matching: find.byType(DebtRowTile),
      ).first,
      matching: find.textContaining(title),
    );
    expect(subtitle, findsOneWidget);
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: subtitle, matching: find.byType(RichText)),
    );
    final String text = paragraph.text.toPlainText();
    final int start = text.indexOf(needle);
    expect(start, isNonNegative, reason: '"$needle" is in "$text"');
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + needle.length),
    );
    expect(boxes, isNotEmpty, reason: 'nothing was painted for "$needle"');
    Rect rect = boxes.first.toRect();
    for (final TextBox box in boxes.skip(1)) {
      rect = rect.expandToInclude(box.toRect());
    }
    return rect;
  }

  testWidgets('an English line puts an Arabic title after the timing',
      (WidgetTester tester) async {
    await openLedger(
      tester,
      title: 'عقد الإيجار',
      language: AppLanguage.english,
    );

    final Rect timing = paintedPart(tester, 'عقد الإيجار', 'days late');
    final Rect title = paintedPart(tester, 'عقد الإيجار', 'عقد الإيجار');

    expect(
      timing.left,
      lessThan(title.left),
      reason: 'the timing has to be the first thing the eye reads: '
          'timing=$timing title=$title',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Arabic line puts a Latin title before the timing',
      (WidgetTester tester) async {
    await openLedger(
      tester,
      title: 'Car loan',
      language: AppLanguage.arabic,
    );

    final Rect timing = paintedPart(tester, 'Car loan', 'متأخر');
    final Rect title = paintedPart(tester, 'Car loan', 'Car loan');

    expect(
      title.left,
      greaterThan(timing.left),
      reason: 'Arabic reads the title first, on the right: '
          'title=$title timing=$timing',
    );
    expect(tester.takeException(), isNull);
  });
}
