import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/features/settings/pin_sheet.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PIN keypad is a dialer: 1 top-left, in Arabic as in English.
///
/// On the device the settings sheet's own grid (it builds one instead of using
/// PinKeypad) printed "3 2 1" across the top row under the RTL locale — the
/// exact mirroring PinKeypad documents having fixed at its own call site.
void main() {
  testWidgets('the PIN sheet keypad reads 1 2 3 left to right',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: PinSheet(mode: PinSheetMode.create),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1'), findsOneWidget);
    final double x1 = tester.getCenter(find.text('1')).dx;
    final double x2 = tester.getCenter(find.text('2')).dx;
    final double x3 = tester.getCenter(find.text('3')).dx;

    expect(x1, lessThan(x2));
    expect(x2, lessThan(x3),
        reason: 'the dialer must not mirror under the RTL locale');
  });
}
