import 'package:dhimmah/core/theme/app_icons.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The fixes from `UX-ISSUES.md` that change what a screen *says*.
///
/// Each one was a place where the screen could be read wrongly: a figure
/// that carried its meaning in colour alone, a total that added two opposite
/// directions together, a row named after the page it was on.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await seedLedger(db);
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

  testWidgets('UX-01, UX-21: a person row names its side and its open debts',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);

    // Ahmed owes nothing to me in rupees but I owe him on the car loan: the
    // figure says which side it is on in words, not only in red.
    expect(find.text('عليّ'), findsWidgets);
    // Khalid's one debt is open, and the count says so.
    expect(find.text('دين مفتوح'), findsOneWidget);
  });

  testWidgets('UX-05: on a person page a row is named by its debt',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.text('محمد أحمد عبدالرحمن'));
    await settle(tester);

    expect(find.text('قرض سيارة'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
  });

  testWidgets('UX-03: the report never adds received and paid out together',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('المزيد').last);
    await settle(tester);
    await tester.tap(find.text('التقارير'));
    await settle(tester);

    expect(find.text('إجمالي ما تم سداده'), findsNothing);
    expect(find.text('حركة الشهر'), findsOneWidget);
    expect(find.text('ما تم استلامه'), findsOneWidget);
    expect(find.text('ما تم دفعه'), findsOneWidget);
  });

  testWidgets('UX-30: a debt has one share control, and it offers both kinds',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.text('خالد العلي'));
    await settle(tester);
    await tester.tap(find.text('سلفة'));
    await settle(tester);

    final Finder share = find.byTooltip('مشاركة');
    expect(share, findsOneWidget);
    await tester.tap(share);
    await settle(tester);
    expect(find.text('مشاركة كشف حساب PDF'), findsOneWidget);
    expect(find.text('مشاركة كنص سريع'), findsOneWidget);
  });

  testWidgets('UX-12: a row that needs attention says what kind it is',
      (WidgetTester tester) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);

    // The late car loan is on my side; the internet bill is an obligation.
    expect(find.textContaining('عليّ ·'), findsWidgets);
    expect(find.textContaining('التزام ·'), findsWidgets);
  });

  testWidgets('UX-22: an empty list has no filters above it',
      (WidgetTester tester) async {
    final AppDatabase empty = AppDatabase.memory();
    addTearDown(empty.close);
    await buildService(empty).createPerson(
      const PersonDraft(name: 'بلا ديون'),
    );
    await pumpDhimmah(tester, db: empty);
    await settle(tester);
    await tester.tap(find.text('الأشخاص').last);
    await settle(tester);
    await tester.tap(find.text('بلا ديون'));
    await settle(tester);

    expect(find.text('الفلاتر'), findsNothing);
    expect(find.byIcon(AppIcons.tune), findsNothing);
  });
}
