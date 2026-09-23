import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../domain/entities/obligation.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import 'obligation_actions.dart';

/// The obligations tab: every recurring commitment, with the period that is
/// currently due.
///
/// Grouping is by obligation rather than by period, because that is how the user
/// thinks about rent — one thing, every month — while the detail screen keeps the
/// period-by-period history.
class ObligationsScreen extends ConsumerStatefulWidget {
  const ObligationsScreen({super.key});

  @override
  ConsumerState<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends ConsumerState<ObligationsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<ObligationInstance>> instances =
        ref.watch(obligationInstancesProvider);
    final DateTime asOf = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.obligationsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: localizations.filterArchived,
            icon: Icon(
              _showArchived ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: AsyncValueView<List<ObligationInstance>>(
        value: instances,
        onRetry: () => ref.invalidate(obligationInstancesProvider),
        loading: const ListSkeleton(),
        builder: (BuildContext context, List<ObligationInstance> data) {
          final List<ObligationGroup> groups = ObligationGroup.from(data);

          if (groups.isEmpty && !_showArchived) {
            return EmptyState(
              title: localizations.obligationsEmptyTitle,
              body: localizations.obligationsEmptyBody,
              actionLabel: localizations.obligationFormNew,
              onAction: () => context.push(AppRoutes.obligationsNew),
            );
          }

          final List<ObligationGroup> open = <ObligationGroup>[
            for (final ObligationGroup group in groups)
              if (!group.obligation.isArchived) group,
          ];
          final List<ObligationGroup> archived = <ObligationGroup>[
            for (final ObligationGroup group in groups)
              if (group.obligation.isArchived) group,
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.massive,
            ),
            children: <Widget>[
              Text(
                localizations.obligationsSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final ObligationGroup group in open) ...<Widget>[
                ObligationCard(group: group, asOf: asOf),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_showArchived && archived.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(title: localizations.filterArchived),
                for (final ObligationGroup group in archived) ...<Widget>[
                  ObligationCard(group: group, asOf: asOf),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ],
          );
        },
      ),
      // No add button here: this screen is a shell destination, and the shell
      // already owns one. A second FAB would render on top of it.
    );
  }
}

/// One obligation and the periods currently associated with it.
class ObligationGroup {
  const ObligationGroup({
    required this.obligation,
    required this.current,
    required this.history,
  });

  final Obligation obligation;

  /// The period that still needs paying, if there is one.
  final ObligationInstance? current;

  /// Periods already dealt with, newest first.
  final List<ObligationInstance> history;

  static List<ObligationGroup> from(List<ObligationInstance> instances) {
    final Map<String, List<ObligationInstance>> byId =
        <String, List<ObligationInstance>>{};
    final Map<String, Obligation> obligations = <String, Obligation>{};
    for (final ObligationInstance instance in instances) {
      byId.putIfAbsent(instance.obligation.id, () => <ObligationInstance>[]).add(instance);
      obligations[instance.obligation.id] = instance.obligation;
    }

    final List<ObligationGroup> groups = <ObligationGroup>[];
    for (final MapEntry<String, Obligation> entry in obligations.entries) {
      final List<ObligationInstance> all = byId[entry.key] ?? <ObligationInstance>[];
      all.sort((ObligationInstance a, ObligationInstance b) =>
          a.dueAt.compareTo(b.dueAt));
      final List<ObligationInstance> open = <ObligationInstance>[
        for (final ObligationInstance instance in all)
          if (instance.occurrence.isPayable) instance,
      ];
      groups.add(
        ObligationGroup(
          obligation: entry.value,
          current: open.isEmpty ? null : open.first,
          history: <ObligationInstance>[...all.reversed],
        ),
      );
    }
    groups.sort((ObligationGroup a, ObligationGroup b) {
      final DateTime? aDue = a.current?.dueAt;
      final DateTime? bDue = b.current?.dueAt;
      // Anything currently due sorts above everything, soonest first.
      if (aDue != null && bDue != null) return aDue.compareTo(bDue);
      if (aDue != null) return -1;
      if (bDue != null) return 1;
      return a.obligation.name.compareTo(b.obligation.name);
    });
    return groups;
  }
}

/// A single obligation, with its next due period and the action for it.
class ObligationCard extends ConsumerWidget {
  const ObligationCard({required this.group, required this.asOf, super.key});

  final ObligationGroup group;
  final DateTime asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Obligation obligation = group.obligation;
    final ObligationInstance? current = group.current;

    return AppCard(
      onTap: () => context.push(AppRoutes.obligationPath(obligation.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.brandContainer,
                  borderRadius: AppRadius.rSm,
                ),
                child: Icon(
                  obligation.category.icon,
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
                      obligation.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Allowed to wrap: the date is the point of this line, and an
                    // ellipsis in the middle of it is worse than a second line.
                    Text(
                      obligation.isArchived
                          ? localizations.obligationArchived
                          : localizations.obligationNextDue(
                              context.formatting.date(obligation.nextDueAt),
                            ),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
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
                    Money(obligation.amountMinor, obligation.currency),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    obligation.frequency.label(
                      localizations,
                      interval: obligation.intervalCount,
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          if (current != null && !obligation.isArchived) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const AppDivider(),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: ObligationActionButtons(instance: current),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
