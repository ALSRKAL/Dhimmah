import 'dart:convert';

import 'package:dhimmah/core/files/backup_folder_channel.dart';
import 'package:dhimmah/core/files/backup_location.dart';
import 'package:dhimmah/core/files/backup_location_repository.dart';
import 'package:dhimmah/domain/services/backup_format.dart';

/// The user's backup folder, remembered by the test.
///
/// It behaves like a real one in the ways that matter: the folder is the
/// authority on what is in it, a file's content decides whether it is a backup,
/// and every way a provider can refuse is reachable by setting one field.
class FakeBackupLocationRepository implements BackupLocationRepository {
  FakeBackupLocationRepository({this.configured, this.platform = BackupPlatform.android});

  /// A repository whose folder is already chosen, which is the state after the
  /// first run: the screen has a folder to talk about from the first frame.
  FakeBackupLocationRepository.used({this.platform = BackupPlatform.android})
      : configured = BackupLocation(
          identifier: 'content://test/dhimmah-backups',
          displayName: BackupFolderChannel.folderName,
          platform: platform,
          verifiedAt: DateTime.now(),
        );

  /// The folder as remembered, or null when none has been chosen.
  BackupLocation? configured;

  final BackupPlatform platform;

  /// What the folder holds, by name. This *is* the folder: adding a file here is
  /// what the user doing it outside the app looks like.
  final Map<String, List<int>> files = <String, List<int>>{};

  /// The standing grant. False is what a revoked permission looks like.
  bool persisted = true;

  /// Whether the folder accepts writes.
  bool writable = true;

  /// When set, reading a document back hands back the same length with every
  /// byte changed — what a provider that rewrote the file would do, and the one
  /// case a length check alone cannot catch.
  bool corruptReads = false;

  /// Set to make every operation fail this way, as a provider that has gone
  /// away or withdrawn its grant would.
  FolderFailure? failWith;

  int chooseCalls = 0;
  int checks = 0;
  final List<String> deletedNames = <String>[];

  /// The last name the app asked to write, so a test can assert the naming rule.
  String? lastSuggestedName;

  /// A file added behind the app's back, before the next listing.
  void addFile(String name, List<int> bytes) => files[name] = bytes;

  /// A real backup's bytes — an empty ledger, but a real envelope and a
  /// checksum that covers its payload — for tests that need a file the app will
  /// accept.
  List<int> realBackup() {
    final CanonicalPayload payload = BackupFormat.build(
      schemaVersion: 4,
      tables: const <String, List<Map<String, Object?>>>{},
      settings: const <String, Object?>{},
      counts: const <String, int>{},
    );
    return utf8.encode(
      BackupFormat.wrap(
        payloadJson: payload.text,
        checksum: payload.digest,
        appVersion: '1.0.0+1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        kind: 'manual',
      ),
    );
  }

  @override
  Future<BackupLocation?> getConfiguredLocation() async => configured;

  @override
  Future<ChosenFolder?> chooseLocation() async {
    chooseCalls++;
    final FolderFailure? failure = failWith;
    if (failure != null) throw FolderException(failure, 'the provider refused');
    final BackupLocation location = BackupLocation(
      identifier: 'content://test/dhimmah-backups',
      displayName: BackupFolderChannel.folderName,
      platform: platform,
      verifiedAt: DateTime.now(),
      isPersisted: persisted,
    );
    configured = location;
    return ChosenFolder(
      location: location,
      disposition: FolderDisposition.alreadyNamed,
    );
  }

  @override
  Future<BackupLocationHealth> check({bool deep = false}) async {
    checks++;
    final BackupLocation? location = configured;
    if (location == null) return const BackupLocationHealth.notConfigured();
    final FolderFailure? failure = failWith;
    if (failure == FolderFailure.forbidden) {
      return BackupLocationHealth(
        status: BackupLocationStatus.permissionRevoked,
        checkedAt: DateTime.now(),
      );
    }
    if (failure != null) {
      return BackupLocationHealth(
        status: BackupLocationStatus.unavailable,
        checkedAt: DateTime.now(),
        detail: 'the provider refused',
      );
    }
    if (!persisted) {
      return BackupLocationHealth(
        status: BackupLocationStatus.permissionRevoked,
        checkedAt: DateTime.now(),
      );
    }
    if (!writable && deep) {
      return BackupLocationHealth(
        status: BackupLocationStatus.readOnly,
        checkedAt: DateTime.now(),
      );
    }
    final List<ExternalBackupFile> listed = await listBackups();
    // The newest usable copy's own timestamp, from the envelope rather than from
    // the filesystem — the same rule the real repository follows, so a test
    // cannot pass on a fiction the app would not produce.
    DateTime? newest;
    for (final ExternalBackupFile file in listed) {
      if (!file.isValid) continue;
      final DateTime? made = file.createdAt ?? file.modifiedAt;
      if (made != null && (newest == null || made.isAfter(newest))) newest = made;
    }
    return BackupLocationHealth(
      status: BackupLocationStatus.available,
      checkedAt: DateTime.now(),
      validBackups: listed.where((ExternalBackupFile f) => f.isValid).length,
      invalidFiles: listed
          .where((ExternalBackupFile f) => f.validity == ExternalFileValidity.invalid)
          .length,
      otherFiles: listed
          .where((ExternalBackupFile f) => f.validity == ExternalFileValidity.unrelated)
          .length,
      newestBackupAt: newest,
    );
  }

  @override
  Future<List<ExternalBackupFile>> listBackups() async {
    final FolderFailure? failure = failWith;
    if (failure != null) throw FolderException(failure, 'the provider refused');
    final List<ExternalBackupFile> out = <ExternalBackupFile>[];
    for (final MapEntry<String, List<int>> entry in files.entries) {
      ExternalFileValidity validity = ExternalFileValidity.unrelated;
      String? kind;
      DateTime? createdAt;
      if (entry.key.endsWith(BackupFormat.extension)) {
        validity = ExternalFileValidity.invalid;
        if (entry.value.isNotEmpty) {
          try {
            final ParsedBackup backup = BackupFormat.parse(utf8.decode(entry.value));
            validity = ExternalFileValidity.valid;
            kind = backup.kind;
            createdAt = backup.createdAt;
          } on BackupFormatException {
            validity = ExternalFileValidity.invalid;
          }
        }
      }
      out.add(ExternalBackupFile(
        identifier: 'content://test/${Uri.encodeComponent(entry.key)}',
        displayName: entry.key,
        sizeBytes: entry.value.length,
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(0),
        validity: validity,
        kind: kind,
        createdAt: createdAt,
      ));
    }
    // Newest first, the way the sheet shows them.
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
    lastSuggestedName = suggestedName;
    final FolderFailure? failure = failWith;
    if (failure != null) throw FolderException(failure, 'the provider refused');
    if (!writable) throw const FolderException(FolderFailure.readOnly, 'read-only');
    files[suggestedName] = List<int>.from(bytes);
    return ExternalBackupFile(
      identifier: 'content://test/${Uri.encodeComponent(suggestedName)}',
      displayName: suggestedName,
      sizeBytes: bytes.length,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<int>> readBackup(ExternalBackupFile file) async {
    final FolderFailure? failure = failWith;
    if (failure != null) throw FolderException(failure, 'the provider refused');
    final List<int>? bytes = files[file.displayName];
    if (bytes == null) {
      throw FolderException(FolderFailure.io, 'the file is gone');
    }
    if (corruptReads) {
      return bytes.map((int b) => b ^ 0xff).toList(growable: false);
    }
    return bytes;
  }

  @override
  Future<void> deleteBackup(ExternalBackupFile file) async {
    final FolderFailure? failure = failWith;
    if (failure != null) throw FolderException(failure, 'the provider refused');
    if (files.remove(file.displayName) == null) {
      // Already gone is simply gone: the folder is the authority, and the file
      // the user removed by hand is not an error to report.
      return;
    }
    deletedNames.add(file.displayName);
  }

  @override
  Future<String?> initialLocation() async => configured?.identifier;

  @override
  Future<void> clearLocation() async {
    configured = null;
  }
}
