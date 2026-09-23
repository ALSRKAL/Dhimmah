import 'package:meta/meta.dart';

import '../../domain/services/notification_planner.dart';
import '../../l10n/generated/app_localizations.dart';
import '../formatting/app_formatting.dart';
import '../money/money.dart';

/// How much a notification deserves the user's attention.
///
/// The three tiers exist so the loud one keeps meaning something: a digest that
/// arrives on the same channel as a missed payment is a digest the user learns to
/// swipe away.
enum NotificationPriority {
  /// Due today or already late.
  now,

  /// Due in the next few days.
  soon,

  /// A summary; nothing to do.
  digest,
}

/// A notification ready to hand to the operating system.
class ComposedNotification {
  const ComposedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.when,
    required this.kind,
    required this.priority,
  });

  /// The notification's identity, derived from what it is about rather than from
  /// its position in the list.
  ///
  /// Android replaces a notification that shares an id, which is the mechanism
  /// that makes a duplicate impossible: two passes that both plan "the 20:00
  /// reminder for Ahmed's car loan" compute the same id and the second replaces
  /// the first. Positional ids could not do that — the same reminder moved
  /// position as soon as any other record changed, and Android saw two
  /// different notifications.
  final int id;

  final String title;
  final String body;
  final String payload;
  final DateTime when;
  final NotificationKind kind;
  final NotificationPriority priority;

  bool get isSummary => kind == NotificationKind.monthEndSummary;
}

/// Turns planner intents into localised notification text.
///
/// Kept apart from delivery so the wording can be reviewed and tested without a
/// device, and so a notification reads exactly like the screen it opens.
class NotificationComposer {
  const NotificationComposer({required this.localizations, required this.formatting});

  final AppLocalizations localizations;
  final AppFormatting formatting;

  ComposedNotification compose(NotificationIntent intent, int id) {
    return ComposedNotification(
      id: id,
      title: _title(intent),
      body: _body(intent),
      payload: intent.payload,
      when: intent.when,
      kind: intent.kind,
      priority: _priorityFor(intent),
    );
  }

  /// Composes a whole batch, identifying each notification by what it is about.
  List<ComposedNotification> composeAll(List<NotificationIntent> intents) {
    final List<ComposedNotification> out = <ComposedNotification>[];
    for (final NotificationIntent intent in intents) {
      out.add(compose(intent, idFor(intent)));
    }
    return out;
  }

  /// The notification id for an intent, stable across scheduling passes.
  ///
  /// The identity is the record, the kind of reminder and the moment it is for:
  /// exactly the three things that make two notifications the same notification.
  /// A 31-bit FNV-1a hash of that string, which is what Android's id needs to be.
  @visibleForTesting
  static int idFor(NotificationIntent intent) {
    final String identity =
        '${intent.payload}|${intent.kind.name}|${intent.when.toIso8601String()}';
    int hash = 0x811c9dc5;
    for (final int unit in identity.codeUnits) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    // Keep it inside a positive 31-bit range: Android notification ids are ints
    // and the plugin passes them through a signed 32-bit channel.
    return hash & 0x7FFFFFFF;
  }

  /// Suspends nothing: the tier follows the record's own deadline, not how the
  /// notification was triggered. A "three days before" reminder for something
  /// already overdue is still urgent.
  static NotificationPriority _priorityFor(NotificationIntent intent) {
    return switch (intent.kind) {
      NotificationKind.debtDueToday ||
      NotificationKind.debtOverdue ||
      NotificationKind.obligationOverdue =>
        NotificationPriority.now,
      NotificationKind.debtDueSoon ||
      NotificationKind.obligationDue ||
      NotificationKind.reminderDue =>
        (intent.daysUntil ?? 0) <= 0
            ? NotificationPriority.now
            : NotificationPriority.soon,
      NotificationKind.monthEndSummary => NotificationPriority.digest,
    };
  }

  String _title(NotificationIntent intent) => switch (intent.kind) {
        NotificationKind.debtDueSoon => localizations.notifDueSoonTitle,
        NotificationKind.debtDueToday => localizations.notifDueTodayTitle,
        NotificationKind.debtOverdue => localizations.notifOverdueTitle,
        NotificationKind.obligationDue => localizations.notifObligationTitle,
        NotificationKind.obligationOverdue => localizations.notifOverdueTitle,
        NotificationKind.reminderDue => localizations.notifReminderTitle,
        NotificationKind.monthEndSummary => localizations.notifMonthEndTitle,
      };

  String _body(NotificationIntent intent) {
    if (intent.kind == NotificationKind.monthEndSummary) {
      return _summaryBody(intent);
    }

    if (intent.kind == NotificationKind.reminderDue) {
      return localizations.notifReminderBody(intent.reminderTitle ?? '');
    }

    final String name = intent.displayName;
    final Money? amount = intent.amount;
    if (amount == null) return name;

    final String formatted = formatting.amount(amount);

    if (intent.kind == NotificationKind.debtDueToday) {
      return localizations.notifDueTodayBody(name, formatted);
    }

    final int days = intent.daysUntil ?? 0;
    final String when = days < 0
        ? localizations.dateOverdueBy(-days)
        : localizations.dateInDays(days);

    return localizations.notifDueSoonBody(name, formatted, when);
  }

  String _summaryBody(NotificationIntent intent) {
    final MonthEndFigures? figures = intent.summary;
    if (figures == null) return '';

    final String iOwe = formatting.amount(
      Money(figures.iOweMinor, figures.currency),
    );
    final String owedToMe = formatting.amount(
      Money(figures.owedToMeMinor, figures.currency),
    );
    final String paid = formatting.amount(
      Money(figures.paidMinor, figures.currency),
    );

    if (!figures.hasOverdue) {
      return localizations.notifMonthEndBody(iOwe, owedToMe, paid);
    }
    final String overdue = formatting.amount(
      Money(figures.overdueMinor, figures.currency),
    );
    return localizations.notifMonthEndBodyWithOverdue(iOwe, owedToMe, paid, overdue);
  }
}
