import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/files/backup_location.dart';
import '../core/files/backup_location_repository.dart';
import '../core/files/file_gateway.dart';
import '../core/notifications/notification_composer.dart';
import '../data/services/backup_coordinator.dart';
import '../data/services/backup_restore_service.dart';
import '../data/services/backup_service.dart';
import '../data/services/external_backup_service.dart';
import '../data/services/ledger_service.dart';
import '../domain/services/backup_format.dart';
import '../domain/services/backup_progress.dart';
import '../domain/services/backup_protection.dart';
import '../domain/services/backup_validation.dart';
import '../domain/services/notification_planner.dart';
import '../l10n/generated/app_localizations.dart';
import 'providers.dart';

/// What the backup screen needs to know, worked out from the files and the
/// records rather than from a stored flag.
class BackupStatus {
  const BackupStatus({
    required this.last,
    required this.snapshots,
    required this.changedRecords,
    required this.hasLocalData,
    required this.autoEnabled,
  });

  /// The newest snapshot of any kind, or null when there has never been one.
  final BackupFileInfo? last;

  /// How many snapshots are on the device.
  final int snapshots;

  /// Records changed since that snapshot. Zero means nothing is waiting.
  final int changedRecords;

  final bool hasLocalData;
  final bool autoEnabled;

  bool get hasBackup => last != null;
  bool get isStale => last == null || changedRecords > 0;
  bool get isHealthy => last != null && changedRecords == 0;
}

/// The user's own storage: the system picker and the share sheet.
final Provider<FileGateway> fileGatewayProvider =
    Provider<FileGateway>((Ref ref) => const PlatformFileGateway());

/// Where the app keeps its own snapshots.
///
/// Null means "the app's documents directory", which is where a real install
/// keeps them: inside the sandbox, unreadable by anything else. It is a provider
/// so a test can point it at a temporary directory instead of reaching for the
/// platform, and so the choice is stated once rather than discovered inside the
/// service.
final Provider<Directory?> backupDirectoryProvider =
    Provider<Directory?>((Ref ref) => null);

final Provider<BackupService> backupServiceProvider =
    Provider<BackupService>((Ref ref) {
  return BackupService(
    database: ref.watch(databaseProvider),
    appVersion: ref.watch(appVersionProvider).value?.name ?? 'unknown',
    clock: () => ref.read(clockProvider)(),
    directory: ref.watch(backupDirectoryProvider),
  );
});

final Provider<BackupRestoreService> backupRestoreServiceProvider =
    Provider<BackupRestoreService>((Ref ref) {
  return BackupRestoreService(
    database: ref.watch(databaseProvider),
    backups: ref.watch(backupServiceProvider),
    rebuildDerivedState: () async {
      // Periods first, then the schedule: a restore can bring back a commitment
      // whose month has turned over, and the notifications have to describe the
      // restored records rather than the ones that were here before.
      final LedgerService ledger = ref.read(ledgerServiceProvider);
      await ledger.ensureOccurrences();
      await ledger.refreshNotifications();
    },
  );
});

/// The user's backup folder, chosen once and remembered.
///
/// Typed as the interface, so the rest of the app depends on the contract and a
/// test can stand in for the platform.
final Provider<BackupLocationRepository> backupLocationRepositoryProvider =
    Provider<BackupLocationRepository>((Ref ref) {
  return PlatformBackupLocationRepository();
});

/// What the folder is right now, checked when the screen opens.
final FutureProvider<BackupLocationHealth> backupLocationHealthProvider =
    FutureProvider<BackupLocationHealth>((Ref ref) async {
  return ref.watch(backupLocationRepositoryProvider).check();
});

/// Saving a copy into the user's backup folder, with the read-back check.
final Provider<ExternalBackupService> externalBackupServiceProvider =
    Provider<ExternalBackupService>((Ref ref) {
  return ExternalBackupService(
    backups: ref.watch(backupServiceProvider),
    folders: ref.watch(backupLocationRepositoryProvider),
    files: ref.watch(fileGatewayProvider),
  );
});

final Provider<BackupCoordinator> backupCoordinatorProvider =
    Provider<BackupCoordinator>((Ref ref) {
  final BackupCoordinator coordinator = BackupCoordinator(
    database: ref.watch(databaseProvider),
    backups: ref.watch(backupServiceProvider),
    settings: () => ref.read(effectiveSettingsProvider),
    clock: () => ref.read(clockProvider)(),
  );
  coordinator.start();
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// The listing, the age and the pending-change count, re-read on demand.
final FutureProvider<BackupStatus> backupStatusProvider =
    FutureProvider<BackupStatus>((Ref ref) async {
  // Every dependency is read *before* the first await, and that is deliberate.
  // A `watch` after an await registers the dependency late; if the settings or
  // the coordinator settle while this body is still running, the body is
  // restarted and the future the first caller is holding is abandoned — which
  // showed up as a status card that never left its spinner. Reading them up
  // front keeps one run and one answer.
  final BackupService backups = ref.watch(backupServiceProvider);
  final BackupCoordinator coordinator = ref.watch(backupCoordinatorProvider);
  final bool autoEnabled =
      ref.watch(effectiveSettingsProvider).backupAutoEnabled;

  final List<BackupFileInfo> all = await backups.list();
  final BackupFileInfo? last = all.isEmpty ? null : all.first;

  final int changed;
  if (last != null) {
    // The same rule the automatic snapshots are taken by, so the card and the
    // policy behind it cannot disagree: a snapshot dated in the future is
    // reported as pending, never as "saved".
    changed = await coordinator.pendingChanges();
  } else {
    changed = await backups.isEmpty() ? 0 : 1;
  }

  return BackupStatus(
    last: last,
    snapshots: all.length,
    changedRecords: changed,
    hasLocalData: !await backups.isEmpty(),
    autoEnabled: autoEnabled,
  );
});

/// The one sentence the user actually needs: are my data protected?
///
/// Built from the three layers of fact the app already has — the snapshots, the
/// folder's own report, and how the last attempts went — and folded into a single
/// state by [protectionFrom], which is pure and therefore tested on its own.
///
/// Both of the reads below are `watch`ed before any await, for the reason given
/// above: a dependency registered after an await is registered late, and the
/// first caller's future is abandoned when the provider is restarted.
final FutureProvider<BackupProtectionReport> backupProtectionProvider =
    FutureProvider<BackupProtectionReport>((Ref ref) async {
  final BackupStatus status = await ref.watch(backupStatusProvider.future);
  final AsyncValue<BackupLocationHealth> folder =
      ref.watch(backupLocationHealthProvider);
  final BackupCoordinator coordinator = ref.watch(backupCoordinatorProvider);
  await coordinator.ready;

  final BackupLocationHealth? health = folder.value;
  return protectionFrom(
    BackupProtectionInputs(
      hasLocalData: status.hasLocalData,
      snapshots: status.snapshots,
      folderBackups: health?.validBackups ?? 0,
      changedRecords: status.changedRecords,
      autoEnabled: status.autoEnabled,
      folderConfigured: health != null &&
          health.status != BackupLocationStatus.notConfigured,
      folderRevoked: health?.status == BackupLocationStatus.permissionRevoked,
      folderUnavailable: health?.status == BackupLocationStatus.unavailable,
      folderReadOnly: health?.status == BackupLocationStatus.readOnly,
      attempts: coordinator.attempts,
      newestSnapshotAt: status.last?.createdAt,
      newestFolderCopyAt: health?.newestBackupAt,
    ),
  );
});

/// A file the user chose, with the verdict on it.
///
/// [backup] is null when the file could not be read as a backup at all; the
/// verdict then carries the reason, and nothing here touches the ledger.
class InspectedBackup {
  const InspectedBackup({
    required this.path,
    required this.backup,
    required this.validation,
  });

  final String path;
  final ParsedBackup? backup;
  final BackupValidation validation;

  BackupPreview? get preview => validation.preview;

  bool get canRestore => backup != null && validation.isUsable;
}

/// Everything the backup screens do, in one place, so the widgets stay about
/// layout and the rules stay testable.
class BackupController {
  BackupController(this._ref);

  final Ref _ref;

  BackupService get _backups => _ref.read(backupServiceProvider);
  FileGateway get _files => _ref.read(fileGatewayProvider);

  /// The repository for the user's backup folder.
  BackupLocationRepository get _folders =>
      _ref.read(backupLocationRepositoryProvider);

  /// Saves a verified copy into the user's backup folder.
  ///
  /// This is the backup action: it does not depend on any other application
  /// being installed, it uses the folder chosen once, and it reports success
  /// only after the document has been read back and checked. [onStep] names the
  /// work while it happens.
  Future<ExternalSaveReport> saveExternal({
    void Function(BackupStep step)? onStep,
  }) async {
    final ExternalSaveReport report =
        await _ref.read(externalBackupServiceProvider).save(onStep: onStep);
    _ref.invalidate(backupStatusProvider);
    _ref.invalidate(backupLocationHealthProvider);
    return report;
  }

  /// Discusses the whole ledger with no way back, so a copy is kept first.
  ///
  /// Called before the two actions that are irreversible for the user — clearing
  /// all data, and deleting a person — and deliberately not before ordinary edits:
  /// a snapshot per deletion would be a snapshot per tap, and the policy that
  /// decides when to write one exists precisely so that this is not needed
  /// everywhere.
  ///
  /// Guarded by freshness rather than run every time, so ten deletions in a row
  /// make one copy and not ten — as long as the recent copy still holds the
  /// ledger as it is. Returns the file when it made one, and null when the
  /// recent snapshot already covered it, or when there is nothing to protect.
  Future<BackupFileInfo?> safetyBeforeDestructive() async {
    final BackupService backups = _ref.read(backupServiceProvider);
    if (await backups.isEmpty()) return null;

    final BackupFileInfo? last = await backups.latest();
    final DateTime now = _ref.read(clockProvider)();
    if (last != null && now.difference(last.createdAt) < safetyFreshness) {
      // Recent is not enough on its own: a copy from two minutes ago does not
      // hold the three debts added one minute ago, and deleting everything
      // then left them in no copy at all. It stands in only when nothing has
      // changed since it was written.
      final int pending =
          await _ref.read(backupCoordinatorProvider).pendingChanges();
      if (pending == 0) return null;
    }
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.safety);
    _ref.invalidate(backupStatusProvider);
    return BackupFileInfo(
      path: written.file.path,
      kind: BackupKind.safety,
      createdAt: now,
      sizeBytes: await written.file.length(),
    );
  }

  /// How recent a snapshot has to be for a destructive action to go ahead
  /// without making another one.
  ///
  /// Ten minutes: long enough that a run of deletions shares one copy, short
  /// enough that the copy is of the ledger the user is looking at.
  static const Duration safetyFreshness = Duration(minutes: 10);

  /// Asks the user to choose the backup folder, and remembers it.
  ///
  /// Null when they backed out. A folder the app could not make
  /// `Dhimmah Backups` inside is returned with
  /// [FolderDisposition.needsConfirmation], and using it is the user's call.
  Future<ChosenFolder?> chooseFolder() async {
    final ChosenFolder? chosen = await _folders.chooseLocation();
    // Whatever was wrong before, the user has just changed it. Making them wait
    // out a backoff earned by the old folder would be absurd.
    await _actedOnTheProblem();
    _ref.invalidate(backupLocationHealthProvider);
    return chosen;
  }

  /// Forgets the folder and gives the platform its grant back.
  Future<void> forgetFolder() async {
    await _folders.clearLocation();
    _ref.invalidate(backupLocationHealthProvider);
  }

  /// The folder as it is right now.
  ///
  /// Asking for a check is the user acting on the problem, so it also clears the
  /// record of failed attempts: if the check finds the folder healthy, the very
  /// next automatic attempt should be allowed to happen.
  Future<BackupLocationHealth> checkFolder({bool deep = false}) async {
    await _actedOnTheProblem();
    _ref.invalidate(backupLocationHealthProvider);
    return _ref.read(backupLocationRepositoryProvider).check(deep: deep);
  }

  /// Records that the user has just done something about a problem.
  ///
  /// Choosing a folder, re-authorizing one, or asking for a check all mean the
  /// situation the failures described is no longer the situation. Forgetting the
  /// failures lets the very next automatic attempt happen instead of waiting out
  /// a delay the app earned when it was broken.
  ///
  /// It deliberately does not forget *when a snapshot last worked*: that is a
  /// fact about the data, and the user re-authorizing a folder has not just made
  /// a backup.
  Future<void> _actedOnTheProblem() async {
    await _ref.read(backupCoordinatorProvider).forgetFailures();
  }

  /// Re-reads everything the app knows about protection, from its sources.
  ///
  /// The point is that nothing is taken on trust: the snapshot list is re-read
  /// from the directory, the folder is re-asked what it actually holds, and the
  /// attempt record is re-read from its file. Anything cached is thrown away
  /// first, because a cache is exactly what goes stale in the situations this
  /// exists for — the app coming back to the foreground after the user deleted
  /// files in their own file manager, or came back from a reinstall.
  ///
  /// Called after the first frame, on every resume, after a folder is chosen or
  /// re-authorized, and whenever the backup screen is opened. Deliberately not
  /// before the first frame: it reads a directory and a provider, and the
  /// dashboard must not wait for it.
  Future<void> reconcile() async {
    _ref.invalidate(backupStatusProvider);
    _ref.invalidate(backupLocationHealthProvider);
    try {
      await _ref.read(backupStatusProvider.future);
      // The folder is read through its provider, so the health the screen will
      // show is the one this just fetched rather than the one it had.
      await _ref.read(backupLocationHealthProvider.future);
    } on Object {
      // A reconciliation that could not complete leaves the previous reading in
      // place, which is better than blanking the screen: the next boundary tries
      // again, and nothing here is a reason to disturb the user.
      return;
    }
    await _alertIfProtectionBroke();
  }

  /// The last state a notification was posted for, so the same problem does not
  /// become a notification every time the app is opened.
  ///
  /// Only the state, and only for this run: an app has no business keeping a
  /// record across launches of what it has already told the user, and a problem
  /// that is still there tomorrow is still worth one sentence tomorrow. It is
  /// re-armed as soon as protection is healthy again, so a problem that comes
  /// back is announced again.
  BackupProtection? _alertedFor;

  /// Says so, once, when the app can no longer keep its promise.
  ///
  /// Deliberately narrow: a successful snapshot never notifies — the whole point
  /// of automatic saving is that it is silent — and neither does a state the app
  /// is still handling on its own. Only the two states the user has to act on,
  /// and only when the state changes.
  Future<void> _alertIfProtectionBroke() async {
    final BackupProtectionReport report;
    try {
      report = await _ref.read(backupProtectionProvider.future);
    } on Object {
      return;
    }

    final bool broken = report.state == BackupProtection.attentionNeeded ||
        report.state == BackupProtection.storageIssue;
    if (!broken) {
      // Healthy again: if it breaks again, that is news again.
      _alertedFor = null;
      return;
    }
    if (_alertedFor == report.state) return;
    _alertedFor = report.state;

    final AppLocalizations localizations = _ref.read(localizationsProvider);
    await _ref.read(notificationServiceProvider).showNow(
          ComposedNotification(
            // One id for this kind of message, so a second alert replaces the
            // first rather than stacking — the same identity rule the reminders
            // are built on.
            id: _backupAlertId,
            title: localizations.backupAlertTitle,
            body: localizations.backupAlertBody,
            payload: 'backup:problem',
            when: _ref.read(clockProvider)(),
            kind: NotificationKind.backupProblem,
            priority: NotificationPriority.alert,
          ),
        );
  }

  /// A fixed id for the backup alert: there is one such message at a time.
  static const int _backupAlertId = 0x0D11;

  /// The backups in the folder, each classified by its content.
  Future<List<ExternalBackupFile>> externalBackups() =>
      _ref.read(backupLocationRepositoryProvider).listBackups();

  /// Where a restore picker should start, when a folder is configured.
  Future<String?> restoreStartLocation() => _folders.initialLocation();

  /// Removes one backup document from the user's folder.
  Future<void> deleteExternal(ExternalBackupFile file) async {
    await _folders.deleteBackup(file);
    _ref.invalidate(backupLocationHealthProvider);
  }

  /// Reads one backup document from the folder.
  Future<List<int>> readExternal(ExternalBackupFile file) =>
      _folders.readBackup(file);

  /// Takes a snapshot now and offers it to the system share sheet.
  ///
  /// The secondary action: a share asks another application to take a copy, and
  /// it is a convenience beside [saveExternal] rather than the way a backup is
  /// kept.
  Future<File> shareNow({
    void Function(BackupStep step)? onStep,
  }) async {
    final ({File file, ParsedBackup backup}) written =
        await _backups.create(kind: BackupKind.manual, onStep: onStep);
    await _files.shareFile(
      written.file.path,
      subject: _ref.read(localizationsProvider).settingsBackup,
    );
    _ref.invalidate(backupStatusProvider);
    return written.file;
  }

  /// Opens the picker and inspects whatever the user chose.
  ///
  /// Returns null when they cancelled. A file that cannot be read comes back
  /// with its verdict, so the screen can say *why* rather than "failed".
  ///
  /// The file is parsed **once**. Reading it here and again to hand the rows to
  /// the restore meant decoding, checksumming and validating the same bytes
  /// twice — which at ten thousand records is about a second of work for a
  /// second identical answer.
  Future<InspectedBackup?> pickAndInspect({
    void Function(RestoreStep step)? onStep,
  }) async {
    // The picker starts in the backup folder when there is one. It is a hint:
    // providers ignore it at their discretion, and a picker that opens
    // somewhere else still works.
    final String? startAt = await _folders.initialLocation();
    final String? path = await _files.pickBackupFile(initialDirectory: startAt);
    if (path == null) return null;
    return inspectPath(path, onStep: onStep);
  }

  /// Inspects a backup the app can reach *without* the user finding it in a
  /// picker — an internal snapshot, or a document in the backup folder.
  ///
  /// This is the recovery path that was missing: the app keeps complete,
  /// verified snapshots, and a restore that asks the user to go and find a file
  /// first makes the safest copy the hardest one to use. The same parse,
  /// checksum and validation apply as for a picked file.
  Future<InspectedBackup?> inspectPath(
    String path, {
    void Function(RestoreStep step)? onStep,
  }) async {
    try {
      final ({ParsedBackup backup, BackupValidation validation}) opened =
          await _backups.open(path, onStep: onStep);
      return InspectedBackup(
        path: path,
        backup: opened.backup,
        validation: opened.validation,
      );
    } on BackupFormatException catch (error) {
      return InspectedBackup(
        path: path,
        backup: null,
        validation: BackupValidation(
          errors: <BackupIssue>[
            BackupIssue(code: error.problem.name, detail: error.problem.name),
          ],
          warnings: const <BackupIssue>[],
          preview: null,
        ),
      );
    }
  }

  /// The file behind an internal snapshot.
  Future<InspectedBackup?> inspectInternal(
    BackupFileInfo info, {
    void Function(RestoreStep step)? onStep,
  }) =>
      inspectPath(info.path, onStep: onStep);

  /// The document behind a folder backup, copied into the app's own temporary
  /// storage so the same reader can open it.
  ///
  /// A folder document is reached through a platform handle that is not a path,
  /// and the restore reads a path — so the bytes are copied once, locally, and
  /// the copy is what gets parsed. Nothing in the folder is changed.
  Future<InspectedBackup?> inspectExternal(
    ExternalBackupFile file, {
    void Function(RestoreStep step)? onStep,
  }) async {
    final List<int> bytes = await _folders.readBackup(file);
    final Directory temp = await getTemporaryDirectory();
    final File copy = File(
      '${temp.path}/restore-${DateTime.now().millisecondsSinceEpoch}'
      '${BackupFormat.extension}',
    );
    await copy.writeAsBytes(bytes, flush: true);
    return inspectPath(copy.path, onStep: onStep);
  }

  Future<RestoreReport> apply({
    required InspectedBackup inspected,
    required RestoreMode mode,
    void Function(RestoreStep step)? onStep,
  }) async {
    final ParsedBackup? backup = inspected.backup;
    if (backup == null) {
      throw const BackupFormatException(BackupProblem.unreadablePayload);
    }
    final RestoreReport report = await _ref
        .read(backupRestoreServiceProvider)
        .apply(backup: backup, mode: mode, onStep: onStep);
    _ref.invalidate(backupStatusProvider);
    return report;
  }

  Future<void> delete(BackupFileInfo info) async {
    await _backups.delete(info.path);
    _ref.invalidate(backupStatusProvider);
  }

  Future<void> share(BackupFileInfo info) => _files.shareFile(
        info.path,
        subject: _ref.read(localizationsProvider).settingsBackup,
      );

  Future<void> setAutoEnabled(bool enabled) async {
    await _ref.read(settingsControllerProvider).setBackupAutoEnabled(enabled);
    _ref.invalidate(backupStatusProvider);
  }
}

final Provider<BackupController> backupControllerProvider =
    Provider<BackupController>(BackupController.new);
