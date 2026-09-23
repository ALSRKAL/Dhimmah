import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/entities/reminder.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What the planner decides to schedule, and when.
///
/// These are the rules that decide whether a reminder reaches the user at all,
/// so they are asserted against a controlled clock rather than against whatever
/// time the test machine happens to be at.
///
/// Two defects are pinned here:
///
/// * The scheduling guard compared a wall-clock moment against *midnight*, so a
///   reminder whose hour had already passed today was still "in the future" and
///   was handed to Android as a past instant — which fires it immediately, as a
///   burst, while the user is looking at the app.
/// * An obligation's payload carried the *occurrence* id while the route looks
///   the record up by obligation id, so every obligation reminder opened a page
///   saying the record had been deleted. Obligations also never produced an
///   overdue nudge at all.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late NotificationComposer composer;

  setUp(() {
    db = AppDatabase.memory();
    service = buildService(db);
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
    composer = NotificationComposer(
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    );
    queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
  });
  tearDown(() async => db.close());

  /// The app's notification hour is 20:00; these tests reason from that.
  const int hour = 20;

  Future<List<DebtView>> views(DateTime asOf) async {
    final List<DebtView> out = <DebtView>[];
    await for (final List<DebtView> batch in queries.watchDebtViews(
      dueSoonWindowDays: 7,
      asOf: dateOnly(asOf),
    )) {
      out
        ..clear()
        ..addAll(batch);
      break;
    }
    return out;
  }

  Future<List<ObligationInstance>> instances(DateTime asOf) async {
    final List<ObligationInstance> out = <ObligationInstance>[];
    await for (final List<ObligationInstance> batch in
        queries.watchObligationInstances(asOf: dateOnly(asOf))) {
      out
        ..clear()
        ..addAll(batch);
      break;
    }
    return out;
  }

  List<NotificationIntent> planAt(
    DateTime now, {
    required List<DebtView> debts,
    List<ObligationInstance> obligations = const <ObligationInstance>[],
  }) =>
      NotificationPlanner.plan(
        debts: debts,
        obligations: obligations,
        reminders: const <Reminder>[],
        settings: AppSettings.initial,
        now: now,
      );

  group('a reminder whose moment has passed is not scheduled', () {
    final DateTime today = dateOnly(DateTime.now());

    Future<void> debtDueToday() async {
      final Person person = await service.createPerson(
        const PersonDraft(name: 'أحمد'),
      );
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personId: person.id,
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -1),
          dueAt: today,
          reminderLeads: const <ReminderLead>[ReminderLead.onDueDate],
        ),
      );
    }

    test('before the notification hour it is scheduled for today', () async {
      await debtDueToday();
      final DateTime now = DateTime(today.year, today.month, today.day, hour - 1);

      final List<NotificationIntent> intents =
          planAt(now, debts: await views(now));

      expect(
        intents.where((NotificationIntent i) =>
            i.kind == NotificationKind.debtDueToday),
        hasLength(1),
        reason: 'the reminder is still ahead of the user',
      );
      expect(
        intents.singleWhere((NotificationIntent i) =>
            i.kind == NotificationKind.debtDueToday).when,
        DateTime(today.year, today.month, today.day, hour),
      );
    });

    test('after the notification hour it is dropped, not fired late', () async {
      await debtDueToday();
      final DateTime now = DateTime(today.year, today.month, today.day, hour + 2);

      final List<NotificationIntent> intents =
          planAt(now, debts: await views(now));

      // Previously this intent existed with `when` two hours in the past, and the
      // plugin delivered it the instant the app opened.
      for (final NotificationIntent intent in intents) {
        expect(
          intent.when.isAfter(now),
          isTrue,
          reason: 'every scheduled moment must still be in the future; '
              '${intent.kind} was ${intent.when}',
        );
      }
      expect(
        intents.where((NotificationIntent i) =>
            i.kind == NotificationKind.debtDueToday),
        isEmpty,
      );
    });
  });

  group('obligations', () {
    final DateTime today = dateOnly(DateTime.now());

    Future<Obligation> monthlyBill() => service.createObligation(
          ObligationDraft(
            name: 'فاتورة الإنترنت',
            category: ObligationCategory.telecom,
            amountMinor: 120000,
            currency: AppCurrency.inr,
            frequency: RecurrenceFrequency.monthly,
            startAt: today,
            dayOfMonth: today.day,
            reminderLeads: const <ReminderLead>[ReminderLead.onDueDate],
          ),
        );

    test('a reminder links to the obligation, not to one of its periods',
        () async {
      final Obligation obligation = await monthlyBill();
      await service.ensureOccurrences();
      final DateTime now = DateTime(today.year, today.month, today.day, 8);

      final List<ObligationInstance> periods = await instances(now);
      final List<NotificationIntent> intents = planAt(
        now,
        debts: await views(now),
        obligations: periods,
      );

      final List<NotificationIntent> due = intents
          .where((NotificationIntent i) => i.kind == NotificationKind.obligationDue)
          .toList();
      expect(due, isNotEmpty);

      final Set<String> occurrenceIds = periods
          .map((ObligationInstance i) => i.occurrence.id)
          .toSet();
      for (final NotificationIntent intent in due) {
        expect(
          intent.payload,
          'obligation:${obligation.id}',
          reason: 'the route opens /obligations/<payload id> and looks the '
              'record up by obligation id',
        );
        // And never an occurrence id, which is what it used to carry.
        for (final String id in occurrenceIds) {
          expect(intent.payload, isNot('obligation:$id'));
        }
      }
    });

    test('every unpaid period that passes its date is nudged, once each',
        () async {
      await monthlyBill();
      await service.ensureOccurrences();

      final DateTime now = DateTime(today.year, today.month, today.day, 8);
      final List<ObligationInstance> periods = await instances(now);
      final int payable = periods
          .where((ObligationInstance i) => i.occurrence.isPayable)
          .length;

      final List<NotificationIntent> nudges = planAt(
        now,
        debts: await views(now),
        obligations: periods,
      )
          .where((NotificationIntent i) =>
              i.kind == NotificationKind.obligationOverdue)
          .toList();

      expect(
        nudges,
        hasLength(payable),
        reason: 'a commitment that passes its date must not go quiet',
      );
      for (final NotificationIntent nudge in nudges) {
        expect(nudge.when.isAfter(now), isTrue);
      }
    });

    test('paying a period stops exactly its own nudge', () async {
      await monthlyBill();
      await service.ensureOccurrences();

      final DateTime now = DateTime(today.year, today.month, today.day, 8);
      final List<ObligationInstance> before = await instances(now);
      final int nudgesBefore = planAt(
        now,
        debts: await views(now),
        obligations: before,
      ).where((NotificationIntent i) =>
          i.kind == NotificationKind.obligationOverdue).length;

      final ObligationInstance first = before.firstWhere(
        (ObligationInstance i) => i.occurrence.isPayable,
      );
      await service.markObligationPaid(first);

      final List<ObligationInstance> after = await instances(now);
      final int nudgesAfter = planAt(
        now,
        debts: await views(now),
        obligations: after,
      ).where((NotificationIntent i) =>
          i.kind == NotificationKind.obligationOverdue).length;

      expect(
        nudgesAfter,
        nudgesBefore - 1,
        reason: 'a paid period must stop being reminded about, and only it',
      );
    });
  });

  group('a notification has one identity, not a position', () {
    final DateTime today = dateOnly(DateTime.now());

    test('the same reminder gets the same id across planning passes', () async {
      final Person person = await service.createPerson(
        const PersonDraft(name: 'أحمد'),
      );
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personId: person.id,
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: addDays(today, 5),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );
      final DateTime now = DateTime(today.year, today.month, today.day, 8);
      final List<DebtView> list = await views(now);

      final List<ComposedNotification> first = composer.composeAll(
        planAt(now, debts: list),
      );
      // A second pass, a moment later, for the same ledger.
      final List<ComposedNotification> second = composer.composeAll(
        planAt(addDays(now, 0), debts: list),
      );

      expect(first, isNotEmpty);
      expect(
        first.map((ComposedNotification n) => n.id).toSet(),
        second.map((ComposedNotification n) => n.id).toSet(),
        reason: 'Android replaces a notification with a matching id; positional '
            'ids made the same reminder a different notification each pass',
      );
    });

    test('two different reminders never share an id', () async {
      final Person person = await service.createPerson(
        const PersonDraft(name: 'أحمد'),
      );
      for (final int days in <int>[5, 9, 14]) {
        await service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            personId: person.id,
            principalMinor: 100000,
            currency: AppCurrency.inr,
            issuedAt: today,
            dueAt: addDays(today, days),
            reminderLeads: const <ReminderLead>[
              ReminderLead.oneDayBefore,
              ReminderLead.threeDaysBefore,
            ],
          ),
        );
      }
      final DateTime now = DateTime(today.year, today.month, today.day, 8);
      final List<ComposedNotification> all = composer.composeAll(
        planAt(now, debts: await views(now)),
      );

      expect(all.length, greaterThan(3));
      expect(
        all.map((ComposedNotification n) => n.id).toSet(),
        hasLength(all.length),
        reason: 'a collision would make one reminder silently replace another',
      );
      for (final ComposedNotification n in all) {
        expect(n.id, greaterThanOrEqualTo(0));
      }
    });
  });
}
