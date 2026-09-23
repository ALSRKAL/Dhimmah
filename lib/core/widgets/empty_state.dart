import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// The empty state used everywhere a list can have nothing in it.
///
/// Deliberately not the usual large circle containing a large icon, which is a
/// shape every app has and which says nothing. A short rule, a sentence that
/// explains the situation, and the one action that changes it. The rule is the
/// brand's gold, so even an empty screen still carries the app's voice.
///
/// The copy does the work: a quiet screen is a chance to tell someone their
/// ledger is in order, which is worth more than a picture of an empty box.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.icon,
    this.compact = false,
    this.tone = EmptyTone.neutral,
    super.key,
  });

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional small glyph, drawn at text size beside the title. Kept for cases
  /// where a glyph carries real meaning — an error, a completed check.
  final IconData? icon;

  final bool compact;

  /// Whether the emptiness is good news or just absences.
  final EmptyTone tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final Color accent = switch (tone) {
      EmptyTone.positive => palette.settled,
      EmptyTone.neutral => palette.gold,
    };

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xl : AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 28,
              height: 2,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 17, color: accent),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (body != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
            if (onAction != null && actionLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (onSecondary != null && secondaryLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Whether an empty screen is good news.
enum EmptyTone {
  /// Nothing to do — everything is settled. Shown in the settled green.
  positive,

  /// Nothing recorded yet. Shown in the brand accent.
  neutral,
}

/// Shown when something failed. Offers a retry rather than an apology.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.message,
    this.retryLabel,
    this.onRetry,
    super.key,
  });

  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 24, color: palette.overdue),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null && retryLabel != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
