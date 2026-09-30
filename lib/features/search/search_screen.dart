import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/search_text.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/directional_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/person_avatar.dart';
import '../../core/widgets/record_rows.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reminder.dart';
import '../../l10n/generated/app_localizations.dart';

/// Instant search across names, obligations and notes.
///
/// The query is filtered in memory over the live streams rather than through a
/// database round trip: the whole ledger is already loaded, so results are
/// immediate and there is no debounce to sit through.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Open with the keyboard up: the user came here to type.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final DateTime asOf = ref.watch(todayProvider);

    final List<DebtView> debts =
        ref.watch(debtViewsProvider).value ?? const <DebtView>[];
    final List<ObligationInstance> obligations =
        ref.watch(obligationInstancesProvider).value ?? const <ObligationInstance>[];
    final List<Reminder> reminders =
        ref.watch(remindersProvider).value ?? const <Reminder>[];
    final List<PersonDirectoryEntry> people =
        ref.watch(peopleDirectoryProvider).value ??
            const <PersonDirectoryEntry>[];

    // Folded, as every field it is compared with is: «احمد» finds «أحمد».
    final String needle = foldForSearch(_query.trim());
    final bool searching = needle.isNotEmpty;

    // People first: the screen promises "names", and before this a person with
    // no records was unfindable here — even though the People tab lists them.
    final List<PersonDirectoryEntry> peopleHits = searching
        ? <PersonDirectoryEntry>[
            for (final PersonDirectoryEntry entry in people)
              if (searchMatches(entry.person.name, needle) ||
                  searchMatches(entry.person.phone, needle))
                entry,
          ]
        : const <PersonDirectoryEntry>[];

    final List<DebtView> debtHits = searching
        ? <DebtView>[
            for (final DebtView view in debts)
              if (_matchesDebt(view, needle)) view,
          ]
        : const <DebtView>[];

    final List<ObligationInstance> obligationHits = searching
        ? <ObligationInstance>[
            for (final ObligationInstance instance in obligations)
              if (_matchesObligation(instance, needle)) instance,
          ]
        : const <ObligationInstance>[];

    final List<Reminder> reminderHits = searching
        ? <Reminder>[
            for (final Reminder reminder in reminders)
              if (searchMatches(reminder.title, needle) ||
                  searchMatches(reminder.note, needle))
                reminder,
          ]
        : const <Reminder>[];

    final bool hasResults =
        peopleHits.isNotEmpty ||
        debtHits.isNotEmpty ||
        obligationHits.isNotEmpty ||
        reminderHits.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: DirectionalField(
          controller: _controller,
          builder: (BuildContext context, FieldLayout field) => TextField(
            controller: field.controller,
            textDirection: field.direction,
            textAlign: field.align,
            onTap: field.onTap,
            focusNode: _focus,
            onChanged: (String value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: localizations.searchHint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        actions: <Widget>[
          if (searching)
            IconButton(
              tooltip: localizations.actionClear,
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: !searching
          ? EmptyState(
              icon: Icons.search,
              title: localizations.searchTitle,
              body: localizations.searchHint,
            )
          : !hasResults
              ? EmptyState(
                  icon: Icons.search_off,
                  title: localizations.searchEmptyTitle,
                  body: localizations.searchEmptyBody,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.massive,
                  ),
                  children: <Widget>[
                    if (peopleHits.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        title:
                            '${localizations.navPeople} · ${peopleHits.length}',
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < peopleHits.length; i++)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ListTile(
                                    leading:
                                        PersonAvatar.of(peopleHits[i].person),
                                    title: Text(peopleHits[i].person.name),
                                    onTap: () => context.push(
                                      AppRoutes.personPath(
                                        peopleHits[i].person.id,
                                      ),
                                    ),
                                  ),
                                  if (i != peopleHits.length - 1)
                                    const AppDivider(indent: 70),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (debtHits.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        title:
                            '${localizations.filterDebts} · ${debtHits.length}',
                      ),
                      AppCard(padding: EdgeInsets.zero, child: _DebtHits(hits: debtHits, asOf: asOf)),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (obligationHits.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        title:
                            '${localizations.filterObligations} · ${obligationHits.length}',
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < obligationHits.length; i++)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ObligationRowTile(
                                    instance: obligationHits[i],
                                    asOf: asOf,
                                    onTap: () => context.push(
                                      AppRoutes.obligationPath(
                                        obligationHits[i].obligation.id,
                                      ),
                                    ),
                                  ),
                                  if (i != obligationHits.length - 1)
                                    const AppDivider(indent: 70),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                    if (reminderHits.isNotEmpty) ...<Widget>[
                      SectionHeader(
                        title:
                            '${localizations.navReminders} · ${reminderHits.length}',
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < reminderHits.length; i++)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ListTile(
                                    leading: Icon(
                                      Icons.notifications_none,
                                      color: palette.textSecondary,
                                    ),
                                    title: Text(reminderHits[i].title),
                                    subtitle: Text(
                                      context.formatting
                                          .date(reminderHits[i].dueAt),
                                    ),
                                    onTap: () => context.push(
                                      AppRoutes.reminderPath(
                                        reminderHits[i].id,
                                      ),
                                    ),
                                  ),
                                  if (i != reminderHits.length - 1)
                                    const AppDivider(indent: 64),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  /// [needle] is already folded with [foldForSearch].
  static bool _matchesDebt(DebtView view, String needle) {
    if (searchMatches(view.displayName, needle)) return true;
    if (searchMatches(view.debt.title, needle)) return true;
    if (searchMatches(view.debt.note, needle)) return true;
    // Every participant, not just the first: a shared record has to be findable
    // by any of the people it is with, and by their numbers.
    for (final Person person in view.participants) {
      if (searchMatches(person.name, needle)) return true;
      if (searchMatches(person.phone, needle)) return true;
    }
    return false;
  }

  /// [needle] is already folded with [foldForSearch].
  static bool _matchesObligation(ObligationInstance instance, String needle) {
    return searchMatches(instance.obligation.name, needle) ||
        searchMatches(instance.obligation.note, needle);
  }
}

class _DebtHits extends StatelessWidget {
  const _DebtHits({required this.hits, required this.asOf});

  final List<DebtView> hits;
  final DateTime asOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < hits.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DebtRowTile(
                view: hits[i],
                asOf: asOf,
                showDirectionBadge: true,
                onTap: () => context.push(AppRoutes.debtPath(hits[i].debt.id)),
              ),
              if (i != hits.length - 1) const AppDivider(indent: 70),
            ],
          ),
      ],
    );
  }
}
