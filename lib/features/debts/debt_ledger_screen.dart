import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_style.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/money_text.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/services/debt_calculator.dart';
import '../../l10n/generated/app_localizations.dart';
import 'debt_list.dart';

/// One side of the ledger: everything the user owes, or everything they are
/// owed.
///
/// The two tabs differ only by [direction], so the summary strip at the top, the
/// filters and the empty states all come from the same code — which is what stops
/// the two sides from drifting apart in behaviour.
class DebtLedgerScreen extends ConsumerStatefulWidget {
  const DebtLedgerScreen({this.initialDirection = DebtDirection.iOwe, super.key});

  /// Which side to open on. The list itself switches freely, so the dashboard's
  /// two figures lead here rather than to two near-identical screens.
  final DebtDirection initialDirection;

  @override
  ConsumerState<DebtLedgerScreen> createState() => _DebtLedgerScreenState();
}

class _DebtLedgerScreenState extends ConsumerState<DebtLedgerScreen> {
  late DebtDirection direction = widget.initialDirection;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<DebtView>> views = ref.watch(debtViewsProvider);

    final bool isIOwe = direction.isIOwe;
    final List<DebtView> scoped = <DebtView>[
      for (final DebtView view in views.value ?? const <DebtView>[])
        if (view.debt.direction == direction) view,
    ];

    final List<CurrencyTotals> totals = _totals(
      scoped,
      asOf: ref.watch(todayProvider),
      dueSoonWindowDays: ref.watch(effectiveSettingsProvider).dueSoonWindowDays,
    );

    return Scaffold(
      appBar: AppBar(title: Text(localizations.navLedger)),
      body: AsyncValueView<List<DebtView>>(
        value: views,
        onRetry: () => ref.invalidate(debtViewsProvider),
        loading: const ListSkeleton(),
        builder: (BuildContext context, List<DebtView> _) => DebtListBody(
          views: scoped,
          direction: direction,
          headerSlivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: _SideSwitch(
                  direction: direction,
                  onChanged: (DebtDirection value) =>
                      setState(() => direction = value),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SummaryStrip(totals: totals, direction: direction),
            ),
          ],
          emptyTitle:
              isIOwe ? localizations.ioweEmptyTitle : localizations.owedToMeEmptyTitle,
          emptyBody: isIOwe
              ? localizations.ioweEmptyBody
              : localizations.owedToMeEmptyBody,
          emptyActionLabel: localizations.addDebtAction,
          onEmptyAction: () =>
              context.push('${AppRoutes.debtNew}?direction=${direction.name}'),
        ),
      ),
      // No add button here: this screen is a shell destination, and the shell
      // already owns one. A second FAB would render on top of it.
    );
  }

  /// Totals for this side only, one entry per currency.
  static List<CurrencyTotals> _totals(
    List<DebtView> views, {
    required DateTime asOf,
    required int dueSoonWindowDays,
  }) {
    return DebtCalculator.totalsByCurrency(
      views,
      asOf: asOf,
      dueSoonWindowDays: dueSoonWindowDays,
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.totals, required this.direction});

  final List<CurrencyTotals> totals;
  final DebtDirection direction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Color accent = palette.forDirection(direction);

    // Not a card.
    //
    // It held one amount and one meta line inside a full-width card, so roughly
    // half the card was empty, and the count it printed ("4 سجلات · INR") is
    // printed again in the row underneath, which already says how many records
    // the filter matched. A container earns its place by grouping things; this
    // one grouped a single figure, so the figure stands on its own.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: totals.isEmpty
          ? Row(
              children: <Widget>[
                Icon(Icons.check_circle_outline, size: 18, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  localizations.dashboardBalanced,
                  style: theme.textTheme.titleSmall?.copyWith(color: accent),
                ),
              ],
            )
          : Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                for (final CurrencyTotals entry in totals)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        entry.currency.code,
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // The side this screen is showing, not the owe-side total:
                      // the totals carry both directions, and printing `iOwe`
                      // unconditionally made the owed-to-me headline read ₹0
                      // above a list of ₹2,000 (proven on the device).
                      MoneyText(
                        Money(
                          direction.isIOwe
                              ? entry.iOweMinor
                              : entry.owedToMeMinor,
                          entry.currency,
                        ),
                        color: accent,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

/// Which side of the ledger is on screen.
///
/// A switch rather than two destinations: it is one list with one filter, and
/// pretending otherwise cost a navigation slot that People needed more.
class _SideSwitch extends StatelessWidget {
  const _SideSwitch({required this.direction, required this.onChanged});

  final DebtDirection direction;
  final ValueChanged<DebtDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<DebtDirection>(
        segments: <ButtonSegment<DebtDirection>>[
          ButtonSegment<DebtDirection>(
            value: DebtDirection.iOwe,
            label: Text(localizations.ledgerSwitchIOwe),
            icon: const Icon(Icons.arrow_upward_rounded, size: 16),
          ),
          ButtonSegment<DebtDirection>(
            value: DebtDirection.owedToMe,
            label: Text(localizations.ledgerSwitchOwedToMe),
            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
          ),
        ],
        selected: <DebtDirection>{direction},
        showSelectedIcon: false,
        onSelectionChanged: (Set<DebtDirection> selection) {
          if (selection.isNotEmpty) onChanged(selection.first);
        },
      ),
    );
  }
}
