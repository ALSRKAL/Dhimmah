// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'incomes_dao.dart';

// ignore_for_file: type=lint
mixin _$IncomesDaoMixin on DatabaseAccessor<AppDatabase> {
  $IncomesTable get incomes => attachedDatabase.incomes;
  IncomesDaoManager get managers => IncomesDaoManager(this);
}

class IncomesDaoManager {
  final _$IncomesDaoMixin _db;
  IncomesDaoManager(this._db);
  $$IncomesTableTableManager get incomes =>
      $$IncomesTableTableManager(_db.attachedDatabase, _db.incomes);
}
