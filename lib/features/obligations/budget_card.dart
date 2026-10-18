import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/money_text.dart';
import '../../domain/entities/monthly_budget.dart';
import '../../l10n/generated/app_localizations.dart';
import 'income_manage_sheet.dart';

/// What this month's income leaves after this month's commitments.
///
/// Sits above the list of commitments, because the number a person opens this
/// screen for is "what is left", and the individual bills are the working out.
///
/// It is drawn in two states and the difference matters. With no income recorded
/// there is nothing to subtract from, so the card asks for one instead of
/// drawing a figure against a zero — a "remaining" of minus the rent is not a
/// useful thing to show someone who has simply not told the app their salary
/// yet. With an income recorded it reads out the three numbers and the share of
/// the income the commitments take.
class BudgetCard extends ConsumerStatefulWidget {
  const BudgetCard({required this.asOf, super.key});

  final DateTime asOf;

  @override
  ConsumerState<BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends ConsumerState<BudgetCard> {
  /// The currency the card is reading, or null to follow the default.
  ///
  /// Held here rather than in a provider because it is a property of this screen
  /// being open, not of the ledger: leaving the tab and coming back should not
  /// remember a currency the user picked once to look at.
  AppCurrency? _selected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final List<AppCurrency> currencies = ref.watch(budgetCurrenciesProvider);
    final AppCurrency fallback =
        ref.watch(effectiveSettingsProvider).defaultCurrency;
    final AppCurrency? chosen = _selected;
    // `currencies` always carries at least the default, so `first` is safe.
    final AppCurrency currency = chosen != null && currencies.contains(chosen)
        ? chosen
        : (currencies.contains(fallback) ? fallback : currencies.first);

    final BudgetArgs args = (
      year: widget.asOf.year,
      month: widget.asOf.month,
      currency: currency,
    );
    final MonthlyBudget budget =
        ref.watch(monthlyBudgetProvider(args)).value ??
            MonthlyBudget.empty(
              year: widget.asOf.year,
              month: widget.asOf.month,
              currency: currency,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (currencies.length > 1) ...<Widget>[
          _CurrencyStrip(
            currencies: currencies,
            selected: currency,
            onChanged: (AppCurrency value) => setState(() => _selected = value),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (budget.hasIncome)
          _FilledCard(budget: budget, localizations: localizations)
        else
          _InvitationCard(
            currency: currency,
            onAdd: () => showIncomeManageSheet(context),
          ),
      ],
    );
  }
}

/// The card as it reads once an income exists.
class _FilledCard extends StatelessWidget {
  const _FilledCard({required this.budget, required this.localizations});

  final MonthlyBudget budget;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppFormatting formatting = context.formatting;

    // Three states, and the colour is the only thing that distinguishes the
    // first two at a glance: over the income entirely, close to it, comfortable.
    final bool over = budget.isOverCommitted;
    final bool tight = !over && budget.consumptionRatio >= 0.8;
    final Color accent = over
        ? palette.overdue
        : tight
            ? palette.dueSoon
            : palette.settled;
    final Color accentContainer = over
        ? palette.overdueContainer
        : tight
            ? palette.dueSoonContainer
            : palette.settledContainer;

    // Over-committed, the headline figure is the *overage* under a label that
    // names it, not the negative remainder: «المتبقي من الدخل −₹1,000» reads as
    // a balance below zero, and it puts a minus sign at the start of an amount,
    // which is exactly the thing the two scripts lay out differently. The
    // number itself is the same either way — this is the sign moved into words.
    final String headline =
        over ? localizations.budgetOverBy : localizations.budgetRemaining;
    final Money figure = Money(
      over ? budget.overMinor : budget.remainingMinor,
      budget.currency,
    );

    return AppCard(
      onTap: () => showIncomeManageSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentContainer,
                  borderRadius: AppRadius.rSm,
                ),
                child: Icon(
                  // The same mark the attention list uses for money that has
                  // gone wrong, so "over" reads as the same kind of fact here.
                  over ? Icons.error_outline : Icons.savings_outlined,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      headline,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    // Keyed on the figure, so a month that changes underneath
                    // the reader — a commitment edited, an income added — cross
                    // fades to the new number instead of snapping to it.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: MoneyText(
                        figure,
                        key: ValueKey<String>(
                          '${figure.minorUnits}|${figure.currency.code}',
                        ),
                        style: theme.textTheme.headlineSmall,
                        color: accent,
                        shrinkToFit: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // How much of the income the month's commitments take. Drawn from the
          // capped ratio so an over-committed month fills the bar rather than
          // overflowing it, and the words above already say which case it is.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: budget.consumptionRatioClamped),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? child) =>
                  LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: palette.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              // A month with nothing due says so in words rather than reporting
              // "0% of your income goes to commitments", which is a number
              // about nothing. The rest of the card already reads zero.
              budget.hasObligations
                  ? localizations.budgetConsumed(
                      formatting.percent(budget.consumptionRatio),
                    )
                  : localizations.budgetAllAvailable,
              key: ValueKey<bool>(budget.hasObligations),
              style: theme.textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppDivider(),
          const SizedBox(height: AppSpacing.sm),
          DetailRow(
            label: localizations.budgetTotalIncome,
            value: formatting.amount(Money(budget.incomeMinor, budget.currency)),
          ),
          DetailRow(
            label: localizations.budgetTotalObligations,
            value: formatting.amount(
              Money(budget.obligationsMinor, budget.currency),
            ),
          ),
          Padding(
            // Indented under the total they add up to, so the two parts read as
            // parts rather than as two more totals.
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.lg,
              top: AppSpacing.xxs,
            ),
            child: Column(
              children: <Widget>[
                DetailRow(
                  label: localizations.budgetPaidLabel,
                  value: formatting.amount(
                    Money(budget.paidObligationsMinor, budget.currency),
                  ),
                  valueColor: palette.settled,
                ),
                DetailRow(
                  label: localizations.budgetUnpaidLabel,
                  value: formatting.amount(
                    Money(budget.unpaidObligationsMinor, budget.currency),
                  ),
                ),
                if (budget.overdueObligationsMinor > 0)
                  DetailRow(
                    label: localizations.budgetOverdueLabel,
                    value: formatting.amount(
                      Money(budget.overdueObligationsMinor, budget.currency),
                    ),
                    valueColor: palette.overdue,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // The card *is* the way into the income list — tap it and every source
          // is there to edit. A card that opens something without saying so is a
          // feature only its author knows about, so it says so, once, quietly.
          Row(
            children: <Widget>[
              Icon(Icons.edit_outlined, size: 13, color: palette.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  localizations.budgetManageIncome,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                size: 16,
                color: palette.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The card before any income is recorded.
class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.currency, required this.onAdd});

  final AppCurrency currency;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return AppCard(
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
                  Icons.savings_outlined,
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
                      localizations.budgetEmptyTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizations.budgetEmptyBody,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(localizations.budgetAddIncome),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of currency chips, drawn only when the ledger holds more than one.
///
/// Two currencies are never added together anywhere in the app, so a summary
/// covering both has to say which one it is about. With a single currency in use
/// there is nothing to choose and the row would be noise.
class _CurrencyStrip extends StatelessWidget {
  const _CurrencyStrip({
    required this.currencies,
    required this.selected,
    required this.onChanged,
  });

  final List<AppCurrency> currencies;
  final AppCurrency selected;
  final ValueChanged<AppCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final AppCurrency currency in currencies)
          ChoiceChip(
            label: Text(currency.codeAndSymbol),
            selected: currency == selected,
            onSelected: (_) => onChanged(currency),
          ),
      ],
    );
  }
}
