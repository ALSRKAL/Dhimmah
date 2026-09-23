// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'obligations_dao.dart';

// ignore_for_file: type=lint
mixin _$ObligationsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ObligationsTable get obligations => attachedDatabase.obligations;
  $ObligationOccurrencesTable get obligationOccurrences =>
      attachedDatabase.obligationOccurrences;
  ObligationsDaoManager get managers => ObligationsDaoManager(this);
}

class ObligationsDaoManager {
  final _$ObligationsDaoMixin _db;
  ObligationsDaoManager(this._db);
  $$ObligationsTableTableManager get obligations =>
      $$ObligationsTableTableManager(_db.attachedDatabase, _db.obligations);
  $$ObligationOccurrencesTableTableManager get obligationOccurrences =>
      $$ObligationOccurrencesTableTableManager(
        _db.attachedDatabase,
        _db.obligationOccurrences,
      );
}
