import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed settings store, held in a single row.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<AppSettings> watch() =>
      _db.settingsDao.watch().map((Setting row) => row.toEntity());

  @override
  Future<AppSettings> get() async {
    final Setting? row = await _db.settingsDao.get();
    return row?.toEntity() ?? AppSettings.initial;
  }

  @override
  Future<void> save(AppSettings settings) =>
      _db.settingsDao.write(settings.toCompanion());

  @override
  Future<AppSettings> update(
    AppSettings Function(AppSettings current) transform,
  ) {
    // The read and the write share one transaction so two settings screens
    // saving at once cannot clobber each other.
    return _db.transaction(() async {
      final Setting? row = await _db.settingsDao.get();
      final AppSettings current = row?.toEntity() ?? AppSettings.initial;
      final AppSettings next = transform(current);
      await _db.settingsDao.write(next.toCompanion());
      return next;
    });
  }
}
