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
import '../../domain/services/participant_rules.dart';
import '../../l10n/generated/app_localizations.dart';
import '../database/app_database.dart';
import '../database/daos/debts_dao.dart';
import '../mappers/db_mappers.dart';

/// The debt reminders one plan produced, and the read it took.
@immutable
class _DebtPlan {
  const _DebtPlan({required this.intents, required this.recordsRead});

  final List<NotificationIntent> intents;
  final int recordsRead;
}

/// What a month-end summary states, and the currency it is stated in.
@immutable
class _SummaryFigures {
  const _SummaryFigures({
    required this.currency,
    required this.iOweMinor,
    required this.owedToMeMinor,
    required this.paidMinor,
    required this.overdueMinor,
  });

  final AppCurrency currency;
  final int iOweMinor;
  final int owedToMeMinor;
  final int paidMinor;
  final int overdueMinor;
}

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

  /// Removes a person. Their debts survive without them, because deleting a
  /// person must never quietly delete money the user is still owed.
  ///
  /// A shared debt loses exactly this participant and keeps the others; a debt
  /// this person was the only one on keeps its amount and its history and is left
  /// naming nobody. Both happen inside the transaction that removes the person,
  /// so no debt is ever briefly pointing at somebody who is gone.
  Future<void> deletePerson(String id) async {
    final Person? existing = await people.getById(id);
    final List<Debt> affected = await debts.forPerson(id);
    await _db.transaction(() async {
      await people.delete(id);
      for (final Debt debt in affected) {
        await debts.setParticipants(
          debt.id,
          <String>[
            for (final String personId in debt.personIds)
              if (personId != id) personId,
          ],
        );
      }
    });
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

  /// Refuses a record that names nobody, and drops blanks and repeats.
  ///
  /// Both screens and callers pass through here, so "who is this with" is a rule
  /// of the ledger rather than a rule of one form.
  static List<String> _requireParticipants(List<String> personIds) {
    final List<String> normalised = ParticipantRules.normalise(personIds);
    if (!ParticipantRules.isValid(normalised)) {
      throw const MissingParticipantsException();
    }
    return normalised;
  }

  Future<Debt> createDebt(DebtDraft draft) async {
    _requireValidAmount(draft.principalMinor, 'debt principal');
    final List<String> personIds = _requireParticipants(draft.personIds);
    final DateTime now = clock();
    final Debt debt = Debt(
      id: newId(),
      personIds: personIds,
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
    final List<String> personIds = _requireParticipants(draft.personIds);

    // One transaction: the record, the payments that follow its currency and
    // its closing stamp are one fact, and a failure between them used to be
    // able to leave a dollar debt holding rupee payments.
    final bool found = await _db.transaction(() async {
      final Debt? existing = await debts.getById(id);
      if (existing == null) return false;

      // The record is edited, never replaced: the same id, the same created-at
      // and the same payment history. Only the fields the form owns are written.
      final Debt updated = existing.copyWith(
        personIds: personIds,
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
        recurrenceEndAt: draft.recurrenceEndAt == null
            ? null
            : dateOnly(draft.recurrenceEndAt!),
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
      // A changed balance can change whether a closing stamp is still correct —
      // and lowering the amount to what has already been paid closes the debt
      // exactly as a final payment would, next period included.
      await _settleIfPaid(updated);
      return true;
    });
    if (!found) return;
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
    // The payment, its feed entry, the closing stamp and a recurring debt's next
    // period are one write: a failure part-way must not leave a paid-off debt
    // open, or an open one with nothing to show for the money.
    final Payment payment = await _db.transaction(() async {
      final Debt? debt = await debts.getById(debtId);
      if (debt == null) {
        throw StateError(
          'Cannot record a payment for a debt that no longer exists',
        );
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
      await _settleIfPaid(debt);
      return payment;
    });

    await refreshNotifications();
    return payment;
  }

  Future<void> updatePayment(String id, PaymentDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'payment');
    final bool found = await _db.transaction(() async {
      final Payment? existing = await payments.getById(id);
      if (existing == null) return false;
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
        // A corrected amount can be the one that pays the debt off, and it
        // closes the debt exactly as a new payment would.
        if (debt != null) await _settleIfPaid(debt);
      }
      return true;
    });
    if (!found) return;
    await refreshNotifications();
  }

  /// Puts a deleted payment back, used by the undo on the payments list.
  ///
  /// Only the stamp is brought back in line: the debt's closing was announced
  /// when the payment was first recorded, and its next period, if it has one,
  /// already exists.
  Future<void> restorePaymentRecord(Payment payment) async {
    await _db.transaction(() async {
      await payments.save(payment);
      final String? debtId = payment.debtId;
      if (debtId != null) {
        final Debt? debt = await debts.getById(debtId);
        if (debt != null) await _syncClosedStamp(debt);
      }
    });
    await refreshNotifications();
  }

  Future<void> deletePayment(String id) async {
    final bool found = await _db.transaction(() async {
      final Payment? existing = await payments.getById(id);
      if (existing == null) return false;
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
      return true;
    });
    if (!found) return;
    await refreshNotifications();
  }

  /// Brings a debt's closing stamp in line with its payment history.
  ///
  /// This is the single place that decides whether a debt is closed, so the
  /// stamp can never disagree with the payments that justify it. It also says
  /// whether *this* call is the one that closed it, which is the only moment
  /// the closing may be announced or a recurring debt's next period created.
  Future<({Debt debt, bool justClosed})> _syncClosedStamp(Debt debt) async {
    final List<Payment> history = await payments.forDebt(debt.id);
    final int remaining = DebtCalculator.remainingOf(
      debt.principalMinor,
      DebtCalculator.totalPaid(history),
    );
    final bool shouldBeClosed = remaining <= 0;

    if (shouldBeClosed && debt.closedAt == null) {
      final Debt updated = debt.copyWith(closedAt: clock(), updatedAt: clock());
      await debts.save(updated);
      return (debt: updated, justClosed: true);
    }
    if (!shouldBeClosed && debt.closedAt != null) {
      final Debt updated = debt.copyWith(closedAt: null, updatedAt: clock());
      await debts.save(updated);
      return (debt: updated, justClosed: false);
    }
    return (debt: debt, justClosed: false);
  }

  /// Everything that follows a change to what a debt owes: the stamp, and —
  /// only when this write is the one that closed it — the feed entry and a
  /// recurring debt's next period.
  ///
  /// A payment, a corrected payment and a lowered amount can each be what pays
  /// a debt off, and they used to disagree: only a new payment announced the
  /// closing or created the next period, and it did so again when a debt that
  /// was already closed received another payment.
  Future<void> _settleIfPaid(Debt debt) async {
    final ({Debt debt, bool justClosed}) closing = await _syncClosedStamp(debt);
    if (!closing.justClosed) return;
    final Debt settled = closing.debt;
    await _log(
      type: ActivityType.debtClosed,
      entityType: RelatedEntityType.debt,
      entityId: settled.id,
      title: await _displayNameFor(settled),
      amountMinor: settled.principalMinor,
      currency: settled.currency,
    );
    await _spawnNextRecurrence(settled);
  }

  /// Creates the next period of a recurring debt once the current one is settled.
  Future<void> _spawnNextRecurrence(Debt settled) async {
    if (!settled.isRecurring) return;
    final DateTime basis = settled.dueAt ?? settled.issuedAt;
    final DateTime? nextDue = settled.nextOccurrenceAfter(basis);
    if (nextDue == null) return;

    // Do not build a second open record for a period that is already recorded —
    // for example when the user reopens and re-settles the same debt.
    //
    // Every participant's records are searched, not just the first one's: a
    // shared record's follow-up is on all of their pages, and looking at one
    // person's list is how the same period gets recorded twice.
    final Set<String> checked = <String>{settled.id};
    for (final String personId in settled.personIds) {
      for (final Debt sibling in await debts.forPerson(personId)) {
        if (!checked.add(sibling.id)) continue;
        if (sibling.recurrence == settled.recurrence &&
            sibling.title == settled.title &&
            sibling.dueAt == nextDue) {
          return;
        }
      }
    }

    final DateTime now = clock();
    final Debt followUp = Debt(
      id: newId(),
      personIds: settled.personIds,
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

  /// How many records a reminder plan reads, soonest due first.
  ///
  /// The armed set is the soonest notifications, and this is the read that
  /// produces it: the records that fall due soonest, in order, until either the
  /// plan has everything the nearest notifications need or this many rows have
  /// been read. It bounds the work of a save, and it is far above the number of
  /// records that can contribute to the nearest [NotificationService.maxScheduled]
  /// notifications in any ledger a person keeps.
  static const int reminderReadLimit = 1600;

  /// Records read per query while walking that window.
  static const int reminderReadChunk = 250;

  /// Rebuilds the complete pending-notification set from current records.
  ///
  /// Called after every write and on every launch. The set is rebuilt whole
  /// rather than patched — that is what guarantees a settled debt can never
  /// leave a reminder behind — and the service then makes the platform agree
  /// with it, so nothing is duplicated and nothing stale survives.
  ///
  /// One pass at a time. Two passes used to be able to run at once — a save and
  /// a change of language arrive together, a resume lands in the middle of a
  /// write — and the one that finished last won, whichever of them had read the
  /// older state. Now a call made while a pass is running waits for one more
  /// pass after it, which starts after the call and so sees whatever that caller
  /// wrote; every caller arriving meanwhile shares that same pass, because it
  /// reads what all of them wrote.
  Future<NotificationSyncResult> refreshNotifications() {
    final Future<NotificationSyncResult>? running = _refreshRunning;
    if (running == null) return _startRefresh();
    return _refreshQueued ??= running.then<void>(
      (NotificationSyncResult _) {},
      // The pass that failed has already reported it to its own caller; the
      // next one is still owed to everyone waiting on it.
      onError: (Object _) {},
    ).then((void _) {
      _refreshQueued = null;
      return _startRefresh();
    });
  }

  Future<NotificationSyncResult>? _refreshRunning;
  Future<NotificationSyncResult>? _refreshQueued;

  Future<NotificationSyncResult> _startRefresh() {
    final Future<NotificationSyncResult> pass = _refreshPass();
    _refreshRunning = pass;
    return pass.whenComplete(() {
      if (identical(_refreshRunning, pass)) _refreshRunning = null;
    });
  }

  Future<NotificationSyncResult> _refreshPass() async {
    final AppSettings current = await settings.get();
    if (!current.notificationsEnabled) {
      // Nothing may fire, and nothing should be held: an armed set the user has
      // switched off would only mislead the reminder field.
      await notifications.cancelAll();
      return const NotificationSyncResult.blocked();
    }

    final DateTime now = clock();
    final DateTime asOf = dateOnly(now);

    final _DebtPlan plan = await _planDebtReminders(current, now, asOf);
    final List<NotificationIntent> intents = <NotificationIntent>[
      ...plan.intents,
      ...NotificationPlanner.planObligations(
        obligations: await _obligationInstancesInWindow(asOf),
        settings: current,
        now: now,
      ),
      ...NotificationPlanner.planReminders(
        reminders: await reminders.getAll(),
        settings: current,
        now: now,
      ),
    ];

    // The month-end summary, armed in the last days before its moment so it
    // arrives when the user asked for it whether or not the app is open then.
    final NotificationIntent? summary =
        await _monthEndSummaryToArm(current, now, asOf);
    if (summary != null) intents.add(summary);

    final NotificationComposer activeComposer = composer();
    final List<ComposedNotification> composed =
        activeComposer.composeAll(intents);
    final NotificationSyncResult result = await notifications.sync(
      composed,
      recordsRead: plan.recordsRead,
    );

    if (summary != null) {
      await _recordArmedSummary(summary, composed, result, current);
    }
    await _deliverPendingSummary(current, now, asOf, activeComposer);
    return result;
  }

  /// The month-end summary to arm in this pass, or null.
  ///
  /// Only inside [NotificationPlanner.monthEndArmWindow]: the figures read the
  /// whole ledger, and outside that window no save pays for them.
  Future<NotificationIntent?> _monthEndSummaryToArm(
    AppSettings current,
    DateTime now,
    DateTime asOf,
  ) async {
    final DateTime? moment =
        NotificationPlanner.monthEndToArm(settings: current, now: now);
    if (moment == null) return null;
    final List<DebtView> views = await _summaryViews(current, asOf);
    // The same rule as the catch-up: a ledger with nothing in it is not told
    // that its totals are zero.
    if (views.isEmpty) return null;
    final _SummaryFigures figures =
        await _summaryFigures(views, current, asOf, month: moment);
    return NotificationPlanner.monthEndSummary(
      settings: current,
      now: now,
      iOweMinor: figures.iOweMinor,
      owedToMeMinor: figures.owedToMeMinor,
      paidMinor: figures.paidMinor,
      overdueMinor: figures.overdueMinor,
      currency: figures.currency,
    );
  }

  /// Records the summary's month as handed over, once the phone is holding it.
  ///
  /// Without this the catch-up could not tell a summary that was delivered on
  /// time from one that never was, and would show it a second time on the first
  /// launch after its moment.
  Future<void> _recordArmedSummary(
    NotificationIntent summary,
    List<ComposedNotification> composed,
    NotificationSyncResult result,
    AppSettings current,
  ) async {
    final ComposedNotification? armed =
        composed.where((ComposedNotification n) => n.isSummary).firstOrNull;
    if (armed == null || !result.armedIds.contains(armed.id)) return;
    final MonthEndFigures? figures = summary.summary;
    if (figures == null) return;
    final DateTime month = DateTime(figures.year, figures.month);
    final DateTime record = NotificationPlanner.summaryRecordFor(month, current);
    final DateTime? last = current.lastSummarySentOn;
    // Every pass in the window arms the same summary; only the first writes.
    if (last != null && !last.isBefore(record)) return;
    await _recordSummaryHandedOver(month);
  }

  /// Notes that [month]'s summary has reached the phone, never moving the
  /// record backwards: a late catch-up for an older month must not undo the
  /// record of a newer one that is already armed.
  Future<void> _recordSummaryHandedOver(DateTime month) async {
    await settings.update((AppSettings s) {
      final DateTime record = NotificationPlanner.summaryRecordFor(month, s);
      final DateTime? last = s.lastSummarySentOn;
      if (last != null && !last.isBefore(record)) return s;
      return s.copyWith(lastSummarySentOn: record);
    });
  }

  /// The debt reminders the nearest notifications are made of.
  ///
  /// Walks the records that carry a reminder from the soonest due date outwards,
  /// in pages, and stops as soon as no record further out could deliver earlier
  /// than the ones already planned — which is what keeps a save on a large
  /// ledger from reading the whole ledger to build a few hundred notifications.
  Future<_DebtPlan> _planDebtReminders(
    AppSettings current,
    DateTime now,
    DateTime asOf,
  ) async {
    final DateTime to = addDays(asOf, NotificationPlanner.horizon.inDays);
    // The window starts a little in the past, not today: a record that fell due
    // two days ago still has its nudge ahead of it, and reading from today
    // onwards silently dropped exactly those.
    final DateTime from =
        addDays(asOf, -NotificationPlanner.overdueNudgeAfterDays);
    final List<NotificationIntent> intents = <NotificationIntent>[];
    int offset = 0;

    while (offset < reminderReadLimit) {
      final List<DebtRow> rows = await _db.debtsDao.reminderCandidates(
        from: from,
        to: to,
        limit: reminderReadChunk,
        offset: offset,
      );
      if (rows.isEmpty) break;
      offset += rows.length;

      intents.addAll(
        NotificationPlanner.planDebts(
          debts: await _viewsOfRows(rows, current, asOf),
          settings: current,
          now: now,
        ),
      );

      // Stop once the records already read cover the nearest notifications:
      // a record further out cannot deliver before `due - the longest lead`,
      // so once that is later than the last notification that would be armed,
      // nothing beyond this page can change the answer.
      intents.sort(
        (NotificationIntent a, NotificationIntent b) => a.when.compareTo(b.when),
      );
      final DateTime? cutoff = intents.length > NotificationService.maxScheduled
          ? intents[NotificationService.maxScheduled - 1].when
          : null;
      final DateTime lastDue = rows.last.dueAt!;
      final DateTime earliestFromLaterRows =
          addDays(lastDue, -NotificationPlanner.maxLeadDays);
      if (cutoff != null && earliestFromLaterRows.isAfter(cutoff)) break;
      if (rows.length < reminderReadChunk) break;
    }

    return _DebtPlan(intents: intents, recordsRead: offset);
  }

  /// What the debt half of a plan cost: the notifications, and how many records
  /// had to be read to produce them.
  ///
  /// The count is reported rather than inferred because it is the guarantee: a
  /// save costs what the records asking for a reminder cost, not what the ledger
  /// costs. `test/data/reminder_plan_test.dart` holds it to that.
  /// Builds the views a reminder plan needs, for one page of rows.
  ///
  /// Only what a notification reads: the record, what is still owed, and the
  /// name it leads with. Payments are summed for the page rather than for the
  /// ledger, and the person comes from the row's own projection column — a
  /// notification names one person, and it is the one the record leads with.
  Future<List<DebtView>> _viewsOfRows(
    List<DebtRow> rows,
    AppSettings current,
    DateTime asOf,
  ) async {
    final List<DebtPaymentTotals> totals = await _db.debtsDao.paymentTotalsFor(
      rows.map((DebtRow row) => row.id),
    );
    final Map<String, PaymentTotals> byDebt = <String, PaymentTotals>{
      for (final DebtPaymentTotals t in totals)
        t.debtId: PaymentTotals(
          paidMinor: t.paidMinor,
          count: t.count,
          lastPaidAt: t.lastPaidAt,
        ),
    };
    final List<PersonRow> people = await _db.peopleDao.getByIds(
      <String>[
        for (final DebtRow row in rows)
          if (row.personId != null) row.personId!,
      ],
    );
    final Map<String, Person> byId = <String, Person>{
      for (final PersonRow person in people) person.id: person.toEntity(),
    };

    return <DebtView>[
      for (final DebtRow row in rows)
        DebtCalculator.buildViewFromTotals(
          debt: row.toEntity(
            personIds: row.personId == null
                ? const <String>[]
                : <String>[row.personId!],
          ),
          totals: byDebt[row.id] ?? const PaymentTotals.none(),
          participants: <Person>[
            if (row.personId != null && byId[row.personId] != null)
              byId[row.personId]!,
          ],
          asOf: asOf,
          dueSoonWindowDays: current.dueSoonWindowDays,
        ),
    ];
  }

  /// The commitment periods a reminder can still be planned from.
  ///
  /// The window starts a little in the past, exactly as the debts' does: a
  /// period that fell due yesterday still has its overdue nudge ahead of it.
  /// Reading from today onwards left that period out of every plan made after
  /// its due date — and a plan leaves out what it does not want, so the nudge
  /// that was armed on the day was cancelled by the next save, and a commitment
  /// passed its date in silence for anyone who used the app in between.
  Future<List<ObligationInstance>> _obligationInstancesInWindow(
    DateTime asOf,
  ) async {
    final List<ObligationOccurrenceRow> occurrences =
        await _db.obligationsDao.occurrencesBetween(
      from: addDays(asOf, -NotificationPlanner.overdueNudgeAfterDays),
      to: addDays(asOf, NotificationPlanner.horizon.inDays),
    );
    if (occurrences.isEmpty) return const <ObligationInstance>[];
    final List<ObligationRow> rows = await _db.obligationsDao.getByIds(
      occurrences.map((ObligationOccurrenceRow row) => row.obligationId),
    );
    final Map<String, Obligation> byId = <String, Obligation>{
      for (final ObligationRow row in rows)
        if (row.archivedAt == null) row.id: row.toEntity(),
    };

    return <ObligationInstance>[
      for (final ObligationOccurrenceRow row in occurrences)
        if (byId[row.obligationId] != null)
          ObligationInstance(
            obligation: byId[row.obligationId]!,
            occurrence: row.toEntity().copyWith(
              status: ObligationSchedule.resolveStatus(
                stored: row.toEntity().status,
                dueAt: row.toEntity().dueAt,
                asOf: asOf,
              ),
            ),
          ),
    ];
  }

  /// Delivers a month-end summary that was missed while the app was closed.
  ///
  /// The figures need the whole ledger, so they are computed only once the cheap
  /// test says a summary is actually owed — otherwise every save in the app
  /// would read every record to work out that nothing was due.
  Future<void> _deliverPendingSummary(
    AppSettings current,
    DateTime now,
    DateTime asOf,
    NotificationComposer composer,
  ) async {
    final DateTime? month =
        NotificationPlanner.catchUpSummaryMonth(settings: current, now: now);
    if (month == null) return;
    final List<DebtView> views = await _summaryViews(current, asOf);
    // A ledger with nothing in it owes nobody a summary: an install that has not
    // recorded anything yet used to be greeted with a month-end notification
    // reporting three zeroes.
    if (views.isEmpty) return;
    final _SummaryFigures figures =
        await _summaryFigures(views, current, asOf, month: month);

    final NotificationIntent? catchUp = NotificationPlanner.pendingCatchUpSummary(
      settings: current,
      now: now,
      iOweMinor: figures.iOweMinor,
      owedToMeMinor: figures.owedToMeMinor,
      paidMinor: figures.paidMinor,
      overdueMinor: figures.overdueMinor,
      currency: figures.currency,
    );
    if (catchUp == null) return;

    // The id comes from the same identity rule as every other notification, and
    // the catch-up's moment is its month's: a summary that is delivered twice
    // replaces itself instead of stacking up.
    await notifications.showNow(composer.compose(catchUp, _summaryId(catchUp)));
    await _recordSummaryHandedOver(month);
    await _log(
      type: ActivityType.monthSummaryGenerated,
      entityType: RelatedEntityType.none,
      title: '',
    );
  }

  static int _summaryId(NotificationIntent intent) =>
      NotificationComposer.idFor(intent);

  /// The figures a month-end summary states, in the ledger's main currency.
  ///
  /// The balances are the ledger as it stands; "paid" is what was paid against
  /// debts during [month] itself — read from the payments, not inferred from
  /// each debt's lifetime total.
  Future<_SummaryFigures> _summaryFigures(
    List<DebtView> views,
    AppSettings current,
    DateTime asOf, {
    required DateTime month,
  }) async {
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
    final int paid = await _db.debtsDao.debtPaymentsTotalBetween(
      currencyCode: primary.code,
      from: startOfMonth(month),
      to: endOfMonth(month),
    );
    return _SummaryFigures(
      currency: primary,
      iOweMinor: pick?.iOweMinor ?? 0,
      owedToMeMinor: pick?.owedToMeMinor ?? 0,
      paidMinor: paid,
      overdueMinor: pick?.overdueMinor ?? 0,
    );
  }

  /// The whole ledger, as cheaply as the month-end summary can be told it.
  ///
  /// The summary needs the figures and nothing else: no names, no links, and no
  /// individual payments. Reading rows and one aggregate over the payments table
  /// keeps `DebtCalculator` as the only arithmetic while costing a fraction of
  /// building every record's full view — which is what made the first save after
  /// a month end slow on a large ledger.
  Future<List<DebtView>> _summaryViews(
    AppSettings current,
    DateTime asOf,
  ) async {
    final List<DebtRow> rows = await _db.debtsDao.getAll();
    final List<DebtPaymentTotals> totals =
        await _db.debtsDao.paymentTotalsByDebt();
    final Map<String, PaymentTotals> byDebt = <String, PaymentTotals>{
      for (final DebtPaymentTotals t in totals)
        t.debtId: PaymentTotals(
          paidMinor: t.paidMinor,
          count: t.count,
          lastPaidAt: t.lastPaidAt,
        ),
    };

    return <DebtView>[
      for (final DebtRow row in rows)
        DebtCalculator.buildViewFromTotals(
          debt: row.toEntity(
            personIds: row.personId == null
                ? const <String>[]
                : <String>[row.personId!],
          ),
          totals: byDebt[row.id] ?? const PaymentTotals.none(),
          asOf: asOf,
          dueSoonWindowDays: current.dueSoonWindowDays,
        ),
    ];
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

  /// The name shown in the feed: everyone the record is with, or its title.
  ///
  /// A shared record names the whole group, because "أحمد" alone would read as a
  /// debt with one person and hide the two others it is also with.
  Future<String> _displayNameFor(Debt debt) async {
    final List<String> names = <String>[];
    for (final String personId in debt.personIds) {
      final Person? person = await people.getById(personId);
      if (person != null && person.name.trim().isNotEmpty) {
        names.add(person.name.trim());
      }
    }
    if (names.isNotEmpty) return names.join(' + ');
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
