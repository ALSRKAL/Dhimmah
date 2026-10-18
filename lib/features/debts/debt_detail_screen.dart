import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/money.dart';
import '../../core/notifications/notification_service.dart';
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
import '../../domain/entities/person.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../people/statement_screen.dart';
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
          detail.value?.view.displayName ?? localizations.recordDeleted,
        ),
        actions: <Widget>[
          if (detail.value != null) ...<Widget>[
            // One share affordance, and it asks before it sends. A single icon
            // used to mean "quick text" on this screen while "Share statement"
            // on a person's page meant a PDF file, so the same gesture gave two
            // very different things and neither said which.
            PopupMenuButton<_ShareChoice>(
              tooltip: localizations.actionShare,
              icon: const Icon(Icons.ios_share, size: 20),
              onSelected: (_ShareChoice choice) => _share(
                context,
                ref,
                detail.value!,
                choice,
              ),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<_ShareChoice>>[
                PopupMenuItem<_ShareChoice>(
                  value: _ShareChoice.pdf,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                    title: Text(localizations.actionSharePdf),
                  ),
                ),
                PopupMenuItem<_ShareChoice>(
                  value: _ShareChoice.text,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notes_outlined, size: 20),
                    title: Text(localizations.actionShareText),
                  ),
                ),
              ],
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
        // The record is gone while this screen was open — deleted from here,
        // from another copy of this screen, or through the ledger. The screen
        // says so and removes itself instead of sitting over nothing: on the
        // device a stale second copy of this route once read "Total" — the
        // balance card's own label — as its title, with no way to know what
        // had happened.
        empty: Builder(
          builder: (BuildContext context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.of(context).canPop()) {
                // Through go_router, so its page list stays matched to the
                // Navigator's.
                GoRouter.of(context).pop();
              }
            });
            return Center(child: Text(localizations.recordGone));
          },
        ),
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

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    DebtDetail data,
    _ShareChoice choice,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (choice == _ShareChoice.pdf) {
      // The statement is a person's, not a single record's: it is the whole
      // balance as they will see it. A record with nobody on it has none.
      final String? personId = data.view.debt.personId;
      if (personId == null) {
        AppFeedback.error(context, localizations.somethingWentWrong);
        return;
      }
      await showStatement(context, personId);
      return;
    }
    final ShareService service = ShareService(
      localizations: localizations,
      formatting: context.formatting,
    );
    await service.shareText(service.debtSummary(data.view));
  }
}

/// What a tap on the share button is sending.
enum _ShareChoice { pdf, text }

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
              // Unlike the other records, a deleted debt can be undone for a
              // few seconds — the dialog must not claim otherwise.
              body: localizations.deleteUndoableBody,
              confirmLabel: localizations.actionDelete,
            );
            if (!confirmed || !context.mounted) return;
            // Captured before the write, because the write unmounts this menu:
            // the record vanishing rebuilds the screen without it, and the
            // continuation would then find `context.mounted` false — on the
            // device the delete went through with no pop and no undo offer.
            final ScaffoldMessengerState messenger =
                ScaffoldMessenger.of(context);
            final Color undoIcon = context.palette.textSecondary;
            final Color errorIcon = context.palette.overdue;
            void reportFailure() => AppFeedback.errorDetached(
                  messenger: messenger,
                  message: localizations.somethingWentWrong,
                  iconColor: errorIcon,
                );
            // The router object itself, not its Navigator: go_router keeps its
            // own page list, and a raw Navigator pop leaves the two disagreeing
            // — the device showed a blank screen after exactly that.
            final GoRouter router = GoRouter.of(context);
            final LedgerServiceSnapshot snapshot;
            try {
              snapshot = await service.deleteDebtWithSnapshot(debtId);
            } on Object {
              // Said, and the page is left where it is: a record that did go
              // is noticed by the page itself, as any vanished record is.
              reportFailure();
              return;
            }
            AppFeedback.undoableDetached(
              messenger: messenger,
              message: localizations.recordDeleted,
              undoLabel: localizations.actionUndo,
              iconColor: undoIcon,
              // A failed undo is said, instead of escaping as an error nothing
              // catches.
              onUndo: () async {
                try {
                  await service.restoreDeleted(snapshot);
                } on Object {
                  reportFailure();
                }
              },
            );
            router.pop();
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
        // A legacy shared debt names several people on one pot, so a payment
        // on it would settle everyone at once. The notice stays until the user
        // splits the record into independent debts.
        if (view.debt.isShared) ...<Widget>[
          _LegacySharedCard(view: view),
          const SizedBox(height: AppSpacing.lg),
        ],
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

class _FactsCard extends ConsumerWidget {
  const _FactsCard({required this.view});

  final DebtView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;
    final String? reminderUnavailableReason = !ref
            .watch(effectiveSettingsProvider)
            .notificationsEnabled
        ? localizations.reminderNotArmedOff
        : (ref.watch(notificationPermissionProvider).value ??
                    ref.read(notificationServiceProvider).permission) ==
                NotificationPermission.denied
            ? localizations.reminderNotArmedDenied
            : null;
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
              // A reminder that cannot arrive is stated as such here too: the
              // record must not promise a notification the phone will not show.
              value: reminderUnavailableReason == null
                  ? leads.join(' · ')
                  : '${leads.join(' · ')} — $reminderUnavailableReason',
              valueColor: reminderUnavailableReason == null
                  ? null
                  : context.palette.dueSoon,
            ),
          if (view.participants.isNotEmpty)
            DetailRow(
              icon: Icons.group_outlined,
              label: localizations.fieldPeople,
              value: view.participants
                  .map((Person person) => person.name)
                  .join('، '),
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

    // Payments are paused on a legacy shared debt: recording one here would
    // settle every participant at once. The split replaces the payment action
    // until the record is independent debts — except on a settled record,
    // where there is nothing left to split: its history just stays readable.
    if (view.debt.isShared && view.isSettled) {
      return const SizedBox.shrink();
    }
    if (view.debt.isShared) {
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
                onPressed: () => _split(context, ref),
                icon: const Icon(Icons.call_split, size: 20),
                label: Text(localizations.legacySharedSplit),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      );
    }

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

  /// Converts the legacy shared record into independent debts, after the user
  /// has reviewed its payment history shown above.
  Future<void> _split(BuildContext context, WidgetRef ref) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.legacySharedSplitConfirmTitle),
        content: Text(localizations.legacySharedSplitConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.legacySharedSplit),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(ledgerServiceProvider).splitSharedDebt(view.debt.id);
    } on Object {
      if (!context.mounted) return;
      AppFeedback.error(context, localizations.somethingWentWrong);
      return;
    }
    if (!context.mounted) return;
    // The original row keeps its id for the first participant, so this screen
    // now shows that person's independent debt; the streams rebuild it.
    ref.invalidate(debtDetailProvider(view.debt.id));
    AppFeedback.info(
      context,
      localizations.legacySharedSplitDone,
      icon: Icons.check_circle_outline,
    );
  }
}

/// The notice on a legacy shared debt: why payments are paused and what to do.
class _LegacySharedCard extends StatelessWidget {
  const _LegacySharedCard({required this.view});

  final DebtView view;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_outlined,
            size: 20,
            color: palette.dueSoon,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  localizations.legacySharedTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: palette.dueSoon),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  view.isSettled
                      ? localizations.legacySharedSettledBody
                      : localizations.legacySharedBody,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
