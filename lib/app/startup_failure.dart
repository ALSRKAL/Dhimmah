import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/dhimmah_logo.dart';
import '../data/database/app_database.dart';
import '../l10n/generated/app_localizations.dart';

/// What the app shows when the ledger cannot be opened at all.
///
/// Reached only from start-up, and only when the very first database read fails.
/// Without it that failure is the worst possible one: `main` never calls
/// `runApp`, so the user is left on the launch screen — frozen, silent, and
/// indistinguishable from a hung app — with nothing to do but force-quit. This
/// was reachable in practice: opening a database written by a newer build threw
/// an unhandled exception before the first frame.
///
/// Two things it has to get right:
///
/// * **Say something true and specific.** A schema mismatch is a different
///   situation from a corrupted file, and only one of them is fixed by updating
///   the app. Both strings are shown because the stored language setting is
///   itself in the database that would not open — guessing would leave some
///   users reading a language they may not know.
/// * **Never write.** Nothing here touches the file, so the message that the
///   records are untouched is a fact rather than reassurance.
class DhimmahStartupFailureApp extends StatefulWidget {
  const DhimmahStartupFailureApp({
    required this.error,
    required this.onRetry,
    super.key,
  });

  /// What went wrong, used only to choose the specific explanation.
  final Object error;

  /// Whether this failure is a schema this build is too old to read.
  ///
  /// Deliberately not `error is DatabaseTooNewException`. The database runs on
  /// its own isolate and drift marshals failures across the port, so the type is
  /// replaced by a plain exception that preserves only `toString()`. The device
  /// proved it: the log carried `DatabaseTooNewException(file=99, supported=2)`
  /// while the screen took the generic branch, because the object arriving here
  /// was no longer an instance of the class that was thrown.
  ///
  /// The name of the type is therefore the only signal that survives the
  /// boundary, and matching on it is the honest way to reach the specific
  /// message. The `is` check stays first so the same code works if a future
  /// drift stops marshalling.
  @visibleForTesting
  static bool isTooNew(Object error) =>
      error is DatabaseTooNewException ||
      error.toString().contains('DatabaseTooNewException');

  /// Runs the bootstrap again from a fresh container.
  ///
  /// A fresh one matters: the failed attempt memoised its failure, so retrying
  /// the same provider container would fail identically however the problem was
  /// resolved.
  final Future<void> Function() onRetry;

  @override
  State<DhimmahStartupFailureApp> createState() =>
      _DhimmahStartupFailureAppState();
}

class _DhimmahStartupFailureAppState extends State<DhimmahStartupFailureApp> {
  /// True while a retry is running.
  ///
  /// Each retry opens the database in a fresh container, so a second tap while
  /// the first was still opening used to start a second one: two connections to
  /// one file, and two apps racing to replace this screen.
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } on Object {
      // The retry reports its own failure by showing this screen again; there
      // is nothing more to say here, and the button must come back.
    } finally {
      // A retry that failed again replaces this screen with another of the
      // same type, which keeps this state: the button has to be usable again.
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
    final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    final bool tooNew = DhimmahStartupFailureApp.isTooNew(widget.error);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppPalette.light.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.light.brand,
          surface: AppPalette.light.background,
        ),
      ),
      home: Builder(
        builder: (BuildContext context) {
          final AppPalette palette = AppPalette.light;
          final ThemeData theme = Theme.of(context);
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Spacer(),
                    const DhimmahLogo(size: 48),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      ar.startupFailedTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      tooNew ? ar.startupFailedTooNew : ar.startupFailedBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Said in both cases, including the schema mismatch — which
                    // is exactly when a person is most likely to fear the worst,
                    // and when it is most certainly true, because this path never
                    // writes.
                    Text(
                      ar.startupFailedSafe,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.settled,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // The same lines in English, quieter. Someone reading English
                    // must not be stuck with Arabic they cannot read.
                    //
                    // Wrapped in an explicit LTR direction. These sentences sit
                    // inside a right-to-left paragraph, and the bidirectional
                    // algorithm moved every full stop to the start of its line —
                    // ".Nothing in your ledger was changed" — which is exactly the
                    // kind of detail that makes an interface feel careless.
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            en.startupFailedTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            tooNew
                                ? en.startupFailedTooNew
                                : en.startupFailedBody,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            en.startupFailedSafe,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _retrying ? null : _retry,
                      child: Text(ar.startupFailedRetry),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
