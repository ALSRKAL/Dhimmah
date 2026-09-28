import 'package:dhimmah/domain/services/backup_attempts.dart';
import 'package:dhimmah/domain/services/backup_protection.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the app tells the user about their protection, and in what order it
/// decides.
///
/// This is the one sentence most users will ever read about their backups, so
/// the cases are enumerated rather than sampled: every state has a test, and so
/// does every pair where one has to outrank the other. The ordering is the whole
/// of the judgement, and an ordering that is only implied by the code is an
/// ordering that changes by accident.
void main() {
  final DateTime now = DateTime(2026, 9, 27, 18);

  /// Everything fine, then whatever the test cares about.
  BackupProtectionInputs inputs({
    bool hasLocalData = true,
    int snapshots = 3,
    int folderBackups = 4,
    int changedRecords = 0,
    bool autoEnabled = true,
    bool folderConfigured = true,
    bool folderRevoked = false,
    bool folderUnavailable = false,
    bool folderReadOnly = false,
    BackupAttempts? attempts,
    DateTime? newestSnapshotAt,
    bool isWorking = false,
  }) {
    return BackupProtectionInputs(
      hasLocalData: hasLocalData,
      snapshots: snapshots,
      folderBackups: folderBackups,
      changedRecords: changedRecords,
      autoEnabled: autoEnabled,
      folderConfigured: folderConfigured,
      folderRevoked: folderRevoked,
      folderUnavailable: folderUnavailable,
      folderReadOnly: folderReadOnly,
      attempts: attempts ?? BackupAttempts.none.succeeded(now),
      // Derived rather than defaulted: a device with no snapshot has no newest
      // snapshot time, and letting a test build that impossible pair would only
      // hide the case where it matters.
      newestSnapshotAt: snapshots == 0
          ? null
          : newestSnapshotAt ?? now.subtract(const Duration(hours: 1)),
      isWorking: isWorking,
    );
  }

  group('each state', () {
    test('protected when nothing is waiting and everything works', () {
      final BackupProtectionReport report = protectionFrom(inputs());
      expect(report.state, BackupProtection.protected);
      expect(report.needsUser, isFalse);
      expect(report.copies, 7, reason: 'three inside, four in the folder');
      expect(report.lastSuccess, now);
    });

    test('backing up while a snapshot is being written', () {
      expect(
        protectionFrom(inputs(isWorking: true)).state,
        BackupProtection.backingUp,
      );
    });

    test('pending when changes are waiting', () {
      final BackupProtectionReport report =
          protectionFrom(inputs(changedRecords: 4));
      expect(report.state, BackupProtection.pending);
      expect(report.pendingChanges, 4);
      expect(
        report.needsUser,
        isFalse,
        reason: 'waiting changes are the app\'s job, not the user\'s — this is '
            'the state a warning would turn into nagging',
      );
    });

    test('never backed up when there is a ledger and no copy of it anywhere',
        () {
      final BackupProtectionReport report = protectionFrom(
        inputs(snapshots: 0, folderBackups: 0, attempts: BackupAttempts.none),
      );
      expect(report.state, BackupProtection.neverBackedUp);
      expect(report.needsUser, isTrue);
      expect(report.copies, 0);
    });

    test('recoverable when there is nothing here and copies to put back', () {
      final BackupProtectionReport report = protectionFrom(
        inputs(hasLocalData: false, snapshots: 0, folderBackups: 6),
      );
      expect(report.state, BackupProtection.recoverable);
      expect(report.needsUser, isFalse, reason: 'nothing is wrong; there is '
          'simply something to do, and the screen offers it');
    });

    test('attention needed when the folder\'s permission was taken back', () {
      expect(
        protectionFrom(inputs(folderRevoked: true)).state,
        BackupProtection.attentionNeeded,
      );
    });

    test('attention needed when the folder cannot be used', () {
      expect(
        protectionFrom(inputs(folderUnavailable: true)).state,
        BackupProtection.attentionNeeded,
      );
    });

    test('attention needed when the app has failed enough times in a row', () {
      BackupAttempts failed = BackupAttempts.none;
      for (int i = 0; i < BackupBackoff.giveUpAfter; i++) {
        failed = failed.failed(now, BackupFailure.storage);
      }
      final BackupProtectionReport report =
          protectionFrom(inputs(attempts: failed));
      expect(report.state, BackupProtection.attentionNeeded);
      expect(report.consecutiveFailures, BackupBackoff.giveUpAfter);
      expect(report.lastFailure, BackupFailure.storage);
    });

    test('a storage issue when the folder refuses writes', () {
      expect(
        protectionFrom(inputs(folderReadOnly: true)).state,
        BackupProtection.storageIssue,
      );
    });

    test('a storage issue after one failure of the app\'s own write', () {
      final BackupAttempts once =
          BackupAttempts.none.failed(now, BackupFailure.storage);
      expect(
        protectionFrom(inputs(attempts: once)).state,
        BackupProtection.storageIssue,
      );
    });

    test('says nothing is being taken when automatic saving is off', () {
      final BackupProtectionReport report =
          protectionFrom(inputs(autoEnabled: false));
      expect(report.state, BackupProtection.automaticOff);
      expect(
        report.needsUser,
        isTrue,
        reason: 'the user can turn it back on, and no amount of waiting will '
            'add another copy on its own',
      );
      expect(report.copies, 7, reason: 'and the copies they have are still there');
    });

    test('no location when the copies live only inside the app', () {
      final BackupProtectionReport report = protectionFrom(
        inputs(folderConfigured: false, folderBackups: 0),
      );
      expect(report.state, BackupProtection.noLocation);
      expect(
        report.needsUser,
        isTrue,
        reason: 'an uninstalled app takes its own snapshots with it, so this is '
            'worth the user\'s attention even though nothing has failed',
      );
      expect(report.copies, 3, reason: 'the in-app snapshots still protect them');
    });
  });

  group('the order between states', () {
    test('a snapshot in flight outranks every problem', () {
      final BackupProtectionReport report = protectionFrom(
        inputs(isWorking: true, folderRevoked: true, changedRecords: 9),
      );
      expect(
        report.state,
        BackupProtection.backingUp,
        reason: 'reporting a problem while the app is in the middle of handling '
            'it is noise at the worst possible moment',
      );
    });

    test('a wiped device with copies outranks a broken folder', () {
      final BackupProtectionReport report = protectionFrom(
        inputs(
          hasLocalData: false,
          snapshots: 0,
          folderBackups: 5,
          folderRevoked: true,
        ),
      );
      expect(
        report.state,
        BackupProtection.recoverable,
        reason: 'the only thing that matters to this user is putting their data '
            'back, and a revoked grant is a step in doing that — not the '
            'headline',
      );
    });

    test('nothing protected at all outranks a broken folder', () {
      final BackupProtectionReport report = protectionFrom(
        inputs(snapshots: 0, folderBackups: 0, folderRevoked: true),
      );
      expect(
        report.state,
        BackupProtection.neverBackedUp,
        reason: 'a broken folder is a problem with the protection the user has; '
            'this is not having any',
      );
    });

    test('automatic saving off outranks changes that are waiting', () {
      final BackupProtectionReport report = protectionFrom(
        inputs(autoEnabled: false, changedRecords: 6),
      );
      expect(
        report.state,
        BackupProtection.automaticOff,
        reason: 'with the app not saving on its own, waiting changes are not '
            'going to be captured by waiting — this is the more useful fact',
      );
      expect(report.pendingChanges, 6, reason: 'without hiding the count');
    });

    test('a missing folder outranks automatic saving being off, and the other way round is not true', () {
      expect(
        protectionFrom(inputs(autoEnabled: false, folderConfigured: false))
            .state,
        BackupProtection.noLocation,
        reason: 'with no folder at all, turning automatic saving back on would '
            'still leave the copies nowhere durable',
      );
      expect(
        protectionFrom(inputs(autoEnabled: false)).state,
        BackupProtection.automaticOff,
      );
    });

    test('a revoked folder outranks a read-only one and pending changes', () {
      expect(
        protectionFrom(
          inputs(folderRevoked: true, folderReadOnly: true, changedRecords: 3),
        ).state,
        BackupProtection.attentionNeeded,
      );
    });

    test('a folder that refuses writes outranks having no folder at all', () {
      expect(
        protectionFrom(inputs(folderReadOnly: true)).state,
        BackupProtection.storageIssue,
      );
    });

    test('having no folder outranks pending changes', () {
      expect(
        protectionFrom(
          inputs(folderConfigured: false, folderBackups: 0, changedRecords: 7),
        ).state,
        BackupProtection.noLocation,
        reason: 'the pending changes will be captured on their own; the missing '
            'durable copy will not fix itself',
      );
    });

    test('automatic saving off is never reported as protection', () {
      // The acceptance rule, stated as a test: there must be no state in which
      // the user reads "your data is protected" while the app is not saving on
      // its own. Every combination of data, copies and folder is walked, and
      // none of them may come back `protected`.
      for (final bool data in <bool>[true, false]) {
        for (final int inside in <int>[0, 3]) {
          for (final int outside in <int>[0, 4]) {
            final BackupProtectionReport report = protectionFrom(
              inputs(
                hasLocalData: data,
                snapshots: inside,
                folderBackups: outside,
                autoEnabled: false,
              ),
            );
            expect(
              report.state,
              isNot(BackupProtection.protected),
              reason: 'data=$data inside=$inside outside=$outside',
            );
          }
        }
      }
      // And the case the user is most likely to be in — copies exist, nothing
      // new is being added — says exactly that.
      expect(
        protectionFrom(inputs(autoEnabled: false)).state,
        BackupProtection.automaticOff,
      );
    });

    test('a fresh install is asked for a folder, not congratulated', () {
      // A fresh install has nothing to protect — but it also has nowhere to put
      // anything, and this is the first screen the product shows anyone. It read
      // `protected`, which on the phone put `بياناتك محمية` above a line saying
      // no copy had ever been made and above a card asking the user to choose a
      // folder. The state is `noLocation`: not alarming — "your data is not
      // protected yet" is reserved for a ledger that holds something — but not a
      // claim of protection either.
      final BackupProtectionReport report = protectionFrom(
        inputs(
          hasLocalData: false,
          snapshots: 0,
          folderBackups: 0,
          folderConfigured: false,
          attempts: BackupAttempts.none,
        ),
      );
      expect(report.state, BackupProtection.noLocation);
      expect(
        report.needsUser,
        isTrue,
        reason: 'the one thing this install needs is a folder, and saying so is '
            'the point: nothing is broken, but nothing is arranged either',
      );
      expect(
        report.state,
        isNot(BackupProtection.neverBackedUp),
        reason: 'an empty ledger must never be told its data is unprotected',
      );
    });
  });

  group('when it last worked', () {
    test('is the attempt record when there is one', () {
      final DateTime worked = now.subtract(const Duration(hours: 3));
      final BackupProtectionReport report = protectionFrom(
        inputs(attempts: BackupAttempts.none.succeeded(worked)),
      );
      expect(report.lastSuccess, worked);
    });

    test('falls back to the newest snapshot after a restore', () {
      final DateTime snapshot = now.subtract(const Duration(days: 2));
      final BackupProtectionReport report = protectionFrom(
        inputs(
          attempts: BackupAttempts.none,
          newestSnapshotAt: snapshot,
          folderBackups: 6,
        ),
      );
      expect(
        report.lastSuccess,
        snapshot,
        reason: 'a device restored from a backup has copies and no attempt '
            'history, and saying "never" there would be false',
      );
    });

    test('is nothing when there is nothing', () {
      expect(
        protectionFrom(
          inputs(
            snapshots: 0,
            folderBackups: 0,
            attempts: BackupAttempts.none,
          ),
        ).lastSuccess,
        isNull,
      );
    });
  });

  group('what it asks of the user', () {
    test('nothing, in the states where the app is coping', () {
      for (final BackupProtection state in <BackupProtection>[
        BackupProtection.protected,
        BackupProtection.pending,
        BackupProtection.backingUp,
        BackupProtection.recoverable,
      ]) {
        expect(
          protectionFrom(inputs(isWorking: state == BackupProtection.backingUp))
              .needsUser,
          isFalse,
          reason: '$state is not the user\'s problem to solve',
        );
      }
    });

    test('attention, in the states where it is', () {
      for (final BackupProtectionInputs broken in <BackupProtectionInputs>[
        inputs(folderRevoked: true),
        inputs(folderReadOnly: true),
        inputs(snapshots: 0, folderBackups: 0),
        inputs(folderConfigured: false, folderBackups: 0),
        inputs(autoEnabled: false),
      ]) {
        expect(protectionFrom(broken).needsUser, isTrue);
      }
    });
  });
}
