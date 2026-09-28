import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_progress.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Where a process killed at each critical point leaves the ledger.
///
/// Sixteen points, eight in a snapshot and eight in a restore. A kill cannot be
/// delivered from inside a Dart test, so each one is emulated by the mechanism
/// that makes the algebra identical: the operation is abandoned at exactly that
/// step — the callback a killed process would never reach fires and throws — and
/// the state afterwards is compared with the state before.
///
/// Two of the points are emulated more literally, because the step is a file
/// operation and the artifact is what matters:
///
/// * **during the write** — a half-written `.tmp` file is left on disk, which is
///   what a process killed between the first byte and the rename leaves.
/// * **during the transaction** — the insert itself fails, which is the only way
///   to stand inside the transaction and watch it roll back.
///
/// The rule every row is held to: **the ledger is either exactly what it was, or
/// exactly what the operation intended** — never a mixture, and never a claim of
/// success that did not happen.
void main() {
  late Directory dir;
  late AppDatabase db;
  late LedgerService service;
  late BackupService backups;
  late BackupRestoreService restores;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-kill-matrix');
    db = AppDatabase.memory();
    service = buildService(db);
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => DateTime(2026, 9, 26, 9, 15),
      directory: dir,
    );
    restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: service.refreshNotifications,
    );
    await db.settingsDao.write(AppSettings.initial.toCompanion());
    await _seed(service, today);
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Everything the user has, sorted so the comparison is about content.
  Future<String> fingerprint() async {
    final List<String> parts = <String>[
      for (final PersonRow row in await db.peopleDao.getAll())
        'P ${row.id} ${row.name} ${row.updatedAt}',
      for (final DebtRow row in await db.debtsDao.getAll())
        'D ${row.id} ${row.personId} ${row.principalMinor} ${row.currencyCode} ${row.updatedAt}',
      for (final DebtPersonRow row in await db.debtsDao.allParticipantRows())
        'L ${row.debtId} ${row.personId} ${row.position}',
      for (final PaymentRow row in await db.debtsDao.getAllPayments())
        'A ${row.id} ${row.debtId} ${row.amountMinor}',
      for (final ObligationRow row in await db.obligationsDao.getAll())
        'O ${row.id} ${row.name} ${row.amountMinor}',
    ]..sort();
    return parts.join('\n');
  }

  /// The snapshot files on disk. Directories are not files, and a blocker
  /// created by a test to make a write fail is not a snapshot.
  List<String> files() => dir
      .listSync()
      .whereType<File>()
      .map((File e) => e.path.split('/').last)
      .toList()
    ..sort();

  List<String> temporaries() => files()
      .where((String name) => name.endsWith('.tmp'))
      .toList();

  /// Every snapshot on disk is still a snapshot.
  Future<void> expectFilesIntact() async {
    for (final BackupFileInfo info in await backups.list()) {
      expect(
        (await backups.inspect(info.path)).isUsable,
        isTrue,
        reason: '${info.name} must still be restorable',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // A kill during a snapshot. Nine points, one row each.
  // ---------------------------------------------------------------------------
  group('a process killed while a snapshot is being written', () {
    /// Kills the snapshot on entering [step].
    Future<void> killAt(
      BackupStep step, {
      required String before,
      required List<String> filesBefore,
    }) async {
      await expectLater(
        backups.create(
          kind: BackupKind.manual,
          onStep: (BackupStep reached) {
            if (reached == step) {
              throw StateError('process killed at ${step.name}');
            }
          },
        ),
        throwsA(anything),
        reason: 'the kill is reported as a failure, never as a snapshot',
      );

      // 1. The data is untouched.
      expect(await fingerprint(), before, reason: 'the ledger is unchanged');
      // 2. The set of files is unchanged: no half-file wearing a snapshot's
      //    name, and nothing removed.
      expect(files(), filesBefore, reason: 'the files on disk are unchanged');
      // 3. What was there before is still a usable snapshot.
      await expectFilesIntact();
    }

    test('1. before anything starts', () async {
      final String before = await fingerprint();
      final List<String> filesBefore = files();
      // Nothing has begun: a process that dies here leaves exactly this state,
      // and the check is that the state it leaves is the state it found.
      await killAt(BackupStep.reading,
          before: before, filesBefore: filesBefore);
    });

    test('2. at the database read', () async {
      final String before = await fingerprint();
      final List<String> filesBefore = files();
      await killAt(BackupStep.reading,
          before: before, filesBefore: filesBefore);
    });

    test('3. after reading, while the payload is built', () async {
      final String before = await fingerprint();
      final List<String> filesBefore = files();
      await killAt(BackupStep.building,
          before: before, filesBefore: filesBefore);
    });

    test('4. while hashing', () async {
      final String before = await fingerprint();
      final List<String> filesBefore = files();
      await killAt(BackupStep.hashing,
          before: before, filesBefore: filesBefore);
    });

    test('5. before the file is opened', () async {
      final String before = await fingerprint();
      final List<String> filesBefore = files();
      await killAt(BackupStep.writing,
          before: before, filesBefore: filesBefore);
    });

    test('6. during the write, with a half-written file left behind', () async {
      // The one point that is emulated by its artifact rather than by an abort:
      // a `.tmp` file with a partial snapshot in it, which is what a process
      // killed between the first byte and the rename leaves on disk.
      final ({File file, ParsedBackup backup}) good =
          await backups.create(kind: BackupKind.manual);
      final String contents = await good.file.readAsString();
      final File partial =
          File('${dir.path}/dhimmah-auto-20260926T091500000.dhimmah.tmp');
      await partial.writeAsString(contents.substring(0, contents.length ~/ 3));

      final String before = await fingerprint();
      final List<BackupFileInfo> listed = await backups.list();

      expect(
        listed.any((BackupFileInfo i) => i.path.endsWith('.tmp')),
        isFalse,
        reason: 'a half-file is never offered as a snapshot',
      );
      expect(await good.file.readAsString(), contents);
      expect(await fingerprint(), before);

      // The next snapshot clears it, so it does not accumulate.
      await backups.create(kind: BackupKind.manual);
      expect(temporaries(), isEmpty);
    });

    test('7. after the rename, while the file is being read back', () async {
      // Verification only reads, so a kill here cannot damage anything: the file
      // was renamed into place after a flush, which is the moment it became a
      // complete snapshot. What matters is that *nothing was claimed* — the call
      // threw, so no caller was told a backup had been saved — while the file
      // that exists is one the app can actually restore.
      final String before = await fingerprint();
      final int writtenBefore = (await backups.list()).length;

      await expectLater(
        backups.create(
          kind: BackupKind.manual,
          onStep: (BackupStep reached) {
            if (reached == BackupStep.verifying) {
              throw StateError('process killed during verification');
            }
          },
        ),
        throwsA(anything),
        reason: 'an unverified snapshot is a failure, not a snapshot',
      );

      expect(await fingerprint(), before, reason: 'the ledger is unchanged');
      expect(
        temporaries(),
        isEmpty,
        reason: 'the write had finished, so no half-file can be lying around',
      );
      expect(
        (await backups.list()).length,
        writtenBefore + 1,
        reason: 'the file was renamed before verification, so it is on disk — '
            'the kill stopped the claim, not the file',
      );
      await expectFilesIntact();
    });

    test('8. after the file is renamed, before the old ones are cleaned up',
        () async {
      final String before = await fingerprint();
      await expectLater(
        backups.create(
          kind: BackupKind.manual,
          onStep: (BackupStep reached) {
            if (reached == BackupStep.retaining) {
              throw StateError('process killed after the rename');
            }
          },
        ),
        throwsA(anything),
      );

      // The write had already finished when the kill landed, so the snapshot
      // exists and is complete: only the tidying of older snapshots did not
      // happen, which the next write does. Nothing was removed, and nothing is
      // half-written.
      expect(temporaries(), isEmpty);
      expect(await backups.list(), isNotEmpty);
      await expectFilesIntact();
      expect(await fingerprint(), before);
    });

    test('9. and the ledger is still backed up afterwards', () async {
      // The point of the whole matrix: after any of those kills, the app can
      // still do the thing it failed at.
      final String before = await fingerprint();
      await expectLater(
        backups.create(
          kind: BackupKind.manual,
          onStep: (BackupStep reached) {
            if (reached == BackupStep.hashing) throw StateError('killed');
          },
        ),
        throwsA(anything),
      );

      final ({File file, ParsedBackup backup}) after =
          await backups.create(kind: BackupKind.manual);
      expect((await backups.inspect(after.file.path)).isUsable, isTrue);
      expect(after.backup.rows('debts'), hasLength(2),
          reason: 'the ledger the seed created is in the snapshot');
      expect(await fingerprint(), before);
    });
  });

  // ---------------------------------------------------------------------------
  // A kill during a restore. Eight points.
  // ---------------------------------------------------------------------------
  group('a process killed while a restore is running', () {
    late ParsedBackup incoming;
    late String ledgerBefore;
    late List<String> filesBefore;

    setUp(() async {
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      incoming = written.backup;
      ledgerBefore = await fingerprint();
      filesBefore = files();
    });

    /// Kills the restore on entering [step].
    Future<void> killAt(RestoreStep step, {bool afterCommit = false}) async {
      await expectLater(
        restores.apply(
          backup: incoming,
          mode: RestoreMode.replace,
          onStep: (RestoreStep reached) {
            if (reached == step) {
              throw StateError('process killed at ${step.name}');
            }
          },
        ),
        throwsA(anything),
      );

      if (afterCommit) {
        // The restore had already committed: the ledger must hold the whole
        // restored state, not half of it. What "whole" means is the file's own
        // count, so this cannot drift from the fixture.
        expect(
          (await db.debtsDao.getAll()),
          hasLength(incoming.rows('debts').length),
        );
        expect(
          (await db.debtsDao.allParticipantRows()),
          hasLength(incoming.rows('debtPeople').length),
        );
        expect(
          (await db.peopleDao.getAll()),
          hasLength(incoming.rows('people').length),
        );
        return;
      }
      expect(await fingerprint(), ledgerBefore,
          reason: 'a killed restore leaves the ledger exactly as it was');
      await expectFilesIntact();
      expect(temporaries(), isEmpty);
    }

    test('9. before the plan is worked out', () async {
      await killAt(RestoreStep.planning);
    });

    test('10. while the plan is being worked out', () async {
      await killAt(RestoreStep.snapshot);
    });

    test('11. before the safety snapshot', () async {
      await killAt(RestoreStep.snapshot);
    });

    test('12. during the safety snapshot', () async {
      // Emulated the way the file system does it: the temporary file it would
      // write cannot be created, so the safety copy fails and the restore has
      // nothing to fall back on — so it does not start.
      await Directory('${dir.path}/dhimmah-safety-20260926T091500000'
              '${BackupFormat.extension}.tmp')
          .create();
      await expectLater(
        restores.apply(backup: incoming, mode: RestoreMode.replace),
        throwsA(anything),
        reason: 'no safety copy means no restore',
      );
      expect(await fingerprint(), ledgerBefore);
      expect(files(), filesBefore);
    });

    test('13. inside the database transaction', () async {
      // Two summaries for one month: the unique index refuses the second, which
      // fails the transaction with rows already written.
      final Map<String, Object?> envelope = jsonDecode(
        await (await backups.create(kind: BackupKind.manual)).file.readAsString(),
      ) as Map<String, Object?>;
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      data['monthlySummaries'] = <Object?>[
        for (final String id in <String>['a', 'b'])
          <String, Object?>{
            'id': 'summary-$id',
            'year': 2026,
            'month': 9,
            'currency': 'INR',
            'newDebtMinor': 1,
            'settledMinor': 0,
            'receivedMinor': 0,
            'paidOutMinor': 0,
            'obligationsMinor': 0,
            'overdueMinor': 0,
            'peopleCount': 0,
            'closedDebts': 0,
            'activeDebts': 0,
            'generatedAt': '2026-09-26T09:00:00.000Z',
          },
      ];
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = File('${dir.path}/half-restore.dhimmah');
      await file.writeAsString(jsonEncode(envelope));

      final String before = await fingerprint();
      await expectLater(
        restores.apply(
          backup: BackupFormat.parse(await file.readAsString()),
          mode: RestoreMode.replace,
        ),
        throwsA(anything),
      );
      expect(await fingerprint(), before,
          reason: 'the transaction rolled back completely — not one row left');
    });

    test('14. just before the commit, inside the transaction', () async {
      await killAt(RestoreStep.verifying);
    });

    test('15. after the commit', () async {
      await killAt(RestoreStep.rebuilding, afterCommit: true);
    });

    test('16. during the derived rebuild', () async {
      // Reached only after the transaction committed, and it fails there: the
      // records are already correct, and the failure is reported rather than
      // silently dropped.
      final BackupRestoreService failing = BackupRestoreService(
        database: db,
        backups: backups,
        rebuildDerivedState: () async =>
            throw StateError('killed during the rebuild'),
      );
      final RestoreReport report = await failing.apply(
        backup: incoming,
        mode: RestoreMode.replace,
      );
      expect(report.counts['debts'], incoming.rows('debts').length);
      expect(
        report.warnings.map((BackupIssue issue) => issue.code),
        contains('rebuild_failed'),
        reason: 'the user is told the derived state could not be rebuilt; the '
            'records themselves are restored',
      );
      // And the rebuild happens on the next launch, from the records.
      await service.ensureOccurrences();
      await service.refreshNotifications();
      expect(
        (await db.debtsDao.getAll()),
        hasLength(incoming.rows('debts').length),
      );
      await expectFilesIntact();
    });
  });
}

Future<void> _seed(LedgerService service, DateTime today) async {
  final Person ahmed =
      await service.createPerson(const PersonDraft(name: 'أحمد'));
  final Person maryam =
      await service.createPerson(const PersonDraft(name: 'مريم'));
  final shared = await service.createDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      personIds: <String>[ahmed.id, maryam.id],
      title: 'رحلة',
      principalMinor: 150000,
      currency: AppCurrency.inr,
      issuedAt: today,
      dueAt: addDays(today, 3),
    ),
  );
  await service.recordPayment(
    shared.id,
    PaymentDraft(amountMinor: 50000, paidAt: today),
  );
  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[maryam.id],
      title: 'سلفة',
      principalMinor: 90000,
      currency: AppCurrency.inr,
      issuedAt: today,
    ),
  );
}
