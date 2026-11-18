import 'package:dhimmah/core/widgets/app_card.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The facts on a debt page end on one edge, in either script.
///
/// The audit's UX-97 was a value column that drifted into the middle of the
/// card. This test measures the painted glyphs rather than the widget boxes:
/// an end-aligned `Text` in a tight box reports the whole box while its ink
/// sits on one side, which would hide exactly the defect being checked.
void main() {
  late AppDatabase db;

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

  Rect painted(WidgetTester tester, Finder finder) {
    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)).first,
    );
    final String text = paragraph.text.toPlainText();
    final List<TextBox> boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    expect(boxes, isNotEmpty, reason: 'nothing was painted for "$text"');
    Rect local = boxes.first.toRect();
    for (final TextBox box in boxes.skip(1)) {
      local = local.expandToInclude(box.toRect());
    }
    return MatrixUtils.transformRect(paragraph.getTransformTo(null), local);
  }

  for (final bool english in <bool>[false, true]) {
    testWidgets(
      'the ${english ? 'English' : 'Arabic'} debt page ends its facts on one '
      'edge',
      (WidgetTester tester) async {
        await seedLedger(db);
        final TextDirection direction =
            english ? TextDirection.ltr : TextDirection.rtl;

        await pumpDhimmah(
          tester,
          db: db,
          settings: english
              ? AppSettings.initial.copyWith(
                  languagePreference:
                      LanguagePreference.of(AppLanguage.english),
                )
              : null,
        );
        await settle(tester);
        await tester.tap(find.text(english ? 'Ledger' : 'السجل').last);
        await settle(tester);
        await tester.tap(find.textContaining('قرض سيارة').first);
        await settle(tester);

        await tester.scrollUntilVisible(
          find.byType(DetailRow).first,
          280,
          scrollable: find.byType(Scrollable).last,
        );
        await settle(tester);

        final Finder rows = find.byType(DetailRow);
        expect(rows, findsWidgets, reason: 'the facts card drew no rows');
        final Rect card = tester.getRect(
          find.ancestor(of: rows.first, matching: find.byType(AppCard)).first,
        );
        final List<Rect> values = <Rect>[];
        for (int i = 0; i < rows.evaluate().length; i++) {
          final Finder row = rows.at(i);
          final DetailRow widget = tester.widget<DetailRow>(row);
          final Finder value = find.descendant(
            of: row,
            matching: find.text(widget.value),
          );
          expect(
            value,
            findsOneWidget,
            reason: 'the value of "${widget.label}" was not drawn',
          );
          final Rect rect = painted(tester, value);
          final double edge = direction == TextDirection.rtl
              ? rect.left
              : rect.right;
          final double cardInset = direction == TextDirection.rtl
              ? edge - card.left
              : card.right - edge;
          expect(
            cardInset,
            lessThan(60),
            reason: 'a fact on the debt page is stranded '
                '${cardInset.toStringAsFixed(1)} px inside its card',
          );
          expect(
            cardInset,
            greaterThanOrEqualTo(-1),
            reason: 'a fact runs past the card edge',
          );
          values.add(rect);
        }

        final List<double> edges = <double>[
          for (final Rect rect in values)
            direction == TextDirection.rtl ? rect.left : rect.right,
        ];
        for (final double edge in edges) {
          expect(
            (edge - edges.first).abs(),
            lessThanOrEqualTo(4),
            reason: 'the debt facts do not share one trailing edge: $edges',
          );
        }
      },
    );
  }
}
