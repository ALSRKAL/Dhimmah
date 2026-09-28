import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a backup and a restore cost at scale.
///
/// Print only, on purpose: the numbers are the evidence, and a threshold in a
/// test that seeds sixty thousand rows measures the machine more than the app.
///
///   flutter test test/tool/backup_profile_test.dart --dart-define=people=500 --dart-define=debts=5
///   flutter test test/tool/backup_profile_test.dart --dart-define=people=1000 --dart-define=debts=10
const int peopleCount = int.fromEnvironment('people', defaultValue: 500);
const int debtsPerPerson = int.fromEnvironment('debts', defaultValue: 5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup and restore at scale', timeout: const Timeout(Duration(minutes: 20)), () async {
    final Directory dir = await Directory.systemTemp.createTemp('dhimmah-backup-profile');
    final AppDatabase db = AppDatabase.memory();
    final DateTime today = dateOnly(DateTime.now());

    await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
          for (int i = 0; i < peopleCount; i++)
            PeopleCompanion.insert(
              id: 'p$i',
              name: 'شخص رقم $i',
              createdAt: today,
              updatedAt: today,
            ),
        ]));
    final List<DebtsCompanion> debts = <DebtsCompanion>[
      for (int p = 0; p < peopleCount; p++)
        for (int d = 0; d < debtsPerPerson; d++)
          DebtsCompanion.insert(
            id: 'd${p}_$d',
            personId: Value<String>('p$p'),
            direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
            title: Value<String>('قرض $d للشخص $p'),
            principalMinor: 100000 + d * 1000,
            currencyCode: AppCurrency.inr.code,
            issuedAt: addDays(today, -100 - d),
            dueAt: Value<DateTime>(addDays(today, d)),
            recurrence: RecurrenceFrequency.none,
            createdAt: today,
            updatedAt: today,
          ),
    ];
    await db.batch((Batch b) => b.insertAll(db.debts, debts));
    await db.batch((Batch b) => b.insertAll(db.debtPeople, <DebtPeopleCompanion>[
          for (final DebtsCompanion d in debts)
            DebtPeopleCompanion.insert(
              debtId: d.id.value,
              personId: d.personId.value!,
              createdAt: today,
            ),
        ]));
    await db.batch((Batch b) => b.insertAll(db.payments, <PaymentsCompanion>[
          for (final DebtsCompanion d in debts)
            for (int k = 0; k < 4; k++)
              PaymentsCompanion.insert(
                id: 'pay${d.id.value}_$k',
                debtId: Value<String>(d.id.value),
                personId: d.personId,
                amountMinor: 5000,
                currencyCode: AppCurrency.inr.code,
                paidAt: addDays(today, -20 + k),
                createdAt: today,
              ),
        ]));

    final BackupService backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    );
    final BackupRestoreService restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: () async {},
    );

    final Stopwatch write = Stopwatch()..start();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    write.stop();
    final int bytes = await written.file.length();

    // The listing, and a full validation — the two reads the UI does.
    final Stopwatch inspect = Stopwatch()..start();
    final bool usable = (await backups.inspect(written.file.path)).isUsable;
    inspect.stop();

    // An empty ledger, then the restore itself.
    await db.transaction(() async {
      await db.delete(db.payments).go();
      await db.delete(db.debtPeople).go();
      await db.delete(db.debts).go();
      await db.delete(db.people).go();
    });
    final Stopwatch restore = Stopwatch()..start();
    final RestoreReport report = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );
    restore.stop();

    // ignore: avoid_print
    print('''
=== BACKUP PROFILE — $peopleCount people / ${debts.length} debts / ${debts.length * 4} payments ===
   file size                : ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB
   create (write + checksum): ${write.elapsedMilliseconds} ms
   inspect (validate+read)  : ${inspect.elapsedMilliseconds} ms (usable: $usable)
   restore (replace)        : ${restore.elapsedMilliseconds} ms
   restored counts          : ${report.counts}''');

    await db.close();
    await dir.delete(recursive: true);
  });
}
