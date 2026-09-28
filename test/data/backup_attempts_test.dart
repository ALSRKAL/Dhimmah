import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/files/backup_attempt_store.dart';
import 'package:dhimmah/domain/services/backup_attempts.dart';
import 'package:flutter_test/flutter_test.dart';

/// How the app behaves after a snapshot of its own fails.
///
/// Two failures in a row are usually the same failure, and a retry loop over a
/// failing write is how a full disk becomes a flat battery — so the app waits
/// longer each time, and past a point it stops believing this is a blip and says
/// so. What it must never do is either give up silently or try forever.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-attempts');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  final DateTime t0 = DateTime(2026, 9, 27, 16);

  group('the wait between attempts', () {
    test('is nothing when nothing has failed', () {
      expect(BackupBackoff.delayFor(0), Duration.zero);
      expect(BackupBackoff.nextAttemptAt(t0, 0), isNull);
    });

    test('doubles from the first failure', () {
      expect(BackupBackoff.delayFor(1), const Duration(minutes: 2));
      expect(BackupBackoff.delayFor(2), const Duration(minutes: 4));
      expect(BackupBackoff.delayFor(3), const Duration(minutes: 8));
      expect(BackupBackoff.delayFor(4), const Duration(minutes: 16));
    });

    test('stops growing at the ceiling', () {
      // Doubling from two minutes: 32 at the fifth failure, which is the point
      // the state stops calling this a blip, and the ceiling is reached on the
      // sixth. Past there it stays hourly however long the trouble lasts.
      expect(BackupBackoff.delayFor(5), const Duration(minutes: 32));
      expect(BackupBackoff.delayFor(6), const Duration(hours: 1));
      expect(BackupBackoff.delayFor(20), const Duration(hours: 1));
      expect(
        BackupBackoff.delayFor(100000),
        const Duration(hours: 1),
        reason: 'a huge failure count must not overflow into a wait the clock '
            'cannot represent — the shift is bounded before it is used',
      );
    });

    test('is measured from the attempt, not from the first failure', () {
      expect(
        BackupBackoff.nextAttemptAt(t0, 3),
        t0.add(const Duration(minutes: 8)),
        reason: 'a device that was off for a day must not wake up and wait an '
            'hour: the clock that matters is the one on the attempt',
      );
    });
  });

  group('the record of the attempts', () {
    test('a success clears the failures and remembers when it worked', () {
      final BackupAttempts failed =
          BackupAttempts.none.failed(t0, BackupFailure.storage);
      expect(failed.consecutiveFailures, 1);
      expect(failed.needsAttention, isFalse);
      expect(failed.isWaitingAt(t0), isTrue, reason: 'the wait starts at once');

      final DateTime later = t0.add(const Duration(minutes: 5));
      final BackupAttempts ok = failed.succeeded(later);
      expect(ok.consecutiveFailures, 0);
      expect(ok.lastFailure, isNull);
      expect(ok.lastSuccessAt, later);
      expect(ok.nextAttemptAt, isNull);
      expect(ok.isDueAt(later), isTrue);
    });

    test('the wait ends when it is over, and not before', () {
      final BackupAttempts once =
          BackupAttempts.none.failed(t0, BackupFailure.storage);
      expect(once.isDueAt(t0.add(const Duration(seconds: 119))), isFalse);
      expect(once.isDueAt(t0.add(const Duration(minutes: 2))), isTrue);
    });

    test('needs attention only after a run of failures', () {
      BackupAttempts state = BackupAttempts.none;
      for (int i = 1; i < BackupBackoff.giveUpAfter; i++) {
        state = state.failed(t0, BackupFailure.storage);
        expect(
          state.needsAttention,
          isFalse,
          reason: '$i failure(s) is still a blip as far as the state is '
              'concerned, though the wait is already growing',
        );
      }
      state = state.failed(t0, BackupFailure.storage);
      expect(state.consecutiveFailures, BackupBackoff.giveUpAfter);
      expect(
        state.needsAttention,
        isTrue,
        reason: 'past the threshold this is the user\'s business, not a blip',
      );
    });

    test('a success keeps the reason for the earlier failure out of the record',
        () {
      final BackupAttempts ok = BackupAttempts.none
          .failed(t0, BackupFailure.verification)
          .failed(t0, BackupFailure.verification)
          .succeeded(t0);
      expect(ok.lastFailure, isNull);
      expect(ok.consecutiveFailures, 0);
    });

    test('clearing forgets the failures but not when it last worked', () {
      final DateTime worked = t0.subtract(const Duration(hours: 3));
      final BackupAttempts state = BackupAttempts(
        lastAttemptAt: t0,
        lastSuccessAt: worked,
        consecutiveFailures: 3,
        lastFailure: BackupFailure.storage,
        nextAttemptAt: t0.add(const Duration(hours: 1)),
      ).cleared();

      expect(state.consecutiveFailures, 0);
      expect(state.lastFailure, isNull);
      expect(state.nextAttemptAt, isNull);
      expect(
        state.lastSuccessAt,
        worked,
        reason: 'when the data last got out is a fact about the data — a user '
            'who re-authorizes a folder has not just made a backup',
      );
    });
  });

  group('the file it is kept in', () {
    late BackupAttemptStore store;

    setUp(() {
      store = BackupAttemptStore(directory: dir);
    });

    test('is not there until something has been attempted', () async {
      expect(await store.read(), isA<BackupAttempts>());
      final BackupAttempts read = await store.read();
      expect(read.lastAttemptAt, isNull);
      expect(read.consecutiveFailures, 0);
      expect(read.lastSuccessAt, isNull);
    });

    test('survives a round trip', () async {
      final DateTime t1 = DateTime(2026, 9, 27, 16, 2);
      final BackupAttempts written = BackupAttempts.none
          .failed(t0, BackupFailure.storage)
          .failed(t1, BackupFailure.verification);
      await store.write(written);

      final BackupAttempts read = await store.read();
      expect(read.consecutiveFailures, written.consecutiveFailures);
      expect(read.lastFailure, BackupFailure.verification);
      expect(read.lastAttemptAt, t1);
      expect(read.nextAttemptAt, written.nextAttemptAt);
    });

    test('keeps the moment it last worked across a restart', () async {
      await store.write(BackupAttempts.none.succeeded(t0));
      expect((await store.read()).lastSuccessAt, t0);
    });

    test('a file that cannot be parsed is treated as no attempt yet', () async {
      // Written by a build that is not this one, or half-written by a kill. The
      // only safe reading is "no attempt known", which costs one attempt sooner
      // than needed; the unsafe reading is "everything is fine".
      await File('${dir.path}/${BackupAttemptStore.fileName}')
          .writeAsString('{not json at all');

      final BackupAttempts read = await store.read();
      expect(read.consecutiveFailures, 0);
      expect(read.lastSuccessAt, isNull);
    });

    test('an unknown failure code is still a failure', () async {
      await File('${dir.path}/${BackupAttemptStore.fileName}').writeAsString(
        jsonEncode(<String, Object?>{
          'lastAttemptAt': t0.toIso8601String(),
          'consecutiveFailures': 2,
          'lastFailure': 'something_a_newer_build_added',
        }),
      );

      final BackupAttempts read = await store.read();
      expect(read.consecutiveFailures, 2);
      expect(
        read.lastFailure,
        BackupFailure.unknown,
        reason: 'a state that cannot name the problem must still report one — '
            'the alternative is telling the user everything is fine',
      );
    });

    test('clearing removes it', () async {
      await store.write(BackupAttempts.none.failed(t0, BackupFailure.storage));
      await store.clear();
      expect((await store.read()).consecutiveFailures, 0);
    });
  });
}
