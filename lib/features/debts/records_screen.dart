import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/widgets/async_value_view.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/enums/debt_enums.dart';
import '../../l10n/generated/app_localizations.dart';
import 'debt_list.dart';

/// A cross-cutting list reached from the dashboard tiles.
///
/// The metric tiles answer "how much", and tapping one has to answer "which
/// ones" — this is that list. It spans both directions of the ledger, because
/// "due soon" and "overdue" are about timing, not about who owes whom.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({this.filter, this.directionName, super.key});

  /// One of the [DebtFilter] names; unknown values fall back to everything.
  final String? filter;

  /// Optionally narrow to one side of the ledger.
  final String? directionName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final DebtFilter facet = _parseFilter(filter);
    final DebtDirection? direction = _parseDirection(directionName);
    final AsyncValue<List<DebtView>> views = ref.watch(debtViewsProvider);

    final List<DebtView> scoped = <DebtView>[
      for (final DebtView view in views.value ?? const <DebtView>[])
        if (direction == null || view.debt.direction == direction) view,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(facet, direction, localizations)),
      ),
      body: AsyncValueView<List<DebtView>>(
        value: views,
        onRetry: () => ref.invalidate(debtViewsProvider),
        loading: const ListSkeleton(),
        builder: (BuildContext context, List<DebtView> _) => DebtListBody(
          views: scoped,
          direction: direction,
          presetFilter: facet,
          emptyTitle: localizations.searchEmptyTitle,
          emptyBody: localizations.searchEmptyBody,
        ),
      ),
      floatingActionButton: direction == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                '${AppRoutes.debtNew}?direction=${direction.name}',
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(localizations.addDebtAction),
            ),
    );
  }

  static DebtFilter _parseFilter(String? name) {
    switch (name) {
      case 'dueSoon':
        return DebtFilter.dueSoon;
      case 'overdue':
        return DebtFilter.overdue;
      case 'active':
        return DebtFilter.active;
      case 'paid':
        return DebtFilter.paid;
      case 'archived':
        return DebtFilter.archived;
      default:
        return DebtFilter.all;
    }
  }

  static DebtDirection? _parseDirection(String? name) {
    if (name == DebtDirection.iOwe.name) return DebtDirection.iOwe;
    if (name == DebtDirection.owedToMe.name) return DebtDirection.owedToMe;
    return null;
  }

  static String _title(
    DebtFilter facet,
    DebtDirection? direction,
    AppLocalizations localizations,
  ) {
    if (direction != null) {
      return direction.isIOwe
          ? localizations.ioweTitle
          : localizations.owedToMeTitle;
    }
    return switch (facet) {
      DebtFilter.dueSoon => localizations.dashboardDueSoon,
      DebtFilter.overdue => localizations.dashboardOverdue,
      DebtFilter.active => localizations.filterActive,
      DebtFilter.paid => localizations.statusPaid,
      DebtFilter.archived => localizations.filterArchived,
      _ => localizations.allRecords,
    };
  }
}
