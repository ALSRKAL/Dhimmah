import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/notifications/notification_composer.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/amount_rules.dart';
import '../../domain/services/debt_calculator.dart';
import '../../domain/services/notification_planner.dart';
import '../../domain/services/obligation_schedule.dart';
import '../../l10n/generated/app_localizations.dart';
import '../database/app_database.dart';

/// Every write Dhimmah can perform.
///
/// Screens call this and nothing else: the service owns the invariants that must
/// hold whatever route the user took —
///
/// * a payment always belongs to the record it was made against;
/// * closing a debt stamps the moment its balance reached zero;
/// * a recurring commitment always has its next period ready;
/// * every change that matters lands in the activity feed;
/// * the pending notifications are rebuilt after any change, so a settled debt
///   never reminds anyone again.
class LedgerService {
  LedgerService({
    required AppDatabase database,
    required this.people,
    required this.debts,
    required this.payments,
    required this.obligations,
    required this.reminders,
    required this.activity,
    required this.settings,
    required this.notifications,
    required this.localizations,
    required this.composer,
    required this.clock,
  }) : _db = database;

  final AppDatabase _db;
  final PersonRepository people;
  final DebtRepository debts;
  final PaymentRepository payments;
  final ObligationRepository obligations;
  final ReminderRepository reminders;
  final ActivityRepository activity;
  final SettingsRepository settings;
  final NotificationService notifications;

  /// Locale and clock are callbacks because both can change while the app runs:
  /// the user can switch language, and tests move time instead of waiting.
  final AppLocalizations Function() localizations;
  final NotificationComposer Function() composer;
  final DateTime Function() clock;

  /// How far ahead obligation periods are materialised.
  static const int obligationHorizonDays = 90;

  /// How far back unpaid periods are materialised. Anything older is history the
  /// user did not record, and turning it into a wall of overdue rows would be
  /// both wrong and alarming.
  static const int obligationLookbackDays = 60;

  // --- People --------------------------------------------------------------

  Future<Person> createPerson(PersonDraft draft) async {
    final DateTime now = clock();
    final Person person = Person(
      id: newId(),
      name: draft.name.trim(),
      phone: _blankToNull(draft.phone),
      note: _blankToNull(draft.note),
      colorIndex: draft.colorIndex,
      createdAt: now,
      updatedAt: now,
    );
    await people.save(person);
    await _log(
      type: ActivityType.personCreated,
      entityType: RelatedEntityType.person,
      entityId: person.id,
      title: person.name,
    );
    await refreshNotifications();
    return person;
  }

  Future<void> updatePerson(String id, PersonDraft draft) async {
    final Person? existing = await people.getById(id);
    if (existing == null) return;
    await people.save(
      existing.copyWith(
        name: draft.name.trim(),
        phone: _blankToNull(draft.phone),
        note: _blankToNull(draft.note),
        colorIndex: draft.colorIndex,
        updatedAt: clock(),
      ),
    );
    await _log(
      type: ActivityType.personUpdated,
      entityType: RelatedEntityType.person,
      entityId: id,
      title: draft.name.trim(),
    );
  }

  /// Moves a person in or out of the archive.
  Future<void> setPersonArchived(String id, {required bool archived}) async {
    final Person? existing = await people.getById(id);
    if (existing == null) return;
    await people.setArchived(id, archived: archived);
    await _log(
      type: archived ? ActivityType.debtArchived : ActivityType.debtReopened,
      entityType: RelatedEntityType.person,
      entityId: id,
      title: existing.name,
    );
  }

  /// Removes a person. Their debts survive without a link, because deleting a
  /// person must never quietly delete money the user is still owed.
  Future<void> deletePerson(String id) async {
    final Person? existing = await people.getById(id);
    await people.delete(id);
    await _log(
      type: ActivityType.personDeleted,
      entityType: RelatedEntityType.person,
      entityId: id,
      title: existing?.name ?? '',
    );
    await refreshNotifications();
  }

  // --- Debts ---------------------------------------------------------------

  /// Refuses an amount that cannot be money.
  ///
  /// The screens validate first and show a message in the user's language, so
  /// reaching this means a caller skipped that. Failing here is deliberate: a
  /// silently stored zero or negative amount corrupts every total derived from
  /// it, and a negative *payment* would make the remaining balance grow.
  static void _requireValidAmount(int minorUnits, String what) {
    if (!AmountRules.isValid(minorUnits)) {
      throw InvalidAmountException(what, minorUnits);
    }
  }

  Future<Debt> createDebt(DebtDraft draft) async {
    _requireValidAmount(draft.principalMinor, 'debt principal');
    final DateTime now = clock();
    final Debt debt = Debt(
      id: newId(),
      personId: draft.personId,
      direction: draft.direction,
      title: draft.title.trim(),
      principalMinor: draft.principalMinor,
      currency: draft.currency,
      issuedAt: dateOnly(draft.issuedAt),
      dueAt: draft.dueAt == null ? null : dateOnly(draft.dueAt!),
      note: _blankToNull(draft.note),
      reminderLeads: ReminderLead.sorted(draft.reminderLeads),
      recurrence: draft.recurrence,
      recurrenceInterval: draft.recurrenceInterval,
      recurrenceEndAt:
          draft.recurrenceEndAt == null ? null : dateOnly(draft.recurrenceEndAt!),
      createdAt: now,
      updatedAt: now,
    );
    await debts.save(debt);
    await _log(
      type: ActivityType.debtCreated,
      entityType: RelatedEntityType.debt,
      entityId: debt.id,
      title: await _displayNameFor(debt),
      amountMinor: debt.principalMinor,
      currency: debt.currency,
    );
    await refreshNotifications();
    return debt;
  }

  Future<void> updateDebt(String id, DebtDraft draft) async {
    _requireValidAmount(draft.principalMinor, 'debt principal');
    final Debt? existing = await debts.getById(id);
    if (existing == null) return;

    final Debt updated = existing.copyWith(
      personId: draft.personId,
      direction: draft.direction,
      title: draft.title.trim(),
      principalMinor: draft.principalMinor,
      currency: draft.currency,
      issuedAt: dateOnly(draft.issuedAt),
      dueAt: draft.dueAt == null ? null : dateOnly(draft.dueAt!),
      note: _blankToNull(draft.note),
      reminderLeads: ReminderLead.sorted(draft.reminderLeads),
      recurrence: draft.recurrence,
      recurrenceInterval: draft.recurrenceInterval,
      recurrenceEndAt:
          draft.recurrenceEndAt == null ? null : dateOnly(draft.recurrenceEndAt!),
      updatedAt: clock(),
    );
    await debts.save(updated);

    // A payment has no currency of its own: it is recorded in the debt's, and
    // inherits it at creation. So when the user corrects the debt's currency,
    // the payments must follow it — otherwise a debt retagged from rupees to
    // dollars keeps rupee payments and the two get summed as though they were
    // the same unit, which is a wrong number, not a missing feature.
    if (existing.currency != updated.currency) {
      final List<Payment> existingPayments = await payments.forDebt(id);
      for (final Payment payment in existingPayments) {
        if (payment.currency == updated.currency) continue;
        await payments.save(
          payment.copyWith(currency: updated.currency),
        );
      }
    }

    await _log(
      type: ActivityType.debtUpdated,
      entityType: RelatedEntityType.debt,
      entityId: id,
      title: await _displayNameFor(updated),
      amountMinor: updated.principalMinor,
      currency: updated.currency,
    );
    // A changed balance can change whether a closing stamp is still correct.
    await _syncClosedStamp(updated);
    await refreshNotifications();
  }

  Future<void> setDebtArchived(String id, bool archived) async {
    final Debt? existing = await debts.getById(id);
    if (existing == null) return;
    await debts.setArchived(id, archived: archived);
    await _log(
      type: archived ? ActivityType.debtArchived : ActivityType.debtReopened,
      entityType: RelatedEntityType.debt,
      entityId: id,
      title: await _displayNameFor(existing),
    );
    await refreshNotifications();
  }

  /// Permanently removes a debt and its payments.
  Future<void> deleteDebt(String id) async {
    await deleteDebtWithSnapshot(id);
  }

  /// Deletes a debt and returns everything needed to put it back.
  ///
  /// Deleting is offered with an undo rather than a second confirmation, which
  /// only works if the caller can restore the record *and* its payment history —
  /// so the snapshot is captured before anything is removed.
  Future<LedgerServiceSnapshot> deleteDebtWithSnapshot(String id) async {
    final Debt? existing = await debts.getById(id);
    final List<Payment> history = await payments.forDebt(id);
    final String title =
        existing == null ? '' : await _displayNameFor(existing);

    await _db.transaction(() async {
      await payments.deleteForDebt(id);
      await activity.deleteForEntity(RelatedEntityType.debt, id);
      await debts.delete(id);
    });
    await _log(
      type: ActivityType.debtDeleted,
      entityType: RelatedEntityType.debt,
      entityId: id,
      title: title,
    );
    await refreshNotifications();

    return LedgerServiceSnapshot(debt: existing, payments: history);
  }

  /// Restores a debt and its payments exactly as they were.
  ///
  /// Identifiers are preserved, so an undone delete leaves no trace behind: the
  /// same ids, the same timestamps, the same balances.
  Future<void> restoreDeleted(LedgerServiceSnapshot snapshot) async {
    final Debt? debt = snapshot.debt;
    if (debt == null) return;

    await _db.transaction(() async {
      await debts.save(debt);
      for (final Payment payment in snapshot.payments) {
        await payments.save(payment);
      }
      await activity.deleteForEntity(RelatedEntityType.debt, debt.id);
    });
    await _log(
      type: ActivityType.debtCreated,
      entityType: RelatedEntityType.debt,
      entityId: debt.id,
      title: await _displayNameFor(debt),
      amountMinor: debt.principalMinor,
      currency: debt.currency,
    );
    await ensureOccurrences();
    await refreshNotifications();
  }

  // --- Payments ------------------------------------------------------------

  /// Records a payment and settles the debt when the balance reaches zero.
  ///
  /// Returns the created payment so the caller can offer an undo that removes
  /// exactly what it just added.
  Future<Payment> recordPayment(String debtId, PaymentDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'payment');
    final Debt? debt = await debts.getById(debtId);
    if (debt == null) {
      throw StateError('Cannot record a payment for a debt that no longer exists');
    }
    final DateTime now = clock();
    final Payment payment = Payment(
      id: newId(),
      debtId: debtId,
      personId: debt.personId,
      amountMinor: draft.amountMinor,
      currency: debt.currency,
      paidAt: dateOnly(draft.paidAt),
      note: _blankToNull(draft.note),
      createdAt: now,
    );
    await payments.save(payment);
    await _log(
      type: ActivityType.paymentRecorded,
      entityType: RelatedEntityType.debt,
      entityId: debtId,
      title: await _displayNameFor(debt),
      amountMinor: payment.amountMinor,
      currency: payment.currency,
    );

    final Debt? settled = await _syncClosedStamp(debt);
    if (settled != null && settled.closedAt != null) {
      await _log(
        type: ActivityType.debtClosed,
        entityType: RelatedEntityType.debt,
        entityId: debtId,
        title: await _displayNameFor(debt),
        amountMinor: settled.principalMinor,
        currency: settled.currency,
      );
      await _spawnNextRecurrence(settled);
    }

    await refreshNotifications();
    return payment;
  }

  Future<void> updatePayment(String id, PaymentDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'payment');
    final Payment? existing = await payments.getById(id);
    if (existing == null) return;
    await payments.save(
      existing.copyWith(
        amountMinor: draft.amountMinor,
        paidAt: dateOnly(draft.paidAt),
        note: _blankToNull(draft.note),
      ),
    );
    final String? debtId = existing.debtId;
    if (debtId != null) {
      final Debt? debt = await debts.getById(debtId);
      if (debt != null) await _syncClosedStamp(debt);
    }
    await refreshNotifications();
  }

  /// Puts a deleted payment back, used by the undo on the payments list.
  Future<void> restorePaymentRecord(Payment payment) async {
    await payments.save(payment);
    final String? debtId = payment.debtId;
    if (debtId != null) {
      final Debt? debt = await debts.getById(debtId);
      if (debt != null) await _syncClosedStamp(debt);
    }
    await refreshNotifications();
  }

  Future<void> deletePayment(String id) async {
    final Payment? existing = await payments.getById(id);
    if (existing == null) return;
    await payments.delete(id);
    final String? debtId = existing.debtId;
    if (debtId != null) {
      final Debt? debt = await debts.getById(debtId);
      if (debt != null) {
        await _syncClosedStamp(debt);
        await _log(
          type: ActivityType.paymentDeleted,
          entityType: RelatedEntityType.debt,
          entityId: debtId,
          title: await _displayNameFor(debt),
          amountMinor: existing.amountMinor,
          currency: existing.currency,
        );
      }
    }
    await refreshNotifications();
  }

  /// Brings a debt's closing stamp in line with its payment history.
  ///
  /// This is the single place that decides whether a debt is closed, so the
  /// stamp can never disagree with the payments that justify it.
  Future<Debt?> _syncClosedStamp(Debt debt) async {
    final List<Payment> history = await payments.forDebt(debt.id);
    final int remaining = DebtCalculator.remainingOf(
      debt.principalMinor,
      DebtCalculator.totalPaid(history),
    );
    final bool shouldBeClosed = remaining <= 0;

    if (shouldBeClosed && debt.closedAt == null) {
      final Debt updated = debt.copyWith(closedAt: clock(), updatedAt: clock());
      await debts.save(updated);
      return updated;
    }
    if (!shouldBeClosed && debt.closedAt != null) {
      final Debt updated = debt.copyWith(closedAt: null, updatedAt: clock());
      await debts.save(updated);
      return updated;
    }
    return debt;
  }

  /// Creates the next period of a recurring debt once the current one is settled.
  Future<void> _spawnNextRecurrence(Debt settled) async {
    if (!settled.isRecurring) return;
    final DateTime basis = settled.dueAt ?? settled.issuedAt;
    final DateTime? nextDue = settled.nextOccurrenceAfter(basis);
    if (nextDue == null) return;

    // Do not build a second open record for a period that is already recorded —
    // for example when the user reopens and re-settles the same debt.
    final List<Debt> siblings = await debts.forPerson(settled.personId ?? '');
    for (final Debt sibling in siblings) {
      if (sibling.id != settled.id &&
          sibling.recurrence == settled.recurrence &&
          sibling.title == settled.title &&
          sibling.dueAt == nextDue) {
        return;
      }
    }

    final DateTime now = clock();
    final Debt followUp = Debt(
      id: newId(),
      personId: settled.personId,
      direction: settled.direction,
      title: settled.title,
      principalMinor: settled.principalMinor,
      currency: settled.currency,
      issuedAt: dateOnly(nextDue),
      dueAt: dateOnly(nextDue),
      note: settled.note,
      reminderLeads: settled.reminderLeads,
      recurrence: settled.recurrence,
      recurrenceInterval: settled.recurrenceInterval,
      recurrenceEndAt: settled.recurrenceEndAt,
      createdAt: now,
      updatedAt: now,
    );
    await debts.save(followUp);
    await _log(
      type: ActivityType.debtCreated,
      entityType: RelatedEntityType.debt,
      entityId: followUp.id,
      title: await _displayNameFor(followUp),
      amountMinor: followUp.principalMinor,
      currency: followUp.currency,
    );
  }

  // --- Obligations ---------------------------------------------------------

  Future<Obligation> createObligation(ObligationDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'obligation amount');
    final DateTime now = clock();
    final DateTime start = dateOnly(draft.startAt);
    final Obligation obligation = Obligation(
      id: newId(),
      name: draft.name.trim(),
      category: draft.category,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      frequency: draft.frequency,
      intervalCount: draft.intervalCount,
      dayOfMonth: draft.dayOfMonth,
      startAt: start,
      nextDueAt: start,
      endAt: draft.endAt == null ? null : dateOnly(draft.endAt!),
      note: _blankToNull(draft.note),
      reminderLeads: ReminderLead.sorted(draft.reminderLeads),
      createdAt: now,
      updatedAt: now,
    );
    final Obligation anchored = obligation.copyWith(
      nextDueAt: ObligationSchedule.nthDueDate(obligation, 0),
    );
    await obligations.save(anchored);
    await ensureOccurrences();
    await _log(
      type: ActivityType.obligationCreated,
      entityType: RelatedEntityType.obligation,
      entityId: anchored.id,
      title: anchored.name,
      amountMinor: anchored.amountMinor,
      currency: anchored.currency,
    );
    await refreshNotifications();
    return anchored;
  }

  Future<void> updateObligation(String id, ObligationDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'obligation amount');
    final Obligation? existing = await obligations.getById(id);
    if (existing == null) return;

    final bool scheduleChanged =
        existing.frequency != draft.frequency ||
        existing.intervalCount != draft.intervalCount ||
        existing.dayOfMonth != draft.dayOfMonth ||
        !isSameDate(existing.startAt, draft.startAt) ||
        existing.amountMinor != draft.amountMinor ||
        (existing.endAt == null) != (draft.endAt == null) ||
        (existing.endAt != null &&
            draft.endAt != null &&
            !isSameDate(existing.endAt!, draft.endAt!));

    final Obligation updated = existing.copyWith(
      name: draft.name.trim(),
      category: draft.category,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      frequency: draft.frequency,
      intervalCount: draft.intervalCount,
      dayOfMonth: draft.dayOfMonth,
      startAt: dateOnly(draft.startAt),
      endAt: draft.endAt == null ? null : dateOnly(draft.endAt!),
      note: _blankToNull(draft.note),
      reminderLeads: ReminderLead.sorted(draft.reminderLeads),
      updatedAt: clock(),
    );
    await obligations.save(updated);

    if (scheduleChanged) {
      // Paid periods are history and stay untouched; only unpaid ones are rebuilt
      // against the new schedule.
      await _rebuildFutureOccurrences(updated);
    }
    await ensureOccurrences();
    await _log(
      type: ActivityType.obligationCreated,
      entityType: RelatedEntityType.obligation,
      entityId: id,
      title: updated.name,
      amountMinor: updated.amountMinor,
      currency: updated.currency,
    );
    await refreshNotifications();
  }

  Future<void> setObligationArchived(String id, bool archived) async {
    final Obligation? existing = await obligations.getById(id);
    if (existing == null) return;
    await obligations.setArchived(id, archived: archived);
    await _log(
      type: archived ? ActivityType.debtArchived : ActivityType.debtReopened,
      entityType: RelatedEntityType.obligation,
      entityId: id,
      title: existing.name,
    );
    await refreshNotifications();
  }

  Future<void> deleteObligation(String id) async {
    final Obligation? existing = await obligations.getById(id);
    await _db.transaction(() async {
      final List<ObligationOccurrence> occurrences =
          await obligations.occurrencesFor(id);
      for (final ObligationOccurrence occurrence in occurrences) {
        final String? paymentId = occurrence.paymentId;
        if (paymentId != null) await payments.delete(paymentId);
      }
      await activity.deleteForEntity(RelatedEntityType.obligation, id);
      await obligations.deleteOccurrencesFor(id);
      await obligations.delete(id);
    });
    await _log(
      type: ActivityType.debtDeleted,
      entityType: RelatedEntityType.obligation,
      entityId: id,
      title: existing?.name ?? '',
    );
    await refreshNotifications();
  }

  /// Pays one period, then moves the obligation on to its next one.
  Future<void> markObligationPaid(
    ObligationInstance instance, {
    DateTime? paidAt,
  }) async {
    final Obligation obligation = instance.obligation;
    final ObligationOccurrence occurrence = instance.occurrence;
    if (!occurrence.isPayable) return;

    final DateTime when = dateOnly(paidAt ?? clock());
    final DateTime now = clock();
    final Payment payment = Payment(
      id: newId(),
      obligationId: obligation.id,
      occurrenceId: occurrence.id,
      amountMinor: occurrence.amountMinor,
      currency: obligation.currency,
      paidAt: when,
      createdAt: now,
    );

    await _db.transaction(() async {
      await payments.save(payment);
      await obligations.saveOccurrence(
        occurrence.copyWith(
          status: ObligationStatus.paid,
          paidAt: when,
          paymentId: payment.id,
          updatedAt: now,
        ),
      );
    });

    await _log(
      type: ActivityType.obligationPaid,
      entityType: RelatedEntityType.obligation,
      entityId: obligation.id,
      title: obligation.name,
      amountMinor: payment.amountMinor,
      currency: payment.currency,
    );

    // Point the obligation at the next period that still needs paying.
    final DateTime? next = ObligationSchedule.rollForward(
      obligation.copyWith(nextDueAt: occurrence.dueAt),
    );
    if (next != null) {
      await obligations.save(
        obligation.copyWith(nextDueAt: next, updatedAt: now),
      );
      await ensureOccurrences();
    } else {
      await obligations.setArchived(obligation.id, archived: true);
      await _log(
        type: ActivityType.debtArchived,
        entityType: RelatedEntityType.obligation,
        entityId: obligation.id,
        title: obligation.name,
      );
    }
    await refreshNotifications();
  }

  /// Undoes a payment on one period.
  Future<void> undoObligationPayment(ObligationInstance instance) async {
    final ObligationOccurrence occurrence = instance.occurrence;
    final String? paymentId = occurrence.paymentId;
    final DateTime now = clock();
    await _db.transaction(() async {
      if (paymentId != null) await payments.delete(paymentId);
      await obligations.saveOccurrence(
        occurrence.copyWith(
          status: ObligationStatus.upcoming,
          paidAt: null,
          paymentId: null,
          updatedAt: now,
        ),
      );
    });
    if (instance.obligation.isArchived) {
      await obligations.setArchived(instance.obligation.id, archived: false);
    }
    await _log(
      type: ActivityType.paymentDeleted,
      entityType: RelatedEntityType.obligation,
      entityId: instance.obligation.id,
      title: instance.obligation.name,
      amountMinor: occurrence.amountMinor,
      currency: instance.obligation.currency,
    );
    await refreshNotifications();
  }

  /// Marks one period as not applicable — a paused subscription, a month with no
  /// rent.
  Future<void> skipObligationPeriod(ObligationInstance instance) async {
    final DateTime now = clock();
    await obligations.saveOccurrence(
      instance.occurrence.copyWith(
        status: ObligationStatus.skipped,
        updatedAt: now,
      ),
    );
    await _log(
      type: ActivityType.obligationSkipped,
      entityType: RelatedEntityType.obligation,
      entityId: instance.obligation.id,
      title: instance.obligation.name,
    );
    await refreshNotifications();
  }

  /// Materials every obligation's periods for the visible window.
  ///
  /// Safe to call often: existing periods are skipped, so it only ever fills
  /// gaps. This is what makes a commitment's next due date appear without the
  /// user having to do anything.
  Future<void> ensureOccurrences() async {
    final DateTime asOf = dateOnly(clock());
    final DateTime from = addDays(asOf, -obligationLookbackDays);
    final DateTime to = addDays(asOf, obligationHorizonDays);
    final DateTime now = clock();

    for (final Obligation obligation in await obligations.getAll()) {
      if (obligation.frequency == RecurrenceFrequency.none) continue;

      final Set<String> existing = await obligations.existingPeriodKeys(obligation.id);
      final List<DateTime> dueDates = ObligationSchedule.dueDatesBetween(
        obligation,
        from,
        to,
      );

      final List<ObligationOccurrence> missing = <ObligationOccurrence>[];
      for (final DateTime due in dueDates) {
        final String key =
            ObligationSchedule.periodKeyFor(obligation.frequency, due);
        if (existing.contains(key)) continue;
        missing.add(
          ObligationOccurrence(
            id: newId(),
            obligationId: obligation.id,
            periodKey: key,
            dueAt: due,
            amountMinor: obligation.amountMinor,
            status: ObligationStatus.upcoming,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      await obligations.saveOccurrences(missing);
    }
  }

  /// Discards unpaid future periods and regenerates them from the new schedule.
  Future<void> _rebuildFutureOccurrences(Obligation obligation) async {
    final DateTime asOf = dateOnly(clock());
    final List<ObligationOccurrence> current =
        await obligations.occurrencesFor(obligation.id);
    for (final ObligationOccurrence occurrence in current) {
      final bool isFuture = occurrence.dueAt.isAfter(asOf);
      final bool isPaid = occurrence.status == ObligationStatus.paid;
      if (isFuture && !isPaid) {
        await obligations.deleteOccurrence(occurrence.id);
      }
    }
    final DateTime? next = ObligationSchedule.rollForward(
      obligation.copyWith(nextDueAt: addDays(asOf, -1)),
    );
    if (next != null) {
      await obligations.save(
        obligation.copyWith(nextDueAt: next, updatedAt: clock()),
      );
    }
  }

  // --- Reminders -----------------------------------------------------------

  Future<Reminder> createReminder(ReminderDraft draft) async {
    final DateTime now = clock();
    final Reminder reminder = Reminder(
      id: newId(),
      title: draft.title.trim(),
      note: _blankToNull(draft.note),
      dueAt: dateOnly(draft.dueAt),
      relatedType: draft.relatedType,
      relatedId: draft.relatedId,
      status: ReminderStatus.upcoming,
      createdAt: now,
      updatedAt: now,
    );
    await reminders.save(reminder);
    await _log(
      type: ActivityType.reminderCreated,
      entityType: RelatedEntityType.reminder,
      entityId: reminder.id,
      title: reminder.title,
    );
    await refreshNotifications();
    return reminder;
  }

  Future<void> updateReminder(String id, ReminderDraft draft) async {
    final Reminder? existing = await reminders.getById(id);
    if (existing == null) return;
    await reminders.save(
      existing.copyWith(
        title: draft.title.trim(),
        note: _blankToNull(draft.note),
        dueAt: dateOnly(draft.dueAt),
        updatedAt: clock(),
      ),
    );
    await refreshNotifications();
  }

  Future<void> setReminderDone(String id, bool done) async {
    final Reminder? existing = await reminders.getById(id);
    if (existing == null) return;
    await reminders.setStatus(
      id,
      done ? ReminderStatus.completed : ReminderStatus.upcoming,
      completedAt: done ? clock() : null,
    );
    await _log(
      type: done ? ActivityType.reminderCompleted : ActivityType.reminderCreated,
      entityType: RelatedEntityType.reminder,
      entityId: id,
      title: existing.title,
    );
    await refreshNotifications();
  }

  Future<void> deleteReminder(String id) async {
    final Reminder? existing = await reminders.getById(id);
    await activity.deleteForEntity(RelatedEntityType.reminder, id);
    await reminders.delete(id);
    await _log(
      type: ActivityType.debtDeleted,
      entityType: RelatedEntityType.reminder,
      entityId: id,
      title: existing?.title ?? '',
    );
    await refreshNotifications();
  }

  // --- Notifications -------------------------------------------------------

  /// Rebuilds the complete pending-notification set from current records.
  ///
  /// Called after every write and on every launch. Rebroadcasting the whole set
  /// rather than patching individual notifications is what guarantees a settled
  /// debt can never leave a reminder behind.
  Future<void> refreshNotifications() async {
    final AppSettings current = await settings.get();
    if (!current.notificationsEnabled) {
      await notifications.cancelAll();
      return;
    }

    final DateTime now = clock();
    final DateTime asOf = dateOnly(now);

    final List<DebtView> debtViews = await _buildDebtViews(current, asOf);
    final List<ObligationInstance> obligationInstances =
        await _buildObligationInstances(asOf);
    final List<Reminder> reminderList = await reminders.getAll();

    final List<NotificationIntent> intents = NotificationPlanner.plan(
      debts: debtViews,
      obligations: obligationInstances,
      reminders: reminderList,
      settings: current,
      now: now,
    );

    final NotificationComposer activeComposer = composer();
    await notifications.sync(activeComposer.composeAll(intents));

    await _deliverPendingSummary(current, now, asOf, activeComposer);
  }

  /// Delivers a month-end summary that was missed while the app was closed.
  Future<void> _deliverPendingSummary(
    AppSettings current,
    DateTime now,
    DateTime asOf,
    NotificationComposer composer,
  ) async {
    final List<DebtView> views = await _buildDebtViews(current, asOf);
    final totals = views.isEmpty
        ? null
        : _primaryTotals(views, current, asOf);

    final NotificationIntent? catchUp = NotificationPlanner.pendingCatchUpSummary(
      settings: current,
      now: now,
      iOweMinor: totals?.$1 ?? 0,
      owedToMeMinor: totals?.$2 ?? 0,
      paidMinor: totals?.$3 ?? 0,
      overdueMinor: totals?.$4 ?? 0,
    );
    if (catchUp == null) return;

    final ComposedNotification notification = composer.compose(catchUp, 900001);
    await notifications.showNow(notification);
    await settings.update((AppSettings s) => s.copyWith(lastSummarySentOn: asOf));
    await _log(
      type: ActivityType.monthSummaryGenerated,
      entityType: RelatedEntityType.none,
      title: '',
    );
  }

  /// iOwe, owedToMe, paid-this-month and overdue for the user's main currency.
  (int, int, int, int) _primaryTotals(
    List<DebtView> views,
    AppSettings current,
    DateTime asOf,
  ) {
    final List<CurrencyTotals> totals = DebtCalculator.totalsByCurrency(
      views,
      asOf: asOf,
      dueSoonWindowDays: current.dueSoonWindowDays,
    );
    final AppCurrency primary =
        DebtCalculator.primaryCurrency(totals, current.defaultCurrency);
    final CurrencyTotals? pick = totals
        .where((CurrencyTotals t) => t.currency == primary)
        .firstOrNull;
    final DateTime monthStart = startOfMonth(asOf);
    int paidThisMonth = 0;
    for (final DebtView view in views) {
      if (view.currency != primary) continue;
      final DateTime? last = view.lastPaymentAt;
      if (last != null && isWithin(last, monthStart, asOf)) {
        paidThisMonth += view.paidMinor;
      }
    }
    return (
      pick?.iOweMinor ?? 0,
      pick?.owedToMeMinor ?? 0,
      paidThisMonth,
      pick?.overdueMinor ?? 0,
    );
  }

  Future<List<DebtView>> _buildDebtViews(AppSettings current, DateTime asOf) async {
    final List<Debt> all = await debts.getAll();
    final List<Payment> allPayments = await payments.getAll();
    final Map<String, List<Payment>> byDebt = <String, List<Payment>>{};
    for (final Payment payment in allPayments) {
      final String? debtId = payment.debtId;
      if (debtId == null) continue;
      byDebt.putIfAbsent(debtId, () => <Payment>[]).add(payment);
    }
    final List<Person> peopleList = await people.getAll();
    final Map<String, Person> peopleById = <String, Person>{
      for (final Person person in peopleList) person.id: person,
    };

    // The catch-up summary needs the overdue count for the whole month, so it
    // uses a wider window than the dashboard tiles.
    final int window = current.dueSoonWindowDays;
    return <DebtView>[
      for (final Debt debt in all)
        DebtCalculator.buildView(
          debt: debt,
          payments: byDebt[debt.id] ?? const <Payment>[],
          person: debt.personId == null ? null : peopleById[debt.personId],
          asOf: asOf,
          dueSoonWindowDays: window,
        ),
    ];
  }

  Future<List<ObligationInstance>> _buildObligationInstances(DateTime asOf) async {
    final List<Obligation> list = await obligations.getAll();
    final List<ObligationOccurrence> all = await obligations.allOccurrences();
    final Map<String, Obligation> byId = <String, Obligation>{
      for (final Obligation obligation in list) obligation.id: obligation,
    };
    final List<ObligationInstance> out = <ObligationInstance>[];
    for (final ObligationOccurrence occurrence in all) {
      final Obligation? obligation = byId[occurrence.obligationId];
      if (obligation == null || obligation.isArchived) continue;
      final ObligationStatus status = ObligationSchedule.resolveStatus(
        stored: occurrence.status,
        dueAt: occurrence.dueAt,
        asOf: asOf,
      );
      if (!status.isOpen) continue;
      out.add(
        ObligationInstance(
          obligation: obligation,
          occurrence: occurrence.copyWith(status: status),
        ),
      );
    }
    return out;
  }

  // --- Housekeeping --------------------------------------------------------

  /// Erases every record and rebuilds an empty state.
  Future<void> clearAllData() async {
    await notifications.cancelAll();
    await activity.deleteAll();
    await _db.clearAllData();
    await _log(
      type: ActivityType.dataCleared,
      entityType: RelatedEntityType.none,
      title: '',
    );
  }

  /// Marks the settings row after a successful export, for the "last backed up"
  /// line in Settings.
  Future<void> markExported() async {
    await settings.update(
      (AppSettings s) => s.copyWith(lastExportedAt: clock()),
    );
    await _log(
      type: ActivityType.dataExported,
      entityType: RelatedEntityType.none,
      title: '',
    );
  }

  // --- Helpers -------------------------------------------------------------

  Future<void> _log({
    required ActivityType type,
    required RelatedEntityType entityType,
    required String title,
    String? entityId,
    int? amountMinor,
    AppCurrency? currency,
  }) async {
    await activity.add(
      ActivityEntry(
        id: newId(),
        type: type,
        entityType: entityType,
        entityId: entityId,
        title: title,
        amountMinor: amountMinor,
        currency: currency,
        occurredAt: clock(),
      ),
    );
  }

  /// The name shown in the feed: the person if there is one, otherwise the title.
  Future<String> _displayNameFor(Debt debt) async {
    final String? personId = debt.personId;
    if (personId != null) {
      final Person? person = await people.getById(personId);
      if (person != null && person.name.trim().isNotEmpty) return person.name;
    }
    return debt.title.trim();
  }

  static String? _blankToNull(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Text used when sharing a debt, kept here so the app and its notifications
  /// describe a record the same way.
  static Money money(int minor, AppCurrency currency) => Money(minor, currency);
}

/// Everything needed to undo a delete.
@immutable
class LedgerServiceSnapshot {
  const LedgerServiceSnapshot({required this.debt, required this.payments});

  /// Null when the record had already gone.
  final Debt? debt;

  final List<Payment> payments;
}
