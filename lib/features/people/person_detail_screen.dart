import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/hero_amount.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/ledger_views.dart';
import '../../l10n/generated/app_localizations.dart';
import '../debts/debt_list.dart';
import 'statement_screen.dart';

/// One person's page: their totals on top, then every debt linked to them.
///
/// The debts list is the same widget the ledger tabs use, so filtering, sorting
/// and the empty state behave identically here.
class PersonDetailScreen extends ConsumerStatefulWidget {
  const PersonDetailScreen({required this.personId, super.key});

  final String personId;

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  /// How far the header card has scrolled out of view, 0 to 1.
  ///
  /// The name is written large once, in the header card, where it is the first
  /// thing you read; it drifts into the app bar as the card leaves so you never
  /// lose track of whose page this is. Showing both at rest would say the same
  /// thing twice on one screen.
  final ValueNotifier<double> _scrolled = ValueNotifier<double>(0);

  static const double _fadeDistance = 40;

  @override
  void dispose() {
    _scrolled.dispose();
    super.dispose();
  }

  bool _trackScroll(ScrollNotification notification) {
    _scrolled.value = (notification.metrics.pixels / _fadeDistance).clamp(
      0.0,
      1.0,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final String personId = widget.personId;
    final AsyncValue<PersonLedger?> ledger = ref.watch(
      personLedgerProvider(personId),
    );

    return AsyncValueView<PersonLedger?>(
      value: ledger,
      onRetry: () => ref.invalidate(personLedgerProvider(personId)),
      loading: Scaffold(appBar: AppBar(), body: const ListSkeleton()),
      isEmpty: (PersonLedger? value) => value == null,
      empty: Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(localizations.personDeleted)),
      ),
      builder: (BuildContext context, PersonLedger? data) {
        if (data == null) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(
            title: ValueListenableBuilder<double>(
              valueListenable: _scrolled,
              builder: (BuildContext context, double value, Widget? child) =>
                  Opacity(opacity: value, child: child),
              child: Text(data.person.name),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: localizations.actionEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () =>
                    context.push(AppRoutes.personEditPath(personId)),
              ),
              _PersonMenu(personId: personId, ledger: data),
            ],
          ),
          body: NotificationListener<ScrollNotification>(
            onNotification: _trackScroll,
            child: DebtListBody(
              views: data.debts,
              sortLocked: true,
              // The header card already names this person. Leading every row with
              // their name too would say it once per row.
              personIsKnown: true,
              headerSlivers: <Widget>[
                SliverToBoxAdapter(child: _PersonHeader(ledger: data)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      0,
                    ),
                    child: SectionHeader(
                      title: localizations.personDebtsSection,
                    ),
                  ),
                ),
              ],
              emptyTitle: localizations.personNoDebts,
              emptyActionLabel: localizations.personAddDebt,
              onEmptyAction: () =>
                  context.push('${AppRoutes.debtNew}?person=$personId'),
            ),
          ),
          bottomNavigationBar: _PersonActions(
            personId: personId,
            hasOpenDebt: data.debts.any((DebtView view) => view.isOpen),
          ),
        );
      },
    );
  }
}

class _PersonMenu extends ConsumerWidget {
  const _PersonMenu({required this.personId, required this.ledger});

  final String personId;
  final PersonLedger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (String action) async {
        final LedgerService service = ref.read(ledgerServiceProvider);
        if (action == 'archive') {
          await service.setPersonArchived(
            personId,
            archived: !ledger.person.isArchived,
          );
          if (!context.mounted) return;
          AppFeedback.info(
            context,
            ledger.person.isArchived
                ? localizations.debtRestored
                : localizations.debtArchived,
          );
          return;
        }
        final bool confirmed = await AppFeedback.confirmDestructive(
          context,
          title: localizations.personDeleteTitle,
          body: localizations.personDeleteBody,
          confirmLabel: localizations.actionDelete,
        );
        if (!confirmed || !context.mounted) return;
        await service.deletePerson(personId);
        if (!context.mounted) return;
        context.pop();
        AppFeedback.info(context, localizations.personDeleted);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'archive',
          child: Row(
            children: <Widget>[
              Icon(
                ledger.person.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                ledger.person.isArchived
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

class _PersonHeader extends StatelessWidget {
  const _PersonHeader({required this.ledger});

  final PersonLedger ledger;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final List<CurrencyTotals> active = <CurrencyTotals>[
      for (final CurrencyTotals entry in ledger.totals)
        if (!entry.isEmpty) entry,
    ];

    // The page's one moment of focus: where you stand with this person. A single
    // figure in one currency, with the other currencies as quiet supporting
    // lines — the same shape the dashboard uses, so the two screens read as one
    // product rather than two.
    final CurrencyTotals? primary = active.isEmpty ? null : active.first;
    final List<CurrencyTotals> others = active.length > 1
        ? active.sublist(1)
        : const <CurrencyTotals>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                PersonAvatar.of(ledger.person, size: 48),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    ledger.person.name,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            if (primary == null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: palette.settled,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    localizations.dashboardBalanced,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.settled,
                    ),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text(
                primary.net.isNegative
                    ? localizations.dashboardAgainstYou
                    : primary.net.isPositive
                    ? localizations.dashboardInYourFavour
                    : localizations.dashboardBalanced,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 2),
              HeroAmount(
                Money(primary.net.minorUnits.abs(), primary.currency),
                fontSize: 32,
              ),
              if (others.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const AppDivider(),
                const SizedBox(height: AppSpacing.sm),
                for (final CurrencyTotals totals in others)
                  _OtherCurrencyLine(totals: totals),
              ],
            ],
            if (ledger.person.phone != null &&
                ledger.person.phone!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Text(
                ledger.person.phone!.trim(),
                style: theme.textTheme.bodySmall,
                textDirection: TextDirection.ltr,
              ),
            ],
            if (ledger.person.note != null &&
                ledger.person.note!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                ledger.person.note!.trim(),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A currency other than the one the page is focused on.
class _OtherCurrencyLine extends StatelessWidget {
  const _OtherCurrencyLine({required this.totals});

  final CurrencyTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          Text(
            totals.currency.code,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
          const Spacer(),
          Text(
            totals.net.isNegative
                ? localizations.dashboardAgainstYou
                : localizations.dashboardInYourFavour,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(width: AppSpacing.sm),
          MoneyText(
            Money(totals.net.minorUnits.abs(), totals.currency),
            style: theme.textTheme.labelLarge,
            color: totals.net.isNegative ? palette.iOwe : palette.owedToMe,
          ),
        ],
      ),
    );
  }
}

/// The two things anyone opens a person's page to do.
///
/// One primary action, stated in words, plus the statement. Adding a debt is the
/// rarer of the two once a person has a balance, and destructive actions live in
/// the overflow menu rather than next to the primary one.
class _PersonActions extends StatelessWidget {
  const _PersonActions({required this.personId, required this.hasOpenDebt});

  final String personId;
  final bool hasOpenDebt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('${AppRoutes.debtNew}?person=$personId'),
                icon: const Icon(Icons.add, size: 20),
                label: Text(localizations.addDebtAction),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showStatement(context, personId),
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                label: Text(localizations.reportShareStatement),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
