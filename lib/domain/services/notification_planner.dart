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

    final DateTime current = dateOnly(now);
    final DateTime horizonEnd = addDays(current, horizon.inDays);
    final List<NotificationIntent> intents = <NotificationIntent>[];

    intents.addAll(_planDebts(debts, settings, current, now, horizonEnd));
    intents.addAll(
      _planObligations(obligations, settings, current, now, horizonEnd),
    );
    intents.addAll(_planReminders(reminders, settings, current, now, horizonEnd));

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

  static Iterable<NotificationIntent> _planDebts(
    List<DebtView> debts,
    AppSettings settings,
    DateTime current,
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
          daysUntil: daysBetween(current, due),
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
          daysUntil: daysBetween(current, due),
        );
      }
    }
  }

  static Iterable<NotificationIntent> _planObligations(
    List<ObligationInstance> obligations,
    AppSettings settings,
    DateTime current,
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
          daysUntil: daysBetween(current, due),
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
          daysUntil: daysBetween(current, due),
        );
      }
    }
  }

  static Iterable<NotificationIntent> _planReminders(
    List<Reminder> reminders,
    AppSettings settings,
    DateTime current,
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
        daysUntil: daysBetween(current, reminder.dueAt),
      );
    }
  }

  /// The next month-end summary.
  ///
  /// Only one is scheduled: the summary of the month that is about to end, with
  /// the figures as they stand now. Because the app rebuilds this set on every
  /// launch, the number it reports is refreshed long before it is delivered. An
  /// app that is never opened is handled separately by
  /// [pendingCatchUpSummary].
  static Iterable<NotificationIntent> _planMonthEnd({
    required AppSettings settings,
    required DateTime now,
    required int iOweMinor,
    required int owedToMeMinor,
    required int paidMinor,
    required int overdueMinor,
  }) sync* {
    final DateTime sendAt = monthEndMoment(now.year, now.month, settings);
    // Once this month's moment has passed, the catch-up path owns delivery and
    // the next launch will schedule the following month. Scheduling it here with
    // this month's numbers would report the wrong month's figures.
    if (!sendAt.isAfter(now)) return;
    yield NotificationIntent(
      kind: NotificationKind.monthEndSummary,
      when: sendAt,
      payload: 'report:${monthKey(now)}',
      summary: MonthEndFigures(
        year: now.year,
        month: now.month,
        iOweMinor: iOweMinor,
        owedToMeMinor: owedToMeMinor,
        paidMinor: paidMinor,
        overdueMinor: overdueMinor,
        currency: settings.defaultCurrency,
      ),
    );
  }

  /// A summary that should already have been delivered.
  ///
  /// If the app was closed when the month-end moment passed, the notification
  /// never fired. Showing it the next time the app opens is what makes the
  /// feature dependable rather than lucky.
  static NotificationIntent? pendingCatchUpSummary({
    required AppSettings settings,
    required DateTime now,
    required int iOweMinor,
    required int owedToMeMinor,
    required int paidMinor,
    required int overdueMinor,
  }) {
    if (!settings.notificationsEnabled || !settings.monthEndSummaryEnabled) {
      return null;
    }
    // The month that just ended, or the current month if its moment has passed.
    final DateTime? candidateMonth = _lastElapsedSummaryMonth(settings, now);
    if (candidateMonth == null) return null;

    final DateTime? lastSent = settings.lastSummarySentOn;
    if (lastSent != null && !lastSent.isBefore(startOfMonth(candidateMonth))) {
      return null; // Already delivered for that month.
    }

    return NotificationIntent(
      kind: NotificationKind.monthEndSummary,
      when: now,
      payload: 'report:${monthKey(candidateMonth)}',
      summary: MonthEndFigures(
        year: candidateMonth.year,
        month: candidateMonth.month,
        iOweMinor: iOweMinor,
        owedToMeMinor: owedToMeMinor,
        paidMinor: paidMinor,
        overdueMinor: overdueMinor,
        currency: settings.defaultCurrency,
      ),
    );
  }

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
