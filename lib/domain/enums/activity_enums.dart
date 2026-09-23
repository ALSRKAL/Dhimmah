/// Everything worth showing in the "recent activity" feed.
///
/// The activity log is append-only: closing a debt never removes its history, so
/// the user can always see how a balance got to where it is.
enum ActivityType {
  debtCreated,
  debtUpdated,
  debtClosed,
  debtReopened,
  debtArchived,
  debtDeleted,
  paymentRecorded,
  paymentDeleted,
  personCreated,
  personUpdated,
  personDeleted,
  obligationCreated,
  obligationPaid,
  obligationSkipped,
  reminderCreated,
  reminderCompleted,
  dataImported,
  dataExported,
  dataCleared,
  monthSummaryGenerated;

  bool get isMoneyEvent =>
      this == ActivityType.debtCreated ||
      this == ActivityType.paymentRecorded ||
      this == ActivityType.obligationPaid ||
      this == ActivityType.debtClosed;

  /// Whether the entry should be tinted as a positive movement.
  bool get isIncoming => this == ActivityType.paymentRecorded;
}
