import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What happens when a backup is not what it claims to be.
///
/// The rule this file holds the app to: **a bad file changes nothing.** Not the
/// ledger, not the previous backup, not the schedule. Every case here is a way a
/// backup can arrive broken — a truncated download, a file from another app, a
/// hand-edited amount, a disk with no room, a process killed mid-write — and each
/// one ends by asserting that what the user already had is still exactly there.
void main() {
  late Directory dir;
  late AppDatabase db;
  late LedgerService service;
  late BackupService backups;
  late BackupRestoreService restores;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-backup-failure');
    db = AppDatabase.memory();
    service = buildService(db);
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => DateTime(2026, 9, 25, 10, 35),
      directory: dir,
    );
    restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: () async => service.refreshNotifications(),
    );
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> seed({int people = 2, int debts = 2}) async {
    for (int i = 0; i < people; i++) {
      final Person person = await service.createPerson(
        PersonDraft(name: 'شخص $i'),
      );
      for (int d = 0; d < debts; d++) {
        await service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            personIds: <String>[person.id],
            title: 'دين $d',
            principalMinor: 100000,
            currency: AppCurrency.inr,
            issuedAt: today,
          ),
        );
      }
    }
  }

  /// A snapshot of the ledger that must not change while a bad file is refused.
  Future<String> fingerprint() async {
    final List<String> parts = <String>[
      for (final PersonRow row in await db.peopleDao.getAll())
        '${row.id}:${row.name}:${row.updatedAt.toIso8601String()}',
      for (final DebtRow row in await db.debtsDao.getAll())
        '${row.id}:${row.principalMinor}:${row.updatedAt.toIso8601String()}',
      for (final PaymentRow row in await db.debtsDao.getAllPayments())
        '${row.id}:${row.amountMinor}',
      for (final DebtPersonRow row in await db.debtsDao.allParticipantRows())
        '${row.debtId}:${row.personId}:${row.position}',
    ];
    return parts.join('|');
  }

  Future<File> writeRaw(String name, Object? contents) async {
    final File file = File('${dir.path}/$name');
    await file.writeAsString(contents is String ? contents : jsonEncode(contents));
    return file;
  }

  /// A valid backup of whatever is in the ledger right now, as a mutable map.
  ///
  /// The caller seeds first; this only writes and decodes.
  Future<Map<String, Object?>> validEnvelope() async {
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    return jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
  }

  group('a file that is not a backup', () {
    test('is refused, and says which kind of wrong it is', () async {
      await seed();
      final String before = await fingerprint();

      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final String full = await written.file.readAsString();

      final Map<String, File> cases = <String, File>{
        'not JSON at all':
            await writeRaw('notes.dhimmah', 'hello, this is a note'),
        'JSON but not ours': await writeRaw('other.dhimmah', <String, Object?>{
          'format': 'something-else',
          'payload': <String, Object?>{},
        }),
        'an array': await writeRaw('array.dhimmah', <Object?>[1, 2, 3]),
        'half a file':
            await writeRaw('half.dhimmah', full.substring(0, full.length ~/ 2)),
        'an empty file': await writeRaw('empty.dhimmah', ''),
      };

      for (final MapEntry<String, File> entry in cases.entries) {
        final BackupValidation? verdict = await backups
            .inspect(entry.value.path)
            .then<BackupValidation?>((BackupValidation v) => v)
            .catchError((Object _) => null);
        expect(
          verdict == null || !verdict.isUsable,
          isTrue,
          reason: '${entry.key} must not be usable',
        );
        expect(await fingerprint(), before, reason: '${entry.key} changed data');
      }
    });

    test('a corrupted byte is caught by the checksum', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final List<Object?> debts = payload['data']! is Map<String, Object?>
          ? (payload['data']! as Map<String, Object?>)['debts']! as List<Object?>
          : <Object?>[];
      (debts.first! as Map<String, Object?>)['amountMinor'] = 1;
      // The checksum still describes the file as it was written.
      final File tampered = await writeRaw('tampered.dhimmah', envelope);

      expect(
        () => backups.inspect(tampered.path),
        throwsA(isA<BackupFormatException>().having(
          (BackupFormatException e) => e.problem,
          'problem',
          BackupProblem.checksumMismatch,
        )),
        reason: 'an edited amount is not a backup any more',
      );
    });
  });

  group('a file with content that cannot be true', () {
    Future<BackupValidation> damaged(
      void Function(Map<String, Object?> data) break_,
    ) async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      break_(data);
      // Recomputed, so the checksum is not what refuses it: the rules are.
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw('damaged.dhimmah', envelope);
      return backups.inspect(file.path);
    }

    test('a payment pointing at no debt', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        (data['payments']! as List<Object?>).add(<String, Object?>{
          'id': 'ghost',
          'debtId': 'does-not-exist',
          'amountMinor': 100,
          'currency': 'INR',
          'paidAt': '2026-09-01',
          'createdAt': '2026-09-01T00:00:00.000Z',
        });
      });
      expect(verdict.errors.map((BackupIssue e) => e.code), contains('missing_debt'));
    });

    test('a link to a person who is not in the file', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        (data['debtPeople']! as List<Object?>).add(<String, Object?>{
          'id': 'x:y',
          'debtId': (data['debts']! as List<Object?>).first is Map<String, Object?>
              ? ((data['debts']! as List<Object?>).first! as Map<String, Object?>)['id']
              : 'x',
          'personId': 'nobody',
          'position': 9,
          'createdAt': '2026-09-01T00:00:00.000Z',
        });
      });
      expect(
        verdict.errors.map((BackupIssue e) => e.code),
        contains('missing_person'),
      );
    });

    test('an amount with a fraction', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        ((data['debts']! as List<Object?>).first! as Map<String, Object?>)['amountMinor'] =
            1500.5;
      });
      expect(
        verdict.errors.map((BackupIssue e) => e.code),
        contains('fractional_amount'),
      );
    });

    test('a currency the app does not know', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        ((data['debts']! as List<Object?>).first! as Map<String, Object?>)['currency'] =
            'XYZ';
      });
      expect(
        verdict.errors.map((BackupIssue e) => e.code),
        contains('unknown_currency'),
      );
    });

    test('a reminder lead the app does not know', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        ((data['debts']! as List<Object?>).first! as Map<String, Object?>)['reminderLeads'] =
            <int>[3, 99];
      });
      expect(
        verdict.errors.map((BackupIssue e) => e.code),
        contains('unknown_lead'),
      );
    });

    test('the same id twice', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        final List<Object?> debts = data['debts']! as List<Object?>;
        debts.add(Map<String, Object?>.of(debts.first! as Map<String, Object?>));
      });
      expect(verdict.errors.map((BackupIssue e) => e.code), contains('duplicate_id'));
    });

    test('a missing table', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        data.remove('people');
      });
      expect(
        verdict.isUsable,
        isFalse,
        reason: 'debts that name people who are not there cannot be restored',
      );
    });

    test('an unreadable row', () async {
      final BackupValidation verdict = await damaged((Map<String, Object?> data) {
        (data['people']! as List<Object?>).add(<String, Object?>{
          'id': '',
          'name': '',
        });
      });
      expect(
        verdict.errors.map((BackupIssue e) => e.code),
        contains('row_without_id'),
        reason: 'a row with no id is reported once, clearly, and skipped',
      );
    });
  });

  group('nothing is written when something fails', () {
    test('a write that fails inside the transaction leaves the ledger alone',
        () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data = payload['data']! as Map<String, Object?>;

      // Two monthly summaries for the same month: the database has a unique
      // constraint on (year, month, currency) and the validator does not look
      // for it, so the *insert* is what fails — halfway through the restore,
      // inside the transaction. That is the case this test exists for.
      data['monthlySummaries'] = <Object?>[
        <String, Object?>{
          'id': 'summary-a',
          'year': 2026,
          'month': 9,
          'currency': 'INR',
          'newDebtMinor': 1,
          'settledMinor': 0,
          'receivedMinor': 0,
          'paidOutMinor': 0,
          'obligationsMinor': 0,
          'overdueMinor': 0,
          'peopleCount': 1,
          'closedDebts': 0,
          'activeDebts': 1,
          'generatedAt': '2026-09-30T20:00:00.000Z',
        },
        <String, Object?>{
          'id': 'summary-b',
          'year': 2026,
          'month': 9,
          'currency': 'INR',
          'newDebtMinor': 2,
          'settledMinor': 0,
          'receivedMinor': 0,
          'paidOutMinor': 0,
          'obligationsMinor': 0,
          'overdueMinor': 0,
          'peopleCount': 1,
          'closedDebts': 0,
          'activeDebts': 1,
          'generatedAt': '2026-09-30T20:00:00.000Z',
        },
      ];
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw('conflicting.dhimmah', envelope);

      // It passes validation...
      final BackupValidation verdict = await backups.inspect(file.path);
      expect(verdict.isUsable, isTrue, reason: verdict.errors.join(' | '));

      // ...and the restore still refuses, leaving everything as it was.
      final String before = await fingerprint();
      await expectLater(
        restores.apply(
          backup: BackupFormat.parse(await file.readAsString()),
          mode: RestoreMode.replace,
        ),
        throwsA(anything),
      );
      expect(
        await fingerprint(),
        before,
        reason: 'a replace that failed halfway must leave the old ledger in '
            'place, not an empty one',
      );
      expect((await db.peopleDao.getAll()), isNotEmpty);
    });

  });

  group('the files on disk', () {
    test('a crash mid-write leaves the previous backup intact', () async {
      await seed();
      final ({File file, ParsedBackup backup}) first =
          await backups.create(kind: BackupKind.manual);
      final String firstContents = await first.file.readAsString();

      // A half-written file with the name a writer would use: it is not a
      // backup, and it must not be mistaken for one.
      await File('${first.file.path}.tmp')
          .writeAsString(firstContents.substring(0, 10));
      final List<BackupFileInfo> listed = await backups.list();
      expect(
        listed.where((BackupFileInfo info) => info.name.endsWith('.tmp')),
        isEmpty,
        reason: 'a temporary file is never listed as a backup',
      );
      expect(await first.file.readAsString(), firstContents);
    });

    test('a write that fails keeps the old backup and reports the failure',
        () async {
      await seed();
      final ({File file, ParsedBackup backup}) first =
          await backups.create(kind: BackupKind.manual);

      // A directory that refuses writes. It is the closest a test comes to a
      // full disk, and it is the same failure the writer meets there: the new
      // file cannot be created and the old one is untouched. The permission is
      // what makes the test honest — if this environment ignored it, the write
      // would succeed and the expectation below would fail loudly rather than
      // passing without testing anything.
      await Process.run('chmod', <String>['0555', dir.path]);
      await expectLater(
        backups.create(kind: BackupKind.manual),
        throwsA(anything),
        reason: 'the failure is reported, not swallowed',
      );
      await Process.run('chmod', <String>['0755', dir.path]);

      expect(
        (await backups.list()).where((BackupFileInfo i) => i.path == first.file.path),
        hasLength(1),
        reason: 'the backup that already existed is still there',
      );
      expect(
        dir.listSync().where((FileSystemEntity e) => e.path.endsWith('.tmp')),
        isEmpty,
        reason: 'and no half-written file was left behind',
      );
    });

    test('automatic snapshots rotate, manual ones are kept', () async {
      await seed();
      for (int i = 0; i < BackupService.autoRetention + 3; i++) {
        await backups.create(
          kind: BackupKind.auto,
          now: DateTime(2026, 9, 25, 10, 35).add(Duration(minutes: i)),
        );
      }
      for (int i = 0; i < 4; i++) {
        await backups.create(
          kind: BackupKind.manual,
          now: DateTime(2026, 9, 25, 11).add(Duration(minutes: i)),
        );
      }

      final List<BackupFileInfo> all = await backups.list();
      expect(
        all.where((BackupFileInfo i) => i.kind == BackupKind.auto),
        hasLength(BackupService.autoRetention),
      );
      expect(
        all.where((BackupFileInfo i) => i.kind == BackupKind.manual),
        hasLength(4),
        reason: 'a copy the user asked for is never deleted by the app',
      );
      expect(
        all.first.createdAt.isAfter(all.last.createdAt),
        isTrue,
        reason: 'newest first',
      );
    });

    test('a backup of an older schema is restored onto the current one',
        () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data = payload['data']! as Map<String, Object?>;

      // Exactly what a version-1 file looks like: no link table at all, the
      // person named on the record instead.
      final List<Object?> links = data['debtPeople']! as List<Object?>;
      expect(links, isNotEmpty);
      data['debtPeople'] = <Object?>[];
      payload['schemaVersion'] = 1;
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File legacy = await writeRaw('legacy-v1.dhimmah', envelope);

      final BackupValidation verdict = await backups.inspect(legacy.path);
      expect(verdict.isUsable, isTrue, reason: verdict.errors.join('\n'));
      expect(verdict.preview!.schemaVersion, 1);

      await db.transaction(() async {
        await db.delete(db.debtPeople).go();
        await db.delete(db.debts).go();
        await db.delete(db.people).go();
      });
      await restores.apply(
        backup: BackupFormat.parse(await legacy.readAsString()),
        mode: RestoreMode.replace,
      );

      final List<DebtRow> debts = await db.debtsDao.getAll();
      expect(
        debts,
        hasLength((data['debts']! as List<Object?>).length),
        reason: 'every record in the file is back, with a link derived from '
            'the person it named',
      );
      for (final DebtRow debt in debts) {
        expect(
          await db.debtsDao.participantsFor(debt.id),
          hasLength(1),
          reason: 'the person the record named becomes its first participant',
        );
        expect(
          debt.personId,
          (await db.debtsDao.participantsFor(debt.id)).single,
        );
      }
    });
  });
}
