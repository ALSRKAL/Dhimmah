import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/core/widgets/app_card.dart';
import 'package:dhimmah/core/widgets/money_text.dart';
import 'package:dhimmah/core/widgets/record_rows.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/features/debts/person_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The gate against trailing content drifting to the middle of the screen.
///
/// An amount or a control belongs on the edge of its row, and the edge is not a
/// matter of taste here: in Arabic the trailing edge is the left one, and a row
/// laid out `start`-to-`end` will happily leave its last child parked where the
/// leading child ended. That is what a loose `Flexible` does — it shares the
/// free space and is then packed at the start — so the figure began on the 50%
/// line and the whole trailing half of the card stood empty.
///
/// Overflow tests cannot see this: nothing overflowed, everything fitted, and
/// the screen was simply wrong. So this gate measures. Every figure below is a
/// *painted* rectangle, taken from the paragraph's own glyph boxes and mapped
/// through whatever scale the figure was drawn at, not the widget's box: an
/// end-aligned `Text` in a tight box reports the full box while its ink sits on
/// the far edge, and measuring the box would both hide a real defect and invent
/// one.
///
/// Twenty configurations: five phone sizes, both scripts, two text scales. The
/// same ledger runs through all of them, so a layout that only holds together at
/// one size is a failure.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late Person ahmed;

  final DateTime today = dateOnly(DateTime.now());

  /// The five sizes the audit names, from the narrowest phone still in use to
  /// the widest.
  const List<Size> sizes = <Size>[
    Size(320, 640),
    Size(360, 780),
    Size(390, 844),
    Size(412, 915),
    Size(430, 932),
  ];
  const List<double> scales = <double>[1, 1.35];
  const List<bool> scripts = <bool>[false, true]; // false = Arabic

  setUp(() async {
    db = AppDatabase.memory();
    service = buildService(db);
    ahmed = await service.createPerson(
      const PersonDraft(name: 'محمد أحمد عبدالرحمن'),
    );
    final Person khalid = await service.createPerson(
      const PersonDraft(name: 'خالد العلي'),
    );

    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض سيارة',
        principalMinor: 400000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -30),
        dueAt: addDays(today, 10),
      ),
    );
    // Late, so the dashboard's attention list has a row to measure.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id],
        title: 'سلفة',
        principalMinor: 1100000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -40),
        dueAt: addDays(today, -3),
      ),
    );
    // A second currency, so the person's page draws its other-currency line.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id],
        title: 'تحويل',
        principalMinor: 14800,
        currency: AppCurrency.usd,
        issuedAt: addDays(today, -5),
        dueAt: addDays(today, 20),
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[khalid.id],
        title: 'دين',
        principalMinor: 225300,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -10),
        dueAt: addDays(today, 15),
      ),
    );
    // A balance short enough that it cannot fill the half a loose `Flexible`
    // hands it. Without one, a trailing slot that is packed at the *start* of
    // its share looks correct simply because its content is as wide as the
    // share — which is exactly how the defect hid.
    final Person salem = await service.createPerson(
      const PersonDraft(name: 'سالم'),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[salem.id],
        title: 'باقي',
        principalMinor: 1000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -2),
        dueAt: addDays(today, 25),
      ),
    );

    await service.createIncome(
      IncomeDraft(
        name: 'راتب',
        amountMinor: 456500,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        dayOfMonth: 1,
      ),
    );
    // Unpaid and past its day, so the budget card draws all five rows,
    // including "of it, late".
    await service.createObligation(
      ObligationDraft(
        name: 'فاتورة الإنترنت',
        category: ObligationCategory.telecom,
        amountMinor: 100000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        dayOfMonth: 1,
      ),
    );
    await service.ensureOccurrences();
  });
  tearDown(() async => db.close());

  // ---------------------------------------------------------------------------
  // Geometry.
  // ---------------------------------------------------------------------------

  /// The painted glyph bounds of a text, in global coordinates.
  ///
  /// The paragraph's own selection boxes are the only honest answer to "where
  /// is this drawn": a `Text` given a tight box reports that box, and an amount
  /// scaled down by a `FittedBox` reports its unscaled size until the transform
  /// is applied.
  Rect painted(WidgetTester tester, Finder finder) {
    // A `MoneyText` may wrap its paragraph in a `FittedBox`, so the first
    // render object under the widget is the scaler, not the paragraph. Find the
    // `RichText` itself and measure that; its own transform already carries the
    // scale this row drew it at.
    final Finder paragraphFinder =
        find.descendant(of: finder, matching: find.byType(RichText)).first;
    final RenderParagraph paragraph =
        tester.renderObject<RenderParagraph>(paragraphFinder);
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

  /// The edge that must be flush: left in Arabic, right in English.
  double trailing(Rect rect, TextDirection direction) =>
      direction == TextDirection.rtl ? rect.left : rect.right;

  /// How far the painted content sits inside its anchor's trailing edge.
  ///
  /// Negative means it went past it, which is worse than floating.
  double insetFromEdge(Rect painted, Rect anchor, TextDirection direction) =>
      direction == TextDirection.rtl
          ? painted.left - anchor.left
          : anchor.right - painted.right;

  /// Asserts the content is on the trailing edge of [anchor].
  ///
  /// The tolerance is the row's own horizontal padding plus a few pixels of
  /// drawing slop. Sixty is the line the audit drew: past it the content is
  /// floating in the middle, not merely inset.
  void expectOnEdge(
    Rect painted,
    Rect anchor,
    TextDirection direction,
    String what, {
    double tolerance = 44,
  }) {
    final double inset = insetFromEdge(painted, anchor, direction);
    expect(
      inset,
      lessThan(60),
      reason: '$what is stranded ${inset.toStringAsFixed(1)} px inside its '
          'row — that is the middle of the screen, which is the defect this '
          'gate exists for',
    );
    expect(
      inset,
      greaterThanOrEqualTo(-1),
      reason: '$what runs ${(-inset).toStringAsFixed(1)} px past its edge',
    );
    expect(
      inset,
      lessThanOrEqualTo(tolerance),
      reason: '$what sits ${inset.toStringAsFixed(1)} px inside its row; the '
          'row padding is at most $tolerance',
    );
  }

  /// Asserts several elements share one vertical axis on the trailing edge.
  void expectSameAxis(
    List<Rect> rects,
    TextDirection direction,
    String what, {
    double tolerance = 4,
  }) {
    final List<double> edges = <double>[
      for (final Rect rect in rects) trailing(rect, direction),
    ];
    expect(edges, isNotEmpty, reason: 'nothing to compare for $what');
    for (final double edge in edges) {
      expect(
        (edge - edges.first).abs(),
        lessThanOrEqualTo(tolerance),
        reason: '$what do not share a trailing edge: $edges',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation.
  // ---------------------------------------------------------------------------

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 2; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  /// The labels the walk needs, in the script under test.
  ({String people, String ledger, String obligations, String more,
    String reports, String payment, String filters, String manageIncome,
    String income, String commitments, String paid, String unpaid,
    String overdue, String net}) labels(bool english) => english
      ? (
          people: 'People',
          ledger: 'Ledger',
          obligations: 'Obligations',
          more: 'More',
          reports: 'Reports',
          payment: 'Record a payment',
          filters: 'Filters',
          manageIncome: 'Manage income',
          income: 'Total income',
          commitments: 'Total commitments',
          paid: 'Paid so far',
          unpaid: 'Still to pay',
          overdue: 'Of it, late',
          net: 'Net',
        )
      : (
          people: 'الأشخاص',
          ledger: 'السجل',
          obligations: 'التزامات',
          more: 'المزيد',
          reports: 'التقارير',
          payment: 'تسجيل دفعة',
          filters: 'الفلاتر',
          manageIncome: 'إدارة الدخل',
          income: 'إجمالي الدخل',
          commitments: 'إجمالي الالتزامات',
          paid: 'دفعت منها',
          unpaid: 'متبقٍ دفعه',
          overdue: 'منها متأخر',
          net: 'الصافي',
        );

  /// The trailing edge of the screen itself.
  Rect screenRect(WidgetTester tester) {
    final Size size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return Offset.zero & size;
  }

  // ---------------------------------------------------------------------------
  // The walk.
  // ---------------------------------------------------------------------------

  Future<void> walk(WidgetTester tester, {required bool english}) async {
    final TextDirection direction =
        english ? TextDirection.ltr : TextDirection.rtl;
    final ({
      String people,
      String ledger,
      String obligations,
      String more,
      String reports,
      String payment,
      String filters,
      String manageIncome,
      String income,
      String commitments,
      String paid,
      String unpaid,
      String overdue,
      String net,
    }) text = labels(english);
    final Rect screen = screenRect(tester);

    // ---- 1. The dashboard: a figure inside the attention card. ------------
    final Finder attentionMoney = find
        .descendant(
          of: find.byType(AppCard),
          matching: find.textContaining('11,000'),
        )
        .first;
    expect(attentionMoney, findsOneWidget);
    final Finder attentionCard =
        find.ancestor(of: attentionMoney, matching: find.byType(AppCard)).first;
    expectOnEdge(
      painted(tester, attentionMoney),
      tester.getRect(attentionCard),
      direction,
      'the dashboard attention figure',
    );

    // ---- 2. The people list: every balance, and the rule under them. ------
    await tapTab(tester, text.people);
    final Finder balances = find.byType(MoneyText);
    expect(balances, findsWidgets, reason: 'the people list drew no balances');
    final List<Rect> balanceRects = <Rect>[];
    for (int i = 0; i < balances.evaluate().length; i++) {
      final Finder money = balances.at(i);
      final Rect rect = painted(tester, money);
      final Finder row =
          find.ancestor(of: money, matching: find.byType(InkWell)).first;
      expectOnEdge(rect, tester.getRect(row), direction, 'a person balance');
      balanceRects.add(rect);
    }
    expectSameAxis(balanceRects, direction, 'the person balances');
    // The `Divider` widget spans the row; the rule it paints is inset inside
    // it, so the line itself is the `DecoratedBox` it builds.
    final Finder dividerLine = find
        .descendant(
          of: find.byType(Divider).first,
          matching: find.byType(DecoratedBox),
        )
        .first;
    final Rect divider = tester.getRect(dividerLine);
    expect(
      (trailing(balanceRects.first, direction) -
              trailing(divider, direction))
          .abs(),
      lessThanOrEqualTo(4),
      reason: 'the balances and the rule under them end on different axes: '
          '${trailing(balanceRects.first, direction)} against '
          '${trailing(divider, direction)}',
    );

    // ---- 3. The person's page: the other-currency line. -------------------
    await tester.tap(find.textContaining('محمد').first);
    await settle(tester);
    final Finder otherCurrency = find.textContaining('148').first;
    expect(otherCurrency, findsOneWidget);
    final Finder personCard =
        find.ancestor(of: otherCurrency, matching: find.byType(AppCard)).first;
    expectOnEdge(
      painted(tester, otherCurrency),
      tester.getRect(personCard),
      direction,
      'the other-currency figure',
    );

    // ---- 4. The payment sheet: every allocation cell. --------------------
    await tester.tap(find.textContaining(text.payment).first);
    await settle(tester);
    expect(find.byType(PersonPaymentSheet), findsOneWidget);
    // A row with nothing allocated says so in words instead of drawing a zero,
    // so the plan has to hold money before there are cells to measure.
    await tester.enterText(find.byType(EditableText).first, '1000');
    await settle(tester);
    final Finder sheet = find.byType(PersonPaymentSheet);
    final Finder allocationCard = find
        .descendant(of: sheet, matching: find.byType(AppCard))
        .first;
    final Rect allocationRect = tester.getRect(allocationCard);
    final Finder cells =
        find.descendant(of: allocationCard, matching: find.byType(MoneyText));
    expect(cells, findsWidgets, reason: 'the allocation preview drew no cells');
    final List<Rect> cellRects = <Rect>[
      for (int i = 0; i < cells.evaluate().length; i++)
        painted(tester, cells.at(i)),
    ];
    for (final Rect cell in cellRects) {
      expectOnEdge(cell, allocationRect, direction, 'an allocation cell');
    }
    expectSameAxis(cellRects, direction, 'the allocation cells');
    Navigator.of(tester.element(sheet)).pop();
    await settle(tester);

    // Back to the shell; the person's page is a full-screen route.
    for (int i = 0; i < 3 && find.byType(NavigationBar).evaluate().isEmpty; i++) {
      await tester.tap(find.byType(BackButton).first);
      await settle(tester);
    }
    expect(find.byType(NavigationBar), findsOneWidget);

    // ---- 5. The ledger: the controls, against the amount beneath them. ---
    await tapTab(tester, text.ledger);
    final Finder filterButton = find
        .ancestor(
          of: find.text(text.filters),
          matching: find.byType(TextButton),
        )
        .first;
    final Finder sortButton = find.byType(PopupMenuButton<DebtSortOrder>);
    expect(filterButton, findsOneWidget);
    expect(sortButton, findsOneWidget);
    final Rect filterRect = tester.getRect(filterButton);
    final Rect sortRect = tester.getRect(sortButton);
    // The two controls are one group: the sort mark is its outermost element,
    // so that is the edge that has to reach the row's trailing edge. The filter
    // button sits immediately inside it — one touch target away, not stranded.
    expectOnEdge(sortRect, screen, direction, 'the sort button');
    expect(
      (trailing(filterRect, direction) - trailing(sortRect, direction)).abs(),
      lessThanOrEqualTo(64),
      reason: 'the filter button and the sort mark are not packed into one '
          'group: ${trailing(filterRect, direction)} against '
          '${trailing(sortRect, direction)}',
    );

    final Finder firstAmount = find
        .descendant(
          of: find.byType(DebtRowTile).first,
          matching: find.byType(MoneyText),
        )
        .first;
    final double amountEdge = trailing(tester.getRect(firstAmount), direction);
    // The mark the eye sees, not the 48-pixel target around it: the audit's
    // rule is that the sort mark and the amount under it read as one column.
    final Finder sortIcon = find
        .descendant(of: sortButton, matching: find.byType(Icon))
        .first;
    expect(
      (trailing(tester.getRect(sortIcon), direction) - amountEdge).abs(),
      lessThanOrEqualTo(8),
      reason: 'the sort mark and the record amount under it do not share a '
          'vertical axis: '
          '${trailing(tester.getRect(sortIcon), direction)} against $amountEdge',
    );

    // ---- 6. The budget card: every figure, and the chevron below them. ---
    await tapTab(tester, text.obligations);
    // The card is drawn from a stream that answers after the tab opens; until
    // it does, the card shows its invitation state and holds no figures at all.
    for (int i = 0;
        i < 8 && find.text(text.manageIncome).evaluate().isEmpty;
        i++) {
      await settle(tester);
    }
    expect(
      find.text(text.manageIncome),
      findsOneWidget,
      reason: 'the budget card never left its invitation state',
    );
    final Finder budgetCard = find.byType(AppCard).first;
    final Rect cardRect = tester.getRect(budgetCard);
    final List<Rect> valueRects = <Rect>[];
    for (final String label in <String>[
      text.income,
      text.commitments,
      text.paid,
      text.unpaid,
      text.overdue,
    ]) {
      final Finder labelFinder =
          find.descendant(of: budgetCard, matching: find.text(label));
      if (labelFinder.evaluate().isEmpty) continue; // drawn only when late > 0
      final Finder row =
          find.ancestor(of: labelFinder, matching: find.byType(Row)).first;
      final Finder value =
          find.descendant(of: row, matching: find.byType(Text)).last;
      final Rect rect = painted(tester, value);
      expectOnEdge(rect, cardRect, direction, 'the budget row "$label"');
      valueRects.add(rect);
    }
    expect(valueRects, hasLength(5),
        reason: 'the budget card drew ${valueRects.length} of its five figures');
    expectSameAxis(valueRects, direction, 'the budget figures');

    // The chevron on the "manage income" line is the card's own trailing mark;
    // every figure above it has to end on the same axis.
    final Finder chevron = find.descendant(
      of: budgetCard,
      matching: find.byIcon(
        direction == TextDirection.rtl
            ? Icons.chevron_left
            : Icons.chevron_right,
      ),
    );
    expect(chevron, findsOneWidget);
    final Rect chevronRect = tester.getRect(chevron);
    for (final Rect value in valueRects) {
      expect(
        (trailing(value, direction) - trailing(chevronRect, direction)).abs(),
        lessThanOrEqualTo(4),
        reason: 'a budget figure does not end on the chevron\'s axis: '
            '${trailing(value, direction)} against '
            '${trailing(chevronRect, direction)}',
      );
    }
    expect(find.text(text.manageIncome), findsOneWidget);

    // ---- 7. Reports: the position card's rows. ---------------------------
    await tapTab(tester, text.more);
    await tester.tap(find.text(text.reports));
    await settle(tester);
    // Let the route transition finish before dragging; a drag that lands on the
    // transition's barrier scrolls nothing and warns.
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    final Finder netLabel = find.text(text.net);
    for (int i = 0; i < 10 && netLabel.evaluate().isEmpty; i++) {
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -260),
      );
      await settle(tester);
    }
    expect(netLabel, findsOneWidget);
    await settle(tester);
    final Finder positionCard =
        find.ancestor(of: netLabel, matching: find.byType(AppCard)).first;
    final Rect positionRect = tester.getRect(positionCard);
    final Finder positionRows =
        find.descendant(of: positionCard, matching: find.byType(DetailRow));
    expect(positionRows, findsNWidgets(3));
    final List<Rect> positionValues = <Rect>[];
    for (int i = 0; i < 3; i++) {
      final Finder value = find
          .descendant(
            of: positionRows.at(i),
            matching: find.byType(Text),
          )
          .last;
      final Rect rect = painted(tester, value);
      expectOnEdge(rect, positionRect, direction, 'a report position figure');
      positionValues.add(rect);
    }
    expectSameAxis(positionValues, direction, 'the report position figures');
  }

  Future<void> pumpAt(
    WidgetTester tester, {
    required Size size,
    required double scale,
    required bool english,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(
        languagePreference: english
            ? LanguagePreference.english
            : LanguagePreference.arabic,
        numerals: NumeralsStyle.latin,
      ),
    );
    await settle(tester);
  }

  for (final Size size in sizes) {
    for (final bool english in scripts) {
      for (final double scale in scales) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()}, '
          '${english ? 'LTR' : 'RTL'}, ${scale}x: every trailing figure sits '
          'on its edge',
          (WidgetTester tester) async {
            await pumpAt(
              tester,
              size: size,
              scale: scale,
              english: english,
            );
            await walk(tester, english: english);
          },
        );
      }
    }
  }
}
