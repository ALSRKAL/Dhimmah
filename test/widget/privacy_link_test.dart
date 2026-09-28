import 'package:dhimmah/core/links.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Settings → Privacy policy opens the page, in the browser.
///
/// The policy lives outside the app (GitHub Pages), so the row's whole job is
/// to hand the URL over and to say so when nothing can take it. The fake opener
/// stands in for the browser so the test can watch exactly what the app would
/// open — and the app still holds no internet permission of its own.
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

  /// Dashboard → the gear → the row, which sits below the fold.
  Future<void> openSettingsAndTapRow(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);

    final Finder row = find.text('سياسة الخصوصية');
    for (int i = 0; i < 12 && row.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await settle(tester);
    }
    await tester.ensureVisible(row);
    await settle(tester);
    await tester.tap(row);
    await settle(tester);
  }

  testWidgets('the row opens the privacy policy URL', (WidgetTester tester) async {
    final List<Uri> opened = <Uri>[];
    await pumpDhimmah(
      tester,
      db: db,
      urlOpener: (Uri url) async {
        opened.add(url);
        return true;
      },
    );
    await settle(tester);

    await openSettingsAndTapRow(tester);

    expect(opened, <Uri>[AppLinks.privacyPolicy]);
    expect(opened.single.toString(),
        'https://alsrkal.github.io/Dhimmah/privacy/');
    expect(find.text('تعذّر فتح الرابط. تأكد من وجود متصفح على الجهاز.'),
        findsNothing,
        reason: 'opening succeeded; nothing to complain about');
  });

  testWidgets('when nothing can open the link, the screen says so',
      (WidgetTester tester) async {
    await pumpDhimmah(
      tester,
      db: db,
      urlOpener: (Uri url) async => false,
    );
    await settle(tester);

    await openSettingsAndTapRow(tester);

    expect(find.text('تعذّر فتح الرابط. تأكد من وجود متصفح على الجهاز.'),
        findsOneWidget);
  });
}
