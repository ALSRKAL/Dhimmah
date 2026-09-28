/// Which way the money flows for a debt record.
enum DebtDirection {
  /// The user must pay someone.
  iOwe,

  /// Someone must pay the user.
  owedToMe;

  bool get isIOwe => this == DebtDirection.iOwe;

  /// The direction that increases the user's balance.
  bool get isOwedToMe => this == DebtDirection.owedToMe;

  DebtDirection get opposite =>
      this == DebtDirection.iOwe ? DebtDirection.owedToMe : DebtDirection.iOwe;

  /// The direction a route named, or null when it named nothing usable.
  ///
  /// Null is a real answer, not a failure: a link that says nothing about the
  /// side, or says something this build does not know, must leave the form
  /// asking the user rather than picking for them.
  static DebtDirection? fromName(String? name) => switch (name) {
        'iOwe' => DebtDirection.iOwe,
        'owedToMe' => DebtDirection.owedToMe,
        _ => null,
      };
}

/// The single label shown on a record. It answers "where does this stand?"
/// rather than describing every orthogonal property at once.
///
/// Payment progress is deliberately *not* a value here: a half-paid debt that is
/// two days late is [overdue] first, and its progress is shown as a bar. See
/// [DebtFilter] for the "partially paid" facet.
enum DebtLifecycleStatus {
  /// No due date has been set, so nothing is late yet.
  active,

  /// Due date is comfortably in the future.
  upcoming,

  /// Due date falls inside the "due soon" window.
  dueSoon,

  /// Due today.
  dueToday,

  /// Past its due date with a balance outstanding.
  overdue,

  /// Balance has reached zero.
  paid,

  /// Moved out of the way by the user.
  archived;

  /// Whether the record still needs attention.
  bool get isOpen =>
      this != DebtLifecycleStatus.paid && this != DebtLifecycleStatus.archived;

  /// Whether the record is in a state the user must act on.
  bool get needsAction =>
      this == DebtLifecycleStatus.overdue ||
      this == DebtLifecycleStatus.dueToday ||
      this == DebtLifecycleStatus.dueSoon;

  /// Severity used for sorting and for the dashboard counters. Higher is more
  /// urgent.
  int get urgency => switch (this) {
        DebtLifecycleStatus.overdue => 5,
        DebtLifecycleStatus.dueToday => 4,
        DebtLifecycleStatus.dueSoon => 3,
        DebtLifecycleStatus.upcoming => 2,
        DebtLifecycleStatus.active => 1,
        DebtLifecycleStatus.paid => 0,
        DebtLifecycleStatus.archived => -1,
      };
}

/// A facet used by the record filters. Unlike [DebtLifecycleStatus] these can
/// overlap, so a record matches a filter rather than "being" one.
enum DebtFilter {
  all,
  active,
  partiallyPaid,
  unpaid,
  paid,
  overdue,
  dueSoon,
  archived;

  bool get isStatusFacet =>
      this == DebtFilter.paid ||
      this == DebtFilter.overdue ||
      this == DebtFilter.dueSoon ||
      this == DebtFilter.archived;
}

/// Sort options offered on the record lists.
enum DebtSortOrder {
  dueDateSoonest,
  dueDateLatest,
  amountHighest,
  amountLowest,
  recentlyAdded,
  oldestAdded,
  nameAscending,
}
