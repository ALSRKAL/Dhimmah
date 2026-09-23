import 'package:drift/drift.dart';

import '../../../domain/enums/obligation_enums.dart';
import '../app_database.dart';

part 'reminders_dao.g.dart';

/// Queries for user-created reminders.
@DriftAccessor(tables: <Type>[Reminders])
class RemindersDao extends DatabaseAccessor<AppDatabase>
    with _$RemindersDaoMixin {
  RemindersDao(super.db);

  /// Open reminders first, then by due date.
  Stream<List<ReminderRow>> watchAll() {
    return (select(reminders)
          ..orderBy(<OrderingTerm Function($RemindersTable)>[
            (t) => OrderingTerm.asc(t.dueAt),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<ReminderRow>> getAll() => select(reminders).get();

  Stream<ReminderRow?> watchById(String id) =>
      (select(reminders)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<ReminderRow?> getById(String id) =>
      (select(reminders)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Reminders still awaiting action.
  Future<List<ReminderRow>> getOpen() {
    return (select(reminders)
          ..where(
            (t) => t.status.equalsValue(ReminderStatus.upcoming) |
                t.status.equalsValue(ReminderStatus.today) |
                t.status.equalsValue(ReminderStatus.overdue),
          ))
        .get();
  }

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Both matter: without them, clearing a due date, a note or a person
  /// link appears to work and then quietly reverts on the next read.
    Future<void> upsert(ReminderRow row) async {
    await transaction(() async {
      final int changed = await (update(reminders)
            ..where((t) => t.id.equals(row.id)))
          // The companion is written with every value present, so clearing a
          // nullable column actually stores NULL instead of being skipped.
          .write(row.toCompanion(false));
      if (changed == 0) await into(reminders).insert(row);
    });
  }

  Future<void> setStatus(
    String id,
    ReminderStatus status,
    DateTime? completedAt,
    DateTime updatedAt,
  ) {
    return (update(reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(
        status: Value<ReminderStatus>(status),
        completedAt: Value<DateTime?>(completedAt),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  Future<void> setNotificationId(String id, int? notificationId) {
    return (update(reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(notificationId: Value<int?>(notificationId)),
    );
  }

  Future<int> deleteById(String id) =>
      (delete(reminders)..where((t) => t.id.equals(id))).go();
}
