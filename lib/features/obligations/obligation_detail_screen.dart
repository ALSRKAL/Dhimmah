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
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import 'obligation_actions.dart';

/// One obligation: what it costs, when it is next due, and its whole history.
///
/// The history is the point. A recurring commitment is easy to pay and easy to
/// lose track of, so every period it has ever generated is listed with its
/// outcome.
class ObligationDetailScreen extends ConsumerWidget {
  const ObligationDetailScreen({required this.obligationId, super.key});

  final String obligationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<ObligationInstance>> instances =
        ref.watch(obligationInstancesProvider);

    return AsyncValueView<List<ObligationInstance>>(
      value: instances,
      onRetry: () => ref.invalidate(obligationInstancesProvider),
      loading: Scaffold(appBar: AppBar(), body: const ListSkeleton()),
      builder: (BuildContext context, List<ObligationInstance> data) {
        final List<ObligationInstance> mine = <ObligationInstance>[
          for (final ObligationInstance instance in data)
            if (instance.obligation.id == obligationId) instance,
        ];
        if (mine.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(localizations.recordDeleted)),
          );
        }
        final ObligationGroupData group = ObligationGroupData.from(mine);
        return Scaffold(
          appBar: AppBar(
            title: Text(group.obligation.name),
            actions: <Widget>[
              IconButton(
                tooltip: localizations.actionEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () =>
                    context.push(AppRoutes.obligationEditPath(obligationId)),
              ),
              _ObligationMenu(obligationId: obligationId, obligation: group.obligation),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.massive,
            ),
            children: <Widget>[
              _ObligationHeader(group: group),
              if (group.current != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                ObligationActionButtons(
                  instance: group.current!,
                  compact: false,
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              SectionHeader(title: localizations.obligationHistory),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < group.history.length; i++)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _HistoryRow(instance: group.history[i]),
                          if (i != group.history.length - 1)
                            const AppDivider(indent: AppSpacing.lg),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The grouping used by this screen, rebuilt from the shared instance list.
class ObligationGroupData {
  const ObligationGroupData({
    required this.obligation,
    required this.current,
    required this.history,
  });

  final Obligation obligation;
  final ObligationInstance? current;
  final List<ObligationInstance> history;

  static ObligationGroupData from(List<ObligationInstance> instances) {
    final List<ObligationInstance> sorted = List<ObligationInstance>.of(instances)
      ..sort((ObligationInstance a, ObligationInstance b) =>
          b.dueAt.compareTo(a.dueAt));
    ObligationInstance? current;
    for (final ObligationInstance instance in sorted) {
      if (instance.occurrence.isPayable) current = instance;
    }
    return ObligationGroupData(
      obligation: sorted.first.obligation,
      current: current,
      history: sorted,
    );
  }
}

class _ObligationMenu extends ConsumerWidget {
  const _ObligationMenu({required this.obligationId, required this.obligation});

  final String obligationId;
  final Obligation obligation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (String action) async {
        final LedgerService service = ref.read(ledgerServiceProvider);
        if (action == 'archive') {
          await service.setObligationArchived(
            obligationId,
            !obligation.isArchived,
          );
          if (!context.mounted) return;
          AppFeedback.info(
            context,
            obligation.isArchived
                ? localizations.debtRestored
                : localizations.debtArchived,
          );
          return;
        }
        final bool confirmed = await AppFeedback.confirmDestructive(
          context,
          title: localizations.deleteConfirmTitle,
          body: localizations.deleteConfirmBody,
          confirmLabel: localizations.actionDelete,
        );
        if (!confirmed || !context.mounted) return;
        await service.deleteObligation(obligationId);
        if (!context.mounted) return;
        context.pop();
        AppFeedback.info(context, localizations.recordDeleted);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'archive',
          child: Row(
            children: <Widget>[
              Icon(
                obligation.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                obligation.isArchived
                    ? localizations.actionUnarchive
                    : localizations.actionArchive,
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline, size: 18, color: palette.overdue),
              const SizedBox(width: AppSpacing.md),
              Text(
                localizations.actionDelete,
                style: TextStyle(color: palette.overdue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ObligationHeader extends StatelessWidget {
  const _ObligationHeader({required this.group});

  final ObligationGroupData group;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Obligation obligation = group.obligation;
    final ObligationInstance? current = group.current;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.brandContainer,
                  borderRadius: AppRadius.rMd,
                ),
                child: Icon(
                  obligation.category.icon,
                  size: 22,
                  color: palette.onBrandContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(obligation.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      obligation.category.label(localizations),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (current != null)
                current.occurrence.status.chip(context, localizations),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      localizations.obligationMonthlyAmount,
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    MoneyText(
                      Money(obligation.amountMinor, obligation.currency),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              Text(
                obligation.frequency.label(
                  localizations,
                  interval: obligation.intervalCount,
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const AppDivider(),
          const SizedBox(height: AppSpacing.xs),
          DetailRow(
            icon: Icons.event_outlined,
            label: localizations.obligationNextDue(
              context.formatting.date(obligation.nextDueAt),
            ),
            value: context.formatting.relativeDue(
              obligation.nextDueAt,
              DateTime.now(),
            ),
          ),
          DetailRow(
            icon: Icons.play_circle_outline,
            label: localizations.fieldStartDate,
            value: context.formatting.date(obligation.startAt),
          ),
          if (obligation.dayOfMonth != null)
            DetailRow(
              icon: Icons.today_outlined,
              label: localizations.fieldDayOfMonth,
              value: context.formatting.count(obligation.dayOfMonth!),
            ),
          if (obligation.endAt != null)
            DetailRow(
              icon: Icons.event_busy_outlined,
              label: localizations.fieldEndDate,
              value: context.formatting.date(obligation.endAt!),
            ),
          if (obligation.note != null && obligation.note!.trim().isNotEmpty)
            DetailRow(
              icon: Icons.notes,
              label: localizations.fieldNote,
              value: obligation.note!.trim(),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.instance});

  final ObligationInstance instance;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.formatting.dates.monthYear(instance.dueAt),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  instance.occurrence.paidAt != null
                      ? localizations.detailClosedOn(
                          context.formatting.date(instance.occurrence.paidAt!),
                        )
                      : context.formatting.relativeDue(
                          instance.dueAt,
                          DateTime.now(),
                        ),
                  style: theme.textTheme.bodySmall,
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
                style: theme.textTheme.labelLarge,
                color: instance.occurrence.status == ObligationStatus.paid
                    ? palette.settled
                    : palette.textPrimary,
              ),
              const SizedBox(height: 4),
              instance.occurrence.status.chip(
                context,
                localizations,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
