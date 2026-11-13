import 'dart:io';

import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:drift/native.dart';

import 'store_demo_seed.dart';

/// The two files the demo seed writes: the ledger as this build stores it, and
/// the same ledger in the shape of the version 2 schema.
class DemoDatabases {
  const DemoDatabases({required this.current, required this.legacy});

  final File current;

  /// A file written the way a shipped version 2 build left it on a phone.
  final File legacy;
}

/// Writes the demo ledger into [dir], and a version 2 copy beside it.
///
/// One place, used by both the seed tool and the backward-compatibility test.
/// The test used to depend on the tool having been run first and skipped itself
/// when it had not — which made the data-loss gate a no-op on a clean checkout.
/// It now calls this when the file is missing, so it either runs or fails.
Future<DemoDatabases> writeDemoDatabases(Directory dir) async {
  await dir.create(recursive: true);
  final File file = File('${dir.path}/dhimmah.sqlite');
  if (file.existsSync()) await file.delete();

  final AppDatabase db = AppDatabase(NativeDatabase(file));
  await seedStoreDemoData(db, language: AppLanguage.arabic);

  // And a copy in the shape of the *previous* version, which is what the
  // backward-compatibility test opens: a file written by the shipped build
  // before this one, so the migration is exercised with real data rather than
  // only with a synthetic fixture. Everything this build added is removed from
  // the copy and `user_version` is set back, which is exactly what the file on
  // an installed phone looks like.
  final File previous = File('${dir.path}/dhimmah_v2.sqlite');
  if (previous.existsSync()) await previous.delete();
  await db.customStatement('VACUUM INTO ?', <Object?>[previous.path]);
  final AppDatabase old = AppDatabase(NativeDatabase(previous));
  // Everything this build added to the schema, removed from the copy, in the
  // reverse of the order it was introduced. A fixture that kept any of it
  // would fail the migration on "already exists" / "duplicate column" and
  // prove nothing — and `incomes` fails loudest of all, because the version 6
  // step creates the table.
  await old.customStatement('DROP TABLE incomes');
  await old.customStatement('DROP INDEX IF EXISTS idx_incomes_archived');
  await old.customStatement('DROP TABLE debt_people');
  await old.customStatement('DROP INDEX IF EXISTS idx_debt_people_person');
  // Version 4 added the auto-backup switch to settings, so the copy has to
  // lose the column too: a fixture that keeps it would make the migration
  // fail on a duplicate column instead of testing the upgrade.
  await old.customStatement(
    'ALTER TABLE settings DROP COLUMN backup_auto_enabled',
  );
  await old.customStatement('PRAGMA user_version = 2');
  await old.close();

  await db.close();
  return DemoDatabases(current: file, legacy: previous);
}
