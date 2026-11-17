import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/search_text.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/person_avatar.dart';
import '../../domain/entities/ledger_views.dart';
import '../../l10n/generated/app_localizations.dart';

/// How the people list is ordered.
enum PeopleSort { activeFirst, largest, recent, alphabetical }

/// The internal address book.
///
/// Every person is a roll-up of the debts linked to them, never a stored balance,
/// so a person's position can never disagree with the records behind it.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  /// From this many people on, the list gets a search field. Below it the
  /// whole list is on one screen and a field would only push it down.
  static const int searchThreshold = 6;

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  PeopleSort _sort = PeopleSort.activeFirst;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static int _size(PersonDirectoryEntry entry) {
    int largest = 0;
    for (final CurrencyTotals t in entry.totals) {
      final int size = t.iOweMinor + t.owedToMeMinor;
      if (size > largest) largest = size;
    }
    return largest;
  }

  List<PersonDirectoryEntry> _arrange(List<PersonDirectoryEntry> data) {
    final String needle = foldForSearch(_query.trim());
    final List<PersonDirectoryEntry> shown = <PersonDirectoryEntry>[
      for (final PersonDirectoryEntry entry in data)
        if (needle.isEmpty ||
            searchMatches(entry.person.name, needle) ||
            searchMatches(entry.person.phone, needle))
          entry,
    ];
    int byName(PersonDirectoryEntry a, PersonDirectoryEntry b) =>
        a.person.name.compareTo(b.person.name);
    shown.sort(switch (_sort) {
      // Anyone still owed or owing comes first; settled contacts drop to the
      // bottom where they are out of the way but never lost.
      PeopleSort.activeFirst => (PersonDirectoryEntry a, PersonDirectoryEntry b) {
        final bool aActive = a.openDebtCount > 0;
        final bool bActive = b.openDebtCount > 0;
        if (aActive != bActive) return aActive ? -1 : 1;
        return byName(a, b);
      },
      PeopleSort.largest => (PersonDirectoryEntry a, PersonDirectoryEntry b) {
        final int bySize = _size(b).compareTo(_size(a));
        return bySize != 0 ? bySize : byName(a, b);
      },
      PeopleSort.recent => (PersonDirectoryEntry a, PersonDirectoryEntry b) {
        final int byTime = b.lastActivityAt.compareTo(a.lastActivityAt);
        return byTime != 0 ? byTime : byName(a, b);
      },
      PeopleSort.alphabetical => byName,
    });
    return shown;
  }

  String _sortLabel(AppLocalizations localizations, PeopleSort sort) =>
      switch (sort) {
        PeopleSort.activeFirst => localizations.peopleSortActiveFirst,
        PeopleSort.largest => localizations.peopleSortLargest,
        PeopleSort.recent => localizations.peopleSortRecent,
        PeopleSort.alphabetical => localizations.peopleSortAlphabetical,
      };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<PersonDirectoryEntry>> directory =
        ref.watch(peopleDirectoryProvider);
    final bool hasPeople = (directory.value ?? const <PersonDirectoryEntry>[])
        .isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.peopleTitle),
        actions: <Widget>[
          if (hasPeople)
            PopupMenuButton<PeopleSort>(
              tooltip: localizations.filterSort,
              icon: const Icon(AppIcons.swapVert, size: 20),
              initialValue: _sort,
              onSelected: (PeopleSort value) => setState(() => _sort = value),
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<PeopleSort>>[
                    for (final PeopleSort sort in PeopleSort.values)
                      PopupMenuItem<PeopleSort>(
                        value: sort,
                        child: Text(_sortLabel(localizations, sort)),
                      ),
                  ],
            ),
        ],
      ),
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
          final List<PersonDirectoryEntry> sorted = _arrange(data);
          final bool searchable = data.length >= PeopleScreen.searchThreshold;

          return Column(
            children: <Widget>[
              if (searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (String value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: localizations.peopleSearchHint,
                      prefixIcon: const Icon(AppIcons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: localizations.actionClear,
                              icon: const Icon(AppIcons.close, size: 18),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                    ),
                  ),
                ),
              Expanded(
                child: sorted.isEmpty
                    ? EmptyState(
                        compact: true,
                        title: localizations.searchEmptyTitle,
                        body: localizations.searchEmptyBody,
                      )
                    : ListView.builder(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.addButtonClearance,
                        ),
                        itemCount: sorted.length,
                        itemBuilder: (BuildContext context, int index) {
                          final PersonDirectoryEntry entry = sorted[index];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _PersonRow(entry: entry),
                              if (index != sorted.length - 1)
                                // Ends where the row's content ends. The
                                // balances are drawn against that edge, and a
                                // rule that ran on to the screen edge while
                                // they stopped short of it read as a row that
                                // had not been squared off.
                                const AppDivider(
                                  indent: 74,
                                  endIndent: AppSpacing.lg,
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
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
            PersonAvatar.of(
              entry.person,
              size: 46,
              // The same person's header carries this tag: opening their page
              // brings the picture with it.
              heroTag: 'person-avatar:${entry.person.id}',
            ),
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
                          AppIcons.error,
                          size: 14,
                          color: palette.overdue,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    debtCountLabel(
                      localizations,
                      total: entry.debts.length,
                      open: entry.openDebtCount,
                    ),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // The name gives way first — it is truncated with an ellipsis and
            // still names the person — and the balances give way last, by being
            // drawn smaller rather than cut: a shortened amount is a different
            // amount.
            //
            // Tight, not loose. `Flexible` shares the free space and then packs
            // its child at the row's *start*, so the balances began at the 50%
            // line and the whole trailing half of the row stood empty — the
            // amounts floated in the middle in Arabic. Filling the trailing half
            // and letting `_PersonBalances`' own `CrossAxisAlignment.end` place
            // the figures is what puts them on the edge, and it still bounds them
            // so a record-sized amount is scaled down rather than overflowing.
            Expanded(
              child: _PersonBalances(totals: entry.totals),
            ),
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
        // Each figure carries its side in words and a mark, not in colour
        // alone: red over green with nothing else to tell them apart read as
        // two amounts of the same kind to anyone who does not see the colours.
        if (first.iOweMinor > 0)
          _SideAmount(
            label: localizations.peopleSideIOwe,
            icon: AppIcons.arrowUpward,
            money: Money(first.iOweMinor, first.currency),
            color: palette.iOwe,
          ),
        if (first.owedToMeMinor > 0)
          _SideAmount(
            label: localizations.peopleSideOwedToMe,
            icon: AppIcons.arrowDownward,
            money: Money(first.owedToMeMinor, first.currency),
            color: palette.owedToMe,
          ),
        if (active.length > 1)
          Text(
            localizations.peopleMoreCurrencies(active.length - 1),
            style: theme.textTheme.labelSmall,
          ),
      ],
    );
  }
}

/// One side of a person's balance: its mark, its name and the amount.
class _SideAmount extends StatelessWidget {
  const _SideAmount({
    required this.label,
    required this.icon,
    required this.money,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Money money;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        // The amount has the larger share and is drawn smaller rather than cut;
        // the word gives way first, and the mark beside it still says the side.
        Flexible(
          flex: 2,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          flex: 5,
          child: MoneyText(
            money,
            style: theme.textTheme.titleSmall,
            color: color,
            shrinkToFit: true,
          ),
        ),
      ],
    );
  }
}

/// How many debts a person has, and how many of them are still open.
///
/// "Two debts" alone did not say whether anything was left to settle; the
/// count now says which of them are open.
String debtCountLabel(
  AppLocalizations localizations, {
  required int total,
  required int open,
}) {
  if (total == 0) return localizations.personDebtCount(0);
  if (open == total) return localizations.personOpenDebtCount(open);
  if (open == 0) return localizations.personSettledDebtCount(total);
  return localizations.personDebtCountWithOpen(
    localizations.personDebtCount(total),
    localizations.personOpenShort(open),
  );
}
