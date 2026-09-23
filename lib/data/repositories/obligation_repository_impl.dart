import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/obligation_schedule.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed store for recurring commitments and their periods.
class ObligationRepositoryImpl implements ObligationRepository {
  ObligationRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Obligation>> watchAll() =>
      _db.obligationsDao.watchAll().map(_toEntities);

  @override
  Future<List<Obligation>> getAll() async =>
      _toEntities(await _db.obligationsDao.getAll());

  @override
  Future<Obligation?> getById(String id) async =>
      (await _db.obligationsDao.getById(id))?.toEntity();

  @override
  Stream<Obligation?> watchById(String id) =>
      _db.obligationsDao.watchById(id).map((ObligationRow? r) => r?.toEntity());

  @override
  Future<void> save(Obligation obligation) =>
      _db.obligationsDao.upsert(obligation.toRow());

  @override
  Future<void> setArchived(String id, {required bool archived}) {
    return _db.obligationsDao.setArchivedAt(
      id,
      archived ? DateTime.now() : null,
      DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) => _db.obligationsDao.deleteById(id);

  @override
  Stream<List<ObligationOccurrence>> watchOccurrences() => _db
      .obligationsDao
      .watchOccurrences()
      .map(_toOccurrenceEntities);

  @override
  Future<List<ObligationOccurrence>> allOccurrences() async =>
      _toOccurrenceEntities(await _db.obligationsDao.getOccurrences());

  @override
  Stream<List<ObligationOccurrence>> watchOccurrencesFor(String obligationId) =>
      _db.obligationsDao
          .watchOccurrencesFor(obligationId)
          .map(_toOccurrenceEntities);

  @override
  Future<List<ObligationOccurrence>> occurrencesFor(String obligationId) async {
    return _toOccurrenceEntities(
      await _db.obligationsDao.getOccurrencesFor(obligationId),
    );
  }

  @override
  Future<ObligationOccurrence?> occurrenceById(String id) async =>
      (await _db.obligationsDao.getOccurrenceById(id))?.toEntity();

  @override
  Future<void> saveOccurrence(ObligationOccurrence occurrence) =>
      _db.obligationsDao.upsertOccurrence(occurrence.toRow());

  @override
  Future<void> saveOccurrences(List<ObligationOccurrence> occurrences) {
    return _db.obligationsDao.upsertOccurrences(
      occurrences.map((ObligationOccurrence o) => o.toRow()).toList(),
    );
  }

  @override
  Future<void> deleteOccurrence(String id) =>
      _db.obligationsDao.deleteOccurrence(id);

  @override
  Future<void> deleteOccurrencesFor(String obligationId) =>
      _db.obligationsDao.deleteOccurrencesFor(obligationId);

  @override
  Future<Set<String>> existingPeriodKeys(String obligationId) =>
      _db.obligationsDao.existingPeriodKeys(obligationId);

  static List<Obligation> _toEntities(List<ObligationRow> rows) =>
      rows.map((ObligationRow row) => row.toEntity()).toList(growable: false);

  static List<ObligationOccurrence> _toOccurrenceEntities(
    List<ObligationOccurrenceRow> rows,
  ) =>
      rows
          .map((ObligationOccurrenceRow row) => row.toEntity())
          .toList(growable: false);
}

/// Builds a fresh obligation, deriving its first due date from the schedule.
Obligation newObligation({
  required String name,
  required ObligationCategory category,
  required int amountMinor,
  required AppCurrency currency,
  required RecurrenceFrequency frequency,
  required DateTime startAt,
  int intervalCount = 1,
  int? dayOfMonth,
  DateTime? endAt,
  String? note,
  List<ReminderLead> reminderLeads = const <ReminderLead>[],
  DateTime? now,
}) {
  final DateTime timestamp = now ?? DateTime.now();
  final DateTime start = dateOnly(startAt);

  // The first period is the anchor itself, adjusted to the chosen day of month.
  final int day = dayOfMonth ?? start.day;
  final int clampedDay = day > daysInMonth(start.year, start.month)
      ? daysInMonth(start.year, start.month)
      : day;
  final DateTime firstDue = DateTime(start.year, start.month, clampedDay);

  final Obligation draft = Obligation(
    id: newId(),
    name: name.trim(),
    category: category,
    amountMinor: amountMinor,
    currency: currency,
    frequency: frequency,
    intervalCount: intervalCount,
    dayOfMonth: dayOfMonth,
    startAt: start,
    nextDueAt: firstDue,
    endAt: endAt == null ? null : dateOnly(endAt),
    note: note,
    reminderLeads: ReminderLead.sorted(reminderLeads),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  // Anchoring through the schedule keeps the stored first due date identical to
  // the one every later period is derived from.
  return draft.copyWith(nextDueAt: ObligationSchedule.nthDueDate(draft, 0));
}

/// Builds an occurrence row for one period of an obligation.
ObligationOccurrence newOccurrence({
  required Obligation obligation,
  required DateTime dueAt,
  ObligationStatus status = ObligationStatus.upcoming,
  int? amountMinorOverride,
  DateTime? now,
}) {
  final DateTime timestamp = now ?? DateTime.now();
  return ObligationOccurrence(
    id: newId(),
    obligationId: obligation.id,
    periodKey: ObligationSchedule.periodKeyFor(obligation.frequency, dueAt),
    dueAt: dateOnly(dueAt),
    amountMinor: amountMinorOverride ?? obligation.amountMinor,
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

/// Builds a payment that settles one obligation period.
Payment newObligationPayment({
  required Obligation obligation,
  required ObligationOccurrence occurrence,
  required DateTime paidAt,
  String? note,
  DateTime? now,
}) {
  return Payment(
    id: newId(),
    obligationId: obligation.id,
    occurrenceId: occurrence.id,
    amountMinor: occurrence.amountMinor,
    currency: obligation.currency,
    paidAt: dateOnly(paidAt),
    note: note,
    createdAt: now ?? DateTime.now(),
  );
}
