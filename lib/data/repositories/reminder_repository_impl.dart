import '../../core/utils/dates.dart';
import '../../core/utils/id_generator.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed reminder store.
class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Reminder>> watchAll() =>
      _db.remindersDao.watchAll().map(_toEntities);

  @override
  Future<List<Reminder>> getAll() async =>
      _toEntities(await _db.remindersDao.getAll());

  @override
  Future<List<Reminder>> getOpen() async =>
      _toEntities(await _db.remindersDao.getOpen());

  @override
  Future<Reminder?> getById(String id) async =>
      (await _db.remindersDao.getById(id))?.toEntity();

  @override
  Stream<Reminder?> watchById(String id) =>
      _db.remindersDao.watchById(id).map((ReminderRow? r) => r?.toEntity());

  @override
  Future<void> save(Reminder reminder) =>
      _db.remindersDao.upsert(reminder.toRow());

  @override
  Future<void> setStatus(
    String id,
    ReminderStatus status, {
    DateTime? completedAt,
  }) {
    return _db.remindersDao.setStatus(
      id,
      status,
      completedAt,
      DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) => _db.remindersDao.deleteById(id);

  static List<Reminder> _toEntities(List<ReminderRow> rows) =>
      rows.map((ReminderRow row) => row.toEntity()).toList(growable: false);
}

/// Builds a fresh reminder.
Reminder newReminder({
  required String title,
  required DateTime dueAt,
  String? note,
  RelatedEntityType relatedType = RelatedEntityType.none,
  String? relatedId,
  DateTime? now,
}) {
  final DateTime timestamp = now ?? DateTime.now();
  final DateTime due = dateOnly(dueAt);
  return Reminder(
    id: newId(),
    title: title.trim(),
    note: note,
    dueAt: due,
    relatedType: relatedType,
    relatedId: relatedId,
    status: ReminderStatus.upcoming,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
