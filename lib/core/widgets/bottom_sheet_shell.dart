import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// The shared shell for every bottom sheet in the app.
///
/// Sheets are how Dhimmah asks for something without leaving the screen the user
/// was on, so they all share one frame: a title, an optional subtitle, a body
/// that scrolls when the keyboard is up, and the primary action pinned where the
/// thumb already is.
class AppSheet extends StatelessWidget {
  const AppSheet({
    required this.title,
    required this.child,
    this.subtitle,
    this.primaryAction,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.isDestructivePrimary = false,
    this.busy = false,
    this.showCloseButton = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Replaces the default primary button entirely.
  final Widget? primaryAction;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isDestructivePrimary;

  /// Shows a spinner in place of the primary label while a write is in flight.
  final bool busy;

  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final bool hasFooter = primaryAction != null || onPrimary != null;

    // A sheet with no pinned footer ends at the screen edge, where Android 15's
    // edge-to-edge and the iOS home indicator live. `showModalBottomSheet`'s
    // `useSafeArea` only insets the top, left and right, and the Scaffold strips
    // the body's bottom padding whenever there is a navigation bar, so the last
    // row of a content-only sheet — the add sheet's last option, the PIN pad's
    // bottom row — sat partly behind system UI. `paddingOf`, not `viewPaddingOf`:
    // with the keyboard up the inset is zero because the keyboard covers it, and
    // the sheet has already lifted by `viewInsets`.
    final double bottomInset =
        hasFooter ? 0 : MediaQuery.paddingOf(context).bottom;

    // The sheet has to *fit*: a tall body (the restore preview with its modes
    // and notes) used to push the primary button below the screen, where it
    // could not be reached at all — the restore could be read but not
    // confirmed. Constraining the column makes the body scroll inside the space
    // that the header and the primary action leave, on every screen.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical,
      ),
      child: Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleLarge),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCloseButton)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg + bottomInset,
              ),
              child: child,
            ),
          ),
          if (hasFooter)
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceRaised,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (primaryAction != null)
                      primaryAction!
                    else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: busy ? null : onPrimary,
                          style: isDestructivePrimary
                              ? FilledButton.styleFrom(
                                  backgroundColor: palette.overdue,
                                )
                              : null,
                          child: busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    // Matches the label beside it, which takes
                                    // the theme's `onPrimary`. A hardcoded
                                    // white sat on the dark theme's pastel
                                    // `overdue` fill at 2.54:1.
                                    color: palette.textOnBrand,
                                  ),
                                )
                              : Text(primaryLabel ?? ''),
                        ),
                      ),
                    if (onSecondary != null && secondaryLabel != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: busy ? null : onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// Opens [child] as a modal sheet with the standard constraints.
///
/// [useRootNavigator] lifts the sheet above the app shell rather than above the
/// current tab. It matters for a sheet opened *from* a shell destination: the
/// shell's add button is a sibling of the tab's navigator, so it paints over
/// whatever the tab pushes — including the sheet's own primary button, whose
/// right-hand end it then covers. A sheet that carries an action along its
/// bottom edge asks for the root navigator and gets the screen to itself.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    useRootNavigator: useRootNavigator,
    builder: (BuildContext context) => child,
  );
}
