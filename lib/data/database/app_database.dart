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
    DebtPeople,
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
  ///
  /// 3 added [DebtPeople], so one debt can belong to several people. Existing
  /// single-person debts keep their person: the upgrade copies every non-null
  /// `debts.person_id` into a link row, which is the only statement in the
  /// whole migration that touches data at all.
  ///
  /// 5 made the language a preference: `system` joined `arabic` and `english`.
  /// No column changed, but the version had to: a build from before it would
  /// read `system` as an unknown enum value and fail somewhere confusing, where
  /// the version check refuses the file with a message that says why.
  @override
  int get schemaVersion => currentSchemaVersion;

  /// The schema this build writes. Named as a constant so a test can assert
  /// "a file from the future is refused" without repeating the number, and so a
  /// later version has exactly one place to change.
  static const int currentSchemaVersion = 5;

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
          // Every step after version 1 is additive and idempotent, and is
          // applied in one pass in the order it was introduced: the new table,
          // then any index the file is missing, then the data that belongs in
          // it. `createAll` is deliberately not used here — drift's CREATE
          // INDEX is not conditional, so a file that already has the indexes
          // fails on a second run, which is how an upgrade from version 1 used
          // to end with "no such table" half way through.
          if (from < 3) {
            await m.createTable(debtPeople);
            await _ensureIndexes();
            await _backfillDebtPeople();
          }
          if (from < 4) {
            // One column, with a default, so every existing row keeps working
            // and the switch starts on — the state a new install gets.
            await m.addColumn(settings, settings.backupAutoEnabled);
          }
          if (from < 5) {
            await _followDeviceInsteadOfSeededArabic();
          }
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
      languagePreference: defaults.languagePreference,
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

  /// Creates every index the schema declares, if the file does not have it.
  ///
  /// The statements come from the generated schema, with `IF NOT EXISTS` added:
  /// drift emits a plain `CREATE INDEX`, which is the right thing for a fresh
  /// file and the wrong thing for an upgrade that may already have one.
  Future<void> _ensureIndexes() async {
    for (final DatabaseSchemaEntity entity in allSchemaEntities) {
      if (entity is! Index) continue;
      final String? sql = entity.createStatementsByDialect[SqlDialect.sqlite];
      if (sql == null) continue;
      await customStatement(
        sql.replaceFirst('CREATE INDEX ', 'CREATE INDEX IF NOT EXISTS '),
      );
    }
  }

  /// Gives every existing single-person debt its link row.
  ///
  /// Run inside the migration transaction, so a failure leaves the file exactly
  /// as it was. `INSERT OR IGNORE` makes it safe to run against a database that
  /// already has links — a half-applied upgrade, or a file written by a build
  /// that got this far and stopped — because the pair is the primary key.
  Future<void> _backfillDebtPeople() async {
    await customStatement('''
      INSERT OR IGNORE INTO debt_people (debt_id, person_id, position, created_at)
      SELECT id, person_id, 0, CAST(strftime('%s', 'now') AS INTEGER) * 1000
      FROM debts
      WHERE person_id IS NOT NULL
    ''');
  }

  /// Hands the language back to the phone wherever nobody chose one.
  ///
  /// Before version 5 every install was seeded with Arabic and the phone was
  /// never asked, so a stored `arabic` says what the app assumed rather than
  /// what the person picked — and skipping onboarding stored it too. It becomes
  /// "follow the phone", onboarded or not: an Arabic phone stays in Arabic, and
  /// any other phone gets the language it is in, which is what the app would
  /// have done had it been installed today. A stored `english` was always a
  /// choice — nothing but a tap ever wrote it — and is kept.
  ///
  /// It changes this one column and nothing else.
  Future<void> _followDeviceInsteadOfSeededArabic() async {
    await (update(settings)
          ..where(
            ($SettingsTable t) =>
                t.languagePreference.equalsValue(LanguagePreference.arabic),
          ))
        .write(
      const SettingsCompanion(
        languagePreference: Value<LanguagePreference>(LanguagePreference.system),
      ),
    );
  }

  /// Wipes every user row. Used by "delete all data" in Settings.
  Future<void> clearAllData() {
    return transaction(() async {
      await delete(activityEntries).go();
      await delete(payments).go();
      await delete(debtPeople).go();
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
