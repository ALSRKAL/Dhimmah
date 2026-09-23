import '../../core/utils/id_generator.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/repositories.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';

/// SQLite-backed people directory.
class PersonRepositoryImpl implements PersonRepository {
  PersonRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Person>> watchAll() =>
      _db.peopleDao.watchAll().map(_toEntities);

  @override
  Future<List<Person>> getAll() async =>
      _toEntities(await _db.peopleDao.getAll());

  @override
  Future<Person?> getById(String id) async =>
      (await _db.peopleDao.getById(id))?.toEntity();

  @override
  Future<Person?> findByName(String name) async =>
      (await _db.peopleDao.findByName(name))?.toEntity();

  @override
  Stream<Person?> watchById(String id) =>
      _db.peopleDao.watchById(id).map((PersonRow? row) => row?.toEntity());

  @override
  Future<void> save(Person person) => _db.peopleDao.upsert(person.toRow());

  @override
  Future<void> setArchived(String id, {required bool archived}) {
    return _db.peopleDao.setArchived(
      id,
      archived ? DateTime.now() : null,
      DateTime.now(),
    );
  }

  @override
  Future<void> delete(String id) => _db.peopleDao.deleteById(id);

  @override
  Future<int> countActive() => _db.peopleDao.countActive();

  static List<Person> _toEntities(List<PersonRow> rows) =>
      rows.map((PersonRow row) => row.toEntity()).toList(growable: false);
}

/// Convenience for building a fresh person record.
Person newPerson({
  required String name,
  String? phone,
  String? note,
  int colorIndex = 0,
  DateTime? now,
}) {
  final DateTime timestamp = now ?? DateTime.now();
  return Person(
    id: newId(),
    name: name.trim(),
    phone: phone,
    note: note,
    colorIndex: colorIndex,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
