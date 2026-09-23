import 'package:flutter/material.dart';

import '../../domain/entities/ledger_views.dart';
import '../../l10n/generated/app_localizations.dart';
import '../formatting/app_formatting.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'money_text.dart';

/// A labelled progress bar for how much of a debt has been settled.
///
/// Kept beside the debt views rather than in the dashboard: the dashboard shows
/// totals, and progress belongs where a single record is being read.
class DebtProgressBar extends StatelessWidget {
  const DebtProgressBar({
    required this.view,
    this.showLabels = true,
    this.thickness = 8,
    super.key,
  });

  final DebtView view;
  final bool showLabels;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations localizations = AppLocalizations.of(context);

    // The brand colour, not the direction colour.
    //
    // Filling the bar with `forDirection` painted it the same red as the overdue
    // chip sitting on the same row, so one colour carried two meanings: "money
    // you owe" and "this is late". Progress is neither; it gets its own lane.
    final Color fill = palette.brand;
    final bool showPaidLabel = view.isPartiallyPaid || view.isSettled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(thickness),
          child: Semantics(
            label: localizations.progressLabel,
            value: context.formatting.percent(view.progress),
            child: LinearProgressIndicator(
              value: view.progress,
              minHeight: thickness,
              backgroundColor: palette.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(fill),
            ),
          ),
        ),
        if (showLabels && showPaidLabel) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Text(
                localizations.detailPaid,
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(width: AppSpacing.xs),
              MoneyText(
                view.paid,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                context.formatting.percent(view.progress),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
