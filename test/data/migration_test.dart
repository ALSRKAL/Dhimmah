import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/income_repository_impl.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/enums/activity_enums.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:drift/drift.dart' show QueryRow, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upgrading a ledger that already exists.
///
/// The file on a user's phone is the only copy of their records, so a migration
/// is judged by what it does *not* touch. These tests build real databases in the
/// shape of each version the app has shipped — the tables are this schema's own,
/// with the later additions removed and `user_version` set back — then open them
/// with the current code and read every row back.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dhimmah-migration');
  });
  tearDown(() async => temp.delete(recursive: true));

  final DateTime today = dateOnly(DateTime.now());

  /// Sets a file's `user_version` back and removes what later versions added.
  ///
  /// Version 2 added indexes, version 3 added `debt_people`, version 4 added the
  /// auto-backup switch to settings, version 5 changed no column — it made
  /// `system` a stored language — and version 6 added `incomes`. The tables are
  /// otherwise identical, which is exactly what makes this a faithful fixture
  /// rather than a hand-written approximation of one.
  ///
  /// Every removal is conditional on the version that introduced the object, so
  /// the fixture is the shape a phone at that version would really hold. Dropping
  /// `debt_people` unconditionally used to build a version 4 file that no phone
  /// ever had — one missing the link table — and because `from < 3` is false at
  /// version 4 the upgrade never recreated it, so the file reached
  /// `user_version = 5` without the table. The version 4 assertions were about
  /// settings and language, so they passed regardless.
  ///
  /// The same trap waits on `incomes`, and it fails louder: the version 6 step
  /// *creates* the table, so a fixture that still had it would stop the upgrade
  /// on "table incomes already exists" rather than passing quietly.
  Future<void> downgrade(AppDatabase db, int version) async {
    if (version < 6) {
      await db.customStatement('DROP TABLE incomes');
      await db.customStatement('DROP INDEX IF EXISTS idx_incomes_archived');
    }
    if (version < 3) {
      await db.customStatement('DROP TABLE debt_people');
      await db.customStatement('DROP INDEX IF EXISTS idx_debt_people_person');
    }
    if (version < 4) {
      await db.customStatement(
        'ALTER TABLE settings DROP COLUMN backup_auto_enabled',
      );
    }
    if (version < 2) {
      final List<QueryRow> indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
          )
          .get();
      for (final QueryRow row in indexes) {
        await db.customStatement('DROP INDEX ${row.read<String>('name')}');
      }
    }
    await db.customStatement('PRAGMA user_version = $version');
  }

  /// A file with three people, two debts (one paid), a payment and settings.
  Future<void> seed(AppDatabase db) async {
    await db.peopleDao.upsert(
      PersonRow(
        id: 'p1',
        name: 'أحمد',
        phone: '+967771234567',
        colorIndex: 0,
        createdAt: today,
        updatedAt: today,
      ),
    );
    await db.peopleDao.upsert(
      PersonRow(
        id: 'p2',
        name: 'علي',
        colorIndex: 1,
        createdAt: today,
        updatedAt: today,
      ),
    );
    for (final (String id, String person, int amount) in <(String, String, int)>[
      ('d1', 'p1', 150000),
      ('d2', 'p2', 250000),
    ]) {
      await db.debtsDao.upsert(
        DebtRow(
          id: id,
          personId: person,
          direction: DebtDirection.iOwe,
          title: 'قرض $id',
          principalMinor: amount,
          currencyCode: 'INR',
          issuedAt: today,
          dueAt: addDays(today, 10),
          note: 'ملاحظة $id',
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
          recurrence: RecurrenceFrequency.none,
          recurrenceInterval: 0,
          createdAt: today,
          updatedAt: today,
        ),
        personIds: <String>[person],
      );
    }
    await db.debtsDao.upsertPayment(
      PaymentRow(
        id: 'pay1',
        debtId: 'd1',
        personId: 'p1',
        amountMinor: 50000,
        currencyCode: 'INR',
        paidAt: today,
        note: 'دفعة',
        createdAt: today,
      ),
    );
    await db.customStatement(
      "UPDATE debts SET closed_at = ${today.millisecondsSinceEpoch} WHERE id = 'd2'",
    );
  }

  /// Opens a file, seeds it, writes it back as an older version, and closes it.
  Future<File> oldDatabase(int version) async {
    final File file = File('${temp.path}/v$version.sqlite');
    final AppDatabase db = AppDatabase(NativeDatabase(file));
    await seed(db);
    await downgrade(db, version);
    await db.close();
    return file;
  }

  Future<AppDatabase> open(File file) async {
    final AppDatabase db = AppDatabase(NativeDatabase(file));
    // Touching a table forces the migration to run before anything else is read.
    await db.peopleDao.getAll();
    return db;
  }

  group('a version 2 file upgrading to the current schema', () {
    test('keeps every record and gives each debt its person', () async {
      final File file = await oldDatabase(2);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      expect((await db.peopleDao.getAll()).map((PersonRow p) => p.name),
          <String>['أحمد', 'علي']);
      expect((await db.debtsDao.getAll()), hasLength(2));

      final Map<String, List<String>> links = await db.debtsDao.allParticipants();
      expect(links['d1'], <String>['p1']);
      expect(links['d2'], <String>['p2']);

      // The mirror column still agrees with what it mirrors.
      for (final DebtRow row in await db.debtsDao.getAll()) {
        expect(row.personId, links[row.id]!.first);
      }

      // And the records still read as they did, through the current model.
      final List<Debt> debts = await DebtRepositoryImpl(db).getAll();
      expect(debts.firstWhere((Debt d) => d.id == 'd1').personIds,
          <String>['p1']);
      expect(debts.firstWhere((Debt d) => d.id == 'd1').note, 'ملاحظة d1');
      expect((await db.debtsDao.getPaymentsForDebt('d1')), hasLength(1));
    });

    test('is safe to run twice', () async {
      final File file = await oldDatabase(2);

      final AppDatabase first = await open(file);
      await first.close();
      // The second open sees version 3 and runs no migration at all; the third
      // guard is the data itself, which must be unchanged.
      final AppDatabase second = await open(file);
      addTearDown(second.close);

      expect(await second.debtsDao.allParticipants(), hasLength(2));
      expect((await second.debtsDao.getAll()), hasLength(2));
    });

    test('leaves a debt nobody is on alone', () async {
      final File file = File('${temp.path}/unlinked.sqlite');
      final AppDatabase seedDb = AppDatabase(NativeDatabase(file));
      await seed(seedDb);
      // A record from before people were required, written directly so the
      // current rule cannot refuse it.
      await seedDb.debtsDao.upsert(
        DebtRow(
          id: 'd3',
          direction: DebtDirection.owedToMe,
          title: 'قرض البنك',
          principalMinor: 90000,
          currencyCode: 'INR',
          issuedAt: today,
          reminderLeads: const <ReminderLead>[],
          recurrence: RecurrenceFrequency.none,
          recurrenceInterval: 0,
          createdAt: today,
          updatedAt: today,
        ),
      );
      await downgrade(seedDb, 2);
      await seedDb.close();

      final AppDatabase db = await open(file);
      addTearDown(db.close);

      expect(await db.debtsDao.participantsFor('d3'), isEmpty);
      expect((await db.debtsDao.getById('d3'))!.personId, isNull);
      final Debt bankDebt = (await DebtRepositoryImpl(db).getAll())
          .firstWhere((Debt d) => d.id == 'd3');
      expect(bankDebt.personIds, isEmpty);
      expect(bankDebt.title, 'قرض البنك', reason: 'still readable');
    });
  });

  group('a version 3 or 4 file, which already has the link table', () {
    // `from < 3` is false for both, so the upgrade creates nothing: it must
    // leave the link table exactly as the old build left it. Before `downgrade()`
    // was made conditional these fixtures had the table dropped and never
    // recreated, so nothing here was actually being proved.
    for (final int version in <int>[3, 4]) {
      test('version $version keeps every link row it was holding', () async {
        final File file = await oldDatabase(version);
        final AppDatabase db = await open(file);
        addTearDown(db.close);

        final Map<String, List<String>> links =
            await db.debtsDao.allParticipants();
        expect(links['d1'], <String>['p1']);
        expect(links['d2'], <String>['p2']);
        expect(await db.debtsDao.allParticipantRows(), hasLength(2));

        // And the records still read the same through the current model.
        final List<Debt> debts = await DebtRepositoryImpl(db).getAll();
        final Debt d1 = debts.firstWhere((Debt d) => d.id == 'd1');
        expect(d1.personIds, <String>['p1']);
        expect(d1.principalMinor, 150000);
        expect(d1.note, 'ملاحظة d1');
        expect(await db.debtsDao.getPaymentsForDebt('d1'), hasLength(1));
      });
    }

    test('the index on the link table is still in place after version 4',
        () async {
      final File file = await oldDatabase(4);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      final List<QueryRow> indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND tbl_name = 'debt_people'",
          )
          .get();
      expect(
        indexes.map((QueryRow row) => row.read<String>('name')),
        contains('idx_debt_people_person'),
        reason: 'a version 4 file shipped with this index; an upgrade must not drop it',
      );
    });

    test('version 3 also gains the column and the language it was missing',
        () async {
      final File file = await oldDatabase(3);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      // `from < 4` added this column, and `from < 5` moved the language on.
      final List<QueryRow> columns = await db
          .customSelect('PRAGMA table_info(settings)')
          .get();
      expect(
        columns.map((QueryRow row) => row.read<String>('name')),
        contains('backup_auto_enabled'),
      );
      final Setting settings = (await db.settingsDao.get())!;
      expect(settings.backupAutoEnabled, isNotNull);
      expect(settings.languagePreference, LanguagePreference.system);
    });
  });

  group('a version 1 file upgrading to the current schema', () {
    test('recreates the indexes, adds the link table and keeps the data', () async {
      final File file = await oldDatabase(1);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      final List<QueryRow> indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
          )
          .get();
      final Set<String> names = <String>{
        for (final QueryRow row in indexes) row.read<String>('name'),
      };
      expect(names, contains('idx_debts_person'));
      expect(names, contains('idx_payments_debt'));
      expect(names, contains('idx_debt_people_person'));

      expect(await db.debtsDao.allParticipants(), hasLength(2));
      expect((await db.debtsDao.getPaymentsForDebt('d1')), hasLength(1));
    });

    test('carries a paid debt’s closing stamp across', () async {
      final File file = await oldDatabase(1);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      final DebtRow paid = (await db.debtsDao.getById('d2'))!;
      expect(paid.closedAt, isNotNull);
      expect(paid.closedAt!.millisecondsSinceEpoch,
          today.millisecondsSinceEpoch);
    });
  });

  group('a version 4 file upgrading to the language preference', () {
    /// A version 4 file whose settings row says [language], onboarded or not.
    Future<File> version4({
      required String language,
      required bool onboarded,
    }) async {
      final File file = File('${temp.path}/v4-$language-$onboarded.sqlite');
      final AppDatabase db = AppDatabase(NativeDatabase(file));
      await seed(db);
      await db.customStatement(
        "UPDATE settings SET language = '$language', "
        'onboarding_completed = ${onboarded ? 1 : 0}',
      );
      await downgrade(db, 4);
      await db.close();
      return file;
    }

    Future<LanguagePreference> preferenceAfterUpgrade(File file) async {
      final AppDatabase db = await open(file);
      addTearDown(db.close);
      return (await db.settingsDao.get())!.languagePreference;
    }

    test('the seeded Arabic follows the phone — finished, skipped or neither',
        () async {
      // Skipping the old onboarding finished it, so "onboarded" covers both;
      // neither says anything about a language, because the phone was never
      // asked and Arabic was simply what every install was given.
      for (final bool onboarded in <bool>[true, false]) {
        expect(
          await preferenceAfterUpgrade(
            await version4(language: 'arabic', onboarded: onboarded),
          ),
          LanguagePreference.system,
          reason: 'onboarded: $onboarded',
        );
      }
    });

    test('an English choice is kept, finished or not', () async {
      // Nothing but a tap ever stored English.
      for (final bool onboarded in <bool>[true, false]) {
        expect(
          await preferenceAfterUpgrade(
            await version4(language: 'english', onboarded: onboarded),
          ),
          LanguagePreference.english,
          reason: 'onboarded: $onboarded',
        );
      }
    });

    test('nothing else in the settings row changes', () async {
      final File file = File('${temp.path}/v4-everything.sqlite');
      final AppDatabase old = AppDatabase(NativeDatabase(file));
      await seed(old);
      await old.customStatement(
        "UPDATE settings SET language = 'arabic', onboarding_completed = 1, "
        "theme_mode = 'dark', numerals = 'arabicIndic', "
        "default_currency_code = 'USD', notification_hour = 7, "
        'lock_enabled = 1, backup_auto_enabled = 0',
      );
      await downgrade(old, 4);
      final Map<String, Object?> before =
          (await old.customSelect('SELECT * FROM settings').getSingle()).data;
      await old.close();

      final AppDatabase db = await open(file);
      addTearDown(db.close);
      final Map<String, Object?> after =
          (await db.customSelect('SELECT * FROM settings').getSingle()).data;
      expect(after, <String, Object?>{...before, 'language': 'system'});
    });

    test('and every record comes through untouched', () async {
      final File file = await version4(language: 'arabic', onboarded: true);
      final AppDatabase db = await open(file);
      addTearDown(db.close);
      expect(await db.peopleDao.getAll(), hasLength(2));
      expect(await db.debtsDao.getAll(), hasLength(2));
      expect(await db.debtsDao.getPaymentsForDebt('d1'), hasLength(1));
      expect((await db.settingsDao.get())!.backupAutoEnabled, isTrue);
    });
  });

  group('a version 5 file upgrading to the income table', () {
    test('the table is created and every earlier record is still there',
        () async {
      final File file = await oldDatabase(5);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      // The new table exists and starts empty: nothing is invented for a user
      // who never recorded an income.
      expect(await db.incomesDao.getAll(), isEmpty);

      // And the ledger that was in the file is untouched.
      expect(await db.peopleDao.getAll(), hasLength(2));
      expect(await db.debtsDao.getAll(), hasLength(2));
      expect(await db.debtsDao.getPaymentsForDebt('d1'), hasLength(1));
      expect(await db.debtsDao.allParticipants(), hasLength(2));
      expect((await db.settingsDao.get())!.backupAutoEnabled, isTrue);
    });

    test('the migrated table takes a row written by the current code', () async {
      // The point of this one is the *shape*: a table created by the version 6
      // step must have every column the DAO writes to. A missed column would
      // make a v6 file unreadable, and only a real write through the repository
      // proves it can hold a real record.
      final File file = await oldDatabase(5);
      final AppDatabase db = await open(file);
      addTearDown(db.close);

      final IncomeRepositoryImpl incomes = IncomeRepositoryImpl(db);
      await incomes.save(
        newIncome(
          draft: IncomeDraft(
            name: 'الراتب الشهري',
            amountMinor: 400000,
            currency: AppCurrency.inr,
            frequency: RecurrenceFrequency.monthly,
            startAt: today,
            dayOfMonth: 25,
            note: 'يُنزل آخر الشهر',
          ),
        ),
      );

      final List<Income> stored = await incomes.getAll();
      expect(stored, hasLength(1));
      final Income income = stored.single;
      expect(income.name, 'الراتب الشهري');
      expect(income.amountMinor, 400000);
      expect(income.currency, AppCurrency.inr);
      expect(income.frequency, RecurrenceFrequency.monthly);
      expect(income.dayOfMonth, 25);
      expect(income.note, 'يُنزل آخر الشهر');
      expect(income.archivedAt, isNull);

      // Archiving keeps the row and stamps the day, which is what lets a month
      // an income covered go on reading correctly after it stops.
      await incomes.setArchived(income.id, archived: true);
      expect(await incomes.getAll(), hasLength(1));
      expect((await incomes.getAll()).single.archivedAt, isNotNull);
      expect(await incomes.getAll(includeArchived: false), isEmpty);

      // And deleting it removes only that row.
      await incomes.delete(income.id);
      expect(await incomes.getAll(), isEmpty);
      expect(await db.peopleDao.getAll(), hasLength(2));
      expect(await db.debtsDao.getAll(), hasLength(2));
    });

    test('a version 4 file gets the language rule and the new table together',
        () async {
      // A file at 4 has two steps to travel in one pass. This is the case the
      // reordering of `_ensureIndexes` had to survive: the version 5 data rule
      // and the version 6 table both have to run, and neither may be skipped
      // because the file is jumping two versions at once.
      final File file = File('${temp.path}/v4-two-steps.sqlite');
      final AppDatabase db = AppDatabase(NativeDatabase(file));
      await seed(db);
      await db.customStatement(
        "UPDATE settings SET language = 'arabic', onboarding_completed = 1",
      );
      await downgrade(db, 4);
      await db.close();

      final AppDatabase upgraded = await open(file);
      addTearDown(upgraded.close);

      // The version 5 rule ran: the seeded Arabic became "follow the phone".
      expect(
        (await upgraded.settingsDao.get())!.languagePreference,
        LanguagePreference.system,
      );
      // And the version 6 step ran too.
      expect(await upgraded.incomesDao.getAll(), isEmpty);
      expect(await upgraded.peopleDao.getAll(), hasLength(2));
      expect(await upgraded.debtsDao.getAll(), hasLength(2));
    });

    test('a file already at version 5 keeps a stored language', () async {
      // The version 5 rule must *not* run again: at 5 a stored language is a
      // choice the user made, not the seed every install started with.
      final File file = File('${temp.path}/v5-language.sqlite');
      final AppDatabase db = AppDatabase(NativeDatabase(file));
      await seed(db);
      await db.customStatement(
        "UPDATE settings SET language = 'arabic', onboarding_completed = 1",
      );
      await downgrade(db, 5);
      await db.close();

      final AppDatabase upgraded = await open(file);
      addTearDown(upgraded.close);
      expect(
        (await upgraded.settingsDao.get())!.languagePreference,
        LanguagePreference.arabic,
      );
    });
  });

  // --- The whole file, row for row ------------------------------------------
  //
  // The groups above check that the records they name came through. This one
  // makes the stronger claim none of them can: that *nothing* in the file
  // changed except what the version it is upgrading to was meant to add. It
  // reads every table before and after, compares the rows column by column, and
  // recomputes the balances from the rows themselves instead of reading a field
  // back and believing it.
  //
  // It also fills the coverage `AGENTS.md` §4.3 records as missing: `seed()`
  // writes people, debts, links, payments and settings, and leaves
  // `obligations`, `obligation_occurrences`, `reminders`, `activity_entries` and
  // `monthly_summaries` untested across a version bump. Those tables have never
  // changed shape, which is what made that survivable — and this is the test
  // that has to exist before one of them does.
  group('every version arrives whole', () {
    /// A fixture that fills every table a file can hold.
    ///
    /// Built on the ledger the groups above read, so a failure here and a
    /// failure there are about the same records, and written through the same
    /// tables the app writes through — `downgrade()` then takes away whatever
    /// the version being aimed at had not been given yet.
    Future<void> fillEveryTable(AppDatabase db) async {
      await seed(db);

      await db.into(db.obligations).insert(
            ObligationRow(
              id: 'o1',
              name: 'إيجار',
              category: ObligationCategory.housing,
              amountMinor: 300000,
              currencyCode: 'INR',
              frequency: RecurrenceFrequency.monthly,
              intervalCount: 1,
              dayOfMonth: 5,
              startAt: today,
              nextDueAt: addDays(today, 5),
              reminderLeads: const <ReminderLead>[ReminderLead.threeDaysBefore],
              createdAt: today,
              updatedAt: today,
            ),
          );
      await db.obligationsDao.upsertOccurrence(
        ObligationOccurrenceRow(
          id: 'oc1',
          obligationId: 'o1',
          periodKey: 'first',
          dueAt: addDays(today, 5),
          amountMinor: 300000,
          status: ObligationStatus.upcoming,
          createdAt: today,
          updatedAt: today,
        ),
      );
      await db.incomesDao.upsert(
        IncomeRow(
          id: 'i1',
          name: 'راتب',
          amountMinor: 900000,
          currencyCode: 'INR',
          frequency: RecurrenceFrequency.monthly,
          intervalCount: 1,
          dayOfMonth: 1,
          startAt: today,
          createdAt: today,
          updatedAt: today,
        ),
      );
      await db.into(db.reminders).insert(
            ReminderRow(
              id: 'r1',
              title: 'تذكير',
              dueAt: addDays(today, 3),
              relatedType: RelatedEntityType.debt,
              relatedId: 'd1',
              status: ReminderStatus.upcoming,
              createdAt: today,
              updatedAt: today,
            ),
          );
      await db.activityDao.insert(
        ActivityEntryRow(
          id: 'a1',
          type: ActivityType.debtCreated,
          entityType: RelatedEntityType.debt,
          entityId: 'd1',
          title: 'أُنشئ دين',
          amountMinor: 150000,
          currencyCode: 'INR',
          occurredAt: today,
        ),
      );
      await db.into(db.monthlySummaries).insert(
            MonthlySummaryRow(
              id: 'sm1',
              year: today.year,
              month: today.month,
              currencyCode: 'INR',
              newDebtMinor: 150000,
              settledMinor: 0,
              receivedMinor: 0,
              paidOutMinor: 50000,
              obligationsMinor: 300000,
              overdueMinor: 0,
              peopleCount: 2,
              closedDebts: 1,
              activeDebts: 1,
              generatedAt: today,
            ),
          );
      // A stored preference that is *not* the default, so an upgrade that
      // rewrote the settings row would be visible here rather than coincidentally
      // reading the same because the default happens to match.
      await db.settingsDao.write(
        const SettingsCompanion(dueSoonWindowDays: Value<int>(9)),
      );
    }

    /// Every row of every table the file actually holds.
    ///
    /// `SELECT *` on purpose: a file at an older version is missing columns this
    /// code knows about — that is what "older" means — so a read through the
    /// generated tables would fail on a file the app must be able to upgrade.
    ///
    /// The statements are literal rather than assembled from a table name.
    /// SQLite cannot bind an identifier, so building one would be the single
    /// place in this suite where a statement is put together from a string; the
    /// tables are the schema's own fixed list, so there is nothing to build and
    /// eleven literal reads say exactly what is covered.
    Future<Map<String, List<Map<String, Object?>>>> readFile(
      AppDatabase db,
    ) async {
      const Map<String, String> reads = <String, String>{
        'people': 'SELECT * FROM people',
        'debts': 'SELECT * FROM debts',
        'debt_people': 'SELECT * FROM debt_people',
        'payments': 'SELECT * FROM payments',
        'obligations': 'SELECT * FROM obligations',
        'obligation_occurrences': 'SELECT * FROM obligation_occurrences',
        'incomes': 'SELECT * FROM incomes',
        'reminders': 'SELECT * FROM reminders',
        'activity_entries': 'SELECT * FROM activity_entries',
        'monthly_summaries': 'SELECT * FROM monthly_summaries',
        'settings': 'SELECT * FROM settings',
      };

      // A table the version did not have yet is *absent*, not empty: dropping
      // `incomes` from a version 5 file leaves no table behind at all.
      final Set<String> present = <String>{
        for (final QueryRow row in await db
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get())
          row.read<String>('name'),
      };

      final Map<String, List<Map<String, Object?>>> out =
          <String, List<Map<String, Object?>>>{};
      for (final MapEntry<String, String> read in reads.entries) {
        if (!present.contains(read.key)) continue;
        final List<QueryRow> rows = await db.customSelect(read.value).get();
        out[read.key] = <Map<String, Object?>>[
          for (final QueryRow row in rows) row.data,
        ];
      }
      return out;
    }

    /// One row as a comparable string, projected onto [only].
    ///
    /// Columns are sorted, so two reads of the same row are the same text
    /// whatever order SQLite hands the columns back in — and projecting is what
    /// lets a row be compared with itself across a version that added a column
    /// to its table, without that addition counting as a change.
    String canonical(Map<String, Object?> row, Set<String> only) {
      final List<String> keys = <String>[
        for (final String key in row.keys)
          if (only.contains(key)) key,
      ]..sort();
      return '{${<String>[for (final String key in keys) '$key=${row[key]}'].join(' ~ ')}}';
    }

    /// A table's rows, projected and ordered, so two reads compare as lists.
    List<String> project(
      List<Map<String, Object?>> rows,
      Set<String> columns,
    ) {
      final List<String> out = <String>[
        for (final Map<String, Object?> row in rows) canonical(row, columns),
      ];
      out.sort();
      return out;
    }

    /// The columns a table holds, read off its rows.
    Set<String> columnsOf(List<Map<String, Object?>> rows) =>
        <String>{for (final Map<String, Object?> row in rows) ...row.keys};

    /// What is still owed on every debt, added up from the rows themselves.
    ///
    /// principal − everything paid against it. Recomputed rather than read from
    /// a field, so this is a second opinion about the money and not a restatement
    /// of the same read.
    Map<String, int> remainingByDebt(
      Map<String, List<Map<String, Object?>>> file,
    ) {
      final Map<String, int> out = <String, int>{};
      for (final Map<String, Object?> debt in file['debts']!) {
        out['${debt['id']}'] = debt['principal_minor']! as int;
      }
      for (final Map<String, Object?> payment
          in file['payments'] ?? const <Map<String, Object?>>[]) {
        final Object? debtId = payment['debt_id'];
        if (debtId is! String) continue;
        out[debtId] = (out[debtId] ?? 0) - (payment['amount_minor']! as int);
      }
      return out;
    }

    /// The ledger's own balance per direction and currency.
    Map<String, int> totals(
      Map<String, List<Map<String, Object?>>> file,
    ) {
      final Map<String, int> owed = remainingByDebt(file);
      final Map<String, int> out = <String, int>{};
      for (final Map<String, Object?> debt in file['debts']!) {
        final String key = '${debt['direction']}/${debt['currency_code']}';
        out[key] = (out[key] ?? 0) + owed['${debt['id']}']!;
      }
      return out;
    }

    for (final int version in <int>[1, 2, 3, 4, 5]) {
      test('a version $version file arrives with every row and every balance',
          () async {
        final File file = File('${temp.path}/whole-v$version.sqlite');
        final AppDatabase old = AppDatabase(NativeDatabase(file));
        await fillEveryTable(old);
        await downgrade(old, version);

        // Read while the old file is still open: this connection already ran its
        // migration, so what comes back is the file the old build would have
        // found, not a re-upgraded version of it.
        final Map<String, List<Map<String, Object?>>> before =
            await readFile(old);
        await old.close();

        // Every table this version can hold has a row, or the comparisons below
        // would be about nothing at all. `debt_people` arrived with version 3 and
        // `incomes` with version 6.
        expect(
          before.keys,
          containsAll(<String>[
            'people',
            'debts',
            'payments',
            'obligations',
            'obligation_occurrences',
            'reminders',
            'activity_entries',
            'monthly_summaries',
            'settings',
            if (version >= 3) 'debt_people',
          ]),
          reason: 'the fixture must fill every table a version $version file holds',
        );
        for (final String table in before.keys) {
          expect(before[table], isNotEmpty, reason: '$table was left empty');
        }

        final AppDatabase db = await open(file);
        addTearDown(db.close);
        final Map<String, List<Map<String, Object?>>> after = await readFile(db);

        // The counts the file had are the counts it still has. A table that
        // went missing reads as -1 rather than throwing here, so the failure
        // names the table instead of the line that looked it up.
        expect(
          <String, int>{
            for (final String table in before.keys)
              table: after[table]?.length ?? -1,
          },
          <String, int>{
            for (final String table in before.keys)
              table: before[table]!.length,
          },
          reason: 'an upgrade adds a table, never a row to one that had them',
        );

        for (final String table in before.keys) {
          expect(after.keys, contains(table),
              reason: 'an upgrade drops nothing');
          final List<Map<String, Object?>> was = before[table]!;
          final List<Map<String, Object?>> now = after[table]!;
          final Set<String> wasColumns = columnsOf(was);

          // No column the file had is gone either: an upgrade may add one, never
          // take one away.
          expect(columnsOf(now), containsAll(wasColumns),
              reason: '$table lost a column');

          // And every row still says what it said, in every column it had.
          expect(
            project(now, wasColumns),
            project(was, wasColumns),
            reason: '$table: an upgrade must not rewrite a row it was not asked '
                'to change',
          );
        }

        // The money, recomputed from the rows. A migration may add a table; it
        // may not move a balance by one minor unit.
        expect(remainingByDebt(after), remainingByDebt(before),
            reason: 'a debt balance moved');
        expect(totals(after), totals(before), reason: 'a ledger total moved');
      });
    }
  });

  test('a file written by a newer build is refused, not half-read', () async {
    final File file = File('${temp.path}/future.sqlite');
    final AppDatabase db = AppDatabase(NativeDatabase(file));
    await seed(db);
    await db.customStatement('PRAGMA user_version = 99');
    await db.close();

    final AppDatabase future = AppDatabase(NativeDatabase(file));
    await expectLater(
      () => future.peopleDao.getAll(),
      throwsA(
        isA<DatabaseTooNewException>()
            .having((DatabaseTooNewException e) => e.from, 'from', 99)
            .having(
              (DatabaseTooNewException e) => e.supported,
              'supported',
              AppDatabase.currentSchemaVersion,
            ),
      ),
    );
    await future.close();
  });
}
