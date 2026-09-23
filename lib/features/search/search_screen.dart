import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/record_rows.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/obligation.dart';
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

    final String needle = _query.trim().toLowerCase();
    final bool searching = needle.isNotEmpty;

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
              if (reminder.title.toLowerCase().contains(needle) ||
                  (reminder.note ?? '').toLowerCase().contains(needle))
                reminder,
          ]
        : const <Reminder>[];

    final bool hasResults =
        debtHits.isNotEmpty || obligationHits.isNotEmpty || reminderHits.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
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

  static bool _matchesDebt(DebtView view, String needle) {
    if (view.displayName.toLowerCase().contains(needle)) return true;
    if (view.debt.title.toLowerCase().contains(needle)) return true;
    final String? note = view.debt.note;
    if (note != null && note.toLowerCase().contains(needle)) return true;
    final String? phone = view.person?.phone;
    if (phone != null && phone.toLowerCase().contains(needle)) return true;
    return false;
  }

  static bool _matchesObligation(ObligationInstance instance, String needle) {
    if (instance.obligation.name.toLowerCase().contains(needle)) return true;
    final String? note = instance.obligation.note;
    if (note != null && note.toLowerCase().contains(needle)) return true;
    return false;
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
