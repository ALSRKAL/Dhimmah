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
import '../../domain/entities/income.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/amount_rules.dart';
import '../../domain/services/debt_calculator.dart';
import '../../domain/services/notification_planner.dart';
import '../../domain/services/obligation_schedule.dart';
import '../../domain/services/participant_rules.dart';
import '../../domain/services/payment_allocator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../database/app_database.dart';
import '../database/daos/debts_dao.dart';
import '../mappers/db_mappers.dart';
import '../repositories/income_repository_impl.dart';

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
    required this.incomes,
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
  final IncomeRepository incomes;
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
    await people.setArchived(id, archived: archived, now: clock());
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

  Future<List<Debt>> createDebts(DebtDraft draft) async {
    _requireValidAmount(draft.principalMinor, 'debt principal');
    final List<String> personIds = _requireParticipants(draft.personIds);
    final DateTime now = clock();
    // One independent debt per participant, each carrying the full amount.
    //
    // Naming several people is a shortcut for recording the same debt with
    // each of them — not a pot they share. A shared pot meant a full payment
    // from one participant's page settled everyone at once, which is the bug
    // this replaces. Every record below names exactly one person, so settling
    // one record can never touch another's balance.
    //
    // All rows and their feed entries are one write: a failure part-way must
    // not leave half the group recorded.
    final List<Debt> created = await _db.transaction(() async {
      final List<Debt> out = <Debt>[];
      for (final String personId in personIds) {
        final Debt debt = Debt(
          id: newId(),
          personIds: <String>[personId],
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
        out.add(debt);
      }
      return out;
    });
    await refreshNotifications();
    return created;
  }

  Future<Debt> createDebt(DebtDraft draft) async {
    // Kept for the callers that record exactly one debt: with a single
    // participant this is unchanged, and with several it records one
    // independent debt per participant and hands back the first, so no caller
    // can silently recreate the shared pot. Prefer [createDebts] when the
    // count matters.
    final List<Debt> created = await createDebts(draft);
    return created.first;
  }

  /// Splits a legacy shared debt into one independent debt per participant.
  ///
  /// Old records made before the fan-out still exist as one row naming several
  /// people, and payments are paused on them. This is the manual conversion the
  /// user runs after reviewing the previous payments: the original row keeps
  /// its id, its first participant and its whole payment history, while every
  /// other participant gets a fresh debt with the same amount and terms but no
  /// payments. Nothing is divided and no payment is moved — the user has
  /// already seen them where they are.
  Future<List<Debt>> splitSharedDebt(String debtId) async {
    final Debt? existing = await debts.getById(debtId);
    if (existing == null) {
      throw StateError('Cannot split a debt that no longer exists');
    }
    if (!existing.isShared) return <Debt>[existing];
    // A settled pot stays settled: splitting it would fabricate open balances
    // for people who owe nothing. Only a record that still owes converts.
    final List<Payment> history = await payments.forDebt(debtId);
    if (DebtCalculator.remainingOf(
          existing.principalMinor,
          DebtCalculator.totalPaid(history),
        ) <=
        0) {
      throw StateError(
        'Cannot split a settled shared debt: its balance is already zero',
      );
    }
    final DateTime now = clock();
    final List<Debt> result = await _db.transaction(() async {
      final Debt first = existing.copyWith(
        personIds: <String>[existing.personIds.first],
        updatedAt: now,
      );
      await debts.save(first);
      await _log(
        type: ActivityType.debtUpdated,
        entityType: RelatedEntityType.debt,
        entityId: first.id,
        title: await _displayNameFor(first),
        amountMinor: first.principalMinor,
        currency: first.currency,
      );
      final List<Debt> out = <Debt>[first];
      for (final String personId in existing.personIds.skip(1)) {
        final Debt debt = Debt(
          id: newId(),
          personIds: <String>[personId],
          direction: existing.direction,
          title: existing.title,
          principalMinor: existing.principalMinor,
          currency: existing.currency,
          issuedAt: existing.issuedAt,
          dueAt: existing.dueAt,
          note: existing.note,
          reminderLeads: existing.reminderLeads,
          recurrence: existing.recurrence,
          recurrenceInterval: existing.recurrenceInterval,
          recurrenceEndAt: existing.recurrenceEndAt,
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
        out.add(debt);
      }
      return out;
    });
    await refreshNotifications();
    return result;
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

      // Widening a single record to several people would recreate the shared
      // pot the fan-out removed, so it is refused before anything is written.
      // Maintaining a legacy record's own participants — or narrowing it down
      // to one person — stays allowed.
      if (!existing.isShared && personIds.length > 1) {
        throw const NewSharedDebtBlockedException();
      }

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
      // exactly as a final payment would, next period included. Raising it past
      // what has been paid reopens the debt, and takes that next period back.
      await _applyClosureOutcome(updated);
      return true;
    });
    if (!found) return;
    await refreshNotifications();
  }

  Future<void> setDebtArchived(String id, bool archived) async {
    final Debt? existing = await debts.getById(id);
    if (existing == null) return;
    await debts.setArchived(id, archived: archived, now: clock());
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
    // The record's own feed — created, paid, edited — goes with it, so it is
    // kept too: an undo that brought back the debt without it left a record
    // whose history began at the moment it was undone.
    final List<ActivityEntry> feed =
        await activity.forEntity(RelatedEntityType.debt, id);
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

    return LedgerServiceSnapshot(
      debt: existing,
      payments: history,
      activity: feed,
    );
  }

  /// Restores a debt, its payments and its history exactly as they were.
  ///
  /// Identifiers are preserved, so an undone delete leaves no trace behind: the
  /// same ids, the same timestamps, the same balances, the same feed.
  ///
  /// A person the record was with may have been deleted in the meantime. They
  /// are left out, as [deletePerson] would have left them out had the record
  /// been there: a link to nobody used to fail the whole undo.
  Future<void> restoreDeleted(LedgerServiceSnapshot snapshot) async {
    final Debt? debt = snapshot.debt;
    if (debt == null) return;

    await _db.transaction(() async {
      final Set<String> present = <String>{};
      for (final String id in <String>{
        ...debt.personIds,
        for (final Payment payment in snapshot.payments)
          if (payment.personId != null) payment.personId!,
      }) {
        if (await people.getById(id) != null) present.add(id);
      }

      await debts.save(
        debt.copyWith(
          personIds: <String>[
            for (final String id in debt.personIds)
              if (present.contains(id)) id,
          ],
        ),
      );
      for (final Payment payment in snapshot.payments) {
        final String? payer = payment.personId;
        await payments.save(
          payer == null || present.contains(payer)
              ? payment
              : payment.copyWith(personId: null),
        );
      }
      // The entry the delete wrote goes; the record's own entries come back.
      await activity.deleteForEntity(RelatedEntityType.debt, debt.id);
      await activity.addAll(snapshot.activity);
    });
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
      // A legacy shared debt names several people on one pot: any payment on
      // it would settle everyone at once. New payments are refused until the
      // user splits it into independent debts after reviewing its history.
      if (debt.isShared) {
        throw SharedDebtPaymentBlockedException(debtId);
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
      await _applyClosureOutcome(debt);
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
      // Correcting a payment on a legacy shared debt moves everyone's balance
      // together, exactly like a new one would — so it waits for the split too.
      final String? debtId = existing.debtId;
      final Debt? debt =
          debtId == null ? null : await debts.getById(debtId);
      if (debt != null && debt.isShared) {
        throw SharedDebtPaymentBlockedException(debtId!);
      }
      await payments.save(
        existing.copyWith(
          amountMinor: draft.amountMinor,
          paidAt: dateOnly(draft.paidAt),
          note: _blankToNull(draft.note),
        ),
      );
      if (debt != null) {
        // A corrected amount can be the one that pays the debt off, or the one
        // that means it was never paid off. Both directions are handled by the
        // same path a new payment uses.
        await _applyClosureOutcome(debt);
      }
      return true;
    });
    if (!found) return;
    await refreshNotifications();
  }

  /// Puts a deleted payment back, used by the undo on the payments list.
  ///
  /// The closing is not announced a second time — it was announced when the
  /// payment was first recorded — but the next period it created *is* restored
  /// when it is missing: undo takes that period away, so redo has to bring it
  /// back. `_spawnNextRecurrence` refuses to build a period that is already
  /// recorded, so a period that survived the undo is never duplicated.
  Future<void> restorePaymentRecord(Payment payment) async {
    await _db.transaction(() async {
      await payments.save(payment);
      final String? debtId = payment.debtId;
      if (debtId == null) return;
      final Debt? debt = await debts.getById(debtId);
      if (debt == null) return;
      await _applyClosureOutcome(debt, announce: false);
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
          // Deleting money cannot close a debt, so this only ever reopens one —
          // and reopens it *with* the period the closing had created taken back,
          // or the person is left owing the money twice.
          await _applyClosureOutcome(debt);
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
  /// whether *this* call is the one that closed it — which is the only moment
  /// the closing may be announced or a recurring debt's next period created —
  /// and, when the call is the one that *reopens* it, the stamp it carried,
  /// which is what dates the period that has to be taken back.
  Future<({Debt debt, bool justClosed, DateTime? reopenedFrom})>
      _syncClosedStamp(Debt debt) async {
    final List<Payment> history = await payments.forDebt(debt.id);
    final int remaining = DebtCalculator.remainingOf(
      debt.principalMinor,
      DebtCalculator.totalPaid(history),
    );
    final bool shouldBeClosed = remaining <= 0;

    if (shouldBeClosed && debt.closedAt == null) {
      final Debt updated = debt.copyWith(closedAt: clock(), updatedAt: clock());
      await debts.save(updated);
      return (debt: updated, justClosed: true, reopenedFrom: null);
    }
    if (!shouldBeClosed && debt.closedAt != null) {
      final DateTime wasClosedAt = debt.closedAt!;
      final Debt updated = debt.copyWith(closedAt: null, updatedAt: clock());
      await debts.save(updated);
      return (debt: updated, justClosed: false, reopenedFrom: wasClosedAt);
    }
    return (debt: debt, justClosed: false, reopenedFrom: null);
  }

  /// Everything that follows a change to what a debt owes, in both directions.
  ///
  /// Forward — a debt that is now paid off is closed, announced, and given the
  /// next period of its recurrence. Backward — a debt that is no longer paid off
  /// is reopened, and the next period that the closing created is taken back
  /// with it, because that period exists only because the debt was thought
  /// settled. Leaving it behind was a real defect: undoing a payment on a
  /// monthly record reopened that month *and* kept the following month, so the
  /// person owed the money twice.
  ///
  /// A payment, a corrected payment, a lowered amount and a deleted payment can
  /// each be what pays a debt off or what stops it being paid off, and they used
  /// to disagree; now there is one path and they cannot.
  ///
  /// [announce] is false for an undo/redo of a payment whose closing was already
  /// announced: the second pass must restore the period without writing the
  /// "debt closed" line into the feed a second time.
  ///
  /// Returns how many created periods were *left in place* because money had
  /// already been applied to them, so the caller can say so rather than let the
  /// difference pass silently.
  Future<int> _applyClosureOutcome(Debt debt, {bool announce = true}) async {
    final ({Debt debt, bool justClosed, DateTime? reopenedFrom}) closing =
        await _syncClosedStamp(debt);

    if (closing.justClosed) {
      if (announce) {
        await _log(
          type: ActivityType.debtClosed,
          entityType: RelatedEntityType.debt,
          entityId: closing.debt.id,
          title: await _displayNameFor(closing.debt),
          amountMinor: closing.debt.principalMinor,
          currency: closing.debt.currency,
        );
      }
      await _spawnNextRecurrence(closing.debt);
      return 0;
    }

    final DateTime? reopenedFrom = closing.reopenedFrom;
    if (reopenedFrom == null) return 0;
    return _revertSpawnedFollowUp(
      periodId: closing.debt.id,
      closureStamp: reopenedFrom,
    );
  }

  /// Takes back the next period of a recurring debt when the closing that
  /// created it is undone.
  ///
  /// The period is found through the link its creation recorded (the activity
  /// entry's `detail` holds the period it came from), never by looking for a
  /// record that merely matches a title and a date: a user can type a duplicate
  /// title, and deleting their record would be silent data loss. A period
  /// created by a build before that link existed therefore simply is not found,
  /// and is left where it is — the older, quieter failure rather than a guess.
  ///
  /// Three guards keep a record that is in use:
  ///
  /// * it carries money — the applied payment would have nowhere to live;
  /// * it was closed itself, so its own next period may already exist and taking
  ///   it away would orphan that one;
  /// * the user archived it, which is a decision about the record, not a
  ///   consequence of the closing.
  ///
  /// A record that was created *before* the closing cannot be its consequence
  /// and is left too. Returns how many were left for those reasons.
  Future<int> _revertSpawnedFollowUp({
    required String periodId,
    required DateTime closureStamp,
  }) async {
    int leftInPlace = 0;
    for (final ActivityEntry entry in await activity.createdFrom(periodId)) {
      final String? followUpId = entry.entityId;
      if (followUpId == null) continue;
      final Debt? followUp = await debts.getById(followUpId);
      if (followUp == null) continue;
      if (followUp.archivedAt != null ||
          followUp.closedAt != null ||
          followUp.createdAt.isBefore(closureStamp) ||
          (await payments.forDebt(followUpId)).isNotEmpty) {
        leftInPlace++;
        continue;
      }
      // Nothing refers to it: no payment, no link, no closing. Its own feed goes
      // with it, exactly as a deleted record's does, so the timeline is not left
      // pointing at a row that is gone — and no "deleted" line is written,
      // because the entry that would explain it ("this period was created")
      // is the one being removed, and the user's own undo is already in the feed.
      await activity.deleteForEntity(RelatedEntityType.debt, followUpId);
      await debts.delete(followUpId);
    }
    return leftInPlace;
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
      // The period this one came out of. It is the only record of the
      // relationship between the two, and it is what lets an undo find the
      // period again and take it back with the closing that created it.
      detail: settled.id,
    );
  }

  /// Records one payment against everything a person owes on one side of the
  /// ledger, split across their open debts.
  ///
  /// The split is worked out **inside** the transaction, from the balances as
  /// they stand at that moment, and with the same [PaymentAllocator] the sheet
  /// drew its preview from — so the plan the user approved is the plan that is
  /// written. The caller passes the decision (amount, direction, currency,
  /// order, exclusions) and never the amounts, because a preview that went stale
  /// while the sheet was open must not be able to become the ledger.
  ///
  /// Nothing about the shape of the data changes: this writes several ordinary
  /// payments, each with its own debt, so every existing read — the per-debt
  /// balances, the reports, the backup, the feed — sees exactly what it would
  /// have seen had the user recorded each share by hand.
  ///
  /// Returns what was written, so the caller can offer one undo for the group.
  Future<List<Payment>> recordPersonPayment(PersonPaymentDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'payment');

    final List<Payment> created = await _db.transaction(() async {
      final List<DebtView> candidates = await _openDebtsFor(
        personId: draft.personId,
        direction: draft.direction,
        currency: draft.currency,
      );
      // Nothing to pay. Silent rather than a throw: the sheet disables its own
      // save button in this state, and a race that empties the list between the
      // preview and the write should leave the ledger alone, not fail loudly.
      if (candidates.isEmpty) return const <Payment>[];

      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: candidates,
        amountMinor: draft.amountMinor,
        order: draft.order,
        excludedDebtIds: draft.excludedDebtIds,
      );
      final Map<String, Debt> byId = <String, Debt>{
        for (final DebtView view in candidates) view.debt.id: view.debt,
      };

      final DateTime now = clock();
      final DateTime paidAt = dateOnly(draft.paidAt);
      final String? note = _blankToNull(draft.note);
      final List<Payment> out = <Payment>[];

      for (final DebtAllocation allocation in plan) {
        if (allocation.allocatedMinor <= 0) continue;
        final Debt? debt = byId[allocation.debtId];
        if (debt == null) continue;

        final Payment payment = Payment(
          id: newId(),
          debtId: debt.id,
          personId: draft.personId,
          amountMinor: allocation.allocatedMinor,
          currency: debt.currency,
          paidAt: paidAt,
          note: note,
          createdAt: now,
        );
        await payments.save(payment);
        // One entry per debt, not one for the group: a debt's own page reads its
        // timeline with `activity.forEntity(debt, id)`, and a group entry filed
        // against one debt would leave the others with a payment and no record
        // of where it came from.
        await _log(
          type: ActivityType.paymentRecorded,
          entityType: RelatedEntityType.debt,
          entityId: debt.id,
          title: await _displayNameFor(debt),
          amountMinor: payment.amountMinor,
          currency: payment.currency,
        );
        // The single decider of closure, exactly as a hand-recorded payment
        // uses it — so a debt settled here is closed, announced, and given its
        // next period if it recurs, by the same code path as any other.
        await _applyClosureOutcome(debt);
        out.add(payment);
      }
      return out;
    });

    await refreshNotifications();
    return created;
  }

  /// Removes a group of payments in one write.
  ///
  /// The undo behind one person-level payment, which is several rows at once:
  /// taking them away one call at a time would rebuild the whole notification
  /// plan once per row, and would leave the ledger briefly holding a half-undone
  /// split if the app stopped in the middle.
  ///
  /// Each affected debt's closing stamp is brought back in line, exactly as
  /// [deletePayment] does it — including taking back a recurring debt's next
  /// period when the undo is what reopens it — and one `paymentDeleted` entry is
  /// written per debt carrying the total that came off it.
  ///
  /// Returns how many of those next periods had to be left in place because
  /// money had already been applied to them, so the caller can say so instead of
  /// quietly leaving a balance the user did not expect.
  Future<int> deletePaymentsBatch(List<String> paymentIds) async {
    if (paymentIds.isEmpty) return 0;
    final int leftInPlace = await _db.transaction(() async {
      final Map<String, int> removedByDebt = <String, int>{};
      for (final String id in paymentIds) {
        final Payment? existing = await payments.getById(id);
        if (existing == null) continue;
        await payments.delete(id);
        final String? debtId = existing.debtId;
        if (debtId == null) continue;
        removedByDebt[debtId] = (removedByDebt[debtId] ?? 0) + existing.amountMinor;
      }

      int left = 0;
      for (final MapEntry<String, int> entry in removedByDebt.entries) {
        final Debt? debt = await debts.getById(entry.key);
        if (debt == null) continue;
        // Deleting money cannot close a debt, so this only ever reopens one.
        left += await _applyClosureOutcome(debt);
        await _log(
          type: ActivityType.paymentDeleted,
          entityType: RelatedEntityType.debt,
          entityId: debt.id,
          title: await _displayNameFor(debt),
          amountMinor: entry.value,
          currency: debt.currency,
        );
      }
      return left;
    });
    await refreshNotifications();
    return leftInPlace;
  }

  /// A person's open debts on one side of the ledger, in one currency, as views.
  ///
  /// Three exclusions, each of which would be a bug if left in:
  ///
  /// * **archived** — the user set the record aside; its balance is not theirs
  ///   to collect or pay any more;
  /// * **settled** — nothing left to apply money to;
  /// * **shared legacy records** (`personIds.length > 1`) — a payment on one
  ///   settles everybody at once, which is why `recordPayment` refuses them. Left
  ///   in, one would abort the whole split mid-transaction.
  ///
  /// Balances come from one grouped query rather than one per debt, which at a
  /// dozen debts on a person's page is the difference between a write and a
  /// pause.
  Future<List<DebtView>> _openDebtsFor({
    required String personId,
    required DebtDirection direction,
    required AppCurrency currency,
  }) async {
    final List<Debt> personDebts = await debts.forPerson(personId);
    final List<Debt> eligible = <Debt>[
      for (final Debt debt in personDebts)
        if (!debt.isArchived &&
            !debt.isShared &&
            debt.direction == direction &&
            debt.currency == currency)
          debt,
    ];
    if (eligible.isEmpty) return const <DebtView>[];

    final List<DebtPaymentTotals> totals = await _db.debtsDao.paymentTotalsFor(
      eligible.map((Debt debt) => debt.id),
    );
    final Map<String, PaymentTotals> byDebt = <String, PaymentTotals>{
      for (final DebtPaymentTotals t in totals)
        t.debtId: PaymentTotals(
          paidMinor: t.paidMinor,
          count: t.count,
          lastPaidAt: t.lastPaidAt,
        ),
    };
    final AppSettings settings = await this.settings.get();
    final DateTime asOf = dateOnly(clock());

    return <DebtView>[
      for (final Debt debt in eligible)
        DebtCalculator.buildViewFromTotals(
          debt: debt,
          totals: byDebt[debt.id] ?? const PaymentTotals.none(),
          asOf: asOf,
          dueSoonWindowDays: settings.dueSoonWindowDays,
        ),
    ];
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
    await _db.transaction(() async {
      await obligations.save(anchored);
      await ensureOccurrences();
      // A schedule that started long ago has its first open period inside the
      // look-back, not at its anchor years back.
      await _syncNextDue(anchored.id, now);
      await _log(
        type: ActivityType.obligationCreated,
        entityType: RelatedEntityType.obligation,
        entityId: anchored.id,
        title: anchored.name,
        amountMinor: anchored.amountMinor,
        currency: anchored.currency,
      );
    });
    await refreshNotifications();
    return (await obligations.getById(anchored.id)) ?? anchored;
  }

  Future<void> updateObligation(String id, ObligationDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'obligation amount');
    final bool found = await _db.transaction(() async {
      final Obligation? existing = await obligations.getById(id);
      if (existing == null) return false;

      // The rhythm is when periods fall. Changing it replaces the schedule;
      // changing the amount, the start or the end keeps it and moves its edges.
      final bool sameRhythm = existing.frequency == draft.frequency &&
          existing.intervalCount == draft.intervalCount &&
          existing.dayOfMonth == draft.dayOfMonth;
      final bool scheduleChanged = !sameRhythm ||
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
        // Paid periods are history and stay untouched; the periods the new
        // schedule no longer has are removed, and it is filled in again.
        await _rebuildFutureOccurrences(updated, sameRhythm: sameRhythm);
        final DateTime asOf = dateOnly(clock());
        await _materialise(
          updated,
          // A new rhythm starts today. Its dates before today were never due —
          // filling them in turned "monthly rent is now weekly" into a late
          // week for every week of the last two months.
          from: sameRhythm ? addDays(asOf, -obligationLookbackDays) : asOf,
          to: addDays(asOf, obligationHorizonDays),
          now: clock(),
        );
      }
      await ensureOccurrences();
      await _syncNextDue(id, clock());
      await _log(
        type: ActivityType.obligationCreated,
        entityType: RelatedEntityType.obligation,
        entityId: id,
        title: updated.name,
        amountMinor: updated.amountMinor,
        currency: updated.currency,
      );
      return true;
    });
    if (!found) return;
    await refreshNotifications();
  }

  Future<void> setObligationArchived(String id, bool archived) async {
    final Obligation? existing = await obligations.getById(id);
    if (existing == null) return;
    await obligations.setArchived(id, archived: archived, now: clock());
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

  // --- Income --------------------------------------------------------------

  /// Records a new source of recurring income.
  ///
  /// No periods are materialised and no notifications are scheduled: an income
  /// has no state to keep and nothing to be reminded about. The only thing this
  /// write changes is the month's budget reading, which is derived.
  Future<Income> createIncome(IncomeDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'income amount');
    final Income income = newIncome(draft: draft, now: clock());
    await _db.transaction(() async {
      await incomes.save(income);
      await _log(
        type: ActivityType.incomeCreated,
        entityType: RelatedEntityType.income,
        entityId: income.id,
        title: income.name,
        amountMinor: income.amountMinor,
        currency: income.currency,
      );
    });
    return income;
  }

  /// Edits an income in place.
  ///
  /// Nothing downstream has to be rebuilt: the months this income has already
  /// paid are not stored anywhere, so re-anchoring the schedule changes what
  /// every month reads from now on and rewrites no history. That is the whole
  /// reason income is kept as a rule rather than as a record per payslip.
  Future<void> updateIncome(String id, IncomeDraft draft) async {
    _requireValidAmount(draft.amountMinor, 'income amount');
    await _db.transaction(() async {
      final Income? existing = await incomes.getById(id);
      if (existing == null) return;
      // Built fresh rather than copied onto: the identity, the creation moment
      // and the archived flag are the three things an edit may not move, and
      // taking them from [existing] makes that explicit instead of relying on
      // the draft to leave them out.
      final Income built = newIncome(draft: draft, now: clock());
      final Income updated = Income(
        id: existing.id,
        name: built.name,
        amountMinor: built.amountMinor,
        currency: built.currency,
        frequency: built.frequency,
        intervalCount: built.intervalCount,
        dayOfMonth: built.dayOfMonth,
        startAt: built.startAt,
        note: built.note,
        archivedAt: existing.archivedAt,
        createdAt: existing.createdAt,
        updatedAt: built.updatedAt,
      );
      await incomes.save(updated);
      await _log(
        type: ActivityType.incomeUpdated,
        entityType: RelatedEntityType.income,
        entityId: updated.id,
        title: updated.name,
        amountMinor: updated.amountMinor,
        currency: updated.currency,
      );
    });
  }

  /// Sets an income aside, or brings it back.
  ///
  /// Archiving is the normal way to end an income; the record stays so the
  /// months it covered keep reading correctly, and it can be restored.
  Future<void> setIncomeArchived(String id, bool archived) async {
    final Income? existing = await incomes.getById(id);
    if (existing == null) return;
    await incomes.setArchived(id, archived: archived, now: clock());
    await _log(
      type: archived ? ActivityType.incomeArchived : ActivityType.incomeRestored,
      entityType: RelatedEntityType.income,
      entityId: id,
      title: existing.name,
    );
  }

  /// Removes an income for good.
  Future<void> deleteIncome(String id) async {
    final Income? existing = await incomes.getById(id);
    await _db.transaction(() async {
      await activity.deleteForEntity(RelatedEntityType.income, id);
      await incomes.delete(id);
    });
    await _log(
      type: ActivityType.incomeDeleted,
      entityType: RelatedEntityType.income,
      entityId: id,
      title: existing?.name ?? '',
    );
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

    // The payment, the period, the periods after it and where the commitment
    // points next are one write.
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
      await _log(
        type: ActivityType.obligationPaid,
        entityType: RelatedEntityType.obligation,
        entityId: obligation.id,
        title: obligation.name,
        amountMinor: payment.amountMinor,
        currency: payment.currency,
      );
      // Later periods first, so the next due date can point at one of them.
      await ensureOccurrences();
      await _syncNextDue(obligation.id, now);
    });
    await refreshNotifications();
  }

  /// Undoes a payment on one period — or re-opens a skipped one, which the
  /// same action on the screen also calls.
  Future<void> undoObligationPayment(ObligationInstance instance) async {
    final ObligationOccurrence occurrence = instance.occurrence;
    final String? paymentId = occurrence.paymentId;
    final String id = instance.obligation.id;
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
      // A period open again means the commitment is not finished, whatever
      // paying its last period had concluded.
      final Obligation? stored = await obligations.getById(id);
      if (stored != null && stored.isArchived) {
        await obligations.setArchived(id, archived: false, now: clock());
      }
      // Only a payment is announced as removed: re-opening a skipped period
      // used to add "payment deleted" to the feed, with an amount nobody paid.
      if (paymentId != null) {
        await _log(
          type: ActivityType.paymentDeleted,
          entityType: RelatedEntityType.obligation,
          entityId: id,
          title: instance.obligation.name,
          amountMinor: occurrence.amountMinor,
          currency: instance.obligation.currency,
        );
      }
      await _syncNextDue(id, now);
    });
    await refreshNotifications();
  }

  /// Marks one period as not applicable — a paused subscription, a month with no
  /// rent.
  Future<void> skipObligationPeriod(ObligationInstance instance) async {
    final DateTime now = clock();
    await _db.transaction(() async {
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
      await _syncNextDue(instance.obligation.id, now);
    });
    await refreshNotifications();
  }

  /// Points a commitment at its earliest period still to be paid, and archives
  /// it only once its schedule has ended with nothing left open.
  ///
  /// The one place "next due" is decided, for paying, undoing, skipping and
  /// editing alike. It used to be worked out from the period just paid, which
  /// went wrong twice: paying the *last* period of a schedule archived the
  /// commitment even while earlier periods were unpaid — and an archived
  /// commitment is hidden, so those periods vanished from the dashboard, the
  /// attention list and the reminders — and paying an older period out of
  /// order moved "next due" backwards, onto a period that was already paid.
  Future<void> _syncNextDue(String obligationId, DateTime now) async {
    final Obligation? obligation = await obligations.getById(obligationId);
    if (obligation == null) return;
    final List<ObligationOccurrence> periods =
        await obligations.occurrencesFor(obligationId);
    if (periods.isEmpty) return;

    DateTime? earliestOpen;
    DateTime latest = periods.first.dueAt;
    for (final ObligationOccurrence period in periods) {
      if (period.dueAt.isAfter(latest)) latest = period.dueAt;
      if (!period.isPayable) continue;
      if (earliestOpen == null || period.dueAt.isBefore(earliestOpen)) {
        earliestOpen = period.dueAt;
      }
    }

    // Nothing open: the first period the schedule has not produced yet, or
    // none at all once it has ended.
    final DateTime? next = earliestOpen ??
        ObligationSchedule.rollForward(obligation.copyWith(nextDueAt: latest));
    if (next == null) {
      if (obligation.isArchived) return;
      await obligations.setArchived(obligationId, archived: true, now: clock());
      await _log(
        type: ActivityType.debtArchived,
        entityType: RelatedEntityType.obligation,
        entityId: obligationId,
        title: obligation.name,
      );
      return;
    }
    if (isSameDate(next, obligation.nextDueAt)) return;
    await obligations.save(obligation.copyWith(nextDueAt: next, updatedAt: now));
  }

  /// Materials every obligation's periods for the visible window.
  ///
  /// Safe to call often: existing periods are skipped, so it only ever fills
  /// gaps. This is what makes a commitment's next due date appear without the
  /// user having to do anything.
  Future<void> ensureOccurrences() async {
    final DateTime asOf = dateOnly(clock());
    final DateTime lookback = addDays(asOf, -obligationLookbackDays);
    final DateTime to = addDays(asOf, obligationHorizonDays);
    final DateTime now = clock();

    for (final Obligation obligation in await obligations.getAll()) {
      if (obligation.frequency == RecurrenceFrequency.none) continue;
      await _materialise(
        obligation,
        from: await _extendFrom(obligation, lookback),
        to: to,
        now: now,
      );
    }
  }

  /// Where filling a commitment's periods starts: the look-back, or the day
  /// after the last period it already has, whichever is later.
  ///
  /// A schedule is extended, never filled in behind periods that exist: a gap
  /// there is not a missing period but a changed schedule, and filling it
  /// produced periods for dates that were never due.
  Future<DateTime> _extendFrom(Obligation obligation, DateTime lookback) async {
    final DateTime? latest = await obligations.latestPeriodDue(obligation.id);
    if (latest == null) return lookback;
    final DateTime next = addDays(latest, 1);
    return next.isAfter(lookback) ? next : lookback;
  }

  /// Creates the periods [obligation]'s schedule has in `[from, to]` that do
  /// not exist yet.
  Future<void> _materialise(
    Obligation obligation, {
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    if (from.isAfter(to)) return;
    final Set<String> existing =
        await obligations.existingPeriodKeys(obligation.id);
    final List<DateTime> dueDates =
        ObligationSchedule.dueDatesBetween(obligation, from, to);

    final List<ObligationOccurrence> missing = <ObligationOccurrence>[];
    for (final DateTime due in dueDates) {
      final String key = ObligationSchedule.periodKeyFor(obligation.frequency, due);
      if (!existing.add(key)) continue;
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

  /// Removes the periods a changed schedule no longer has.
  ///
  /// Paid periods are history and are never touched. Of the others:
  ///
  /// * an open period still ahead is removed, to be created again from the new
  ///   schedule (with its new amount, on its new day);
  /// * a skipped period ahead is kept while the rhythm is the same — the user
  ///   said that month does not apply, and a new amount does not undo that —
  ///   and removed when the rhythm changes, since the period it stood for is
  ///   gone;
  /// * an open period outside the new schedule's start and end never belonged
  ///   to it, and would otherwise sit there late for ever.
  Future<void> _rebuildFutureOccurrences(
    Obligation obligation, {
    required bool sameRhythm,
  }) async {
    final DateTime asOf = dateOnly(clock());
    final DateTime start = ObligationSchedule.anchorFor(obligation);
    final DateTime? end =
        obligation.endAt == null ? null : dateOnly(obligation.endAt!);
    final List<ObligationOccurrence> current =
        await obligations.occurrencesFor(obligation.id);
    for (final ObligationOccurrence occurrence in current) {
      if (occurrence.isPaid) continue;
      final bool open = occurrence.isPayable;
      final bool outside = occurrence.dueAt.isBefore(start) ||
          (end != null && occurrence.dueAt.isAfter(end));
      final bool discard = occurrence.dueAt.isAfter(asOf)
          ? open || !sameRhythm
          : open && outside;
      if (discard) await obligations.deleteOccurrence(occurrence.id);
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
    await _deliverPendingSummary(now, asOf, activeComposer);
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
  ///
  /// Settings are read again here rather than taken from the pass, because the
  /// pass may have just handed a summary to the phone. That write is what marks
  /// a month as done, and a check made against the snapshot from before it could
  /// not see it — so the same pass armed this month's summary *and* caught up
  /// the one that had gone past, and the user was sent two month-end
  /// notifications for one save. Every pass in the arm window arms the same
  /// summary, so this is the check that has to be made against what has actually
  /// been recorded, not against what was true when the pass began.
  Future<void> _deliverPendingSummary(
    DateTime now,
    DateTime asOf,
    NotificationComposer composer,
  ) async {
    final AppSettings current = await settings.get();
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
    // Recorded straight after it is fired, and before anything else can be
    // written, so the mark that stops a second delivery is in place as soon as
    // this one exists. A later pass — a settings change, a resume, the next
    // save — reads it and does not send it again.
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
    String? detail,
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
        detail: detail,
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

/// A new or corrected payment was refused on a legacy shared debt.
///
/// One row naming several people is one pot: any payment on it settles
/// everyone at once. The user must split the record into independent debts
/// first, after reviewing its history.
class SharedDebtPaymentBlockedException implements Exception {
  const SharedDebtPaymentBlockedException(this.debtId);

  final String debtId;

  @override
  String toString() =>
      'SharedDebtPaymentBlockedException(legacy shared debt $debtId '
      'refuses new payments; split it into independent debts first)';
}

/// An edit that would turn a single debt into a shared pot was refused.
///
/// One row naming several people is one pot, so widening a record's
/// participants recreates the bug the fan-out removed: a later payment would
/// settle everyone at once. Narrowing a legacy record down to one person stays
/// allowed, and so does maintaining a legacy record's own participants.
class NewSharedDebtBlockedException implements Exception {
  const NewSharedDebtBlockedException();

  @override
  String toString() =>
      'NewSharedDebtBlockedException(an edit must not link a single debt to '
      'several people; record a new debt per person instead)';
}

/// Everything needed to undo a delete.
@immutable
class LedgerServiceSnapshot {
  const LedgerServiceSnapshot({
    required this.debt,
    required this.payments,
    required this.activity,
  });

  /// Null when the record had already gone.
  final Debt? debt;

  final List<Payment> payments;

  /// The record's feed entries, as they were before the delete.
  final List<ActivityEntry> activity;
}
