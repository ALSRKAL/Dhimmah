/// Lifecycle of one occurrence of a recurring obligation.
///
/// An obligation ("rent, 20,000, monthly") generates occurrences ("rent for
/// September, due 1 Sep"). Only occurrences can be paid, which is what keeps the
/// history of a recurring commitment intact.
enum ObligationStatus {
  /// Due date is in the future.
  upcoming,

  /// Due today.
  dueToday,

  /// Past its due date and still unpaid.
  overdue,

  /// Paid for this period.
  paid,

  /// Skipped by the user — a month with no rent, or a paused subscription.
  skipped,

  /// The obligation itself was archived before this occurrence came due.
  cancelled;

  bool get isOpen =>
      this == ObligationStatus.upcoming ||
      this == ObligationStatus.dueToday ||
      this == ObligationStatus.overdue;

  bool get needsAction =>
      this == ObligationStatus.overdue || this == ObligationStatus.dueToday;

  int get urgency => switch (this) {
        ObligationStatus.overdue => 4,
        ObligationStatus.dueToday => 3,
        ObligationStatus.upcoming => 2,
        ObligationStatus.paid => 1,
        ObligationStatus.skipped => 0,
        ObligationStatus.cancelled => -1,
      };
}

/// Broad buckets used to pick an icon and to group the obligations list.
enum ObligationCategory {
  housing,
  utilities,
  telecom,
  subscription,
  loan,
  installment,
  salary,
  insurance,
  tax,
  other,
}

/// How the reminder list groups its entries.
enum ReminderBucket { today, tomorrow, thisWeek, later, overdue, completed }

/// Lifecycle of a user-created reminder.
enum ReminderStatus { upcoming, today, overdue, completed, dismissed }

/// What a reminder, activity entry or notification points at.
enum RelatedEntityType { none, debt, obligation, person, reminder, payment }
