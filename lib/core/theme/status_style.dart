import 'package:flutter/material.dart';

import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import 'app_palette.dart';

/// How one status is drawn: a foreground colour, a tinted container and a glyph.
///
/// Every status carries an icon as well as a colour, because colour alone must
/// never be the only thing distinguishing "due soon" from "overdue".
@immutable
class StatusStyle {
  const StatusStyle({
    required this.foreground,
    required this.container,
    required this.icon,
  });

  final Color foreground;
  final Color container;
  final IconData icon;
}

/// Maps the money semantics onto the palette.
///
/// Green means money coming to the user, red means money going out. Those two
/// are reserved: nothing else in the app uses them for decoration.
extension MoneySemantics on AppPalette {
  /// The colour for an amount on a given side of the ledger.
  Color forDirection(DebtDirection direction) =>
      direction.isIOwe ? iOwe : owedToMe;

  Color containerForDirection(DebtDirection direction) =>
      direction.isIOwe ? iOweContainer : owedToMeContainer;

  Color forObligationStatus(ObligationStatus status) => switch (status) {
        ObligationStatus.overdue => overdue,
        ObligationStatus.dueToday => dueSoon,
        ObligationStatus.upcoming => iOwe,
        ObligationStatus.paid => settled,
        ObligationStatus.skipped => neutralStatus,
        ObligationStatus.cancelled => neutralStatus,
      };

  StatusStyle statusStyle(DebtLifecycleStatus status) => switch (status) {
        DebtLifecycleStatus.overdue => StatusStyle(
            foreground: overdue,
            container: overdueContainer,
            icon: Icons.error_outline,
          ),
        DebtLifecycleStatus.dueToday => StatusStyle(
            foreground: dueSoon,
            container: dueSoonContainer,
            icon: Icons.today_outlined,
          ),
        DebtLifecycleStatus.dueSoon => StatusStyle(
            foreground: dueSoon,
            container: dueSoonContainer,
            icon: Icons.schedule_outlined,
          ),
        DebtLifecycleStatus.upcoming => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: Icons.event_outlined,
          ),
        DebtLifecycleStatus.active => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: Icons.sync_outlined,
          ),
        DebtLifecycleStatus.paid => StatusStyle(
            foreground: settled,
            container: settledContainer,
            icon: Icons.check_circle_outline,
          ),
        DebtLifecycleStatus.archived => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: Icons.inventory_2_outlined,
          ),
      };

  StatusStyle obligationStyle(ObligationStatus status) => switch (status) {
        ObligationStatus.overdue => StatusStyle(
            foreground: overdue,
            container: overdueContainer,
            icon: Icons.error_outline,
          ),
        ObligationStatus.dueToday => StatusStyle(
            foreground: dueSoon,
            container: dueSoonContainer,
            icon: Icons.today_outlined,
          ),
        ObligationStatus.upcoming => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: Icons.event_outlined,
          ),
        ObligationStatus.paid => StatusStyle(
            foreground: settled,
            container: settledContainer,
            icon: Icons.check_circle_outline,
          ),
        ObligationStatus.skipped => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: Icons.skip_next_outlined,
          ),
        ObligationStatus.cancelled => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: Icons.cancel_outlined,
          ),
      };
}
