import 'package:flutter/material.dart';

import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import 'app_icons.dart';
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
            icon: AppIcons.error,
          ),
        DebtLifecycleStatus.dueToday => StatusStyle(
            foreground: dueSoon,
            container: dueSoonContainer,
            icon: AppIcons.today,
          ),
        DebtLifecycleStatus.dueSoon => StatusStyle(
            foreground: dueSoon,
            container: dueSoonContainer,
            icon: AppIcons.schedule,
          ),
        DebtLifecycleStatus.upcoming => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: AppIcons.event,
          ),
        DebtLifecycleStatus.active => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: AppIcons.sync,
          ),
        DebtLifecycleStatus.paid => StatusStyle(
            foreground: settled,
            container: settledContainer,
            icon: AppIcons.checkCircle,
          ),
        DebtLifecycleStatus.archived => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: AppIcons.inventory2,
          ),
      };

  StatusStyle obligationStyle(ObligationStatus status) => switch (status) {
        ObligationStatus.overdue => StatusStyle(
            foreground: overdue,
            container: overdueContainer,
            icon: AppIcons.error,
          ),
        ObligationStatus.dueToday => StatusStyle(
            foreground: dueSoon,
            container: dueSoonContainer,
            icon: AppIcons.today,
          ),
        ObligationStatus.upcoming => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: AppIcons.event,
          ),
        ObligationStatus.paid => StatusStyle(
            foreground: settled,
            container: settledContainer,
            icon: AppIcons.checkCircle,
          ),
        ObligationStatus.skipped => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: AppIcons.skipNext,
          ),
        ObligationStatus.cancelled => StatusStyle(
            foreground: neutralStatus,
            container: neutralStatusContainer,
            icon: AppIcons.cancel,
          ),
      };
}
