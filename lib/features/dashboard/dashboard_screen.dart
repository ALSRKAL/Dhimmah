import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_style.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_update_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/record_rows.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/services/attention_list.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shell/app_shell.dart';
import 'widgets/dashboard_header.dart';

/// The home screen: it answers four questions before the user scrolls.
///
/// How much do I owe, how much am I owed, what is due soon, and what is late.
/// Everything else on the page is a shortcut into one of those answers.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Which currency's tiles are on screen. Null means "the snapshot's choice",
  /// so the dashboard follows the data until the user picks explicitly.
  AppCurrency? _selectedCurrency;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<DashboardSnapshot> snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: AsyncValueView<DashboardSnapshot>(
        value: snapshot,
        onRetry: () => ref.invalidate(dashboardProvider),
        loading: const ListSkeleton(rows: 6, height: 88),
        builder: (BuildContext context, DashboardSnapshot data) {
          final AppCurrency currency =
              _selectedCurrency ?? data.primaryCurrency;
          final CurrencyTotals totals = _totalsFor(data, currency);
          final DateTime asOf = ref.watch(todayProvider);
          final int dueSoonWindowDays =
              ref.watch(effectiveSettingsProvider).dueSoonWindowDays;

          // One pass over what is urgent, then the schedule, then history. The
          // attention list absorbs the old "upcoming" strip because the two
          // showed the same records at different levels of urgency.
          // Built once without a cap: the two figures above the list must sum
          // every item — including the obligations the debt-only totals used to
          // skip — while the list itself still shows only the most urgent few.
          // Built from the full lists, not the display ones: those stop at six
          // debts and four periods, and a seventh late debt was left out of
          // "late".
          final List<AttentionItem> allAttention = AttentionList.build(
            debts: data.attentionDebts,
            obligations: data.attentionObligations,
            asOf: asOf,
            windowDays: dueSoonWindowDays,
            limit: null,
            nameOf: (DebtView view) => context.formatting.recordName(view),
          );
          final List<AttentionItem> attention =
              allAttention.take(5).toList(growable: false);
          final ({int overdueMinor, int dueSoonMinor}) attentionTotals =
              AttentionList.totalsFor(allAttention, currency);
          final Set<String> attentionObligations = <String>{
            for (final AttentionItem item in attention)
              if (item.obligationId != null) item.obligationId!,
          };
          final List<ObligationInstance> scheduled = <ObligationInstance>[
            for (final ObligationInstance instance in data.upcomingObligations)
              if (!attentionObligations.contains(instance.obligation.id)) instance,
          ];

          return CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: DashboardHeader(
                  totals: totals,
                  showTotals: data.hasAnyRecord,
                  today: asOf,
                  currencies: data.totalsByCurrency
                      .map((CurrencyTotals t) => t.currency)
                      .toList(),
                  selectedCurrency: currency,
                  onCurrencySelected: (AppCurrency value) =>
                      setState(() => _selectedCurrency = value),
                  onSearch: () => context.push(AppRoutes.search),
                  onSettings: () => context.push(AppRoutes.settings),
                ),
              ),
              // The update prompt sits under the header, and only here.
              //
              // It is the first thing after the balance rather than the last
              // thing on the page because a download the user started has to be
              // findable when they come back to it — and because the card is a
              // line of text and two buttons, so it does not compete with the
              // one figure this screen is built around. It draws nothing at all
              // when there is no update, so a user on the current version never
              // learns that an update system exists.
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: AppUpdateCard(),
                ),
              ),
              if (!data.hasAnyRecord)
                SliverToBoxAdapter(
                  child: EmptyState(
                    compact: true,
                    tone: EmptyTone.positive,
                    title: localizations.dashboardEmptyTitle,
                    body: localizations.dashboardEmptyBody,
                    actionLabel: localizations.dashboardEmptyAddDebt,
                    onAction: () => context.push(AppRoutes.debtNew),
                    secondaryLabel: localizations.dashboardEmptyAddObligation,
                    onSecondary: () => context.push(AppRoutes.obligationsNew),
                  ),
                )
              else ...<Widget>[
                SliverToBoxAdapter(
                  child: _NeedsAttention(
                    items: attention,
                    asOf: asOf,
                    overdue: Money(attentionTotals.overdueMinor, currency),
                    dueSoon: Money(attentionTotals.dueSoonMinor, currency),
                    onViewAll: () =>
                        context.push('${AppRoutes.records}?filter=active'),
                  ),
                ),
                if (scheduled.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _UpcomingObligations(
                      instances: scheduled.take(3).toList(),
                      asOf: asOf,
                      onViewAll: () => context.go(AppRoutes.obligations),
                    ),
                  ),
                if (data.recentActivity.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _RecentActivity(
                      entries: data.recentActivity,
                      asOf: asOf,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: kFabClearance)),
              ],
            ],
          );
        },
      ),
    );
  }

  static CurrencyTotals _totalsFor(DashboardSnapshot data, AppCurrency currency) {
    for (final CurrencyTotals totals in data.totalsByCurrency) {
      if (totals.currency == currency) return totals;
    }
    return CurrencyTotals.empty(currency);
  }
}

/// String names for the filter query parameter, kept next to the route that
/// reads it.
abstract final class DebtFilterName {
  const DebtFilterName._();
  static const String dueSoon = 'dueSoon';
  static const String overdue = 'overdue';
  static const String active = 'active';
  static const String all = 'all';
}

class _UpcomingObligations extends StatelessWidget {
  const _UpcomingObligations({
    required this.instances,
    required this.asOf,
    required this.onViewAll,
  });

  final List<ObligationInstance> instances;
  final DateTime asOf;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            0,
          ),
          child: SectionHeader(
            title: localizations.dashboardObligations,
            action: onViewAll,
            actionLabel: localizations.dashboardViewAll,
          ),
        ),
        AppCard(
          margin: AppSpacing.screen,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < instances.length; i++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ObligationRowTile(
                      instance: instances[i],
                      asOf: asOf,
                      onTap: () => context.push(
                        AppRoutes.obligationPath(instances[i].obligation.id),
                      ),
                    ),
                    if (i != instances.length - 1)
                      const AppDivider(indent: 70),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.entries, required this.asOf});

  final List<ActivityEntry> entries;
  final DateTime asOf;

  static String? _routeFor(ActivityEntry entry) {
    final String? id = entry.entityId;
    if (id == null || id.isEmpty) return null;
    return switch (entry.entityType) {
      RelatedEntityType.debt => AppRoutes.debtPath(id),
      RelatedEntityType.obligation => AppRoutes.obligationPath(id),
      RelatedEntityType.person => AppRoutes.personPath(id),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            0,
          ),
          child: SectionHeader(title: localizations.dashboardRecentActivity),
        ),
        AppCard(
          margin: AppSpacing.screen,
          padding: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < entries.length; i++)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ActivityRowTile(
                      entry: entries[i],
                      asOf: asOf,
                      // A row that looked tappable and did nothing. It opens
                      // the record it is about, where there is one to open.
                      onTap: _routeFor(entries[i]) == null
                          ? null
                          : () => context.push(_routeFor(entries[i])!),
                    ),
                    if (i != entries.length - 1)
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

/// What needs doing, stated plainly.
///
/// The dashboard already reports totals; this is the part that tells the user
/// *which* record to act on. When nothing is pressing it says so rather than
/// disappearing, so its absence is never ambiguous.
class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention({
    required this.items,
    required this.asOf,
    required this.overdue,
    required this.dueSoon,
    required this.onViewAll,
  });

  final List<AttentionItem> items;

  /// The app's today, which the items were sorted against. The rows used to
  /// read the wall clock instead, so a row could name a different day from
  /// the figures above it.
  final DateTime asOf;

  /// Summed over everything that needs attention — debts and obligations
  /// alike, every period of a commitment, and the records past the rows shown —
  /// so the figures are what is really late and due, not what fits here.
  final Money overdue;
  final Money dueSoon;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final int lateCount = items
        .where((AttentionItem item) => item.reason == AttentionReason.overdue)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: localizations.reportNeedsAttention,
            // Only shown when there is something to see; an action that leads to
            // an empty list is a dead end.
            action: items.isEmpty ? null : onViewAll,
            actionLabel: items.isEmpty ? null : localizations.dashboardViewAll,
          ),
          if (items.isNotEmpty && !(overdue.isZero && dueSoon.isZero))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AttentionAmounts(overdue: overdue, dueSoon: dueSoon),
            ),
          if (items.isEmpty)
            AppCard(
              child: Row(
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
                  Expanded(
                    child: Text(
                      localizations.reportNeedsAttentionEmpty,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: palette.settled),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  if (lateCount > 1) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            AppIcons.error,
                            size: 18,
                            color: palette.overdue,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              localizations.attentionOverdueGroup(lateCount),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: palette.overdue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  for (int i = 0; i < items.length; i++)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _AttentionRow(
                          item: items[i],
                          asOf: asOf,
                          // One late group has one red mark, on its heading.
                          // Repeating it down every row made the list read as
                          // four separate alarms about the same thing.
                          showStatusIcon: !(lateCount > 1 &&
                              items[i].reason == AttentionReason.overdue),
                        ),
                        if (i != items.length - 1)
                          const AppDivider(indent: AppSpacing.lg),
                      ],
                    ),
                ],
              ),
            ),
          // No add-button clearance here: this section is in the middle of the
          // page, and the clearance it used to carry opened a screen-tall gap
          // between it and the sections below. The page's own last sliver
          // keeps the final row clear of the button.
        ],
      ),
    );
  }
}

/// How much is late and how much is nearly due.
///
/// This is what the old pair of dashboard tiles said, said once, next to the
/// list of the records that make it up.
class _AttentionAmounts extends StatelessWidget {
  const _AttentionAmounts({required this.overdue, required this.dueSoon});

  final Money overdue;
  final Money dueSoon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    // Each figure is a row while the text fits, and its own wrap when it does
    // not: at a large text size the label and the figure may take two lines,
    // but neither is cut and the amount stays whole.
    final bool stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget figure(String label, Money money, Color color) {
      final Widget labelText = Text(
        '$label ',
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
        ),
      );
      final Widget moneyText = MoneyText(
        money,
        color: color,
        style: theme.textTheme.titleSmall,
        shrinkToFit: true,
      );
      return stacked
          ? Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[labelText, moneyText],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // The label may take a second line on the narrowest phone even
                // at the normal text size; the amount beside it stays whole.
                Flexible(child: labelText),
                moneyText,
              ],
            );
    }

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        if (!overdue.isZero)
          figure(localizations.dashboardOverdue, overdue, palette.overdue),
        if (!dueSoon.isZero)
          figure(localizations.dashboardDueSoon, dueSoon, palette.dueSoon),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.item,
    required this.asOf,
    this.showStatusIcon = true,
  });

  final AttentionItem item;
  final DateTime asOf;

  /// Whether the row draws its own status mark. The late group carries one on
  /// its heading, so its rows do not repeat it.
  final bool showStatusIcon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    // One status mark per row, on the leading edge. The subtitle already names
    // the state in words — "متأخر 17 يومًا" — so a chip repeating that word, with
    // the same icon drawn a second time, only crowded the amount beside it. The
    // icon differs by shape as well as colour, so the rail of marks down the
    // list reads without colour at all.
    final (Color color, IconData icon) = switch (item.reason) {
      AttentionReason.overdue => (palette.overdue, AppIcons.error),
      AttentionReason.dueToday => (palette.dueSoon, AppIcons.today),
      AttentionReason.dueSoon => (palette.dueSoon, AppIcons.schedule),
    };

    final Color amountColor = item.direction == null
        ? palette.textPrimary
        : palette.forDirection(item.direction!);
    String kind(AppLocalizations l) => item.isObligation
        ? l.attentionKindObligation
        : item.direction == null
        ? l.attentionKindDebt
        : item.direction!.isIOwe
        ? l.dashboardIOwe
        : l.dashboardOwedToMe;

    return InkWell(
      onTap: () => context.push(
        item.isObligation
            ? AppRoutes.obligationPath(item.obligationId!)
            : AppRoutes.debtPath(item.debtId!),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            if (showStatusIcon)
              Icon(icon, size: 18, color: color)
            else
              const SizedBox(width: 18),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    item.title.isEmpty
                        ? localizations.unknownPerson
                        : item.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // What the row is, how long there is, then the date. The
                    // kind comes first because the amounts are coloured by side
                    // for debts and plain for obligations, and one list mixing
                    // the two needed to say which was which.
                    '${kind(localizations)}'
                    ' · ${context.formatting.dates.attentionLabel(item.dueAt, asOf)}'
                    ' · ${context.formatting.date(item.dueAt)}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // The row has to hold a title and a figure; when the figure is what
            // cannot fit — the largest amount at the largest text size — it is
            // drawn smaller rather than ellipsized, because a shortened amount
            // reads as a different amount.
            //
            // Tight and end-aligned. A loose `Flexible` shares the free space
            // and is then packed at the row's start, which left the figure
            // floating on the midline with the trailing half of the card empty;
            // the `Align` is what actually holds it against the edge.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MoneyText(
                  item.money,
                  style: theme.textTheme.titleSmall,
                  color: amountColor,
                  shrinkToFit: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
