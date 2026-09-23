import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// Feedback helpers.
///
/// Every action that changes data reports what happened, and destructive ones
/// offer an undo instead of a second confirmation. Deleting is reversible for a
/// few seconds rather than permanently blocking a mis-tap.
abstract final class AppFeedback {
  const AppFeedback._();

  /// A short confirmation.
  ///
  /// A single light haptic marks the moment a write succeeded. It is used only
  /// here, so the feedback keeps meaning "something was saved" rather than
  /// becoming background noise on every tap.
  static void info(BuildContext context, String message, {IconData? icon}) {
    final AppPalette palette = context.palette;
    unawaited(HapticFeedback.lightImpact());
    _show(
      context,
      message: message,
      icon: icon ?? Icons.check_circle_outline,
      iconColor: palette.owedToMe,
    );
  }

  /// A confirmation with an undo action.
  static void undoable(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    String? undoLabel,
  }) {
    final AppPalette palette = context.palette;
    _show(
      context,
      message: message,
      icon: Icons.delete_outline,
      iconColor: palette.textSecondary,
      actionLabel: undoLabel ?? AppLocalizations.of(context).actionUndo,
      onAction: onUndo,
      duration: const Duration(seconds: 6),
    );
  }

  /// Something failed. Says what the user can do, not what went wrong inside.
  static void error(BuildContext context, String message) {
    final AppPalette palette = context.palette;
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      iconColor: palette.overdue,
      duration: const Duration(seconds: 5),
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          content: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
          action: onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel ?? '',
                  onPressed: onAction,
                ),
        ),
      );
  }

  /// The standard destructive confirmation.
  ///
  /// Returns true when the user confirmed. Callers must not delete anything
  /// without this, which is the rule the spec sets for the whole app.
  static Future<bool> confirmDestructive(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    String? cancelLabel,
  }) async {
    final AppPalette palette = context.palette;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              cancelLabel ?? MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.overdue),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
