import '../../core/utils/dates.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/income.dart';
import '../../domain/enums/recurrence.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed store for recurring income.
class IncomeRepositoryImpl implements IncomeRepository {
  IncomeRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Income>> watchAll({bool includeArchived = true}) => _db.incomesDao
      .watchAll(includeArchived: includeArchived)
      .map(_toEntities);

  @override
  Future<List<Income>> getAll({bool includeArchived = true}) async =>
      _toEntities(await _db.incomesDao.getAll(includeArchived: includeArchived));

  @override
  Future<Income?> getById(String id) async =>
      (await _db.incomesDao.getById(id))?.toEntity();

  @override
  Stream<Income?> watchById(String id) =>
      _db.incomesDao.watchById(id).map((IncomeRow? row) => row?.toEntity());

  @override
  Future<void> save(Income income) => _db.incomesDao.upsert(income.toRow());

  @override
  Future<void> setArchived(String id, {required bool archived}) {
    final DateTime now = DateTime.now();
    return _db.incomesDao.setArchivedAt(id, archived ? now : null, now);
  }

  @override
  Future<void> delete(String id) => _db.incomesDao.deleteById(id);

  static List<Income> _toEntities(List<IncomeRow> rows) =>
      rows.map((IncomeRow row) => row.toEntity()).toList(growable: false);
}

/// Builds a fresh income, anchoring its schedule the way an obligation anchors
/// its own.
///
/// The clamp matters for the same reason it does there: a salary that lands on
/// the 31st must not slide to the 28th in February and stay there.
Income newIncome({
  required IncomeDraft draft,
  DateTime? now,
}) {
  final DateTime timestamp = now ?? DateTime.now();
  final DateTime start = dateOnly(draft.startAt);
  final int day = draft.dayOfMonth ?? start.day;
  final int clampedDay =
      day > daysInMonth(start.year, start.month) ? daysInMonth(start.year, start.month) : day;

  return Income(
    id: newId(),
    name: draft.name.trim(),
    amountMinor: draft.amountMinor,
    currency: draft.currency,
    frequency: draft.frequency,
    intervalCount: draft.intervalCount <= 0 ? 1 : draft.intervalCount,
    dayOfMonth: draft.frequency == RecurrenceFrequency.weekly
        ? null
        : draft.dayOfMonth,
    startAt: DateTime(start.year, start.month, clampedDay),
    note: draft.note,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
