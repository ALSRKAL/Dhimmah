import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/services/amount_rules.dart';
import 'package:dhimmah/features/people/person_picker_sheet.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What a phone's keyboard can put into an amount field, and what comes out.
///
/// An Arabic keyboard types Arabic-Indic digits (٥), a Persian one types
/// extended Arabic-Indic ones (۵), and an Arabic comma or dot may be either the
/// decimal or the grouping mark. The field used to filter those characters out —
/// so the digits a user typed were silently deleted as they typed them, and the
/// form then refused a save over an empty field. Everything here is about that
/// path: what the field accepts, what it makes of it, and where the ceiling is.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  group('the field', () {
    late List<int> accepted;
    late int rejected;

    Future<void> pumpField(WidgetTester tester, {int? initialMinor}) async {
      accepted = <int>[];
      rejected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AmountField(
                label: 'المبلغ',
                currency: AppCurrency.inr,
                initialMinor: initialMinor,
                onChanged: accepted.add,
                onRejected: () => rejected++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    String shown(WidgetTester tester) => tester
        .widget<EditableText>(
          find.descendant(
            of: find.byType(AmountField),
            matching: find.byType(EditableText),
          ),
        )
        .controller
        .text;

    testWidgets('Arabic-Indic digits are read as the numbers they are',
        (WidgetTester tester) async {
      await pumpField(tester);

      await tester.enterText(find.byType(AmountField), '٥٠٠٠');
      await tester.pump();

      // ٥٠٠٠ is five thousand rupees: 5,000 in the field, 500,000 in the ledger.
      expect(shown(tester), '٥٠٠٠', reason: 'what the user typed is still there');
      expect(accepted, isNotEmpty);
      expect(accepted.last, 500000);
      expect(rejected, 0);
    });

    testWidgets('the Arabic decimal mark and the Western one agree',
        (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '١٢٥٫٥٠');
      await tester.pump();
      expect(accepted.last, 12550, reason: '125.50 in the Arabic notation');

      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '١٢٥.٥٠');
      await tester.pump();
      expect(accepted.last, 12550, reason: 'and in the Western one');
    });

    testWidgets('the Arabic thousands mark is a separator, not a decimal point',
        (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '١٢٥٬٥٠٠');
      await tester.pump();

      expect(
        accepted.last,
        12550000,
        reason: '125,500 — reading ٬ as a decimal point would make it 125.5',
      );
    });

    testWidgets('extended Arabic-Indic digits are read as well',
        (WidgetTester tester) async {
      // What a Persian or Urdu keyboard produces.
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '۵۰۰۰');
      await tester.pump();
      expect(accepted.last, 500000);
    });

    testWidgets('grouping is ignored in either notation', (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '١٢٬٣٤٥٫٦٧');
      await tester.pump();
      expect(accepted.last, 1234567);
    });

    testWidgets('the largest amount is accepted, in either notation',
        (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '١٠٠٠٠٠٠٠٠٠');
      await tester.pump();

      expect(shown(tester), '١٠٠٠٠٠٠٠٠٠');
      expect(
        accepted.last,
        AmountRules.maxMinor,
        reason: 'one billion, the ceiling the domain allows',
      );
      expect(rejected, 0);
    });

    testWidgets('one digit more is refused, and the caller is told',
        (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '١٠٠٠٠٠٠٠٠٠٠');
      await tester.pump();

      expect(find.text('المبلغ كبير جدًا.'), findsOneWidget);
      expect(
        rejected,
        1,
        reason: 'the form has to stop trusting the figure it was last given',
      );
      expect(
        accepted,
        isEmpty,
        reason: 'nothing acceptable was ever typed here',
      );
    });

    testWidgets('a Western figure past the ceiling is refused the same way',
        (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '2000000000');
      await tester.pump();

      expect(find.text('المبلغ كبير جدًا.'), findsOneWidget);
      expect(rejected, 1);
    });

    testWidgets('a typed figure that stops being money tells the caller at once',
        (WidgetTester tester) async {
      await pumpField(tester);
      await tester.enterText(find.byType(AmountField), '٥٠٠');
      await tester.pump();
      expect(accepted.last, 50000);

      // Clearing the field is not a rejection — it is "nothing typed yet" — so
      // the last accepted figure stands and no error is raised.
      await tester.enterText(find.byType(AmountField), '');
      await tester.pump();
      expect(rejected, 0);
      expect(find.text('المبلغ كبير جدًا.'), findsNothing);
    });
  });

  group('through the form', () {
    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<void> reveal(WidgetTester tester, Finder target) async {
      for (int i = 0; i < 12 && target.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await settle(tester);
      }
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target.first);
        await settle(tester);
      }
    }

    testWidgets('a debt typed entirely on an Arabic keyboard is saved as typed',
        (WidgetTester tester) async {
      final Person ahmed =
          await buildService(db).createPerson(const PersonDraft(name: 'أحمد'));
      await pumpDhimmah(tester, db: db);
      await settle(tester);

      await tester.tap(find.text('إضافة أول دين'));
      await settle(tester);

      // Who it is with.
      await reveal(tester, find.text('اختر شخصًا أو أضف جديدًا'));
      await tester.tap(find.text('اختر شخصًا أو أضف جديدًا'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(PeoplePickerSheet),
          matching: find.text('أحمد'),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('تم'));
      await settle(tester);

      // Which side, and the amount — typed with the digits an Arabic phone
      // produces, which is the whole point of this test.
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('عليّ').first);
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '٥٠٠٠',
      );
      await settle(tester);

      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      final List<DebtRow> stored = await db.debtsDao.getAll();
      expect(stored, hasLength(1), reason: 'the save went through');
      expect(
        stored.single.principalMinor,
        500000,
        reason: 'five thousand rupees, not the empty amount the field used to '
            'filter the digits down to',
      );
      expect(
        await db.debtsDao.participantsFor(stored.single.id),
        <String>[ahmed.id],
      );
    });

    testWidgets('an Arabic figure past the ceiling cannot be saved',
        (WidgetTester tester) async {
      await pumpDhimmah(tester, db: db);
      await settle(tester);
      await tester.tap(find.text('إضافة أول دين'));
      await settle(tester);

      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await settle(tester);
      await tester.tap(find.text('عليّ').first);
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextFormField),
        ),
        '٩٩٩٩٩٩٩٩٩٩٩',
      );
      await settle(tester);
      expect(find.text('المبلغ كبير جدًا.'), findsOneWidget);

      await tester.tap(find.text('حفظ الدين'));
      await settle(tester);

      expect(
        await db.debtsDao.getAll(),
        isEmpty,
        reason: 'the field refused the figure and the form did not write one',
      );
      expect(find.text('أدخل مبلغًا صحيحًا أكبر من صفر.'), findsOneWidget);
    });
  });
}
