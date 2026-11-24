import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/people/people_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The three actions on a person's page, at the sizes a phone really uses.
///
/// The primary action takes a line of its own and the two secondaries share the
/// next one. No label is allowed to wrap, shrink, or gain an ellipsis: the
/// buttons move instead. The real IBM Plex Sans Arabic files are loaded here
/// because the test engine's fallback font gives every glyph the em's full
/// width, which no Arabic or Latin label on a phone actually has.
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

  Future<void> openKhalid(
    WidgetTester tester, {
    required AppLanguage language,
    required double scale,
    required double width,
  }) async {
    await seedLedger(db);
    tester.view.physicalSize = Size(width * 3, 900 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(
        languagePreference: LanguagePreference.of(language),
      ),
    );
    await settle(tester);

    await tester.tap(
      find.text(language == AppLanguage.arabic ? 'الأشخاص' : 'People').last,
    );
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(PeopleScreen),
        matching: find.text('خالد العلي'),
      ),
    );
    await settle(tester);
  }

  for (final AppLanguage language in AppLanguage.values) {
    for (final double scale in <double>[1.0, 1.3, 2.0]) {
      for (final double width in <double>[320, 360, 412]) {
        testWidgets(
          'the person actions at ${language.name}, ${scale}x, ${width}px',
          (WidgetTester tester) async {
            await openKhalid(
              tester,
              language: language,
              scale: scale,
              width: width,
            );

            final bool arabic = language == AppLanguage.arabic;
            final String primaryLabel =
                arabic ? 'تسجيل دفعة' : 'Record a payment';
            final String addDebtLabel = arabic ? 'إضافة دين' : 'Add a debt';
            final String statementLabel = arabic ? 'كشف' : 'Statement';

            Finder buttonFor(String label) => find
                .ancestor(
                  of: find.text(label),
                  matching: find.byWidgetPredicate(
                    (Widget widget) =>
                        widget is FilledButton || widget is OutlinedButton,
                  ),
                )
                .first;

            for (final String label in <String>[
              primaryLabel,
              addDebtLabel,
              statementLabel,
            ]) {
              expect(
                find.text(label),
                findsOneWidget,
                reason: 'the person page has one "$label" action',
              );
              final RenderParagraph paragraph = tester.renderObject<
                  RenderParagraph>(
                find.descendant(
                  of: find.text(label),
                  matching: find.byType(RichText),
                ),
              );
              expect(paragraph.maxLines, 1, reason: '"$label" is one line');
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '"$label" fits its button without wrapping',
              );
            }

            expect(
              tester.takeException(),
              isNull,
              reason: 'no action overflows at $scale x on $width',
            );

            final Rect primaryRect = tester.getRect(buttonFor(primaryLabel));
            final Rect addDebtRect = tester.getRect(buttonFor(addDebtLabel));
            final Rect statementRect =
                tester.getRect(buttonFor(statementLabel));

            // Full width inside the bar's 16-pixel side margins.
            expect(
              primaryRect.width,
              closeTo(width - 32, 0.5),
              reason: 'the primary action owns its row',
            );
            // The two secondary actions sit on one row below the primary.
            expect(
              addDebtRect.center.dy,
              closeTo(statementRect.center.dy, 0.5),
              reason: 'add debt and statement share the second row',
            );
            expect(
              addDebtRect.top,
              greaterThan(primaryRect.bottom),
              reason: 'the second row starts below the primary',
            );
            // The row is full: the statement keeps its content width and
            // adding a debt takes the rest, with the 4-pixel gap between them.
            expect(
              addDebtRect.width + statementRect.width + 4,
              closeTo(width - 32, 0.5),
              reason: 'the second row leaves no empty strip',
            );
            expect(
              addDebtRect.width,
              greaterThan(statementRect.width),
              reason: 'the wider action is the one that can flex',
            );
          },
        );
      }
    }
  }
}
