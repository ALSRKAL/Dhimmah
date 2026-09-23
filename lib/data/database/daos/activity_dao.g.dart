// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_dao.dart';

// ignore_for_file: type=lint
mixin _$ActivityDaoMixin on DatabaseAccessor<AppDatabase> {
  $ActivityEntriesTable get activityEntries => attachedDatabase.activityEntries;
  $MonthlySummariesTable get monthlySummaries =>
      attachedDatabase.monthlySummaries;
  ActivityDaoManager get managers => ActivityDaoManager(this);
}

class ActivityDaoManager {
  final _$ActivityDaoMixin _db;
  ActivityDaoManager(this._db);
  $$ActivityEntriesTableTableManager get activityEntries =>
      $$ActivityEntriesTableTableManager(
        _db.attachedDatabase,
        _db.activityEntries,
      );
  $$MonthlySummariesTableTableManager get monthlySummaries =>
      $$MonthlySummariesTableTableManager(
        _db.attachedDatabase,
        _db.monthlySummaries,
      );
}
