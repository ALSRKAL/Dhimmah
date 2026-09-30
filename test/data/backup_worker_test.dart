import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/backup/backup_worker.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_progress.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The worker isolate's contract, including the paths a restore depends on when
/// it is *not* going to get an answer.
///
/// The success path is already covered indirectly — every backup test reads its
/// file through `open()`, which uses the worker — but a fallback that is only
/// exercised by accident is not a fallback anyone can rely on. These are the
/// paths that must never wait:
///
/// * a worker that cannot start, or is too slow (a zero timeout is a slow worker
///   taken to its limit);
/// * a file the worker refuses, which must arrive as the same exception the
///   inline path throws;
/// * and the inline path itself, which must produce exactly what the worker
///   produced.
void main() {
  late Directory dir;
  late AppDatabase db;
  late BackupService backups;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-worker');
    db = AppDatabase.memory();
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => DateTime(2026, 9, 26, 12),
      directory: dir,
    );
    final service = buildService(db);
    final person = await service.createPerson(const PersonDraft(name: 'أحمد'));
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'قرض',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 5),
      ),
    );
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('success: the worker returns the same payload and verdict as inline',
      () async {
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    final ({ParsedBackup backup, BackupValidation validation}) offThread =
        (await openOnWorker(path: written.file.path, schemaVersion: AppDatabase.currentSchemaVersion))!;
    final ({ParsedBackup backup, BackupValidation validation}) inline =
        await backups.openInline(written.file.path);

    expect(offThread.validation.isUsable, isTrue);
    expect(inline.validation.isUsable, isTrue);
    expect(offThread.backup.counts, inline.backup.counts);
    expect(
      offThread.backup.rows('debts'),
      inline.backup.rows('debts'),
      reason: 'the worker and the inline path cannot disagree about the file',
    );
  });

  test('the steps the worker reports are the steps that happen', () async {
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final List<RestoreStep> steps = <RestoreStep>[];
    await backups.open(written.file.path, onStep: steps.add);

    expect(steps, containsAllInOrder(<RestoreStep>[
      RestoreStep.reading,
      RestoreStep.decoding,
      RestoreStep.checking,
      RestoreStep.validating,
    ]));
  });

  test('a slow worker returns null instead of waiting, and the caller falls '
      'back inline', () async {
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    // A zero timeout is the slowest worker there is: the wait is over before it
    // can be answered.
    //
    // Which of the two wins is a race, and this test does not pretend otherwise.
    // `Future.timeout(Duration.zero)` schedules a timer and races it against the
    // isolate's reply, and on a machine that is not busy the reply can arrive in
    // the same turn. So the assertion is the contract rather than the winner: the
    // call returns promptly either way, and an answer, when there is one, is a
    // real one. Asserting `isNull` outright made this fail about once in four
    // runs of the whole set — a test that was measuring the load on the machine.
    final Stopwatch race = Stopwatch()..start();
    final ({ParsedBackup backup, BackupValidation validation})? answer =
        await openOnWorker(
      path: written.file.path,
      schemaVersion: AppDatabase.currentSchemaVersion,
      timeout: Duration.zero,
    );
    race.stop();
    expect(
      race.elapsedMilliseconds,
      lessThan(5000),
      reason: 'a worker that cannot answer in time must not be waited for',
    );
    if (answer != null) {
      expect(
        answer.validation.isUsable,
        isTrue,
        reason: 'an answer that did arrive has to be the right one',
      );
    }

    // And the caller still gets an answer, from the inline path.
    final Stopwatch watch = Stopwatch()..start();
    final ({ParsedBackup backup, BackupValidation validation}) opened =
        await backups.open(written.file.path);
    watch.stop();
    expect(opened.validation.isUsable, isTrue);
    expect(
      watch.elapsedMilliseconds,
      lessThan(30000),
      reason: 'the fallback completes rather than hanging on a missing worker',
    );
  });

  test('a missing file is refused with the reason intact', () async {
    expect(
      await _problemOf(path: '${dir.path}/not-there.dhimmah'),
      BackupProblem.unreadableEnvelope,
    );
  });

  test('the worker does not classify refusals: it reports no answer, and the '
      'inline path names the problem', () async {
    // Observed and recorded rather than hidden: when the file cannot be opened,
    // the worker's refusal arrives as *no answer*, so `open()` does the work
    // again inline and throws from there. The product contract is unaffected —
    // the right problem reaches the caller — and the cost is one extra pass over
    // a file that was not going to be restored anyway.
    final File junk = File('${dir.path}/refusal.dhimmah');
    await junk.writeAsString('{"hello":"world"}');
    expect(
      await openOnWorker(path: junk.path, schemaVersion: AppDatabase.currentSchemaVersion),
      isNull,
      reason: 'no answer, not a classification',
    );
    expect(
      await _problemOf(path: junk.path),
      BackupProblem.notADhimmahBackup,
      reason: 'and the caller still learns exactly what is wrong',
    );
  });

  test('a file that is not a backup is refused, and the ledger is untouched',
      () async {
    final File junk = File('${dir.path}/junk.dhimmah');
    await junk.writeAsString('{"hello":"world"}');
    expect(
      await _problemOf(path: junk.path),
      BackupProblem.notADhimmahBackup,
    );
    expect(await db.debtsDao.getAll(), hasLength(1));
  });

  test('a damaged payload is refused by the checksum', () async {
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final Map<String, Object?> envelope =
        jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
    envelope['checksum'] = 'sha256:${'0' * 64}';
    final File tampered = File('${dir.path}/tampered.dhimmah');
    await tampered.writeAsString(jsonEncode(envelope));

    expect(
      await _problemOf(path: tampered.path),
      BackupProblem.checksumMismatch,
    );
  });


  test('a file from a newer schema comes back as a verdict, not an exception',
      () async {
    // The worker classifies unreadable files as exceptions and usable-but-wrong
    // ones as verdicts; a restore screen needs both to look different.
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final Map<String, Object?> envelope =
        jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
    final Map<String, Object?> payload =
        envelope['payload']! as Map<String, Object?>;
    payload['schemaVersion'] = AppDatabase.currentSchemaVersion + 1;
    envelope['checksum'] = BackupFormat.checksumOf(payload);
    final File future = File('${dir.path}/future.dhimmah');
    await future.writeAsString(jsonEncode(envelope));

    final ({ParsedBackup backup, BackupValidation validation})? opened =
        await openOnWorker(path: future.path, schemaVersion: AppDatabase.currentSchemaVersion);
    expect(opened, isNotNull);
    expect(opened!.validation.isUsable, isFalse);
    expect(
      opened.validation.errors.map((BackupIssue i) => i.code),
      contains('schema_too_new'),
    );
  });
}

/// The reason the worker gave, or null if it answered instead of refusing.
///
/// Written as a catch rather than a matcher because the interesting part is
/// *which* problem came back, and a refusal that never arrives shows up here as
/// a test that never finishes rather than as a pass.
Future<BackupProblem?> _problemOf({required String path}) async {
  final AppDatabase db = AppDatabase.memory();
  final Directory dir = Directory(path).parent;
  final BackupService backups = BackupService(
    database: db,
    appVersion: '1.0.0+1',
    clock: DateTime.now,
    directory: dir,
  );
  try {
    await backups.open(path);
    return null;
  } on BackupFormatException catch (error) {
    return error.problem;
  } finally {
    await db.close();
  }
}
