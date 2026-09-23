import 'package:flutter/material.dart';

import '../../../core/formatting/app_formatting.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dhimmah_logo.dart';
import '../../../core/widgets/hero_amount.dart';
import '../../../core/widgets/money_text.dart';
import '../../../domain/entities/ledger_views.dart';
import '../../../l10n/generated/app_localizations.dart';

/// The dashboard header.
///
/// Three facts, in the order a person actually asks for them: where do I stand
/// overall, what do I owe, and what am I owed. Hierarchy does the work — one
/// large figure, two smaller ones, a hairline between them — rather than a
/// coloured panel, which would add weight without adding information.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    required this.totals,
    required this.currencies,
    required this.selectedCurrency,
    required this.onCurrencySelected,
    required this.today,
    required this.onSearch,
    required this.onSettings,
    super.key,
  });

  final CurrencyTotals totals;
  final List<AppCurrency> currencies;
  final AppCurrency selectedCurrency;
  final ValueChanged<AppCurrency> onCurrencySelected;

  /// The date shown under the app name.
  final DateTime today;

  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final int net = totals.net.minorUnits;
    final String position = net > 0
        ? localizations.dashboardInYourFavour
        : net < 0
            ? localizations.dashboardAgainstYou
            : localizations.dashboardBalanced;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _IdentityRow(
            today: today,
            onSearch: onSearch,
            onSettings: onSettings,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            position,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 2),
          // The one number the app exists to show, at its magnitude only: the
          // sentence above already carries the direction, and pairing "عليك"
          // with a minus sign reads as a double negative. The person page states
          // the same figure the same way, so the two screens match.
          HeroAmount(
            Money(totals.net.minorUnits.abs(), totals.net.currency),
            fontSize: 38,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SideBySide(totals: totals),
          if (currencies.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _CurrencySwitch(
              currencies: currencies,
              selected: selectedCurrency,
              onSelected: onCurrencySelected,
            ),
          ],
        ],
      ),
    );
  }
}

/// The app mark and today's date, with the two actions that belong on every
/// screen of a ledger.
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.today,
    required this.onSearch,
    required this.onSettings,
  });

  final DateTime today;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        const DhimmahLogo(size: 30),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(localizations.appName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 3),
              Container(
                width: 22,
                height: 2,
                decoration: BoxDecoration(
                  color: palette.gold,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.formatting.date(today),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: localizations.searchTitle,
          onPressed: onSearch,
          icon: const Icon(Icons.search_outlined, size: 22),
        ),
        IconButton(
          tooltip: localizations.settingsTitle,
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 22),
        ),
      ],
    );
  }
}

/// What I owe and what I am owed, given equal weight because neither is
/// secondary — they are the two sides of the same ledger.
class _SideBySide extends StatelessWidget {
  const _SideBySide({required this.totals});

  final CurrencyTotals totals;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _Side(
            label: localizations.dashboardIOwe,
            money: totals.iOwe,
            color: palette.iOwe,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        Container(width: 1, height: 42, color: palette.border),
        Expanded(
          child: _Side(
            label: localizations.dashboardOwedToMe,
            money: totals.owedToMe,
            color: palette.owedToMe,
            icon: Icons.arrow_downward_rounded,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.money,
    required this.color,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final Money money;
  final Color color;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 3),
        MoneyText(money, color: color, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

/// Switches the whole header between currencies.
///
/// Shown only when more than one is in use, so the common case stays quiet.
class _CurrencySwitch extends StatelessWidget {
  const _CurrencySwitch({
    required this.currencies,
    required this.selected,
    required this.onSelected,
  });

  final List<AppCurrency> currencies;
  final AppCurrency selected;
  final ValueChanged<AppCurrency> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final AppCurrency currency in currencies)
          ChoiceChip(
            label: Text(currency.code),
            selected: currency == selected,
            onSelected: (_) => onSelected(currency),
            visualDensity: VisualDensity.compact,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: currency == selected
                      ? palette.onBrandContainer
                      : palette.textSecondary,
                ),
          ),
      ],
    );
  }
}
