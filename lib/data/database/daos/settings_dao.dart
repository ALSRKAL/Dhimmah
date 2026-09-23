import 'package:drift/drift.dart';

import '../app_database.dart';

part 'settings_dao.g.dart';

/// Reads and writes the single settings row.
@DriftAccessor(tables: <Type>[Settings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Stream<Setting> watch() {
    return (select(settings)
          ..where((t) => t.id.equals(Settings.singletonId)))
        .watchSingle();
  }

  Future<Setting?> get() {
    return (select(settings)..where((t) => t.id.equals(Settings.singletonId)))
        .getSingleOrNull();
  }

  /// Writes the whole row. The settings screen always sends a complete object,
  /// so a full write keeps the stored row and the in-memory model identical.
  Future<void> write(SettingsCompanion companion) {
    return (update(settings)..where((t) => t.id.equals(Settings.singletonId)))
        .write(companion);
  }

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Both matter: without them, clearing a due date, a note or a person
  /// link appears to work and then quietly reverts on the next read.
    Future<void> replace(Setting row) async {
    await transaction(() async {
      final int changed = await (update(settings)
            ..where((t) => t.id.equals(row.id)))
          // The companion is written with every value present, so clearing a
          // nullable column actually stores NULL instead of being skipped.
          .write(row.toCompanion(false));
      if (changed == 0) await into(settings).insert(row);
    });
  }
}
