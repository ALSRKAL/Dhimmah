import 'dart:io';

import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What a snapshot must prove before the app calls it saved.
///
/// A `write` that returned without throwing is not evidence that the bytes are
/// on the disk. The rename can land on a full volume, a stream can end early, a
/// filesystem can hand back something other than what was flushed — and the
/// result is a file with the right name, a plausible size, and a payload that
/// will not restore. Calling that a saved backup is worse than saying nothing,
/// because it is the moment the user stops worrying.
///
/// The judgement is `BackupFormat.checkReadBack`, which is pure, so every way it
/// can say no is tested here directly. The I/O wrapper around it — read the file,
/// and delete it when the judgement says no — is exercised on the happy path
/// through `create`; its failure branch needs a filesystem that misbehaves,
/// and the alternative to not testing it that way would be a test-only hook in
/// production code, which is worse.
void main() {
  late Directory dir;
  late AppDatabase db;
  late BackupService backups;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-verify');
    db = AppDatabase.memory();
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => DateTime(2026, 9, 27, 15, 30),
      directory: dir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A complete, valid envelope over [people] rows, with its digest.
  ({String text, String digest, Map<String, int> counts}) envelopeWith({
    required int people,
  }) {
    final CanonicalPayload canonical = BackupFormat.build(
      schemaVersion: 4,
      tables: <String, List<Map<String, Object?>>>{
        'people': <Map<String, Object?>>[
          for (int i = 0; i < people; i++)
            <String, Object?>{'id': 'p$i', 'name': 'Person $i'},
        ],
      },
      settings: const <String, Object?>{},
      counts: <String, int>{'people': people},
    );
    return (
      text: BackupFormat.wrap(
        payloadJson: canonical.text,
        checksum: canonical.digest,
        appVersion: '1.0.0+1',
        createdAt: DateTime(2026, 9, 27, 15, 30),
        kind: 'auto',
      ),
      digest: canonical.digest,
      counts: <String, int>{'people': people},
    );
  }

  group('what came back off the disk', () {
    test('is accepted when it is the snapshot that was meant to be written', () {
      final ({String text, String digest, Map<String, int> counts}) written =
          envelopeWith(people: 3);

      expect(
        BackupFormat.checkReadBack(
          written.text,
          expectedDigest: written.digest,
          expectedCounts: written.counts,
        ),
        isNull,
        reason: 'a file that parses, hashes to what was written, and carries '
            'the rows that were read is the file that was meant',
      );
    });

    test('is refused when the bytes were cut short', () {
      final ({String text, String digest, Map<String, int> counts}) written =
          envelopeWith(people: 40);
      final String truncated = written.text.substring(0, written.text.length ~/ 2);

      expect(
        BackupFormat.checkReadBack(
          truncated,
          expectedDigest: written.digest,
          expectedCounts: written.counts,
        ),
        BackupProblem.notJson,
        reason: 'half a file is not JSON, and must not be called a backup',
      );
    });

    test('is refused when a value was altered but the checksum kept', () {
      final ({String text, String digest, Map<String, int> counts}) written =
          envelopeWith(people: 1);
      final String tampered =
          written.text.replaceFirst('"Person 0"', '"Somebody Else"');
      expect(tampered, isNot(written.text), reason: 'the edit has to land');

      expect(
        BackupFormat.checkReadBack(
          tampered,
          expectedDigest: written.digest,
          expectedCounts: written.counts,
        ),
        BackupProblem.checksumMismatch,
        reason: 'the payload no longer hashes to the checksum stored beside it',
      );
    });

    test('is refused when it is a valid backup, but not this snapshot', () {
      final ({String text, String digest, Map<String, int> counts}) mine =
          envelopeWith(people: 3);
      final ({String text, String digest, Map<String, int> counts}) other =
          envelopeWith(people: 5);

      expect(
        BackupFormat.checkReadBack(
          other.text,
          expectedDigest: mine.digest,
          expectedCounts: mine.counts,
        ),
        BackupProblem.checksumMismatch,
        reason: 'a perfectly good backup of something else is not the file this '
            'call just wrote, and accepting it would report the wrong snapshot',
      );
    });

    test('is refused when it carries a different number of rows', () {
      final ({String text, String digest, Map<String, int> counts}) written =
          envelopeWith(people: 2);

      expect(
        BackupFormat.checkReadBack(
          written.text,
          expectedDigest: written.digest,
          expectedCounts: <String, int>{'people': 3},
        ),
        BackupProblem.unreadablePayload,
        reason: 'self-consistent is not the same as carrying the records that '
            'were read from the ledger',
      );
    });

    test('is refused when a table the ledger has is missing from the file', () {
      final ({String text, String digest, Map<String, int> counts}) written =
          envelopeWith(people: 2);

      expect(
        BackupFormat.checkReadBack(
          written.text,
          expectedDigest: written.digest,
          expectedCounts: <String, int>{'people': 2, 'debts': 1},
        ),
        BackupProblem.unreadablePayload,
        reason: 'a file that does not mention a table cannot be shown to hold it',
      );
    });
  });

  group('the snapshot itself', () {
    test('is read back off the disk before it is called saved', () async {
      await buildService(db).createPerson(const PersonDraft(name: 'أحمد'));
      final List<BackupStep> steps = <BackupStep>[];

      final ({File file, ParsedBackup backup}) written = await backups.create(
        kind: BackupKind.auto,
        onStep: steps.add,
      );

      expect(
        steps,
        contains(BackupStep.verifying),
        reason: 'the work has to be visible: a step that is not reported reads '
            'as a pause in whatever came before it',
      );
      expect(
        steps.indexOf(BackupStep.verifying),
        greaterThan(steps.indexOf(BackupStep.writing)),
        reason: 'the file is verified after it is written',
      );
      expect(
        steps.indexOf(BackupStep.verifying),
        lessThan(steps.indexOf(BackupStep.retaining)),
        reason: 'and before anything is deleted on the strength of it: a '
            'retention pass that ran first could drop a good snapshot to make '
            'room for one that never verified',
      );
      expect(written.backup.counts['people'], 1);
    });

    test('returns what the file holds, not what was in memory', () async {
      await buildService(db).createPerson(const PersonDraft(name: 'أحمد'));
      await buildService(db).createPerson(const PersonDraft(name: 'خالد'));

      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.auto);

      // Read the same file the app wrote, independently, and compare.
      final ParsedBackup fromDisk =
          BackupFormat.parse(await written.file.readAsString());
      expect(
        written.backup.counts,
        fromDisk.counts,
        reason: 'the caller is told what is on the disk, because that is what '
            'they would get back',
      );
      expect(
        written.backup.rows('people').length,
        2,
        reason: 'and the rows are really there',
      );
    });

    test('is verified for every kind of snapshot, not only the automatic one',
        () async {
      await buildService(db).createPerson(const PersonDraft(name: 'أحمد'));

      for (final BackupKind kind in BackupKind.values) {
        final List<BackupStep> steps = <BackupStep>[];
        final ({File file, ParsedBackup backup}) written =
            await backups.create(kind: kind, onStep: steps.add);
        expect(
          steps,
          contains(BackupStep.verifying),
          reason: '$kind is a snapshot the user may have to rely on',
        );
        expect(written.backup.counts['people'], 1);
      }
    });

    test('leaves nothing behind when the ledger is empty', () async {
      // An empty ledger still produces a valid, verifiable file — the app has
      // no business refusing to snapshot "nothing", because the user's next
      // act may be to restore it over something.
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.auto);
      expect(await written.file.exists(), isTrue);
      expect(written.backup.counts['people'], 0);
    });
  });
}
