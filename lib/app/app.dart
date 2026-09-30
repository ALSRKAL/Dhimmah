import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatting/app_formatting.dart';
import '../core/notifications/notification_composer.dart';
import '../core/notifications/notification_service.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dates.dart';
import '../domain/entities/app_settings.dart';
import '../domain/enums/preference_enums.dart';
import '../l10n/enum_labels.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_update_controller.dart';
import 'backup_providers.dart';
import 'lock_gate.dart';
import 'providers.dart';
import 'router.dart';

/// The application root.
///
/// Theme comes from the stored settings, and language from the stored
/// preference and the phone together, so changing either — in Settings, or in
/// the phone's own settings while the app is open — applies everywhere at once
/// rather than needing a restart. Text direction follows the language.
class DhimmahApp extends ConsumerStatefulWidget {
  const DhimmahApp({required this.onboardingCompleted, super.key});

  /// Captured before the first frame so the router starts on the right screen.
  final bool onboardingCompleted;

  @override
  ConsumerState<DhimmahApp> createState() => _DhimmahAppState();
}

class _DhimmahAppState extends ConsumerState<DhimmahApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router = buildRouter(
    onboardingCompleted: widget.onboardingCompleted,
    navigatorKey: _navigatorKey,
  );
  StreamSubscription<String>? _notificationTaps;
  ProviderSubscription<NotificationComposer>? _wording;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // What a reminder says is decided when it is scheduled, so a change of
    // language — chosen in Settings, or the phone's own — has to reach the ones
    // already waiting. The composer is rebuilt exactly when its wording could
    // change, and each rebuild re-words the pending set and renames the
    // channels the system settings list.
    _wording = ref.listenManual<NotificationComposer>(
      notificationComposerProvider,
      (NotificationComposer? previous, NotificationComposer next) =>
          unawaited(_rewordNotifications()),
    );
    // The app starts in the foreground, so the tick starts with it. Waiting for
    // a background-and-back cycle first would mean the tick never ran in a
    // session that did not have one — which is the session it was added for.
    _startTicker();
    // Tapping a notification opens the record it is about.
    _notificationTaps =
        ref.read(notificationServiceProvider).taps.listen(_openPayload);

    // The update check starts here — after the first frame, never before it.
    //
    // Nothing about the ledger depends on knowing whether an update exists, so
    // the app must be on screen and usable first: an update prompt that delayed
    // the dashboard would trade something the user asked for against something
    // they did not. `checkIfDue` returns immediately and does its work in the
    // background, so this callback is not a pause.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      // A tap that *launched* the app arrives before anything is listening, so
      // the service holds it. Without this, tapping a reminder on a closed app
      // opened the dashboard and the record the user asked for was lost.
      final String? launch =
          ref.read(notificationServiceProvider).takeLaunchPayload();
      if (launch != null) _openPayload(launch);

      // The pending set is rebuilt once the app is on screen: reminders are not
      // part of the first frame, and on a large ledger the read behind them is
      // long enough that waiting for it would be the first thing the user saw.
      unawaited(ref.read(ledgerServiceProvider).refreshNotifications());

      unawaited(
        ref.read(appUpdateControllerProvider.notifier).checkIfDue(),
      );

      // What the app believes about the user's protection is re-read, once, as
      // soon as the first frame is on screen. It reads a directory listing and
      // the folder's state, so it is exactly the kind of work that must not be
      // allowed to delay the dashboard — and it is the reason a device that was
      // reinstalled, or whose folder was emptied outside the app, opens on the
      // truth rather than on what the last launch happened to leave behind.
      unawaited(ref.read(backupControllerProvider).reconcile());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Two things happen at these boundaries, and nowhere else: the notification
    // environment is re-read on the way back in, and a snapshot is taken on the
    // way out — which is the one moment when writing a few megabytes cannot be
    // seen, because the user is leaving.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _stopTicker();
      unawaited(_backupOnLeave());
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // The phone's language can change while the app is in the background, and
    // not every phone reports it to an app that is not on screen.
    ref.read(deviceLocalesProvider.notifier).refresh();
    unawaited(_reconcileNotifications());
    unawaited(_backupIfStale());
    // Everything the app believes about protection is re-read, because the
    // things it believes it about can change while the app is not looking: the
    // user can delete a file in their own file manager, revoke a folder's
    // permission, or come back to an app they reinstalled.
    unawaited(ref.read(backupControllerProvider).reconcile());
    _startTicker();
  }

  /// The phone's language list changed while the app is on screen.
  ///
  /// With the preference left to the phone, this is the whole of "follow the
  /// device": the resolved language moves, and everything built on it — the
  /// interface, the formatting, the reminders' wording — moves with it.
  @override
  void didChangeLocales(List<Locale>? locales) {
    ref.read(deviceLocalesProvider.notifier).refresh();
  }

  /// Re-words the pending reminders and renames the channels.
  Future<void> _rewordNotifications() async {
    if (!mounted) return;
    try {
      await ref
          .read(notificationServiceProvider)
          .relabelChannels(ref.read(localizationsProvider));
      await ref.read(ledgerServiceProvider).refreshNotifications();
    } on Object {
      // A reminder in the old language is a cosmetic fault, not a lost one: the
      // record is intact and the next pass re-words it.
    }
  }

  /// How often the app asks itself whether a snapshot is due, while the user is
  /// working.
  ///
  /// This is the whole of the app's "periodic backup", and it is deliberately
  /// not a background job. Nothing can change the ledger while the app is
  /// closed, so a snapshot taken by a background task could not capture anything
  /// a session cannot — while a second process opening the same database file is
  /// a real way to corrupt it. What a long session *does* need is a chance to
  /// save without the user having to leave first, and that is what this is for.
  ///
  /// Asking is cheap: the decision is a few indexed counts. Writing is not, and
  /// the policy decides that, including refusing when the user has just changed
  /// something. Five minutes is comfortably shorter than the interval the policy
  /// works on, so a session is never kept waiting by the tick itself.
  static const Duration _tick = Duration(minutes: 5);

  Timer? _ticker;

  void _startTicker() {
    _ticker ??= Timer.periodic(_tick, (Timer _) {
      if (!mounted) return;
      unawaited(_backupIfStale());
    });
    _startMidnight();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _midnight?.cancel();
    _midnight = null;
  }

  /// Wakes at the next midnight while the app is on screen.
  ///
  /// "Today" used to move only when the app came back from the background, so
  /// a ledger left open overnight still called yesterday's deadline "due
  /// today". Paused with the ticker, because a resume refreshes the day anyway.
  Timer? _midnight;

  void _startMidnight() {
    _midnight?.cancel();
    final DateTime now = ref.read(clockProvider)();
    // A second past midnight, so the timer never wakes a moment early and
    // reads the day that is ending.
    final Duration wait = addDays(dateOnly(now), 1).difference(now) +
        const Duration(seconds: 1);
    _midnight = Timer(wait, () {
      if (!mounted) return;
      ref.read(todayProvider.notifier).refresh();
      _startMidnight();
    });
  }

  /// Takes a snapshot as the app leaves the foreground, when one is due.
  Future<void> _backupOnLeave() async {
    if (!mounted) return;
    try {
      await ref
          .read(backupCoordinatorProvider)
          .runIfDue(leavingForeground: true);
      ref.invalidate(backupStatusProvider);
    } on Object {
      // A snapshot that could not be written must never be the reason an app
      // crash-lands on its way to the background: the records are safe, the
      // previous snapshot is still there, and the next boundary tries again.
    }
  }

  /// The daily safety net, and the crash-recovery path: if the last snapshot is
  /// old enough, or the app was killed before it could take one, this is when
  /// that is noticed.
  Future<void> _backupIfStale() async {
    if (!mounted) return;
    try {
      await ref
          .read(backupCoordinatorProvider)
          .runIfDue(leavingForeground: false);
      ref.invalidate(backupStatusProvider);
    } on Object {
      // Same reasoning as above.
    }
  }

  /// Re-reads the phone's notification state after the app comes back.
  ///
  /// Permission can be granted or revoked, and the device can change timezone,
  /// while Dhimmah sits in the background — and both change what should be
  /// armed. Nothing is rebuilt unless something actually changed, so an ordinary
  /// resume costs one platform read and no ledger work.
  Future<void> _reconcileNotifications() async {
    if (!mounted) return;
    try {
      final NotificationEnvironment environment =
          await ref.read(notificationServiceProvider).refreshEnvironment();
      if (!environment.changed || !mounted) return;
      // The phone may be in another country now, and the suggested currency
      // follows its time zone.
      ref.invalidate(deviceTimeZoneProvider);
      if (environment.mustReschedule) {
        await ref.read(ledgerServiceProvider).refreshNotifications();
      }
    } on Object {
      // A failure here must never take the app down: the ledger is unaffected,
      // and the next resume tries again.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _wording?.close();
    _notificationTaps?.cancel();
    _router.dispose();
    super.dispose();
  }

  void _openPayload(String payload) {
    final String? location = AppRoutes.forNotificationPayload(payload);
    if (location == null) return;
    // Tapping the same reminder twice, or a reminder for the page already on
    // screen, used to stack an identical page on top of it — one more back
    // press for every tap.
    if (_isShowing(location)) return;
    _router.push(location);
  }

  /// Whether [location] is the page the user is already looking at.
  ///
  /// The top of the stack, pushed pages included: the configuration's own
  /// location is the page underneath them.
  bool _isShowing(String location) {
    if (_router.routerDelegate.currentConfiguration.isEmpty) return false;
    return _router.state.uri.toString() == location;
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeMode theme = ref.watch(
      effectiveSettingsProvider.select((AppSettings s) => s.themeMode),
    );
    final AppLocalizations localizations = ref.watch(localizationsProvider);
    final AppFormatting formatting = ref.watch(formattingProvider);
    // Resolved here rather than by MaterialApp, and passed down explicitly: the
    // services that write notifications and statements read the same provider,
    // so the screen and everything the app sends are always one language.
    final Locale locale = ref.watch(appLanguageProvider).locale;
    final ThemeMode themeMode = switch (theme) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: localizations.appName,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        // The formatting scope sits inside the localisation delegates so
        // `context.formatting` always agrees with the visible locale.
        return AppFormattingScope(
          formatting: formatting,
          child: LockGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
