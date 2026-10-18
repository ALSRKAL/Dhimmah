/// Everything worth showing in the "recent activity" feed.
///
/// The activity log is append-only: closing a debt never removes its history, so
/// the user can always see how a balance got to where it is.
///
/// Values are stored by name in `activity_entries.type`, so the ones already
/// shipped are frozen: they may be appended to, never renamed and never removed.
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
  // Added with schema 6, beside the obligation entries they read like.
  incomeCreated,
  incomeUpdated,
  incomeArchived,
  incomeRestored,
  incomeDeleted,
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
      this == ActivityType.debtClosed ||
      this == ActivityType.incomeCreated ||
      this == ActivityType.incomeUpdated;

  /// Whether the entry should be tinted as a positive movement.
  ///
  /// An income belongs here and not beside the obligations: the money is
  /// arriving, which is the one thing the tint says.
  bool get isIncoming =>
      this == ActivityType.paymentRecorded ||
      this == ActivityType.incomeCreated ||
      this == ActivityType.incomeUpdated;
}
