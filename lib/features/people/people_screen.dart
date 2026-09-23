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
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../domain/entities/ledger_views.dart';
import '../../l10n/generated/app_localizations.dart';

/// The internal address book.
///
/// Every person is a roll-up of the debts linked to them, never a stored balance,
/// so a person's position can never disagree with the records behind it.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<PersonDirectoryEntry>> directory =
        ref.watch(peopleDirectoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.peopleTitle)),
      body: AsyncValueView<List<PersonDirectoryEntry>>(
        value: directory,
        onRetry: () => ref.invalidate(peopleDirectoryProvider),
        loading: const ListSkeleton(),
        isEmpty: (List<PersonDirectoryEntry> data) => data.isEmpty,
        empty: EmptyState(
          title: localizations.peopleEmptyTitle,
          body: localizations.peopleEmptyBody,
          actionLabel: localizations.personNew,
          onAction: () => context.push(AppRoutes.personNew),
        ),
        builder: (BuildContext context, List<PersonDirectoryEntry> data) {
          final List<PersonDirectoryEntry> sorted = List<PersonDirectoryEntry>.of(data)
            ..sort((PersonDirectoryEntry a, PersonDirectoryEntry b) {
              // Anyone still owed or owing comes first; settled contacts drop to
              // the bottom where they are out of the way but never lost.
              final bool aActive = a.openDebtCount > 0;
              final bool bActive = b.openDebtCount > 0;
              if (aActive != bActive) return aActive ? -1 : 1;
              return a.person.name.compareTo(b.person.name);
            });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.massive),
            itemCount: sorted.length,
            itemBuilder: (BuildContext context, int index) {
              final PersonDirectoryEntry entry = sorted[index];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _PersonRow(entry: entry),
                  if (index != sorted.length - 1)
                    const AppDivider(indent: 74),
                ],
              );
            },
          );
        },
      ),
      // No add button here: this is a shell destination and the shell owns one.
      // A second FAB would draw on top of it.
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.entry});

  final PersonDirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push(AppRoutes.personPath(entry.person.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            PersonAvatar.of(entry.person, size: 46),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          entry.person.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.hasOverdue) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: palette.overdue,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizations.personDebtCount(entry.debts.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _PersonBalances(totals: entry.totals),
          ],
        ),
      ),
    );
  }
}

/// The two-sided balance for one person, one line per currency.
class _PersonBalances extends StatelessWidget {
  const _PersonBalances({required this.totals});

  final List<CurrencyTotals> totals;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final List<CurrencyTotals> active = <CurrencyTotals>[
      for (final CurrencyTotals entry in totals)
        if (entry.iOweMinor > 0 || entry.owedToMeMinor > 0) entry,
    ];

    if (active.isEmpty) {
      // Nobody owes anybody: say so rather than showing a zero, which would
      // read as a balance that needs attention.
      return Text(
        localizations.dashboardBalanced,
        style: theme.textTheme.labelSmall?.copyWith(color: palette.textTertiary),
      );
    }

    final CurrencyTotals first = active.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (first.iOweMinor > 0)
          MoneyText(
            Money(first.iOweMinor, first.currency),
            style: theme.textTheme.titleSmall,
            color: palette.iOwe,
          ),
        if (first.owedToMeMinor > 0)
          MoneyText(
            Money(first.owedToMeMinor, first.currency),
            style: theme.textTheme.titleSmall,
            color: palette.owedToMe,
          ),
        if (active.length > 1)
          Text(
            '+${active.length - 1}',
            style: theme.textTheme.labelSmall,
          ),
      ],
    );
  }
}
