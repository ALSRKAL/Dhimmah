import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/money_text.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/features/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The dashboard's longest attention phrases stay whole in both languages.
///
/// These pump the real row at its real width, after the amount and every margin
/// have taken their share. A standalone TextPainter would miss the original bug.
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

  Future<void> seedAttentionRows(AppLanguage language) async {
    final DateTime today = DateTime(2026, 11, 24);
    final LedgerService service = buildService(
      db,
      language: language,
      clock: () => today,
    );
    final Person person = await service.createPerson(
      const PersonDraft(name: 'شخص اختبار العرض'),
    );

    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[person.id],
        title: 'دين متأخر',
        principalMinor: 9876500,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -150),
        dueAt: addDays(today, -120),
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[person.id],
        title: 'دين قريب',
        principalMinor: 9876500,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 6),
      ),
    );
    final Obligation obligation = await service.createObligation(
      ObligationDraft(
        name: 'التزام متأخر',
        category: ObligationCategory.other,
        amountMinor: 9876500,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: addDays(today, -120),
        dayOfMonth: addDays(today, -120).day,
      ),
    );
    await service.ensureOccurrences();
    await service.obligations.saveOccurrence(
      ObligationOccurrence(
        id: 'oldest-attention-period',
        obligationId: obligation.id,
        periodKey: '2026-07',
        dueAt: addDays(today, -120),
        amountMinor: 9876500,
        status: ObligationStatus.upcoming,
        createdAt: today,
        updatedAt: today,
      ),
    );
    final List<ObligationOccurrence> occurrences =
        await service.obligations.occurrencesFor(obligation.id)
          ..sort(
            (ObligationOccurrence a, ObligationOccurrence b) =>
                a.dueAt.compareTo(b.dueAt),
          );
    for (final ObligationOccurrence occurrence in occurrences.skip(1)) {
      await service.markObligationPaid(
        ObligationInstance(obligation: obligation, occurrence: occurrence),
      );
    }
  }

  for (final AppLanguage language in AppLanguage.values) {
    for (final double width in <double>[360, 411]) {
      for (final double scale in <double>[1.0, 1.3]) {
        testWidgets(
          'attention rows stay whole: ${language.name}, ${width}dp, ${scale}x',
          (WidgetTester tester) async {
            await seedAttentionRows(language);
            tester.view.physicalSize = Size(width * 3, 1200 * 3);
            tester.view.devicePixelRatio = 3;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );

            await pumpDhimmah(
              tester,
              db: db,
              settings: AppSettings.initial.copyWith(
                languagePreference: LanguagePreference.of(language),
                notificationsEnabled: false,
              ),
              clock: () => DateTime(2026, 11, 24),
            );
            await settle(tester);

            final bool arabic = language == AppLanguage.arabic;
            final List<String> expected = arabic
                ? <String>[
                    'التزام · متأخر 120 يومًا',
                    'لي · متأخر 120 يومًا',
                    'لي · خلال 6 أيام',
                  ]
                : <String>[
                    'Obligation · 120d late',
                    'Owed to Me · 120d late',
                    'Owed to Me · In 6d',
                  ];

            for (final String phrase in expected) {
              final Finder text = find.descendant(
                of: find.byType(DashboardScreen),
                matching: find.text(phrase),
              );
              expect(text, findsOneWidget, reason: phrase);
              final RenderParagraph paragraph = tester
                  .renderObject<RenderParagraph>(
                    find.descendant(of: text, matching: find.byType(RichText)),
                  );
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: 'a dashboard line is clipped: "$phrase"',
              );
              expect(paragraph.size.width, greaterThan(0));

              final Finder row = find
                  .ancestor(of: text, matching: find.byType(InkWell))
                  .first;
              final MoneyText money = tester.widget<MoneyText>(
                find.descendant(of: row, matching: find.byType(MoneyText)),
              );
              expect(money.money.minorUnits, 9876500);
              final RenderParagraph amount = tester
                  .renderObject<RenderParagraph>(
                    find.descendant(
                      of: find.descendant(
                        of: row,
                        matching: find.byType(MoneyText),
                      ),
                      matching: find.byType(RichText),
                    ),
                  );
              final Rect textRect =
                  paragraph.localToGlobal(Offset.zero) & paragraph.size;
              final Rect amountRect =
                  amount.localToGlobal(Offset.zero) & amount.size;
              expect(textRect.overlaps(amountRect), isFalse);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
