import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed debt store.
class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Debt>> watchAll() => _db.debtsDao.watchAll().map(_toEntities);

  @override
  Future<List<Debt>> getAll() async => _toEntities(await _db.debtsDao.getAll());

  @override
  Future<Debt?> getById(String id) async =>
      (await _db.debtsDao.getById(id))?.toEntity();

  @override
  Stream<Debt?> watchById(String id) =>
      _db.debtsDao.watchById(id).map((DebtRow? row) => row?.toEntity());

  @override
  Stream<List<Debt>> watchForPerson(String personId) =>
      _db.debtsDao.watchForPerson(personId).map(_toEntities);

  @override
  Future<List<Debt>> forPerson(String personId) async {
    // Filtered by the database. Loading the whole table and filtering in Dart
    // made this 265 ms at 2,500 debts, and the person page runs it for every
    // debt a person has.
    return _toEntities(await _db.debtsDao.getForPerson(personId));
  }

  @override
  Future<void> save(Debt debt) => _db.debtsDao.upsert(debt.toRow());

  @override
  Future<void> setArchived(String id, {required bool archived}) {
    return _db.debtsDao.setArchivedAt(
      id,
      archived ? DateTime.now() : null,
      DateTime.now(),
    );
  }

  @override
  Future<void> setClosed(String id, DateTime? closedAt) =>
      _db.debtsDao.setClosedAt(id, closedAt, DateTime.now());

  @override
  Future<void> reassignPerson(String fromPersonId, String? toPersonId) =>
      _db.debtsDao.reassignPerson(fromPersonId, toPersonId);

  @override
  Future<void> delete(String id) => _db.debtsDao.deleteById(id);

  static List<Debt> _toEntities(List<DebtRow> rows) =>
      rows.map((DebtRow row) => row.toEntity()).toList(growable: false);
}

/// SQLite-backed payment store.
class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Payment>> watchAll() =>
      _db.debtsDao.watchAllPayments().map(_toEntities);

  @override
  Future<List<Payment>> getAll() async =>
      _toEntities(await _db.debtsDao.getAllPayments());

  @override
  Future<Payment?> getById(String id) async =>
      (await _db.debtsDao.getPaymentById(id))?.toEntity();

  @override
  Stream<List<Payment>> watchForDebt(String debtId) =>
      _db.debtsDao.watchPaymentsForDebt(debtId).map(_toEntities);

  @override
  Future<List<Payment>> forDebt(String debtId) async =>
      _toEntities(await _db.debtsDao.getPaymentsForDebt(debtId));

  @override
  Stream<List<Payment>> watchForPerson(String personId) =>
      _db.debtsDao.watchPaymentsForPerson(personId).map(_toEntities);

  @override
  Future<void> save(Payment payment) =>
      _db.debtsDao.upsertPayment(payment.toRow());

  @override
  Future<void> delete(String id) => _db.debtsDao.deletePayment(id);

  @override
  Future<void> deleteForDebt(String debtId) =>
      _db.debtsDao.deletePaymentsForDebt(debtId);

  static List<Payment> _toEntities(List<PaymentRow> rows) =>
      rows.map((PaymentRow row) => row.toEntity()).toList(growable: false);
}

/// Builds a fresh debt from what the form collected.
Debt newDebt({
  required DebtDirection direction,
  required int principalMinor,
  required AppCurrency currency,
  required DateTime issuedAt,
  String? personId,
  String title = '',
  DateTime? dueAt,
  String? note,
  List<ReminderLead> reminderLeads = const <ReminderLead>[],
  RecurrenceFrequency recurrence = RecurrenceFrequency.none,
  int recurrenceInterval = 0,
  DateTime? recurrenceEndAt,
  DateTime? now,
}) {
  final DateTime timestamp = now ?? DateTime.now();
  return Debt(
    id: newId(),
    personId: personId,
    direction: direction,
    title: title.trim(),
    principalMinor: principalMinor,
    currency: currency,
    issuedAt: dateOnly(issuedAt),
    dueAt: dueAt == null ? null : dateOnly(dueAt),
    note: note,
    reminderLeads: ReminderLead.sorted(reminderLeads),
    recurrence: recurrence,
    recurrenceInterval: recurrenceInterval,
    recurrenceEndAt: recurrenceEndAt == null ? null : dateOnly(recurrenceEndAt),
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

/// Builds a payment against a debt.
Payment newDebtPayment({
  required String debtId,
  required int amountMinor,
  required AppCurrency currency,
  required DateTime paidAt,
  String? personId,
  String? note,
  DateTime? now,
}) {
  return Payment(
    id: newId(),
    debtId: debtId,
    personId: personId,
    amountMinor: amountMinor,
    currency: currency,
    paidAt: dateOnly(paidAt),
    note: note,
    createdAt: now ?? DateTime.now(),
  );
}
