import 'dart:io';

import 'package:dhimmah/core/files/backup_attempt_store.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_coordinator.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/backup_attempts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// When the app decides to take its own snapshot.
///
/// The policy is the product decision this file exists to pin down: a snapshot
/// after a burst of changes, one when the app is left with something unsaved,
/// and a daily net — never one per tap, and never while the user is waiting for
/// a frame.
void main() {
  late Directory dir;
  late AppDatabase db;
  late LedgerService service;
  late BackupService backups;
  late BackupCoordinator coordinator;
  late DateTime now;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-coordinator');
    db = AppDatabase.memory();
    service = buildService(db);
    now = DateTime(2026, 9, 25, 10);
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => now,
      directory: dir,
    );
    coordinator = BackupCoordinator(
      database: db,
      backups: backups,
      settings: () => AppSettings.initial,
      clock: () => now,
      attempts: BackupAttemptStore(directory: dir),
    );
    coordinator.start();
  });
  tearDown(() async {
    await coordinator.dispose();
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Moves the clock past the quiet period, which is what "the user stopped
  /// typing and the save has settled" looks like from the coordinator's side.
  Future<void> stopWorking() async {
    now = now.add(BackupCoordinator.quietPeriod + const Duration(seconds: 1));
  }

  Future<void> addDebt(String name) async {
    final Person person = await service.createPerson(PersonDraft(name: name));
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'دين',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
  }

  group('the policy', () {
    test('a ledger with nothing in it is never backed up', () async {
      expect(await coordinator.dueTrigger(leavingForeground: true), isNull);
      expect(await coordinator.dueTrigger(leavingForeground: false), isNull);
    });

    test('the first changes get a first snapshot at the next boundary',
        () async {
      await addDebt('أحمد');

      expect(
        await coordinator.dueTrigger(leavingForeground: true),
        BackupTrigger.periodic,
        reason: 'there is data and no snapshot at all',
      );
      expect(
        await coordinator.runIfDue(leavingForeground: true),
        isNotNull,
      );
      expect(await backups.list(), hasLength(1));
    });

    test('a few changes right after a snapshot are coalesced, not saved again',
        () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      now = now.add(const Duration(minutes: 1));

      await addDebt('خالد');
      expect(
        await coordinator.dueTrigger(leavingForeground: true),
        isNull,
        reason: 'the snapshot is a minute old and three changes are not worth '
            'another file',
      );
      expect(await backups.list(), hasLength(1));
    });

    test('leaving after the quiet period saves the accumulated changes',
        () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);

      now = now.add(BackupCoordinator.minInterval + const Duration(minutes: 1));
      await addDebt('خالد');

      expect(
        await coordinator.dueTrigger(leavingForeground: true),
        BackupTrigger.onPause,
      );
      await coordinator.runIfDue(leavingForeground: true);
      expect(await backups.list(), hasLength(2));
    });

    test('a burst of changes is saved even without waiting', () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      now = now.add(const Duration(minutes: 1));

      for (int i = 0; i < BackupCoordinator.mutationThreshold; i++) {
        await addDebt('شخص $i');
      }

      expect(
        await coordinator.dueTrigger(leavingForeground: true),
        BackupTrigger.onPause,
        reason: 'twenty changed records are worth capturing on their own',
      );
    });

    test('a stale snapshot is refreshed the next time the app is opened',
        () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      now = now.add(BackupCoordinator.maxAge + const Duration(hours: 1));
      await addDebt('خالد');
      await stopWorking();

      expect(
        await coordinator.dueTrigger(leavingForeground: false),
        BackupTrigger.periodic,
        reason: 'a ledger that has gone a day without a snapshot is the daily '
            'net, not an ordinary working session',
      );
    });

    test('a long session gets its own recovery point, without being left first',
        () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      await addDebt('خالد');

      now = now.add(BackupCoordinator.minInterval + const Duration(minutes: 1));
      await stopWorking();

      expect(
        await coordinator.dueTrigger(leavingForeground: false),
        BackupTrigger.inSession,
        reason: 'the user should not have to leave the app for their work to be '
            'captured — a session that lasts long enough earns a new point',
      );
      expect(await coordinator.runIfDue(leavingForeground: false), isNotNull);
      expect(await backups.list(), hasLength(2));
    });

    test('does not write while the user is still changing things', () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      now = now.add(BackupCoordinator.minInterval + const Duration(minutes: 1));
      await addDebt('خالد');

      // The change landed at `now`, so the ledger has not been quiet at all.
      expect(
        await coordinator.dueTrigger(leavingForeground: false),
        isNull,
        reason: 'starting a write in the same moment as the user\'s save puts '
            'the snapshot and the save on the same disk and the same frame',
      );

      await stopWorking();
      expect(
        await coordinator.dueTrigger(leavingForeground: false),
        BackupTrigger.inSession,
      );
    });

    test('leaving is still allowed in that same moment', () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      now = now.add(BackupCoordinator.minInterval + const Duration(minutes: 1));
      await addDebt('خالد');

      expect(
        await coordinator.dueTrigger(leavingForeground: true),
        BackupTrigger.onPause,
        reason: 'the quiet period protects a write the user can see; a user who '
            'is leaving cannot see it, so the cheapest moment stays available',
      );
    });

    test('the switch in Settings stops it entirely', () async {
      await addDebt('أحمد');
      final BackupCoordinator quiet = BackupCoordinator(
        database: db,
        backups: backups,
        settings: () => AppSettings.initial.copyWith(backupAutoEnabled: false),
        clock: () => now,
      );
      expect(await quiet.dueTrigger(leavingForeground: true), isNull);
      expect(await quiet.runIfDue(leavingForeground: true), isNull);
      expect(await backups.list(), isEmpty);
    });

    test('a record that changed is counted, and an untouched ledger is not',
        () async {
      await addDebt('أحمد');
      // The service writes with the real clock, so the comparison is made
      // against real time rather than against this test's fixture clock.
      final DateTime before = DateTime.now().subtract(const Duration(hours: 1));
      expect(await coordinator.changedRecordsSince(before), greaterThan(0));

      final DateTime after = DateTime.now().add(const Duration(hours: 1));
      expect(
        await coordinator.changedRecordsSince(after),
        0,
        reason: 'nothing has happened since a moment in the future',
      );
    });

    test('activity entries alone do not make a ledger look dirty', () async {
      await addDebt('أحمد');
      await coordinator.runIfDue(leavingForeground: true);
      final DateTime snapshotAt = DateTime.now();

      // A write that touches only the activity feed: the ledger is unchanged,
      // and the counter must agree.
      await service.refreshNotifications();
      expect(await coordinator.changedRecordsSince(snapshotAt), 0);
    });

    test('three boundaries at once write one file and give one answer',
        () async {
      await addDebt('أحمد');
      final List<BackupFileInfo?> results = await Future.wait<BackupFileInfo?>(
        <Future<BackupFileInfo?>>[
          coordinator.runIfDue(leavingForeground: true),
          coordinator.runIfDue(leavingForeground: true),
          coordinator.runIfDue(leavingForeground: true),
        ],
      );
      expect(await backups.list(), hasLength(1),
          reason: 'a pause, a resume and a burst arriving together are one '
              'snapshot, not three');
      expect(results.toSet(), hasLength(1),
          reason: 'every caller is told the same thing, because they are all '
              'waiting on the same snapshot');
    });
  });

  /// A snapshot that cannot be written, and what the app does about it.
  ///
  /// The only signal `dart:io` gives for a full disk is that the write fails, so
  /// a directory that refuses writes is the closest a test comes to one. The
  /// permission is checked by the expectation itself: if this environment
  /// ignored it the write would succeed and the test would fail loudly rather
  /// than passing without testing anything.
  /// The switch, flipped while the app is running.
  ///
  /// The case the device found: the coordinator reads the setting fresh on every
  /// decision, so what matters is that a change made *after* it started is seen
  /// by the next decision — and that turning it back on does not produce a
  /// snapshot out of nowhere, but re-runs the same policy as always.
  group('the switch, flipped while the app is running', () {
    late bool autoEnabled;
    late BackupCoordinator live;

    setUp(() {
      autoEnabled = true;
      live = BackupCoordinator(
        database: db,
        backups: backups,
        settings: () => AppSettings.initial.copyWith(backupAutoEnabled: autoEnabled),
        clock: () => now,
        attempts: BackupAttemptStore(directory: dir),
      );
      live.start();
    });

    test('off means no automatic snapshot, however due the ledger is', () async {
      await addDebt('أحمد');
      await live.runIfDue(leavingForeground: true);
      expect(await backups.list(), hasLength(1), reason: 'the first one landed');

      autoEnabled = false;
      await addDebt('خالد');
      now = now.add(const Duration(hours: 2));

      expect(
        await live.dueTrigger(leavingForeground: true),
        isNull,
        reason: 'the data has changed and the snapshot is old — and none of that '
            'matters while the user has said not to save on its own',
      );
      expect(await live.runIfDue(leavingForeground: true), isNull);
      expect(await backups.list(), hasLength(1), reason: 'and nothing was written');
    });

    test('turning it back on re-evaluates and takes the snapshot that is due',
        () async {
      await addDebt('أحمد');
      await live.runIfDue(leavingForeground: true);
      autoEnabled = false;
      await addDebt('خالد');
      now = now.add(const Duration(hours: 2));
      expect(await live.runIfDue(leavingForeground: true), isNull);

      autoEnabled = true;
      expect(
        await live.dueTrigger(leavingForeground: false),
        isNotNull,
        reason: 'the same policy as always: something changed and the last '
            'snapshot is old',
      );
      expect(await live.runIfDue(leavingForeground: false), isNotNull);
      expect(await backups.list(), hasLength(2));
    });

    test('turning it back on does not snapshot when nothing is due', () async {
      await addDebt('أحمد');
      await live.runIfDue(leavingForeground: true);
      autoEnabled = false;
      autoEnabled = true;

      expect(
        await live.runIfDue(leavingForeground: true),
        isNull,
        reason: 'flipping a switch is not a change to the ledger, and the app '
            'must not make a copy for one',
      );
      expect(await backups.list(), hasLength(1));
    });
  });

  group('when a snapshot cannot be written', () {
    Future<void> makeUnwritable() async {
      await Process.run('chmod', <String>['0555', dir.path]);
    }

    Future<void> makeWritable() async {
      await Process.run('chmod', <String>['0755', dir.path]);
    }

    /// One attempt at a moment where the policy says yes.
    Future<void> attempt() async {
      now = now.add(const Duration(hours: 1));
      await coordinator.runIfDue(leavingForeground: true);
    }

    setUp(() async {
      await addDebt('أحمد');
      // A good snapshot first, so "the previous one is still there" has
      // something to point at.
      await coordinator.runIfDue(leavingForeground: true);
      expect(await backups.list(), hasLength(1));
    });

    test('is remembered, and the next attempt is pushed out', () async {
      await makeUnwritable();
      await addDebt('خالد');
      await attempt();
      await makeWritable();

      expect(coordinator.attempts.consecutiveFailures, 1);
      expect(coordinator.attempts.lastFailure, BackupFailure.storage);
      expect(coordinator.attempts.lastSuccessAt, isNotNull);
      expect(
        await coordinator.runIfDue(leavingForeground: true),
        isNull,
        reason: 'a second attempt in the same moment is the retry loop the '
            'backoff exists to prevent',
      );
      expect(await backups.list(), hasLength(1));
    });

    test('tries again once the wait is over, and clears the record', () async {
      await makeUnwritable();
      await addDebt('خالد');
      await attempt();
      await makeWritable();

      now = now.add(BackupBackoff.base + const Duration(seconds: 1));
      expect(
        await coordinator.runIfDue(leavingForeground: true),
        isNotNull,
        reason: 'the wait is a delay, not a surrender',
      );
      expect(coordinator.attempts.consecutiveFailures, 0);
      expect(coordinator.attempts.lastFailure, isNull);
      expect(coordinator.attempts.lastSuccessAt, now);
      expect(await backups.list(), hasLength(2));
    });

    test('says so when it has failed enough times to be the user\'s business',
        () async {
      await makeUnwritable();
      for (int i = 0; i < BackupBackoff.giveUpAfter; i++) {
        await addDebt('شخص $i');
        await attempt();
      }
      await makeWritable();

      expect(coordinator.attempts.consecutiveFailures, BackupBackoff.giveUpAfter);
      expect(
        coordinator.attempts.needsAttention,
        isTrue,
        reason: 'five failures in a row is not a blip, and a status that kept '
            'calling it one would be lying to the user',
      );
      expect(await backups.list(), hasLength(1));
    });

    test('the wait survives a restart', () async {
      await makeUnwritable();
      await addDebt('خالد');
      await attempt();
      await makeWritable();

      // A new process, the same installation: a fresh coordinator reading the
      // same record must not decide the previous failures never happened.
      final BackupCoordinator restarted = BackupCoordinator(
        database: db,
        backups: backups,
        settings: () => AppSettings.initial,
        clock: () => now,
        attempts: BackupAttemptStore(directory: dir),
      );
      restarted.start();
      await restarted.ready;

      expect(restarted.attempts.consecutiveFailures, 1);
      expect(
        await restarted.runIfDue(leavingForeground: true),
        isNull,
        reason: 'a device that failed a minute ago and was restarted has not '
            'become able to write',
      );

      now = now.add(BackupBackoff.base + const Duration(seconds: 1));
      expect(await restarted.runIfDue(leavingForeground: true), isNotNull);
    });

    test('the user acting on the problem makes the app try again at once',
        () async {
      await makeUnwritable();
      await addDebt('خالد');
      await attempt();
      await makeWritable();

      expect(await coordinator.runIfDue(leavingForeground: true), isNull);

      // What re-authorizing a folder, choosing a new one, or asking for a check
      // does: the old failures are no longer evidence about the new situation.
      await coordinator.forgetFailures();

      expect(coordinator.attempts.consecutiveFailures, 0);
      expect(
        await coordinator.runIfDue(leavingForeground: true),
        isNotNull,
        reason: 'the user has just changed the thing that was broken, and '
            'making them wait out a backoff for it would be absurd',
      );
    });
  });
}
