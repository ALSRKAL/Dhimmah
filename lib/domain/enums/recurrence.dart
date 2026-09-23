/// How often a repeating commitment comes back around.
enum RecurrenceFrequency {
  none,
  weekly,
  monthly,
  quarterly,
  yearly,
  custom;

  bool get repeats => this != RecurrenceFrequency.none;
}

/// Pre-built reminder lead times, expressed as days before the due date.
///
/// The stored value is the day count; `0` means "on the due date". A record can
/// carry several lead times, which is how "more than one reminder" is offered
/// without inventing a whole scheduling DSL.
enum ReminderLead {
  none(-1),
  onDueDate(0),
  oneDayBefore(1),
  twoDaysBefore(2),
  threeDaysBefore(3),
  oneWeekBefore(7),
  twoWeeksBefore(14);

  const ReminderLead(this.daysBefore);

  /// Days before the due date. `-1` is the sentinel for "no reminder".
  final int daysBefore;

  bool get isNone => this == ReminderLead.none;

  static ReminderLead fromDays(int days) {
    for (final ReminderLead lead in ReminderLead.values) {
      if (lead.daysBefore == days) return lead;
    }
    return ReminderLead.none;
  }

  /// Orders lead times from furthest out to the due date itself.
  static List<ReminderLead> sorted(Iterable<ReminderLead> leads) {
    final List<ReminderLead> out = leads.where((l) => !l.isNone).toList()
      ..sort((a, b) => b.daysBefore.compareTo(a.daysBefore));
    return out;
  }
}
