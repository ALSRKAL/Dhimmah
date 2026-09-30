import 'dart:io';

import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:drift/drift.dart' show QueryRow;
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
  /// auto-backup switch to settings, and version 5 changed no column — it made
  /// `system` a stored language — so a version 4 file is this schema with the
  /// version set back. The tables are otherwise identical, which is exactly what
  /// makes this a faithful fixture rather than a hand-written approximation of
  /// one.
  Future<void> downgrade(AppDatabase db, int version) async {
    await db.customStatement('DROP TABLE debt_people');
    await db.customStatement('DROP INDEX IF EXISTS idx_debt_people_person');
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
