import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../entities/app_settings.dart';
import '../entities/ledger_views.dart';
import '../entities/obligation.dart';
import '../entities/reminder.dart';
import '../enums/debt_enums.dart';
import '../enums/recurrence.dart';

/// What a scheduled notification is about.
enum NotificationKind {
  debtDueSoon,
  debtDueToday,
  debtOverdue,
  obligationDue,
  obligationOverdue,
  reminderDue,
  monthEndSummary,

  /// The app itself cannot keep its promise: a backup that will not write, or a
  /// folder whose permission was taken back.
  ///
  /// Not planned from a record like the others — it is raised by the backup
  /// layer when protection actually breaks — but it is a notification kind like
  /// any other, so its wording lives with every other sentence the app sends.
  backupProblem,
}

/// One notification the app wants delivered, described in domain terms.
///
/// Intents carry data, not sentences: the wording is composed later from the ARB
/// files, so a notification is localised exactly like the screen it opens. This
/// is also what keeps the planner testable without a notification plugin.
class NotificationIntent {
  const NotificationIntent({
    required this.kind,
    required this.when,
    required this.payload,
    this.personName,
    this.recordTitle,
    this.amount,
    this.direction,
    this.daysUntil,
    this.reminderTitle,
    this.summary,
  });

  final NotificationKind kind;

  /// Local wall-clock moment the notification should be delivered.
  final DateTime when;

  /// Deep-link payload, e.g. `debt:abc123`.
  final String payload;

  final String? personName;
  final String? recordTitle;
  final Money? amount;
  final DebtDirection? direction;

  /// Days from the day this notification is *delivered* to the record's due
  /// date — 1 for a reminder the day before, negative once it is late.
  ///
  /// Counted from delivery, not from planning: the sentence is read when it
  /// arrives. Counting from the day the plan ran made a reminder planned six
  /// days out arrive the day before the deadline saying «خلال 6 أيام», and made
  /// the words change every day — which, now that a reminder whose words
  /// changed is re-worded, would have re-scheduled every one of them daily.
  final int? daysUntil;
  final String? reminderTitle;

  /// Present only on [NotificationKind.monthEndSummary].
  final MonthEndFigures? summary;

  /// The name to lead with, falling back to the free-text title.
  String get displayName {
    final String? person = personName?.trim();
    if (person != null && person.isNotEmpty) return person;
    final String? title = recordTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return '';
  }
}

/// The numbers carried by a month-end summary notification.
class MonthEndFigures {
  const MonthEndFigures({
    required this.year,
    required this.month,
    required this.iOweMinor,
    required this.owedToMeMinor,
    required this.paidMinor,
    required this.overdueMinor,
    required this.currency,
  });

  final int year;
  final int month;
  final int iOweMinor;
  final int owedToMeMinor;
  final int paidMinor;
  final int overdueMinor;
  final AppCurrency currency;

  bool get hasOverdue => overdueMinor > 0;
}

/// Decides which notifications Dhimmah should have pending.
///
/// The planner is pure: give it the current records and a clock, and it returns
/// the complete set of notifications that should exist. The service replaces
/// whatever was scheduled with this set, which is what keeps a stale reminder
/// from firing after its debt was paid off.
abstract final class NotificationPlanner {
  const NotificationPlanner._();

  /// How many days after a due date to nudge again about something unpaid.
  ///
  /// One nudge, not a daily stream: the spec is explicit that notifications must
  /// not become noise.
  static const int overdueNudgeAfterDays = 2;

  /// Notifications further ahead than this are not worth scheduling; the app
  /// recomputes the whole set every time it opens.
  static const Duration horizon = Duration(days: 400);

  /// The longest lead a record can carry, in days.
  ///
  /// Derived from the enum rather than written down, because it is the bound a
  /// caller uses to decide how far it has to read before the soonest
  /// notifications are certainly covered: a record due later than
  /// `that moment + this many days` cannot deliver before it.
  static final int maxLeadDays = ReminderLead.values
      .map((ReminderLead lead) => lead.daysBefore)
      .reduce((int a, int b) => a > b ? a : b);

  /// Builds the full set of pending notifications.
  static List<NotificationIntent> plan({
    required List<DebtView> debts,
    required List<ObligationInstance> obligations,
    required List<Reminder> reminders,
    required AppSettings settings,
    required DateTime now,
    int? summaryIOweMinor,
    int? summaryOwedToMeMinor,
    int? summaryPaidMinor,
    int? summaryOverdueMinor,
  }) {
    if (!settings.notificationsEnabled) return const <NotificationIntent>[];

    final List<NotificationIntent> intents = <NotificationIntent>[
      ...planDebts(debts: debts, settings: settings, now: now),
      ...planObligations(
        obligations: obligations,
        settings: settings,
        now: now,
      ),
      ...planReminders(reminders: reminders, settings: settings, now: now),
    ];

    if (settings.monthEndSummaryEnabled) {
      intents.addAll(
        _planMonthEnd(
          settings: settings,
          now: now,
          iOweMinor: summaryIOweMinor ?? 0,
          owedToMeMinor: summaryOwedToMeMinor ?? 0,
          paidMinor: summaryPaidMinor ?? 0,
          overdueMinor: summaryOverdueMinor ?? 0,
        ),
      );
    }

    intents.sort(
      (NotificationIntent a, NotificationIntent b) => a.when.compareTo(b.when),
    );
    return intents;
  }

  /// The notifications a set of debts asks for.
  ///
  /// Public because the delivery path plans debts in pages — reading the whole
  /// ledger to build a few hundred notifications is what made every save slow at
  /// scale — and both paths have to produce the same intents.
  static List<NotificationIntent> planDebts({
    required List<DebtView> debts,
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!settings.notificationsEnabled) return const <NotificationIntent>[];
    final DateTime current = dateOnly(now);
    final DateTime horizonEnd = addDays(current, horizon.inDays);
    return _planDebts(debts, settings, now, horizonEnd).toList();
  }

  /// The notifications a set of commitment periods asks for.
  static List<NotificationIntent> planObligations({
    required List<ObligationInstance> obligations,
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!settings.notificationsEnabled) return const <NotificationIntent>[];
    final DateTime current = dateOnly(now);
    final DateTime horizonEnd = addDays(current, horizon.inDays);
    return _planObligations(obligations, settings, now, horizonEnd)
        .toList();
  }

  /// The notifications the user's own reminders ask for.
  static List<NotificationIntent> planReminders({
    required List<Reminder> reminders,
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!settings.notificationsEnabled) return const <NotificationIntent>[];
    final DateTime current = dateOnly(now);
    final DateTime horizonEnd = addDays(current, horizon.inDays);
    return _planReminders(reminders, settings, now, horizonEnd)
        .toList();
  }

  static Iterable<NotificationIntent> _planDebts(
    List<DebtView> debts,
    AppSettings settings,
    DateTime now,
    DateTime horizonEnd,
  ) sync* {
    for (final DebtView view in debts) {
      if (!view.isOpen) continue;
      final DateTime? due = view.debt.dueAt;
      if (due == null) continue;

      for (final ReminderLead lead in view.debt.reminderLeads) {
        if (lead.isNone) continue;
        final DateTime when = _atNotificationTime(
          addDays(due, -lead.daysBefore),
          settings,
        );
        if (!when.isAfter(now) || when.isAfter(horizonEnd)) continue;
        yield NotificationIntent(
          kind: lead.daysBefore == 0
              ? NotificationKind.debtDueToday
              : NotificationKind.debtDueSoon,
          when: when,
          payload: 'debt:${view.debt.id}',
          personName: view.person?.name,
          recordTitle: view.debt.title,
          amount: view.remaining,
          direction: view.debt.direction,
          daysUntil: daysBetween(dateOnly(when), due),
        );
      }

      // A single nudge after the deadline passes, and only for records that
      // were already overdue before today so re-opening the app cannot re-arm it.
      final DateTime nudge = _atNotificationTime(
        addDays(due, overdueNudgeAfterDays),
        settings,
      );
      if (nudge.isAfter(now) && !nudge.isAfter(horizonEnd)) {
        yield NotificationIntent(
          kind: NotificationKind.debtOverdue,
          when: nudge,
          payload: 'debt:${view.debt.id}',
          personName: view.person?.name,
          recordTitle: view.debt.title,
          amount: view.remaining,
          direction: view.debt.direction,
          daysUntil: daysBetween(dateOnly(nudge), due),
        );
      }
    }
  }

  static Iterable<NotificationIntent> _planObligations(
    List<ObligationInstance> obligations,
    AppSettings settings,
    DateTime now,
    DateTime horizonEnd,
  ) sync* {
    for (final ObligationInstance instance in obligations) {
      if (!instance.occurrence.isPayable) continue;
      final DateTime due = instance.occurrence.dueAt;
      final List<ReminderLead> leads = instance.obligation.reminderLeads;

      for (final ReminderLead lead in leads) {
        if (lead.isNone) continue;
        final DateTime when = _atNotificationTime(
          addDays(due, -lead.daysBefore),
          settings,
        );
        if (!when.isAfter(now) || when.isAfter(horizonEnd)) continue;
        yield NotificationIntent(
          kind: NotificationKind.obligationDue,
          when: when,
          // The obligation's id, not the occurrence's: the route opens
          // `/obligations/<id>` and looks the record up by obligation id, so an
          // occurrence id here opened the page for a record that does not exist
          // and told the user it had been deleted.
          payload: 'obligation:${instance.obligation.id}',
          recordTitle: instance.obligation.name,
          amount: instance.money,
          daysUntil: daysBetween(dateOnly(when), due),
        );
      }

      // The same single nudge a debt gets. Without it a recurring commitment
      // could pass its date and go on being late in silence, which is exactly
      // what a reminder app must not do.
      final DateTime nudge = _atNotificationTime(
        addDays(due, overdueNudgeAfterDays),
        settings,
      );
      if (nudge.isAfter(now) && !nudge.isAfter(horizonEnd)) {
        yield NotificationIntent(
          kind: NotificationKind.obligationOverdue,
          when: nudge,
          payload: 'obligation:${instance.obligation.id}',
          recordTitle: instance.obligation.name,
          amount: instance.money,
          daysUntil: daysBetween(dateOnly(nudge), due),
        );
      }
    }
  }

  static Iterable<NotificationIntent> _planReminders(
    List<Reminder> reminders,
    AppSettings settings,
    DateTime now,
    DateTime horizonEnd,
  ) sync* {
    for (final Reminder reminder in reminders) {
      if (!reminder.isOpen) continue;
      final DateTime when = _atNotificationTime(reminder.dueAt, settings);
      if (!when.isAfter(now) || when.isAfter(horizonEnd)) continue;
      yield NotificationIntent(
        kind: NotificationKind.reminderDue,
        when: when,
        payload: 'reminder:${reminder.id}',
        reminderTitle: reminder.title,
        daysUntil: daysBetween(dateOnly(when), reminder.dueAt),
      );
    }
  }

  /// The next month-end summary, for [plan].
  static Iterable<NotificationIntent> _planMonthEnd({
    required AppSettings settings,
    required DateTime now,
    required int iOweMinor,
    required int owedToMeMinor,
    required int paidMinor,
    required int overdueMinor,
  }) sync* {
    final NotificationIntent? summary = monthEndSummary(
      settings: settings,
      now: now,
      iOweMinor: iOweMinor,
      owedToMeMinor: owedToMeMinor,
      paidMinor: paidMinor,
      overdueMinor: overdueMinor,
    );
    if (summary != null) yield summary;
  }

  /// How long before its moment the month-end summary is armed.
  ///
  /// The summary carries the ledger's figures, and working them out reads the
  /// whole ledger — so a save pays for that only in the last days before the
  /// summary is due, and the figures it arrives with are at most that old. A
  /// phone the app is not opened on in those days is covered by
  /// [pendingCatchUpSummary], which delivers it on the next launch.
  static const Duration monthEndArmWindow = Duration(days: 3);

  /// The moment of the month-end summary that should be armed now, or null.
  ///
  /// This month's moment, while it is still ahead and inside
  /// [monthEndArmWindow]. The cheap half of the decision: the delivery path
  /// asks this before it reads a single record.
  ///
  /// Nothing used to arm the summary at all — the service planned debts,
  /// commitments and reminders, and the summary only ever arrived late, as a
  /// catch-up on the first launch after its moment.
  static DateTime? monthEndToArm({
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!settings.notificationsEnabled || !settings.monthEndSummaryEnabled) {
      return null;
    }
    final DateTime sendAt = monthEndMoment(now.year, now.month, settings);
    if (!sendAt.isAfter(now)) return null;
    if (sendAt.difference(now) > monthEndArmWindow) return null;
    return sendAt;
  }

  /// The summary of the month that is about to end, to be delivered at its
  /// moment with the figures as they stand now.
  ///
  /// Null once this month's moment has passed: from then on the catch-up path
  /// owns delivery, and scheduling it here would report this month's figures
  /// under next month's name. [currency] is the one the figures are in, which
  /// is the ledger's main currency and not necessarily the default for new
  /// records.
  static NotificationIntent? monthEndSummary({
    required AppSettings settings,
    required DateTime now,
    required int iOweMinor,
    required int owedToMeMinor,
    required int paidMinor,
    required int overdueMinor,
    AppCurrency? currency,
  }) {
    final DateTime sendAt = monthEndMoment(now.year, now.month, settings);
    if (!sendAt.isAfter(now)) return null;
    return _summaryIntent(
      month: DateTime(now.year, now.month),
      when: sendAt,
      iOweMinor: iOweMinor,
      owedToMeMinor: owedToMeMinor,
      paidMinor: paidMinor,
      overdueMinor: overdueMinor,
      currency: currency ?? settings.defaultCurrency,
    );
  }

  /// A summary that should already have been delivered.
  ///
  /// If the app was closed when the month-end moment passed, the notification
  /// never fired. Showing it the next time the app opens is what makes the
  /// feature dependable rather than lucky.
  ///
  /// Its moment is the one the summarised month was due at, not the moment it is
  /// shown: a notification's identity includes its moment, and "now" made every
  /// catch-up a different notification, so two deliveries stacked instead of
  /// the second replacing the first.
  static NotificationIntent? pendingCatchUpSummary({
    required AppSettings settings,
    required DateTime now,
    required int iOweMinor,
    required int owedToMeMinor,
    required int paidMinor,
    required int overdueMinor,
    AppCurrency? currency,
  }) {
    final DateTime? candidateMonth =
        catchUpSummaryMonth(settings: settings, now: now);
    if (candidateMonth == null) return null;

    return _summaryIntent(
      month: candidateMonth,
      when: monthEndMoment(candidateMonth.year, candidateMonth.month, settings),
      iOweMinor: iOweMinor,
      owedToMeMinor: owedToMeMinor,
      paidMinor: paidMinor,
      overdueMinor: overdueMinor,
      currency: currency ?? settings.defaultCurrency,
    );
  }

  static NotificationIntent _summaryIntent({
    required DateTime month,
    required DateTime when,
    required int iOweMinor,
    required int owedToMeMinor,
    required int paidMinor,
    required int overdueMinor,
    required AppCurrency currency,
  }) {
    return NotificationIntent(
      kind: NotificationKind.monthEndSummary,
      when: when,
      payload: 'report:${monthKey(month)}',
      summary: MonthEndFigures(
        year: month.year,
        month: month.month,
        iOweMinor: iOweMinor,
        owedToMeMinor: owedToMeMinor,
        paidMinor: paidMinor,
        overdueMinor: overdueMinor,
        currency: currency,
      ),
    );
  }

  /// Whether a month-end summary is owed, without working out its figures.
  ///
  /// The figures need the whole ledger; this needs two settings and a date. The
  /// delivery path asks this first, so a save on a large ledger does not read
  /// every record to discover that no summary is due.
  ///
  /// `lastSummarySentOn` holds a day inside the last month whose summary was
  /// handed to the phone — armed ahead of its moment, or shown late — so the
  /// comparison is against the start of the month in question.
  static bool isCatchUpSummaryDue({
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!settings.notificationsEnabled || !settings.monthEndSummaryEnabled) {
      return false;
    }
    final DateTime? candidateMonth = _lastElapsedSummaryMonth(settings, now);
    if (candidateMonth == null) return false;

    final DateTime? lastSent = settings.lastSummarySentOn;
    return lastSent == null || lastSent.isBefore(startOfMonth(candidateMonth));
  }

  /// The month a catch-up summary would describe, or null when none is owed.
  static DateTime? catchUpSummaryMonth({
    required AppSettings settings,
    required DateTime now,
  }) {
    if (!isCatchUpSummaryDue(settings: settings, now: now)) return null;
    return _lastElapsedSummaryMonth(settings, now);
  }

  /// The day recorded once [month]'s summary has been handed to the phone.
  ///
  /// A day inside the month the summary is *about*. The delivery date used to be
  /// recorded instead — and a catch-up is delivered in the following month, so
  /// recording it said the following month was done too, and every other
  /// month's summary was silently skipped.
  static DateTime summaryRecordFor(DateTime month, AppSettings settings) =>
      dateOnly(monthEndMoment(month.year, month.month, settings));

  /// The most recent month whose summary moment has already passed.
  static DateTime? _lastElapsedSummaryMonth(AppSettings settings, DateTime now) {
    final DateTime thisMonthMoment = monthEndMoment(now.year, now.month, settings);
    if (!thisMonthMoment.isAfter(now)) return DateTime(now.year, now.month);
    final DateTime previous = addMonths(DateTime(now.year, now.month), -1);
    return DateTime(previous.year, previous.month);
  }

  /// The exact moment the summary goes out for a given month, clamped to a day
  /// that month actually has.
  static DateTime monthEndMoment(int year, int month, AppSettings settings) {
    final int lastDay = daysInMonth(year, month);
    final int requested = settings.monthEndDay.isLastDay
        ? lastDay
        : settings.monthEndDay.dayOfMonth;
    final int day = requested > lastDay ? lastDay : requested;
    return DateTime(year, month, day, settings.monthEndHour, settings.monthEndMinute);
  }

  /// Moves a calendar date to the user's configured notification time.
  static DateTime _atNotificationTime(DateTime date, AppSettings settings) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      settings.notificationHour,
      settings.notificationMinute,
    );
  }
}
