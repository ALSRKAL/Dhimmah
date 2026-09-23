import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatting/app_formatting.dart';
import '../core/theme/app_theme.dart';
import '../domain/entities/app_settings.dart';
import '../domain/enums/preference_enums.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_update_controller.dart';
import 'lock_gate.dart';
import 'providers.dart';
import 'router.dart';

/// The application root.
///
/// Language, theme and text direction all come from the stored settings, so
/// changing any of them in Settings applies everywhere at once rather than
/// needing a restart.
class DhimmahApp extends ConsumerStatefulWidget {
  const DhimmahApp({required this.onboardingCompleted, super.key});

  /// Captured before the first frame so the router starts on the right screen.
  final bool onboardingCompleted;

  @override
  ConsumerState<DhimmahApp> createState() => _DhimmahAppState();
}

class _DhimmahAppState extends ConsumerState<DhimmahApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router = buildRouter(
    onboardingCompleted: widget.onboardingCompleted,
    navigatorKey: _navigatorKey,
  );
  StreamSubscription<String>? _notificationTaps;

  @override
  void initState() {
    super.initState();
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
      unawaited(
        ref.read(appUpdateControllerProvider.notifier).checkIfDue(),
      );
    });
  }

  @override
  void dispose() {
    _notificationTaps?.cancel();
    _router.dispose();
    super.dispose();
  }

  void _openPayload(String payload) {
    final String? location = AppRoutes.forNotificationPayload(payload);
    if (location == null) return;
    _router.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = ref.watch(effectiveSettingsProvider);
    final AppLocalizations localizations = ref.watch(localizationsProvider);
    final AppFormatting formatting = ref.watch(formattingProvider);
    final Locale locale = Locale(settings.language.code);
    final ThemeMode themeMode = switch (settings.themeMode) {
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
