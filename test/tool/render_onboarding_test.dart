import 'dart:async';

import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every onboarding step to `build/qa/onboarding/`, with the real
/// fonts, so the screens can be looked at rather than only asserted on.
///
///   flutter test --update-goldens --dart-define=DHIMMAH_QA=true \
///     test/tool/render_onboarding_test.dart
///
/// Skipped in the normal run: it proves nothing a widget test does not, and it
/// writes files. What it is for is the review — both languages, both themes, a
/// roomy phone and the smallest one at 1.5x text.
const bool _enabled = bool.fromEnvironment('DHIMMAH_QA');

void main() {
  const List<({String name, Size size, double text})> screens =
      <({String name, Size size, double text})>[
        (name: '390x844', size: Size(390, 844), text: 1.0),
        (name: '360x640-text1.5', size: Size(360, 640), text: 1.5),
      ];

  Future<void> loadFonts() async {
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
    final FontLoader icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  }

  /// Decodes the mark into the image cache before the first pump.
  ///
  /// Once a frame has asked for it, its load belongs to the test's fake clock,
  /// and waiting for it from real time never ends.
  Future<void> warmTheMark() async {
    final Completer<void> done = Completer<void>();
    final ImageStream stream = const AssetImage(
      'assets/icon/icon.png',
    ).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo _, bool _) {
        if (!done.isCompleted) done.complete();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? _) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    stream.addListener(listener);
    await done.future;
  }

  for (final String language in <String>['ar', 'en']) {
    for (final AppThemeMode theme in <AppThemeMode>[
      AppThemeMode.light,
      AppThemeMode.dark,
    ]) {
      for (final ({String name, Size size, double text}) screen in screens) {
        testWidgets('onboarding $language ${theme.name} ${screen.name}', (
          WidgetTester tester,
        ) async {
          await tester.runAsync(loadFonts);
          await tester.runAsync(warmTheMark);
          tester.view.physicalSize = screen.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = screen.text;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          tester.platformDispatcher.localesTestValue = <Locale>[
            Locale(language),
          ];

          final AppDatabase db = AppDatabase.memory();
          addTearDown(db.close);
          await db.settingsDao.write(
            AppSettings.initial.copyWith(themeMode: theme).toCompanion(),
          );
          final ProviderContainer container = ProviderContainer(
            overrides: [databaseProvider.overrideWithValue(db)],
          );
          addTearDown(container.dispose);
          await loadBootSettings(container);

          final GlobalKey frame = GlobalKey();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: frame,
                child: const DhimmahApp(onboardingCompleted: false),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final AppLocalizations l = lookupAppLocalizations(Locale(language));

          // Written through the golden-file machinery, which captures the
          // layer tree the way the framework supports inside a widget test;
          // `--update-goldens` makes it write rather than compare.
          Future<void> capture(String step) => expectLater(
            find.byKey(frame),
            matchesGoldenFile(
              '../../build/qa/onboarding/'
              '$language-${theme.name}-${screen.name}-$step.png',
            ),
          );

          await capture('1-welcome');
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l.onboardingStart));
          await tester.pumpAndSettle();
          await capture('2-currency');
          expect(tester.takeException(), isNull);
          await tester.tap(find.text(l.onboardingNext));
          await tester.pumpAndSettle();
          await capture('3-reminders');
          expect(tester.takeException(), isNull);
        }, skip: !_enabled);
      }
    }
  }

  for (final String language in <String>['ar', 'en']) {
    testWidgets('settings language sheet $language', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(loadFonts);
      await tester.runAsync(warmTheMark);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.localesTestValue = <Locale>[Locale(language)];

      final AppDatabase db = AppDatabase.memory();
      addTearDown(db.close);
      await db.settingsDao.write(
        AppSettings.initial.copyWith(onboardingCompleted: true).toCompanion(),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      await loadBootSettings(container);

      final GlobalKey frame = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: frame,
            child: const DhimmahApp(onboardingCompleted: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final AppLocalizations l = lookupAppLocalizations(Locale(language));
      await tester.tap(find.byTooltip(l.settingsTitle));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(frame),
        matchesGoldenFile(
          '../../build/qa/onboarding/settings-$language-row.png',
        ),
      );
      await tester.tap(find.text(l.settingsLanguage));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(frame),
        matchesGoldenFile(
          '../../build/qa/onboarding/settings-$language-sheet.png',
        ),
      );
    }, skip: !_enabled);
  }
}
