import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/app_update_controller.dart';
import 'app/providers.dart';
import 'app/startup_failure.dart';
import 'data/services/ledger_service.dart';
import 'data/services/play_app_update_service.dart';
import 'domain/entities/app_settings.dart';
import 'l10n/generated/app_localizations.dart';


/// Starts Dhimmah.
///
/// Everything that must be ready before the first frame happens here — the
/// localisation data, the notification plugin and the stored settings — so the app
/// never opens in the wrong language or flashes the wrong theme.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Date symbols for both languages, so `DateFormat` also works outside the
  // widget tree — the notification scheduler formats dates too.
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // Portrait only: this is a list-and-form app, and a landscape phone layout
  // would add layout surface without adding anything the user needs.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await _boot();
}

/// Opens the ledger and starts the app.
///
/// Separated from [main] so the failure screen can run it again from scratch:
/// the first database read is where an unopenable file, a schema written by a
/// newer build, or a full disk surfaces, and this used to be the one unguarded
/// step in start-up. Everything after it — the warm-up, the notifications — was
/// already wrapped; this was not, so a failure here meant `runApp` was never
/// reached and the user sat on the launch screen with no message and no way out.
Future<void> _boot() async {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      // Google Play's own update system, and nothing else: no server is asked
      // for a version, no APK is downloaded, and no permission is involved. The
      // Play Store app decides whether an update is available and performs the
      // whole download and install itself.
      appUpdateServiceProvider.overrideWithValue(PlayAppUpdateService()),
    ],
  );

  final AppSettings settings;
  try {
    settings = await container.read(settingsRepositoryProvider).get();
  } on Object catch (error) {
    _reportBootstrapFailure('opening the database', error);
    container.dispose();
    runApp(DhimmahStartupFailureApp(error: error, onRetry: _boot));
    return;
  }

  // Notification channels carry localised names, so the service is initialised
  // with the strings for the language the user actually chose. A failure here is
  // survivable: reminders are a convenience, and a broken one must never stop the
  // ledger from opening.
  await _initializeNotifications(container, settings);

  final bool onboardingCompleted = settings.onboardingCompleted;
  if (onboardingCompleted) {
    await _warmUp(container);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: DhimmahApp(onboardingCompleted: onboardingCompleted),
    ),
  );
}

/// Records a start-up failure without ever failing the start-up itself.
///
/// Deliberately not `FlutterError.reportError`. A failure that crosses an async
/// boundary — which is every database failure, since drift runs on its own
/// isolate — carries a stack containing `===== asynchronous gap =====`. Flutter's
/// own stack filter asserts on that line, so reporting it threw *inside the
/// error handler* and killed the app before it could draw anything. The device
/// caught this: the failure screen never appeared, and the launch screen stayed
/// frozen — the exact symptom the handler existed to remove.
///
/// `debugPrint` costs nothing in release and carries no stack to parse. Only the
/// error's type and message are written, never a record.
void _reportBootstrapFailure(String what, Object error) {
  if (kDebugMode) {
    debugPrint('Dhimmah start-up: $what failed: $error');
  }
}

/// Brings the schedule up to date before the first frame, so the dashboard opens
/// on real numbers rather than filling in later.
///
/// Only the periods: a commitment whose month has turned over has to exist
/// before the screens read it. The pending notifications are deliberately *not*
/// rebuilt here — they are not on screen, and at ten thousand records the read
/// behind them is long enough to be seen on a cold start. The app rebuilds them
/// after the first frame instead.
Future<void> _warmUp(ProviderContainer container) async {
  final LedgerService service = container.read(ledgerServiceProvider);
  try {
    await service.ensureOccurrences();
  } on Object catch (error) {
    // A failure here must not stop the app from opening: the ledger still works,
    // and the next launch tries again.
    _reportBootstrapFailure('warming up the ledger', error);
  }
}

/// Prepares the notification plugin, tolerating any failure.
Future<void> _initializeNotifications(
  ProviderContainer container,
  AppSettings settings,
) async {
  try {
    await container.read(notificationServiceProvider).initialize(
          localizations: lookupAppLocalizations(Locale(settings.language.code)),
        );
  } on Object catch (error) {
    _reportBootstrapFailure('initialising notifications', error);
  }
}
