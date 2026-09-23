import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../l10n/generated/app_localizations.dart';

/// The quick-add sheet behind the add button.
///
/// Four choices, each one tap from the matching form, because adding a record is
/// the action the whole app exists to make fast.
Future<void> showAddActionSheet(
  BuildContext context, {
  bool personFirst = false,
}) {
  // Sized to its content rather than capped at half the screen: the choices are
  // the point of the sheet, so none of them may be below the fold.
  return showAppSheet<void>(
    context,
    child: AddActionSheet(personFirst: personFirst),
  );
}

class AddActionSheet extends StatelessWidget {
  const AddActionSheet({this.personFirst = false, super.key});

  /// Whether to lead with "new person".
  ///
  /// On the people screen the thing a user is most likely to want is another
  /// person, and an add button that cannot do that is a dead end.
  final bool personFirst;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return AppSheet(
      title: localizations.addTitle,
      showCloseButton: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (personFirst) ...<Widget>[
            _AddOption(
              icon: Icons.person_add_alt,
              color: palette.brand,
              container: palette.brandContainer,
              title: localizations.personNew,
              subtitle: localizations.peopleEmptyBody,
              onTap: () => _open(context, AppRoutes.personNew),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _AddOption(
            icon: Icons.arrow_upward_rounded,
            color: palette.iOwe,
            container: palette.iOweContainer,
            title: localizations.addDebtIOwe,
            subtitle: localizations.addDebtIOweHint,
            onTap: () => _open(context, '${AppRoutes.debtNew}?direction=iOwe'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddOption(
            icon: Icons.arrow_downward_rounded,
            color: palette.owedToMe,
            container: palette.owedToMeContainer,
            title: localizations.addDebtOwedToMe,
            subtitle: localizations.addDebtOwedToMeHint,
            onTap: () =>
                _open(context, '${AppRoutes.debtNew}?direction=owedToMe'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddOption(
            icon: Icons.event_repeat_outlined,
            color: palette.brand,
            container: palette.brandContainer,
            title: localizations.addObligation,
            subtitle: localizations.addObligationHint,
            onTap: () => _open(context, AppRoutes.obligationsNew),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AddOption(
            icon: Icons.notifications_none,
            color: palette.gold,
            container: palette.goldContainer,
            title: localizations.addReminder,
            subtitle: localizations.addReminderHint,
            onTap: () => _open(context, AppRoutes.reminderNew),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String location) {
    // Close the sheet first so the pushed screen animates over the page, not
    // over the sheet.
    Navigator.of(context).pop();
    context.push(location);
  }
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.color,
    required this.container,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color container;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: container,
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: palette.textTertiary),
        ],
      ),
    );
  }
}
