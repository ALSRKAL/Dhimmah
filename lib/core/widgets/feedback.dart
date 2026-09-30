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
    _show(
      context,
      message: message,
      icon: Icons.delete_outline,
      iconColor: context.palette.textSecondary,
      actionLabel: undoLabel ?? AppLocalizations.of(context).actionUndo,
      onAction: onUndo,
      duration: const Duration(seconds: 6),
    );
  }

  /// A detached confirmation, for a write whose screen unmounted while it ran.
  ///
  /// The same shape as [info], for the records that have no undo: obligation
  /// and person deletion is final, so there is deliberately no action here.
  static void infoDetached({
    required ScaffoldMessengerState messenger,
    required String message,
    required Color iconColor,
  }) {
    _show(
      null,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: iconColor,
      messenger: messenger,
    );
  }

  /// The undo offer for a delete whose screen unmounted while the write ran.
  ///
  /// Deleting a record rebuilds the screen that listed it without the menu the
  /// delete started from, so by the time the write returns there is no live
  /// context to ask for a messenger — on the device that meant the delete
  /// completed with no pop and no offer. This constructor takes the messenger
  /// and the two colours, captured before the write, and asks nothing of the
  /// tree.
  static void undoableDetached({
    required ScaffoldMessengerState messenger,
    required String message,
    required String undoLabel,
    required Color iconColor,
    required VoidCallback onUndo,
  }) {
    _show(
      null,
      message: message,
      icon: Icons.delete_outline,
      iconColor: iconColor,
      actionLabel: undoLabel,
      onAction: onUndo,
      duration: const Duration(seconds: 6),
      messenger: messenger,
    );
  }

  /// [error], for a write whose screen may have unmounted while it ran.
  ///
  /// Takes the messenger and the colour captured before the write, like
  /// [infoDetached], so a failure is still reported after its row is gone.
  static void errorDetached({
    required ScaffoldMessengerState messenger,
    required String message,
    required Color iconColor,
  }) {
    _show(
      null,
      message: message,
      icon: Icons.error_outline,
      iconColor: iconColor,
      duration: const Duration(seconds: 5),
      messenger: messenger,
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
    BuildContext? context, {
    required String message,
    required IconData icon,
    required Color iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
    ScaffoldMessengerState? messenger,
  }) {
    final ScaffoldMessengerState target =
        messenger ?? ScaffoldMessenger.of(context!);
    target
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
