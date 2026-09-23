import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/app_settings.dart';
// The generated part file names every enum the tables use, so they have to be in
// scope here even though this file never mentions them directly.
import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/preference_enums.dart';
import '../../domain/enums/recurrence.dart';
import 'converters.dart';
import 'daos/activity_dao.dart';
import 'daos/debts_dao.dart';
import 'daos/obligations_dao.dart';
import 'daos/people_dao.dart';
import 'daos/reminders_dao.dart';
import 'daos/settings_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The local SQLite database.
///
/// Dhimmah is local-first: this file is the source of truth, and every feature
/// works with no network at all. Nothing here knows about widgets, which is what
/// lets the whole data layer be exercised in tests against an in-memory
/// database.
@DriftDatabase(
  tables: <Type>[
    People,
    Debts,
    Payments,
    Obligations,
    ObligationOccurrences,
    Reminders,
    ActivityEntries,
    MonthlySummaries,
    Settings,
  ],
  daos: <Type>[
    PeopleDao,
    DebtsDao,
    ObligationsDao,
    RemindersDao,
    ActivityDao,
    SettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens the on-device database file.
  factory AppDatabase.open() => AppDatabase(_openConnection());

  /// An in-memory database, used by tests.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  /// 2 added the secondary indexes.
  ///
  /// Version 1 shipped with only primary-key autoindexes, so every foreign-key
  /// lookup scanned a whole table — reading one person's five debts cost 265 ms
  /// at 2,500 debts, and the person page ran that query once per debt.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await into(settings).insert(_seedSettings());
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // One callback covers both directions, so the downgrade is caught here.
          //
          // The file was written by a newer build than this one, so its columns
          // may mean things this code does not know. Opening it optimistically
          // would fail later, somewhere confusing; drift's default throws a
          // generic Exception that says nothing a person can act on. This one is
          // specific, and the start-up path turns it into a readable message.
          if (from > to) {
            throw DatabaseTooNewException(from: from, supported: to);
          }
          // `createAll` emits CREATE TABLE/INDEX IF NOT EXISTS, so on an existing
          // database it adds exactly what is missing and touches no data. That
          // matters: the alternative — recreating a table to change its shape —
          // fails on any row that violates the new definition, and a ledger that
          // refuses to open is worse than a slow one. Indexes are additive, so
          // there is nothing to repair and nothing to lose.
          if (from < 2) await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          // Required for the ON DELETE actions declared on the tables.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Writes the default settings row.
  static SettingsCompanion _seedSettings() {
    const AppSettings defaults = AppSettings.initial;
    return SettingsCompanion.insert(
      id: const Value<int>(Settings.singletonId),
      language: defaults.language,
      themeMode: defaults.themeMode,
      numerals: defaults.numerals,
      defaultCurrencyCode: defaults.defaultCurrency.code,
      notificationsEnabled: Value<bool>(defaults.notificationsEnabled),
      notificationHour: Value<int>(defaults.notificationHour),
      notificationMinute: Value<int>(defaults.notificationMinute),
      defaultReminderLeads: Value<List<ReminderLead>>(
        defaults.defaultReminderLeads,
      ),
      monthEndSummaryEnabled: Value<bool>(defaults.monthEndSummaryEnabled),
      monthEndDay: defaults.monthEndDay,
      monthEndHour: Value<int>(defaults.monthEndHour),
      monthEndMinute: Value<int>(defaults.monthEndMinute),
      dueSoonWindowDays: Value<int>(defaults.dueSoonWindowDays),
      lockEnabled: Value<bool>(defaults.lockEnabled),
      biometricEnabled: Value<bool>(defaults.biometricEnabled),
      onboardingCompleted: Value<bool>(defaults.onboardingCompleted),
    );
  }

  /// Wipes every user row. Used by "delete all data" in Settings.
  Future<void> clearAllData() {
    return transaction(() async {
      await delete(activityEntries).go();
      await delete(payments).go();
      await delete(obligationOccurrences).go();
      await delete(obligations).go();
      await delete(debts).go();
      await delete(reminders).go();
      await delete(monthlySummaries).go();
      await delete(people).go();
    });
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File(p.join(dir.path, 'dhimmah.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

/// Thrown when the database on disk was written by a newer build of Dhimmah.
///
/// Reachable in the real world: an app-update rollback, a restored backup, or a
/// second device that is ahead. It is deliberately a *typed* failure so the
/// start-up path can say what happened instead of showing a stack trace, and it
/// is thrown before anything is written — the user's records are untouched.
class DatabaseTooNewException implements Exception {
  const DatabaseTooNewException({required this.from, required this.supported});

  /// The schema version found in the file.
  final int from;

  /// The schema version this build understands.
  final int supported;

  @override
  String toString() =>
      'DatabaseTooNewException(file=$from, supported=$supported)';
}
