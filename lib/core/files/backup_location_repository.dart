import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../domain/services/backup_format.dart';
import 'backup_folder_channel.dart';
import 'backup_location.dart';
import 'backup_location_store.dart';

/// The user's backup folder, as one platform-neutral contract.
///
/// This is the layer the rest of the app is allowed to see. It answers the
/// questions the interface needs — is there a folder, does it work, what is in
/// it — and never exposes *how* a platform grants that access. A `content://`
/// tree URI and a security-scoped bookmark are the same thing to this interface,
/// and neither is ever converted into a path, because a tree URI is not a path
/// and behaves like one only on some providers.
abstract interface class BackupLocationRepository {
  /// The folder as last chosen and remembered, without touching the platform.
  Future<BackupLocation?> getConfiguredLocation();

  /// Asks the user to choose one. Null means they backed out.
  ///
  /// The returned [ChosenFolder.disposition] says how the folder came to be
  /// `Dhimmah Backups`; a folder the app could not make that subfolder inside is
  /// reported as needing the user's agreement rather than adopted silently.
  Future<ChosenFolder?> chooseLocation();

  /// Checks the folder now, and returns how it is.
  ///
  /// [deep] writes a probe file and takes it away again, which is the only way
  /// to know a folder that lists fine also accepts writes. It costs a write to
  /// the user's folder, so it is done when asked for, not on every screen.
  Future<BackupLocationHealth> check({bool deep});

  /// The `.dhimmah` files in the folder, each classified by its content.
  ///
  /// This is the authoritative list of the user's external backups: files the
  /// user added, deleted or moved outside the app are simply what the folder
  /// says, so there is nothing to go stale.
  Future<List<ExternalBackupFile>> listBackups();

  /// Writes a new backup document into the folder, then reads it back.
  Future<ExternalBackupFile> createBackupFile({
    required String suggestedName,
    required List<int> bytes,
  });

  /// Reads a backup document's bytes.
  Future<List<int>> readBackup(ExternalBackupFile file);

  /// Removes one backup document from the folder.
  Future<void> deleteBackup(ExternalBackupFile file);

  /// The folder's identifier, for opening a picker in the right place.
  Future<String?> initialLocation();

  /// Forgets the folder, and gives the platform the grant back.
  Future<void> clearLocation();
}

/// The real repository, over the platform's own directory access.
class PlatformBackupLocationRepository implements BackupLocationRepository {
  PlatformBackupLocationRepository({BackupLocationStore? store}) : _store = store ?? const BackupLocationStore();

  final BackupLocationStore _store;

  /// Folders hold at most a handful of backups, and a Dhimmah file at ten
  /// thousand records is a few megabytes. Anything far larger than that named
  /// `.dhimmah` is not a backup this app wrote, and reading it would only be to
  /// say so; it is classified without being read.
  static const int _maxInspectedBytes = 64 * 1024 * 1024;

  BackupLocation? _current;

  @override
  Future<BackupLocation?> getConfiguredLocation() async {
    _current ??= await _store.read();
    return _current;
  }

  @override
  Future<ChosenFolder?> chooseLocation() async {
    final ChosenFolderDocument? chosen = await BackupFolderChannel.chooseFolder();
    if (chosen == null) return null;

    // The folder the user picked may be the one to use, or the parent of the one
    // to use. If the app can make `Dhimmah Backups` inside it, that is where the
    // backups go; if the provider refuses, the app does not quietly adopt an
    // arbitrary folder — it asks.
    FolderDisposition disposition;
    String identifier = chosen.identifier;
    String displayName = chosen.displayName;
    if (displayName == BackupFolderChannel.folderName) {
      disposition = FolderDisposition.alreadyNamed;
    } else {
      try {
        final ChosenFolderDocument subfolder = await BackupFolderChannel.createFolder(
          identifier: chosen.identifier,
        );
        identifier = subfolder.identifier;
        displayName = subfolder.displayName;
        disposition = FolderDisposition.subfolderCreated;
      } on FolderException catch (error) {
        if (error.failure == FolderFailure.forbidden ||
            error.failure == FolderFailure.readOnly) {
          final BackupLocation location = await _remember(
            chosen.identifier,
            chosen.displayName,
            chosen.isPersisted,
          );
          return ChosenFolder(
            location: location,
            disposition: FolderDisposition.needsConfirmation,
          );
        }
        rethrow;
      }
    }

    return ChosenFolder(
      location: await _remember(identifier, displayName, chosen.isPersisted),
      disposition: disposition,
      subfolderCreated: disposition == FolderDisposition.subfolderCreated,
    );
  }

  /// Remembers the folder, and does not return until it is written.
  ///
  /// A choice that the app forgets because the process stopped a moment later is
  /// worse than no choice at all: the user believed the folder was set.
  Future<BackupLocation> _remember(
    String identifier,
    String displayName,
    bool persisted,
  ) async {
    final BackupLocation location = BackupLocation(
      identifier: identifier,
      displayName: displayName,
      platform: defaultTargetPlatform == TargetPlatform.iOS
          ? BackupPlatform.ios
          : BackupPlatform.android,
      verifiedAt: DateTime.now(),
      isPersisted: persisted,
    );
    _current = location;
    await _store.write(location);
    return location;
  }

  @override
  Future<BackupLocationHealth> check({bool deep = false}) async {
    final BackupLocation? configured = await getConfiguredLocation();
    if (configured == null) return const BackupLocationHealth.notConfigured();

    final DateTime now = DateTime.now();
    ChosenFolderDocument described;
    try {
      described = await BackupFolderChannel.describeFolder(
        identifier: configured.identifier,
      );
    } on FolderException catch (error) {
      return BackupLocationHealth(
        status: error.failure == FolderFailure.forbidden
            ? BackupLocationStatus.permissionRevoked
            : BackupLocationStatus.unavailable,
        checkedAt: now,
        detail: error.detail,
      );
    }

    int valid = 0;
    int invalid = 0;
    int other = 0;
    List<ExternalBackupFile> children;
    try {
      children = await _classify(await BackupFolderChannel.listDocuments(
        identifier: configured.identifier,
      ));
    } on FolderException catch (error) {
      return BackupLocationHealth(
        status: error.failure == FolderFailure.forbidden
            ? BackupLocationStatus.permissionRevoked
            : BackupLocationStatus.unavailable,
        checkedAt: now,
        detail: error.detail,
      );
    }
    // What the folder holds, and when its newest usable copy was made. The
    // timestamp is taken from the file's own envelope rather than from the
    // filesystem, for the same reason validity is decided by content: a copied
    // or restored file has a modification time that says when it was copied,
    // and the question being answered is when the data was captured.
    DateTime? newest;
    for (final ExternalBackupFile file in children) {
      switch (file.validity) {
        case ExternalFileValidity.valid:
          valid++;
          final DateTime? made = file.createdAt ?? file.modifiedAt;
          if (made != null && (newest == null || made.isAfter(newest))) {
            newest = made;
          }
        case ExternalFileValidity.invalid:
          invalid++;
        case ExternalFileValidity.unrelated:
          other++;
        case ExternalFileValidity.unchecked:
          break;
      }
    }

    // A grant that dies with this process is not a folder the app can promise to
    // come back to, so it is reported as needing re-authorization rather than as
    // available.
    if (!described.isPersisted || !configured.isPersisted) {
      return BackupLocationHealth(
        status: BackupLocationStatus.permissionRevoked,
        checkedAt: now,
        validBackups: valid,
        invalidFiles: invalid,
        otherFiles: other,
        newestBackupAt: newest,
      );
    }

    if (deep) {
      try {
        await BackupFolderChannel.verifyWritable(identifier: configured.identifier);
      } on FolderException catch (error) {
        return BackupLocationHealth(
          status: error.failure == FolderFailure.readOnly
              ? BackupLocationStatus.readOnly
              : BackupLocationStatus.unavailable,
          checkedAt: now,
          detail: error.detail,
          validBackups: valid,
          invalidFiles: invalid,
          otherFiles: other,
          newestBackupAt: newest,
        );
      }
    }

    return BackupLocationHealth(
      status: BackupLocationStatus.available,
      checkedAt: now,
      validBackups: valid,
      invalidFiles: invalid,
      otherFiles: other,
      newestBackupAt: newest,
    );
  }

  @override
  Future<List<ExternalBackupFile>> listBackups() async {
    final BackupLocation? configured = await getConfiguredLocation();
    if (configured == null) return const <ExternalBackupFile>[];
    return _classify(await BackupFolderChannel.listDocuments(
      identifier: configured.identifier,
    ));
  }

  /// Reads what the folder holds and says what each file is.
  ///
  /// The name is never the evidence: a `.dhimmah` suffix on a file that is not a
  /// backup is exactly how the folder fills up with things that look right, and
  /// the content decides.
  Future<List<ExternalBackupFile>> _classify(
    List<FolderDocument> documents,
  ) async {
    final List<ExternalBackupFile> out = <ExternalBackupFile>[];
    for (final FolderDocument document in documents) {
      if (!document.displayName.endsWith(BackupFormat.extension)) {
        out.add(ExternalBackupFile(
          identifier: document.identifier,
          displayName: document.displayName,
          sizeBytes: document.sizeBytes,
          modifiedAt: document.modifiedAt,
          validity: ExternalFileValidity.unrelated,
        ));
        continue;
      }
      if (document.sizeBytes <= 0 || document.sizeBytes > _maxInspectedBytes) {
        out.add(ExternalBackupFile(
          identifier: document.identifier,
          displayName: document.displayName,
          sizeBytes: document.sizeBytes,
          modifiedAt: document.modifiedAt,
          validity: ExternalFileValidity.invalid,
        ));
        continue;
      }
      try {
        final List<int> bytes =
            await BackupFolderChannel.readDocument(identifier: document.identifier);
        final ParsedBackup backup = BackupFormat.parse(utf8.decode(bytes));
        out.add(ExternalBackupFile(
          identifier: document.identifier,
          displayName: document.displayName,
          sizeBytes: document.sizeBytes,
          modifiedAt: document.modifiedAt,
          validity: ExternalFileValidity.valid,
          kind: backup.kind,
          createdAt: backup.createdAt,
        ));
      } on BackupFormatException {
        out.add(ExternalBackupFile(
          identifier: document.identifier,
          displayName: document.displayName,
          sizeBytes: document.sizeBytes,
          modifiedAt: document.modifiedAt,
          validity: ExternalFileValidity.invalid,
        ));
      } on FolderException catch (error) {
        // A file the app cannot read right now is not proof it is broken: the
        // provider may have hiccuped. It is not offered as a backup, and it is
        // not labelled broken either.
        out.add(ExternalBackupFile(
          identifier: document.identifier,
          displayName: document.displayName,
          sizeBytes: document.sizeBytes,
          modifiedAt: document.modifiedAt,
          validity: error.failure == FolderFailure.forbidden
              ? ExternalFileValidity.invalid
              : ExternalFileValidity.unchecked,
        ));
      }
    }
    // Newest first, by the folder's own word on modification time.
    out.sort((ExternalBackupFile a, ExternalBackupFile b) {
      final DateTime? aAt = a.modifiedAt ?? a.createdAt;
      final DateTime? bAt = b.modifiedAt ?? b.createdAt;
      if (aAt == null && bAt == null) return 0;
      if (aAt == null) return 1;
      if (bAt == null) return -1;
      return bAt.compareTo(aAt);
    });
    return out;
  }

  @override
  Future<ExternalBackupFile> createBackupFile({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    final BackupLocation? configured = await getConfiguredLocation();
    if (configured == null) {
      throw const FolderException(FolderFailure.identifier, 'no folder is configured');
    }
    final WrittenDocument written = await BackupFolderChannel.writeDocument(
      identifier: configured.identifier,
      name: suggestedName,
      bytes: bytes,
    );
    return ExternalBackupFile(
      identifier: written.identifier,
      displayName: written.displayName,
      sizeBytes: written.sizeBytes == 0 ? bytes.length : written.sizeBytes,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<int>> readBackup(ExternalBackupFile file) =>
      BackupFolderChannel.readDocument(identifier: file.identifier);

  @override
  Future<void> deleteBackup(ExternalBackupFile file) =>
      BackupFolderChannel.deleteDocument(identifier: file.identifier);

  @override
  Future<String?> initialLocation() async =>
      (await getConfiguredLocation())?.identifier;

  @override
  Future<void> clearLocation() async {
    final BackupLocation? configured = await getConfiguredLocation();
    _current = null;
    await _store.clear();
    if (configured != null) {
      try {
        await BackupFolderChannel.releaseFolder(identifier: configured.identifier);
      } on FolderException {
        // The grant may already be gone; forgetting the folder is what was
        // asked for, and it has been done.
      }
    }
  }
}
