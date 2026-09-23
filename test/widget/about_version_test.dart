import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/features/settings/about_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The version the screen shows is the version that is installed.
///
/// The About screen used to print a hardcoded `1.0.0`, and the settings screen
/// printed another one. Both were correct until the first release and then
/// reported the wrong build to whoever was helping the user — which is exactly
/// when a version number is read.
void main() {
  Future<void> pumpAbout(WidgetTester tester, String language) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: const AboutScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it prints what the package reports, not a literal',
      (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Dhimmah',
      packageName: 'com.dhimmah.dhimmah',
      version: '2.3.1',
      buildNumber: '17',
      buildSignature: '',
    );

    await pumpAbout(tester, 'en');

    // Both numbers, because they answer different questions: the name is what a
    // person reads, the build is what Play compares and what support asks for.
    expect(find.textContaining('2.3.1'), findsOneWidget);
    expect(find.textContaining('17'), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsNothing);
  });

  testWidgets('the Arabic screen carries the same numbers',
      (WidgetTester tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Dhimmah',
      packageName: 'com.dhimmah.dhimmah',
      version: '2.3.1',
      buildNumber: '17',
      buildSignature: '',
    );

    await pumpAbout(tester, 'ar');
    expect(find.textContaining('2.3.1'), findsOneWidget);
    expect(find.textContaining('17'), findsOneWidget);
  });

  testWidgets('a platform that will not answer does not crash the screen',
      (WidgetTester tester) async {
    // The plugin has no implementation under `flutter test`, which is the same
    // shape as a platform that refuses: the screen still has to draw, and it
    // must not claim a version it does not know.
    await pumpAbout(tester, 'en');
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.textContaining('1.0.0'), findsNothing);
  });
}
