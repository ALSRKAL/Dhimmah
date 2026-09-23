import 'package:flutter/material.dart';

import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/status_style.dart';

/// A status pill.
///
/// Every chip carries an icon as well as a colour, so the state is still readable
/// without relying on colour perception.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.foreground,
    required this.background,
    required this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? AppSpacing.sm : AppSpacing.md,
          vertical: dense ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.rPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: dense ? 12 : 14, color: foreground),
            SizedBox(width: dense ? 3 : 5),
            Text(
              label,
              style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

extension DebtStatusChip on DebtLifecycleStatus {
  Widget chip(BuildContext context, AppLocalizations localizations, {bool dense = false}) {
    final AppPalette palette = context.palette;
    final StatusStyle style = palette.statusStyle(this);
    return StatusChip(
      label: label(localizations),
      foreground: style.foreground,
      background: style.container,
      icon: style.icon,
      dense: dense,
    );
  }
}

extension ObligationStatusChip on ObligationStatus {
  Widget chip(BuildContext context, AppLocalizations localizations, {bool dense = false}) {
    final AppPalette palette = context.palette;
    final StatusStyle style = palette.obligationStyle(this);
    return StatusChip(
      label: label(localizations),
      foreground: style.foreground,
      background: style.container,
      icon: style.icon,
      dense: dense,
    );
  }
}

