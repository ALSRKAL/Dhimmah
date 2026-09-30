import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../core/money/currency.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/bottom_sheet_shell.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/record_rows.dart';
import '../../../data/services/ledger_service.dart';
import '../../../domain/entities/ledger_views.dart';
import '../../../domain/enums/debt_enums.dart';
import '../../../domain/services/debt_calculator.dart';
import '../../../l10n/enum_labels.dart';
import '../../../l10n/generated/app_localizations.dart';

/// A time window the list can be narrowed to.
enum DateWindow { any, today, thisWeek, thisMonth, custom }

/// Everything that narrows or orders a list of debts.
///
/// An immutable value, so the filter sheet can edit a copy and only commit when
/// the user applies it — cancelling must not change the list behind it.
@immutable
class DebtListFilter {
  const DebtListFilter({
    this.status = DebtFilter.all,
    this.sort = DebtSortOrder.dueDateSoonest,
    this.currency,
    this.window = DateWindow.any,
    this.from,
    this.to,
  });

  final DebtFilter status;
  final DebtSortOrder sort;

  /// Null means every currency.
  final AppCurrency? currency;

  final DateWindow window;
  final DateTime? from;
  final DateTime? to;

  bool get isDefault =>
      status == DebtFilter.all && currency == null && window == DateWindow.any;

  int get activeCount =>
      (status == DebtFilter.all ? 0 : 1) +
      (currency == null ? 0 : 1) +
      (window == DateWindow.any ? 0 : 1);

  DebtListFilter copyWith({
    DebtFilter? status,
    DebtSortOrder? sort,
    Object? currency = _unset,
    DateWindow? window,
    Object? from = _unset,
    Object? to = _unset,
  }) {
    return DebtListFilter(
      status: status ?? this.status,
      sort: sort ?? this.sort,
      currency: identical(currency, _unset)
          ? this.currency
          : currency as AppCurrency?,
      window: window ?? this.window,
      from: identical(from, _unset) ? this.from : from as DateTime?,
      to: identical(to, _unset) ? this.to : to as DateTime?,
    );
  }

  /// Whether [view] passes this filter.
  bool test(
    DebtView view, {
    required int dueSoonWindowDays,
    required DateTime asOf,
  }) {
    if (currency != null && view.currency != currency) return false;
    if (!_matchesWindow(view, asOf)) return false;
    // The archived facet is authoritative: an archived record never appears in
    // the default list, whatever its lifecycle status happens to be.
    if (status == DebtFilter.all) return !view.debt.isArchived;
    return DebtCalculator.matchesFilter(
      view,
      status,
      dueSoonWindowDays: dueSoonWindowDays,
    );
  }

  bool _matchesWindow(DebtView view, DateTime asOf) {
    if (window == DateWindow.any) return true;
    final DateTime? due = view.debt.dueAt;
    // A date filter can say nothing about a record with no deadline, so those
    // are excluded rather than silently included.
    if (due == null) return false;
    final (DateTime, DateTime) range = switch (window) {
      DateWindow.today => (asOf, asOf),
      DateWindow.thisWeek => (startOfWeek(asOf), endOfWeek(asOf)),
      DateWindow.thisMonth => (startOfMonth(asOf), endOfMonth(asOf)),
      DateWindow.custom => (from ?? asOf, to ?? asOf),
      DateWindow.any => (asOf, asOf),
    };
    return isWithin(due, range.$1, range.$2);
  }
}

const Object _unset = Object();

/// The reusable debt list.
///
/// Filtering and ordering live here so "I owe", "owed to me" and the dashboard
/// drill-downs all behave identically — including their empty states. The filter
/// itself is screen state, not app state, which is why it lives in this widget
/// rather than in a provider.
class DebtListBody extends ConsumerStatefulWidget {
  const DebtListBody({
    required this.views,
    this.direction,
    this.presetFilter,
    this.emptyTitle,
    this.emptyBody,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.headerSlivers = const <Widget>[],
    this.sortLocked = false,
    this.knownPersonId,
    super.key,
  });

  final List<DebtView> views;

  /// When set, only debts on this side of the ledger are shown.
  final DebtDirection? direction;

  /// A facet the screen itself imposes, such as the dashboard's "overdue"
  /// drill-down. The user cannot widen past it.
  final DebtFilter? presetFilter;

  final String? emptyTitle;
  final String? emptyBody;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  /// Extra slivers above the list, so a screen keeps one scroll view.
  final List<Widget> headerSlivers;

  /// Hides the sort control where the order is dictated by the screen.
  final bool sortLocked;

  /// The person whose page this list is on, when it is on one. Their rows lead
  /// with the debt's own name rather than repeating theirs, and a shared record
  /// names the others instead.
  final String? knownPersonId;

  @override
  ConsumerState<DebtListBody> createState() => _DebtListBodyState();
}

class _DebtListBodyState extends ConsumerState<DebtListBody> {
  DebtListFilter _filter = const DebtListFilter();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final DateTime asOf = ref.watch(todayProvider);
    final int dueSoonWindow = ref
        .watch(effectiveSettingsProvider)
        .dueSoonWindowDays;

    final DebtListFilter effective = widget.presetFilter == null
        ? _filter
        : _filter.copyWith(status: widget.presetFilter);

    final List<DebtView> scoped = <DebtView>[
      for (final DebtView view in widget.views)
        if (widget.direction == null || view.debt.direction == widget.direction)
          if (effective.test(
            view,
            dueSoonWindowDays: dueSoonWindow,
            asOf: asOf,
          ))
            view,
    ];
    final List<DebtView> sorted = DebtCalculator.sort(
      scoped,
      effective.sort,
      asOf: asOf,
    );

    return CustomScrollView(
      slivers: <Widget>[
        ...widget.headerSlivers,
        SliverToBoxAdapter(
          child: _ListControls(
            filter: effective,
            count: sorted.length,
            sortLocked: widget.sortLocked,
            onOpenFilters: widget.presetFilter == null
                ? () => _openFilters(context)
                : null,
            onSort: (DebtSortOrder order) =>
                setState(() => _filter = _filter.copyWith(sort: order)),
          ),
        ),
        if (sorted.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              // "You owe nothing" is a win, not an absence, and it should look
              // like one.
              // An unfiltered list with nothing in it is a settled ledger; a
              // filtered one is just a filter that matched nothing.
              tone: widget.emptyTitle == null && _filter.isDefault
                  ? EmptyTone.positive
                  : EmptyTone.neutral,
              title:
                  widget.emptyTitle ??
                  (_filter.isDefault
                      ? localizations.ioweEmptyTitle
                      : localizations.searchEmptyTitle),
              body:
                  widget.emptyBody ??
                  (_filter.isDefault ? null : localizations.searchEmptyBody),
              actionLabel: _filter.isDefault ? widget.emptyActionLabel : null,
              onAction: _filter.isDefault ? widget.onEmptyAction : null,
              secondaryLabel: _filter.isDefault
                  ? null
                  : localizations.filterReset,
              onSecondary: _filter.isDefault
                  ? null
                  : () => setState(() => _filter = const DebtListFilter()),
            ),
          )
        else
          SliverList.builder(
            itemCount: sorted.length,
            itemBuilder: (BuildContext context, int index) {
              final DebtView view = sorted[index];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DebtRowTile(
                    view: view,
                    asOf: asOf,
                    showDirectionBadge: widget.direction == null,
                    knownPersonId: widget.knownPersonId,
                    onTap: () => context.push(AppRoutes.debtPath(view.debt.id)),
                    onLongPress: () => _openRowActions(context, view),
                  ),
                  if (index != sorted.length - 1)
                    const AppDivider(indent: AppSpacing.lg),
                ],
              );
            },
          ),
        const SliverToBoxAdapter(child: SliverBottomSpacer()),
      ],
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final DebtListFilter? result = await showAppSheet<DebtListFilter>(
      context,
      child: DebtFilterSheet(
        initial: _filter,
        currencies: ref.read(currenciesInUseProvider),
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _openRowActions(BuildContext context, DebtView view) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    // On a person's page the sheet speaks the same way the row does: about the
    // person whose page it is, not about everyone the record is linked to.
    final String heading = widget.knownPersonId == null
        ? view.displayName
        : view.displayNameFor(widget.knownPersonId!);

    await showAppSheet<void>(
      context,
      // The sheet grows with its content and scrolls when it cannot fit: a
      // heading and four rows are taller than the default cap at 1.5x text on a
      // short screen, and a menu that clips its last row is a menu with an
      // unreachable action. `test/widget/layout_resilience_test.dart` drives it
      // at the largest scale.
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    heading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(localizations.actionEdit),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.debtEditPath(view.debt.id));
                },
              ),
              ListTile(
                leading: Icon(
                  view.debt.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  view.debt.isArchived
                      ? localizations.actionUnarchive
                      : localizations.actionArchive,
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final bool wasArchived = view.debt.isArchived;
                  await ref
                      .read(ledgerServiceProvider)
                      .setDebtArchived(view.debt.id, !wasArchived);
                  if (!context.mounted) return;
                  AppFeedback.info(
                    context,
                    wasArchived
                        ? localizations.debtRestored
                        : localizations.debtArchived,
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: palette.overdue),
                textColor: palette.overdue,
                title: Text(localizations.actionDelete),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _deleteWithUndo(context, view);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  /// Deletes, then offers a real undo that restores the record and its payments.
  ///
  /// Undo rather than a second confirmation dialog: a mis-tap is recoverable, and
  /// the user is not asked to confirm twice for something they meant to do.
  Future<void> _deleteWithUndo(BuildContext context, DebtView view) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed = await AppFeedback.confirmDestructive(
      context,
      title: localizations.deleteConfirmTitle,
      body: localizations.deleteConfirmBody,
      confirmLabel: localizations.actionDelete,
    );
    if (!confirmed || !context.mounted) return;

    // Taken now: the undo can be pressed after this list has gone, when
    // neither `ref` nor `context` may be used any more.
    final LedgerService service = ref.read(ledgerServiceProvider);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Color errorIcon = context.palette.overdue;
    void reportFailure() => AppFeedback.errorDetached(
          messenger: messenger,
          message: localizations.somethingWentWrong,
          iconColor: errorIcon,
        );

    final LedgerServiceSnapshot snapshot;
    try {
      snapshot = await service.deleteDebtWithSnapshot(view.debt.id);
    } on Object {
      reportFailure();
      return;
    }
    if (!context.mounted) return;

    AppFeedback.undoable(
      context,
      message: localizations.recordDeleted,
      // A failed undo is said, instead of escaping as an error nothing catches.
      onUndo: () async {
        try {
          await service.restoreDeleted(snapshot);
        } on Object {
          reportFailure();
        }
      },
    );
  }
}

/// Bottom spacing that clears the floating add button.
class SliverBottomSpacer extends StatelessWidget {
  const SliverBottomSpacer({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: AppSpacing.addButtonClearance);
}

class _ListControls extends StatelessWidget {
  const _ListControls({
    required this.filter,
    required this.count,
    required this.sortLocked,
    this.onOpenFilters,
    required this.onSort,
  });

  final DebtListFilter filter;
  final int count;
  final bool sortLocked;
  final VoidCallback? onOpenFilters;
  final ValueChanged<DebtSortOrder> onSort;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            localizations.recordsCount(count),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: palette.textSecondary),
          ),
          const Spacer(),
          if (onOpenFilters != null)
            TextButton.icon(
              onPressed: onOpenFilters,
              icon: Badge(
                isLabelVisible: filter.activeCount > 0,
                label: Text(filter.activeCount.toString()),
                child: const Icon(Icons.tune, size: 18),
              ),
              label: Text(localizations.filterTitle),
            ),
          if (!sortLocked)
            PopupMenuButton<DebtSortOrder>(
              tooltip: localizations.filterSort,
              icon: const Icon(Icons.swap_vert, size: 20),
              initialValue: filter.sort,
              onSelected: onSort,
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<DebtSortOrder>>[
                    for (final DebtSortOrder order in DebtSortOrder.values)
                      PopupMenuItem<DebtSortOrder>(
                        value: order,
                        child: Text(order.label(localizations)),
                      ),
                  ],
            ),
        ],
      ),
    );
  }
}

/// The filter sheet. Returns the chosen filter, or null when dismissed.
class DebtFilterSheet extends StatefulWidget {
  const DebtFilterSheet({
    required this.initial,
    required this.currencies,
    super.key,
  });

  final DebtListFilter initial;
  final List<AppCurrency> currencies;

  @override
  State<DebtFilterSheet> createState() => _DebtFilterSheetState();
}

class _DebtFilterSheetState extends State<DebtFilterSheet> {
  late DebtListFilter _draft = widget.initial;

  static const List<DebtFilter> _facets = <DebtFilter>[
    DebtFilter.all,
    DebtFilter.active,
    DebtFilter.unpaid,
    DebtFilter.partiallyPaid,
    DebtFilter.dueSoon,
    DebtFilter.overdue,
    DebtFilter.paid,
    DebtFilter.archived,
  ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return AppSheet(
      title: localizations.filterTitle,
      primaryLabel: localizations.filterApply,
      onPrimary: () => Navigator.of(context).pop(_draft),
      secondaryLabel: localizations.filterReset,
      onSecondary: () => setState(() => _draft = const DebtListFilter()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FieldLabel(localizations.filterStatus),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final DebtFilter facet in _facets)
                FilterChip(
                  label: Text(facet.label(localizations)),
                  selected: _draft.status == facet,
                  onSelected: (_) =>
                      setState(() => _draft = _draft.copyWith(status: facet)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FieldLabel(localizations.filterPeriod),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final DateWindow window in DateWindow.values)
                FilterChip(
                  label: Text(windowLabel(window, localizations)),
                  selected: _draft.window == window,
                  onSelected: (_) => _selectWindow(window),
                ),
            ],
          ),
          if (_draft.window == DateWindow.custom) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: localizations.periodFromLabel,
              value: _draft.from,
              onChanged: (DateTime? value) =>
                  setState(() => _draft = _draft.copyWith(from: value)),
            ),
            DateField(
              label: localizations.periodToLabel,
              value: _draft.to,
              onChanged: (DateTime? value) =>
                  setState(() => _draft = _draft.copyWith(to: value)),
            ),
          ],
          if (widget.currencies.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            FieldLabel(localizations.fieldCurrency),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                FilterChip(
                  label: Text(localizations.filterAll),
                  selected: _draft.currency == null,
                  onSelected: (_) =>
                      setState(() => _draft = _draft.copyWith(currency: null)),
                ),
                for (final AppCurrency currency in widget.currencies)
                  FilterChip(
                    label: Text(currency.code),
                    selected: _draft.currency == currency,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(currency: currency),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _selectWindow(DateWindow window) async {
    if (window != DateWindow.custom) {
      setState(() => _draft = _draft.copyWith(window: window));
      return;
    }
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDateRange: _draft.from != null && _draft.to != null
          ? DateTimeRange(start: _draft.from!, end: _draft.to!)
          : null,
    );
    if (range == null) return;
    setState(() {
      _draft = _draft.copyWith(
        window: DateWindow.custom,
        from: range.start,
        to: range.end,
      );
    });
  }
}

String windowLabel(DateWindow window, AppLocalizations localizations) =>
    switch (window) {
      DateWindow.any => localizations.periodAny,
      DateWindow.today => localizations.periodToday,
      DateWindow.thisWeek => localizations.periodThisWeek,
      DateWindow.thisMonth => localizations.periodThisMonth,
      DateWindow.custom => localizations.periodCustom,
    };
