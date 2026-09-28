import 'dart:io';

import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/store_demo_seed.dart';

/// Writes a populated database to a file, for reviewing the app's screens with
/// real data in them. Not part of the normal test run.
///
/// The dataset itself lives in `test/support/store_demo_seed.dart`, shared with
/// the store-capture integration test so both photograph the same ledger.
///
///   flutter test test/tool/seed_demo_data_test.dart
///   adb push build/demo/dhimmah.sqlite /data/local/tmp/
///
void main() {
  test('writes a demo database', () async {
    final Directory dir = Directory('build/demo');
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
    // ignore: avoid_print
    print('SEEDED ${file.path}');
    // ignore: avoid_print
    print('SEEDED ${previous.path} (as version 2)');
  });
}
