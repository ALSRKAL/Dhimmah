import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The key iOS's decimal keypad does not have.
///
/// iOS draws a number pad with no return key, so a field whose only input is
/// digits had no way to dismiss the keyboard. The bar above the keys is that
/// key: one "Done", at the trailing edge. Android's keypad has its own, so the
/// bar is not drawn there.
void main() {
  Future<void> pumpField(
    WidgetTester tester, {
    required TargetPlatform platform,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light().copyWith(platform: platform),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AmountField(
              label: 'المبلغ',
              currency: AppCurrency.inr,
              onChanged: (int value) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> focusField(WidgetTester tester) async {
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
  }

  testWidgets('iOS shows a Done bar over the keyboard', (WidgetTester tester) async {
    await pumpField(tester, platform: TargetPlatform.iOS);
    expect(find.text('تم'), findsNothing, reason: 'not before the field is focused');

    await focusField(tester);
    expect(find.text('تم'), findsOneWidget);
  });

  testWidgets('Done leaves the field and takes the bar away',
      (WidgetTester tester) async {
    await pumpField(tester, platform: TargetPlatform.iOS);
    await focusField(tester);
    await tester.tap(find.text('تم'));
    await tester.pumpAndSettle();

    expect(find.text('تم'), findsNothing);
    final EditableText editable =
        tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('Android does not draw a second return key',
      (WidgetTester tester) async {
    await pumpField(tester, platform: TargetPlatform.android);
    await focusField(tester);
    expect(find.text('تم'), findsNothing);
  });
}
