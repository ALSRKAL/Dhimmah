import 'package:flutter/material.dart';

import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/enums/debt_enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../formatting/app_formatting.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../theme/status_style.dart';
import 'debt_progress.dart';
import 'money_text.dart';
import 'person_avatar.dart';
import 'status_chip.dart';

/// One debt in a list.
///
/// The row answers the three questions a list of debts raises — who, how much is
/// left, and when it is due — and shows progress only when part of it has
/// actually been paid, so settled records do not carry a redundant bar.
class DebtRowTile extends StatelessWidget {
  const DebtRowTile({
    required this.view,
    required this.onTap,
    required this.asOf,
    this.onLongPress,
    this.showDirectionBadge = false,
    this.knownPersonId,
    super.key,
  });

  final DebtView view;
  final VoidCallback onTap;
  final DateTime asOf;
  final VoidCallback? onLongPress;

  /// Shown on mixed lists where "I owe" and "owed to me" appear together.
  final bool showDirectionBadge;

  /// Set on a screen that is already about one person — their own page.
  ///
  /// There the row speaks for that person's side of the record: the debt's own
  /// name takes the lead, and the other people the record is also linked to are
  /// not named, because the page is about this relationship and not about them.
  /// On a mixed list the people are the useful heading and stay.
  final String? knownPersonId;

  bool get personIsKnown => knownPersonId != null;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;
    final DebtDirection direction = view.debt.direction;
    final Color amountColor = palette.forDirection(direction);

    final String lead = personIsKnown
        ? view.displayNameFor(knownPersonId!)
        : view.displayName;
    final List<String> subtitleParts = <String>[
      if (!personIsKnown && view.subtitle != null) view.subtitle!,
      if (view.debt.dueAt != null)
        formatting.relativeDue(view.debt.dueAt!, asOf)
      else
        localizations.dateNoDueDate,
    ];

    return Semantics(
      button: true,
      label: <String>[
        lead,
        formatting.amount(view.remaining),
        localizations.detailRemaining,
        subtitleParts.join(', '),
      ].join('. '),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Leading(view: view, showDirectionBadge: showDirectionBadge),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      lead.isEmpty ? localizations.unknownPerson : lead,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleParts.join(' · '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (view.isPartiallyPaid) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      // The shared widget rather than a second copy of the same
                      // bar: the copy had drifted from it in colour and had lost
                      // its semantics, so a screen reader announced nothing where
                      // the standalone bar says "paid, 40%".
                      SizedBox(
                        width: 140,
                        child: DebtProgressBar(
                          view: view,
                          showLabels: false,
                          thickness: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MoneyText(
                    view.remaining,
                    color: view.isSettled ? palette.textTertiary : amountColor,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  view.status.chip(context, localizations, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.view, required this.showDirectionBadge});

  final DebtView view;
  final bool showDirectionBadge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    if (view.person != null) {
      if (!showDirectionBadge) return PersonAvatar.of(view.person!, size: 42);
      return Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          PersonAvatar.of(view.person!, size: 42),
          PositionedDirectional(
            bottom: -2,
            end: -2,
            child: _DirectionDot(direction: view.debt.direction),
          ),
        ],
      );
    }

    final Color color = palette.forDirection(view.debt.direction);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: palette.containerForDirection(view.debt.direction),
        shape: BoxShape.circle,
      ),
      child: Icon(
        view.debt.direction.isIOwe
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        size: 19,
        color: color,
      ),
    );
  }
}

class _DirectionDot extends StatelessWidget {
  const _DirectionDot({required this.direction});

  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: palette.forDirection(direction),
        shape: BoxShape.circle,
        border: Border.all(color: palette.surface, width: 2),
      ),
      child: Icon(
        direction.isIOwe ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        size: 9,
        color: Colors.white,
      ),
    );
  }
}

/// One obligation period in a list.
class ObligationRowTile extends StatelessWidget {
  const ObligationRowTile({
    required this.instance,
    required this.onTap,
    required this.asOf,
    this.onLongPress,
    super.key,
  });

  final ObligationInstance instance;
  final VoidCallback onTap;
  final DateTime asOf;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;

    return Semantics(
      button: true,
      label: <String>[
        instance.obligation.name,
        formatting.amount(instance.money),
        instance.occurrence.status.label(localizations),
      ].join('. '),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.brandContainer,
                  borderRadius: AppRadius.rSm,
                ),
                child: Icon(
                  instance.obligation.category.icon,
                  size: 20,
                  color: palette.onBrandContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      instance.obligation.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatting.relativeDue(instance.dueAt, asOf),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MoneyText(
                    instance.money,
                    style: theme.textTheme.titleSmall,
                    color: palette.textPrimary,
                  ),
                  const SizedBox(height: 4),
                  instance.occurrence.status.chip(context, localizations, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One line in the dashboard's activity feed.
class ActivityRowTile extends StatelessWidget {
  const ActivityRowTile({
    required this.entry,
    required this.asOf,
    this.onTap,
    super.key,
  });

  final ActivityEntry entry;

  /// The reference date for the relative timestamp.
  final DateTime asOf;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;

    final Color accent =
        entry.type.isIncoming ? palette.owedToMe : palette.neutralStatus;
    final AppCurrency? currency = entry.currency;
    final int? amountMinor = entry.amountMinor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(entry.type.icon, size: 17, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    entry.type.label(localizations),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.title.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      entry.title,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (amountMinor != null && currency != null)
                  MoneyText(
                    Money(amountMinor, currency),
                    style: theme.textTheme.labelLarge,
                    color: accent,
                  ),
                const SizedBox(height: 2),
                Text(
                  formatting.relativeDue(entry.occurredAt, asOf),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
