import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/app_update_controller.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/widgets/record_rows.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/features/debts/debt_ledger_screen.dart';
import 'package:dhimmah/features/shell/add_action_sheet.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/drift.dart' show Table, TableInfo;
import 'package:flutter/foundation.dart';
// drift names its schema table `Table` too; in this file the name means drift's.
import 'package:flutter/material.dart' hide Table;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/fake_app_update_service.dart';
import '../test/support/store_demo_seed.dart';

/// Captures the app's real screens as store screenshots.
///
/// Not part of the normal test run. The database is wiped and seeded with the
/// store demonstration dataset (the same one `test/tool/seed_demo_data_test.dart`
/// writes), the real app runs on top of it, and each screen is reached the way a
/// person reaches it — bottom tabs, the add sheet, tapping a row — before the
/// rendered frame is written out at the device's native resolution.
///
///   flutter test integration_test/store_capture_test.dart -d emulator-5556 \
///     --dart-define=STORE_LANG=ar
///
/// Defines:
///   STORE_LANG     ar | en         (default ar)
///   STORE_THEME    light | dark    (default light)
///   STORE_CURRENCY usd | yer       (default usd) — the ledger the listing shows
///   STORE_ONLY     comma-separated screen keys to capture (default: all)
///
/// Files land in the app's documents directory under `store_capture/<lang>/`;
/// `tool/store_capture/fetch_captures.sh` pulls them to the host.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String langRaw = String.fromEnvironment('STORE_LANG');
  const String themeRaw = String.fromEnvironment('STORE_THEME');
  const String currencyRaw = String.fromEnvironment('STORE_CURRENCY');
  const String onlyDefine = String.fromEnvironment('STORE_ONLY');

  final String langDefine = langRaw.isEmpty ? 'ar' : langRaw;
  final String themeDefine = themeRaw.isEmpty ? 'light' : themeRaw;

  /// The currencies a listing may be photographed in: the dollar for the
  /// English store, the Yemeni riyal for the Arabic one. A run that asks for
  /// anything else stops before it writes a frame, rather than quietly
  /// producing screenshots of a ledger the listing must never show.
  const Map<String, AppCurrency> storeCurrencies = <String, AppCurrency>{
    'usd': AppCurrency.usd,
    'yer': AppCurrency.yer,
  };
  final String currencyDefine = currencyRaw.isEmpty ? 'usd' : currencyRaw;
  final AppLanguage language =
      langDefine == 'en' ? AppLanguage.english : AppLanguage.arabic;
  final AppThemeMode themeMode =
      themeDefine == 'dark' ? AppThemeMode.dark : AppThemeMode.light;
  final Set<String> only =
      onlyDefine.isEmpty ? <String>{} : onlyDefine.split(',').toSet();

  final GlobalKey captureKey = GlobalKey();

  testWidgets('capture the store screenshot set', (WidgetTester tester) async {
    // A fresh install of the app on a device has an empty ledger; the capture
    // starts from that state and builds the demonstration dataset through the
    // real service layer. Nothing is rendered until the seed is complete.
    final ProviderContainer container = ProviderContainer(
      overrides: [
        // The store screenshots must never contain an update card: whether the
        // Play Store on the capture device thinks an update exists is an
        // accident of the environment, not a property of the app.
        appUpdateServiceProvider.overrideWithValue(FakeAppUpdateService()),
      ],
    );
    addTearDown(container.dispose);

    final AppDatabase db = container.read(databaseProvider);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    for (final TableInfo<Table, dynamic> table in db.allTables) {
      // Settings are not wiped: the store writes the singleton row with an
      // UPDATE (created once by the migration), so a deleted row would leave
      // every later save a no-op — and the app would quietly fall back to its
      // defaults, capturing the wrong language and the wrong theme.
      if (table.actualTableName == 'settings') continue;
      await db.customStatement('DELETE FROM "${table.actualTableName}"');
    }
    await db.customStatement('PRAGMA foreign_keys = ON');

    // The settings store updates one singleton row in place; the row is created
    // by the database migration. On a device where an earlier wipe removed it,
    // every save would be a silent no-op and the app would fall back to its
    // defaults — the wrong language, the wrong theme, and a screenshot that
    // lies about neither being chosen. Put the row back if it is missing.
    if (await db.settingsDao.get() == null) {
      await db.into(db.settings).insert(AppSettings.initial.toCompanion());
    }

    // The notification service is brought up before anything is written, in the
    // same order main() uses: creating a debt or a reminder reschedules the
    // pending notifications, and the timezone database that scheduling needs is
    // loaded by `initialize`. Seeding first threw a LateInitializationError per
    // record — caught by the service, but it made the capture run dirty.
    try {
      await container.read(notificationServiceProvider).initialize(
            localizations: lookupAppLocalizations(Locale(language.code)),
          );
    } on Object catch (error) {
      debugPrint('capture: notification init skipped: $error');
    }

    await seedStoreDemoData(
      db,
      language: language,
      themeMode: themeMode,
      currency: storeCurrencies[currencyDefine]!,
    );

    final AppSettings afterSeed =
        await container.read(settingsRepositoryProvider).get();
    debugPrint('capture: after seed language=${afterSeed.language.code} '
        'theme=${afterSeed.themeMode.name}');

    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: UncontrolledProviderScope(
          container: container,
          child: DhimmahApp(onboardingCompleted: true),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    // Streams deliver after the first frames; a few extra pumps let every
    // screen's data arrive before anything is photographed.
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    Future<void> settle() async {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }

    Future<void> capture(String filename) async {
      await settle();
      // Two things must be true of the frame about to be written, and both are
      // checked on the rendered widgets rather than on the intent behind them.
      final AppCurrency? shown = storeCurrencies[currencyDefine];
      if (shown == null) {
        fail('STORE_CURRENCY "$currencyDefine" is not one of '
            '${storeCurrencies.keys.join(' | ')}');
      }
      for (final String banned in <String>['₹', 'INR', 'Indian Rupee']) {
        if (find.textContaining(banned).evaluate().isNotEmpty) {
          fail('"$banned" is on screen in $filename — the listing is never '
              'photographed with it');
        }
      }
      final RenderRepaintBoundary boundary =
          captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image =
          await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final Directory base = await getApplicationDocumentsDirectory();
      // The dark run writes a differently-named file rather than a differently
      // named folder, so one fetch brings the whole language's captures home.
      final File out = File(
        '${base.path}/store_capture/$langDefine/$filename'
        '${themeDefine == 'dark' ? '_dark' : ''}.png',
      );
      await out.create(recursive: true);
      await out.writeAsBytes(data!.buffer.asUint8List());
      debugPrint('CAPTURED ${out.path}');
    }

    bool wanted(String key) => only.isEmpty || only.contains(key);

    final StoreCopy copy = StoreCopy.forLanguage(language);
    // `DhimmahApp` *builds* the router, so its own context sits above it. Any
    // element inside the running app — a Scaffold is always one — can reach the
    // GoRouter that drives it.
    BuildContext routerContext() => tester.element(find.byType(Scaffold).first);

    /// Switches to a bottom-bar destination.
    ///
    /// A selected destination draws the filled icon and an unselected one the
    /// outlined icon, so a tab that is already current has no outlined icon to
    /// tap. Both names are accepted, and whichever is on screen is used.
    Future<void> goTab(IconData outlined, IconData filled) async {
      final Finder finder = find.byIcon(outlined).evaluate().isEmpty
          ? find.byIcon(filled)
          : find.byIcon(outlined);
      await tester.tap(finder.first);
      await settle();
    }

    // The one thing that must be true before a single frame is written: the app
    // is running in the language this run is for. The locale comes from the
    // stored settings through the same providers the screens read, so this
    // reports exactly what the screens will render.
    final AppSettings stored =
        await container.read(settingsRepositoryProvider).get();
    final Locale rendered = Localizations.localeOf(routerContext());
    debugPrint('capture: stored language=${stored.language.code} '
        'rendered locale=${rendered.languageCode}');
    if (rendered.languageCode != language.code) {
      fail('the app is rendering ${rendered.languageCode} but the capture is '
          '${language.code} — the screenshots would be of the wrong language');
    }
    if (stored.themeMode != themeMode) {
      fail('the stored theme is ${stored.themeMode.name} but the capture is '
          '${themeMode.name} — a dark capture would be a light screenshot');
    }
    if (stored.defaultCurrency != storeCurrencies[currencyDefine]) {
      fail('the stored currency is ${stored.defaultCurrency.code} but the '
          'capture is ${storeCurrencies[currencyDefine]!.code} — the amounts '
          'would be in the wrong money');
    }

    // 01 — Dashboard: where the app opens.
    if (wanted('01_dashboard')) {
      await capture('01_dashboard');
    }

    // 02 — Add a debt: the add sheet, then the form. The path a person takes.
    if (wanted('02_add_debt')) {
      await tester.tap(find.byType(FloatingActionButton));
      await settle();
      // The same arrow marks "money I owe" on a dashboard row, so the tap is
      // aimed inside the sheet rather than at the icon in general.
      await tester.tap(find.descendant(
        of: find.byType(AddActionSheet),
        matching: find.byIcon(Icons.arrow_upward_rounded),
      ));
      await settle();
      await capture('02_add_debt');
      routerContext().pop();
      await settle();
    }

    // 03 — People: the directory of who owes and who is owed.
    if (wanted('03_people')) {
      await goTab(Icons.people_outline, Icons.people);
      await capture('03_people');
    }

    // 06 — Ledger: the full list, before opening a record from it.
    if (wanted('06_ledger')) {
      await goTab(Icons.receipt_long_outlined, Icons.receipt_long);
      await capture('06_ledger');
    }

    // 04 — A debt with a payment in it: paid and remaining side by side.
    if (wanted('04_debt_detail')) {
      await goTab(Icons.receipt_long_outlined, Icons.receipt_long);
      // On the mixed ledger a row leads with the person's name and carries the
      // debt's own title in its subtitle, so the row is found by whichever of
      // the two the list actually shows.
      final Finder titled = find.descendant(
        of: find.byType(DebtLedgerScreen),
        matching: find.textContaining(copy.advanceTitle),
      );
      final Finder rows = find.descendant(
        of: find.byType(DebtLedgerScreen),
        matching: find.byType(DebtRowTile),
      );
      await tester.tap((titled.evaluate().isEmpty ? rows : titled).first);
      await settle();
      await capture('04_debt_detail');
      routerContext().pop();
      await settle();
    }

    // 05 — Obligations: the recurring month.
    if (wanted('05_obligations')) {
      await goTab(Icons.event_repeat_outlined, Icons.event_repeat);
      await capture('05_obligations');
    }

    // 07 — Reports: the monthly summary behind the sharable statement.
    if (wanted('07_reports')) {
      unawaited(GoRouter.of(routerContext()).push(AppRoutes.reports));
      await settle();
      await capture('07_reports');
      routerContext().pop();
      await settle();
    }

    // 08 — Backup: where the data is kept safe and exported.
    if (wanted('08_backup')) {
      unawaited(GoRouter.of(routerContext()).push(AppRoutes.backup));
      await settle();
      await capture('08_backup');
      routerContext().pop();
      await settle();
    }

    // The order the frames are numbered in — 01..08 above — is the store
    // story order, not the order they were photographed in.
  });
}
