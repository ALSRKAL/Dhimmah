import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/money.dart';
import '../../core/share/share_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_style.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/debt_progress.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/record_rows.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/read_models/ledger_queries.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/ledger_views.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import 'payment_sheet.dart';

/// Everything about one debt: the balance, its history, and the actions that
/// change it.
///
/// The three numbers the user actually cares about — total, paid, remaining —
/// are stated explicitly at the top rather than left to be inferred from a list,
/// because this is the screen someone opens when they are about to pay.
class DebtDetailScreen extends ConsumerWidget {
  const DebtDetailScreen({required this.debtId, super.key});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<DebtDetail?> detail = ref.watch(debtDetailProvider(debtId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          detail.value?.view.displayName ?? localizations.detailTotal,
        ),
        actions: <Widget>[
          if (detail.value != null) ...<Widget>[
            IconButton(
              tooltip: localizations.actionShare,
              icon: const Icon(Icons.ios_share, size: 20),
              onPressed: () => _share(context, ref, detail.value!),
            ),
            IconButton(
              tooltip: localizations.actionEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => context.push(AppRoutes.debtEditPath(debtId)),
            ),
            _OverflowMenu(debtId: debtId),
          ],
        ],
      ),
      body: AsyncValueView<DebtDetail?>(
        value: detail,
        onRetry: () => ref.invalidate(debtDetailProvider(debtId)),
        loading: const ListSkeleton(rows: 4),
        isEmpty: (DebtDetail? value) => value == null,
        empty: Center(child: Text(localizations.recordDeleted)),
        builder: (BuildContext context, DebtDetail? data) {
          if (data == null) return const SizedBox.shrink();
          return _DetailBody(detail: data);
        },
      ),
      bottomNavigationBar: detail.value == null
          ? null
          : _BottomAction(view: detail.value!.view),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref, DebtDetail data) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ShareService service = ShareService(
      localizations: localizations,
      formatting: context.formatting,
    );
    await service.shareText(service.debtSummary(data.view));
  }
}

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({required this.debtId});

  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final DebtDetail? detail = ref.watch(debtDetailProvider(debtId)).value;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (String action) async {
        final LedgerService service = ref.read(ledgerServiceProvider);
        switch (action) {
          case 'archive':
            final bool wasArchived = detail?.view.debt.isArchived ?? false;
            await service.setDebtArchived(debtId, !wasArchived);
            if (!context.mounted) return;
            AppFeedback.info(
              context,
              wasArchived
                  ? localizations.debtRestored
                  : localizations.debtArchived,
            );
          case 'delete':
            final bool confirmed = await AppFeedback.confirmDestructive(
              context,
              title: localizations.deleteConfirmTitle,
              body: localizations.deleteConfirmBody,
              confirmLabel: localizations.actionDelete,
            );
            if (!confirmed || !context.mounted) return;
            final LedgerServiceSnapshot snapshot =
                await service.deleteDebtWithSnapshot(debtId);
            if (!context.mounted) return;
            context.pop();
            AppFeedback.undoable(
              context,
              message: localizations.recordDeleted,
              onUndo: () => service.restoreDeleted(snapshot),
            );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'archive',
          child: Row(
            children: <Widget>[
              Icon(
                detail?.view.debt.isArchived ?? false
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                detail?.view.debt.isArchived ?? false
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

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final DebtDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final DebtView view = detail.view;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.massive,
      ),
      children: <Widget>[
        _BalanceCard(view: view),
        const SizedBox(height: AppSpacing.lg),
        _FactsCard(view: view),
        if (detail.payments.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxl),
          SectionHeader(title: localizations.paymentTitle),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < detail.payments.length; i++)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PaymentRow(
                        payment: detail.payments[i],
                        view: view,
                      ),
                      if (i != detail.payments.length - 1)
                        const AppDivider(indent: 64),
                    ],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        SectionHeader(title: localizations.detailTimeline),
        if (detail.activity.isEmpty)
          AppCard(
            child: Text(
              localizations.detailNoPayments,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < detail.activity.length; i++)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ActivityRowTile(
                        entry: detail.activity[i],
                        asOf: DateTime.now(),
                      ),
                      if (i != detail.activity.length - 1)
                        const AppDivider(indent: 64),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Total, paid and remaining — stated, not implied.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.view});

  final DebtView view;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Color accent = palette.forDirection(view.debt.direction);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (view.person != null) ...<Widget>[
                PersonAvatar.of(view.person!, size: 40),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      view.displayName.isEmpty
                          ? localizations.unknownPerson
                          : view.displayName,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (view.subtitle != null)
                      Text(view.subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              view.status.chip(context, localizations),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _AmountLine(
            label: localizations.detailTotal,
            money: view.principal,
            emphasis: false,
          ),
          _AmountLine(
            label: localizations.detailPaid,
            money: view.paid,
            emphasis: false,
            color: palette.settled,
          ),
          const AppDivider(),
          const SizedBox(height: AppSpacing.xs),
          _AmountLine(
            label: localizations.detailRemaining,
            money: view.remaining,
            emphasis: true,
            color: accent,
          ),
          const SizedBox(height: AppSpacing.lg),
          DebtProgressBar(view: view, showLabels: false),
        ],
      ),
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.money,
    required this.emphasis,
    this.color,
  });

  final String label;
  final Money money;
  final bool emphasis;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: (emphasis ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                  ?.copyWith(color: context.palette.textSecondary),
            ),
          ),
          MoneyText(
            money,
            color: color,
            style: emphasis ? theme.textTheme.titleLarge : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.view});

  final DebtView view;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;
    final DateTime? due = view.debt.dueAt;
    final List<String> leads = view.debt.reminderLeads
        .map((lead) => lead.label(localizations))
        .toList();

    return AppCard(
      child: Column(
        children: <Widget>[
          DetailRow(
            icon: Icons.calendar_today_outlined,
            label: localizations.detailIssuedOn,
            value: formatting.date(view.debt.issuedAt),
          ),
          DetailRow(
            icon: Icons.event_outlined,
            label: localizations.detailDueOn,
            value: due == null
                ? localizations.dateNoDueDate
                : '${formatting.date(due)} · ${formatting.relativeDue(due, DateTime.now())}',
          ),
          if (leads.isNotEmpty)
            DetailRow(
              icon: Icons.notifications_none,
              label: localizations.fieldReminder,
              value: leads.join(' · '),
            ),
          if (view.debt.isRecurring)
            DetailRow(
              icon: Icons.autorenew,
              label: localizations.fieldRecurrence,
              value: view.debt.recurrence.label(
                localizations,
                interval: view.debt.recurrenceInterval,
              ),
            ),
          if (view.debt.note != null && view.debt.note!.trim().isNotEmpty)
            DetailRow(
              icon: Icons.notes,
              label: localizations.fieldNote,
              value: view.debt.note!.trim(),
            ),
          if (view.paidMinor > view.debt.principalMinor)
            DetailRow(
              icon: Icons.warning_amber_outlined,
              label: localizations.totalLabel,
              value: localizations.detailOverpaid(
                formatting.amount(
                  Money(view.paidMinor - view.debt.principalMinor, view.currency),
                ),
              ),
              valueColor: context.palette.dueSoon,
            ),
        ],
      ),
    );
  }
}

class _BottomAction extends ConsumerWidget {
  const _BottomAction({required this.view});

  final DebtView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: view.isSettled
                  ? null
                  : () => showPaymentSheet(context, view: view),
              icon: const Icon(Icons.payments_outlined, size: 20),
              label: Text(localizations.detailRecordPayment),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: localizations.actionShare,
            onPressed: () async {
              final ShareService service = ShareService(
                localizations: localizations,
                formatting: context.formatting,
              );
              await service.shareText(service.debtSummary(view));
            },
            icon: const Icon(Icons.ios_share, size: 20),
            style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
              side: BorderSide(color: palette.borderStrong),
            ),
          ),
        ],
      ),
    );
  }
}
