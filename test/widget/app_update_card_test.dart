import 'package:dhimmah/app/app_update_controller.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/app_update_card.dart';
import 'package:dhimmah/domain/services/app_update_service.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_update_service.dart';

/// What the user sees, in both languages and both themes.
///
/// The card is the whole visible surface of the update system, so this is where
/// "does it look like Dhimmah" is answerable: no dialog, no gradient, no
/// animation, and nothing at all when there is no update.
void main() {
  late FakeAppUpdateService service;

  setUp(() => service = FakeAppUpdateService());
  tearDown(() => service.dispose());

  Future<void> pumpCard(
    WidgetTester tester, {
    required String language,
    Brightness brightness = Brightness.light,
  }) async {
    final Locale locale = Locale(language);
    final ProviderContainer container = ProviderContainer(
      overrides: [appUpdateServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AppUpdateCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Runs the controller to the state under test.
  Future<void> reach(
    WidgetTester tester,
    AppUpdatePhase phase, {
    AppUpdateInfo? info,
  }) async {
    service.info = info ?? offer();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AppUpdateCard)),
    );
    final AppUpdateController controller =
        container.read(appUpdateControllerProvider.notifier);
    await controller.checkIfDue();
    if (phase == AppUpdatePhase.available) {
      await tester.pumpAndSettle();
      return;
    }
    await controller.start();
    if (phase == AppUpdatePhase.downloading) {
      service.emit(AppUpdateEvent(
        phase: AppUpdatePhase.downloading,
        info: offer(bytesDownloaded: 250, totalBytesToDownload: 1000),
      ));
    } else if (phase == AppUpdatePhase.downloaded) {
      service.emit(const AppUpdateEvent(phase: AppUpdatePhase.downloaded));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is drawn when there is no update', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar');
    expect(find.text('تحديث جديد متوفر'), findsNothing);
    // The card itself is present in the tree; it draws nothing.
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('Arabic reads right to left with both actions', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar');
    await reach(tester, AppUpdatePhase.available);

    expect(find.text('تحديث جديد متوفر'), findsOneWidget);
    expect(find.text('تحديث الآن'), findsOneWidget);
    expect(find.text('لاحقًا'), findsOneWidget);

    // In Arabic the primary action is the rightmost thing on its row.
    final double now = tester.getCenter(find.text('تحديث الآن')).dx;
    final double later = tester.getCenter(find.text('لاحقًا')).dx;
    expect(now, greaterThan(later));
  });

  testWidgets('English reads left to right', (WidgetTester tester) async {
    await pumpCard(tester, language: 'en');
    await reach(tester, AppUpdatePhase.available);

    expect(find.text('A new update is available'), findsOneWidget);
    final double now = tester.getCenter(find.text('Update now')).dx;
    final double later = tester.getCenter(find.text('Later')).dx;
    expect(now, lessThan(later));
  });

  testWidgets('it renders in the dark theme', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar', brightness: Brightness.dark);
    await reach(tester, AppUpdatePhase.available);
    expect(find.text('تحديث جديد متوفر'), findsOneWidget);
  });

  testWidgets('a download shows progress and no button', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar');
    await reach(tester, AppUpdatePhase.downloading);

    expect(find.text('جارٍ تنزيل التحديث'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Nothing to press while Play is downloading.
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('a finished download offers the restart', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar');
    await reach(tester, AppUpdatePhase.downloaded);

    expect(find.text('التحديث جاهز للتثبيت'), findsOneWidget);
    expect(find.text('إعادة التشغيل والتحديث'), findsOneWidget);
    // The quiet option is gone: the download already happened.
    expect(find.text('لاحقًا'), findsNothing);
  });

  testWidgets('a dismissal hides it', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar');
    await reach(tester, AppUpdatePhase.available);

    await tester.tap(find.text('لاحقًا'));
    await tester.pumpAndSettle();
    expect(find.text('تحديث جديد متوفر'), findsNothing);
  });

  testWidgets('tapping update twice starts one flow', (WidgetTester tester) async {
    await pumpCard(tester, language: 'ar');
    await reach(tester, AppUpdatePhase.available);

    final Finder button = find.text('تحديث الآن');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    // `pump`, not `pumpAndSettle`: the download state draws a bar that animates
    // until Play reports a total, and settling would wait for it forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(service.flexibleStarts, 1);
  });

  testWidgets('the copy never claims what the release contains',
      (WidgetTester tester) async {
    // The app cannot read Play's release notes, so the prompt says only that a
    // newer version is ready.
    await pumpCard(tester, language: 'ar');
    await reach(tester, AppUpdatePhase.available);
    for (final String forbidden in <String>[
      'ميزة',
      'إصلاح',
      'أمان',
      'جديد في',
      'الجديد',
    ]) {
      expect(
        find.textContaining(forbidden),
        findsNothing,
        reason: 'the prompt mentions "$forbidden", which it cannot know',
      );
    }
  });
}
