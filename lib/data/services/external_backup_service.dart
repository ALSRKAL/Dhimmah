import 'dart:convert';
import 'dart:io';

import '../../core/files/backup_folder_channel.dart';
import '../../core/files/backup_location.dart';
import '../../core/files/backup_location_repository.dart';
import '../../core/files/file_gateway.dart';
import '../../domain/services/backup_format.dart';
import '../../domain/services/backup_progress.dart';
import '../../domain/services/backup_validation.dart';
import '../database/app_database.dart';
import 'backup_service.dart';

/// What happened when a copy was saved into the user's backup folder.
enum ExternalSaveOutcome {
  /// The document was written **and read back and verified**. Nothing else is
  /// reported as a success.
  saved,

  /// There is no backup folder yet, so there was nothing to save into. The
  /// screen answers with the folder setup, not with an error.
  needsFolder,

  /// The user changed their mind during folder setup. Not a failure, and not an
  /// error to explain.
  cancelled,

  /// The save was attempted and did not produce a verified document.
  failed,
}

/// Why a save did not produce a verified document.
enum ExternalSaveProblem {
  /// The chooser could not be shown, or the platform has no such flow.
  unavailable,

  /// The destination refused the write: no space, no permission, a stream that
  /// ended early.
  write,

  /// The document was written but could not be read back, or read back as
  /// something other than what was written.
  readBack,

  /// The document came back empty, or shorter than what was written.
  incomplete,

  /// The document came back, but its content is not a valid backup.
  invalid,
}

/// The result of one external save, as evidence rather than as a boolean.
class ExternalSaveReport {
  const ExternalSaveReport._({
    required this.outcome,
    this.displayName,
    this.identifier,
    this.bytes = 0,
    this.providerSize,
    this.problem,
    this.preview,
  });

  /// A document that was written and then verified by reading it back.
  const ExternalSaveReport.saved({
    required String displayName,
    required String identifier,
    required int bytes,
    int? providerSize,
    BackupPreview? preview,
  }) : this._(
          outcome: ExternalSaveOutcome.saved,
          displayName: displayName,
          identifier: identifier,
          bytes: bytes,
          providerSize: providerSize,
          preview: preview,
        );

  const ExternalSaveReport.cancelled() : this._(outcome: ExternalSaveOutcome.cancelled);

  const ExternalSaveReport.needsFolder() : this._(outcome: ExternalSaveOutcome.needsFolder);

  const ExternalSaveReport.failed(ExternalSaveProblem problem)
      : this._(outcome: ExternalSaveOutcome.failed, problem: problem);

  final ExternalSaveOutcome outcome;

  /// The name the provider reports for the document, which may differ from the
  /// one that was suggested.
  final String? displayName;

  /// The document handle, kept for diagnostics. Never shown as a path.
  final String? identifier;

  /// The bytes written and read back.
  final int bytes;

  /// The size the provider reports, when it reports one. Recorded rather than
  /// trusted: some providers report a stale value for a document that was just
  /// written, and a disagreement here is not evidence of a bad file when the
  /// bytes themselves have already been verified.
  final int? providerSize;

  final ExternalSaveProblem? problem;

  /// What the verified document contains, for the confirmation.
  final BackupPreview? preview;

  bool get isSaved => outcome == ExternalSaveOutcome.saved;
  bool get isCancelled => outcome == ExternalSaveOutcome.cancelled;
  bool get needsFolder => outcome == ExternalSaveOutcome.needsFolder;
}

/// Saving a backup to a file the user owns.
///
/// The order in [save] is the whole point, and every step is checked before the
/// next begins:
///
/// 1. take a snapshot — the same atomic, checksummed write the app always makes,
///    so there is an internal copy whatever happens next;
/// 2. read those exact bytes and parse them, so the app is asking the user to
///    choose a home for something that is already known to be a valid backup;
/// 3. ask where it should go;
/// 4. write the bytes;
/// 5. **read the document back** and check it against what was sent — same
///    length, same bytes, parses, same checksum, same counts;
/// 6. only then report success.
///
/// Step 5 is the one that makes this a backup rather than a hopeful copy. A
/// document that was never written, was written empty, was truncated, or was
/// written somewhere the app cannot read again is reported as a failure — even
/// though the chooser itself succeeded.
class ExternalBackupService {
  ExternalBackupService({
    required this.backups,
    required this.folders,
    required this.files,
  });

  final BackupService backups;
  final BackupLocationRepository folders;
  final FileGateway files;

  /// Saves a verified copy of the ledger into the user's backup folder.
  ///
  /// The folder is the one the user chose once, not a question asked on every
  /// save; when there is none, the answer is the folder setup rather than an
  /// error, because nothing has gone wrong yet.
  Future<ExternalSaveReport> save({
    void Function(BackupStep step)? onStep,
  }) async {
    // 1. A snapshot, through the one code path that writes backups.
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual, onStep: onStep);

    // 2. The bytes, parsed before anything is written anywhere: a destination
    //    should not receive a payload this build cannot read back itself.
    final List<int> bytes = await backups.bytes(written.file.path);
    if (bytes.isEmpty) {
      return const ExternalSaveReport.failed(ExternalSaveProblem.incomplete);
    }
    try {
      BackupFormat.parse(utf8.decode(bytes));
    } on BackupFormatException {
      return const ExternalSaveReport.failed(ExternalSaveProblem.invalid);
    }

    // 3. The folder, chosen once and remembered.
    final BackupLocation? location = await folders.getConfiguredLocation();
    if (location == null) return const ExternalSaveReport.needsFolder();

    // 4. Write the document into it.
    final ExternalBackupFile document;
    try {
      document = await folders.createBackupFile(
        suggestedName: backupFileName(written.file.path),
        bytes: bytes,
      );
    } on FolderException catch (error) {
      return ExternalSaveReport.failed(_folderProblemFor(error));
    } on Object {
      return const ExternalSaveReport.failed(ExternalSaveProblem.write);
    }

    // 5. Read that document back, and check it is what was sent.
    return _verify(document: document, expected: bytes);
  }

  /// Removes one backup document from the user's folder.
  Future<void> remove(ExternalBackupFile file) => folders.deleteBackup(file);

  Future<ExternalSaveReport> _verify({
    required ExternalBackupFile document,
    required List<int> expected,
  }) async {
    final List<int> readBack;
    try {
      readBack = await folders.readBackup(document);
    } on Object {
      // Whatever went wrong, it happened while looking at the document that was
      // written — so the honest description is that the file could not be
      // checked, not that the write failed.
      return const ExternalSaveReport.failed(ExternalSaveProblem.readBack);
    }

    // A document that is empty, or shorter than what was written, is the one a
    // person can act on: the file that reached the disk is not the whole backup.
    if (readBack.isEmpty || readBack.length < expected.length) {
      return const ExternalSaveReport.failed(ExternalSaveProblem.incomplete);
    }
    // Anything else that does not match — longer, or the same length with
    // different content — is a file the app cannot vouch for. A length check
    // alone would pass the second case, which is exactly why the bytes are
    // compared.
    if (!_sameBytes(readBack, expected)) {
      return const ExternalSaveReport.failed(ExternalSaveProblem.readBack);
    }

    // The bytes are identical, so the file is what was generated. It is still
    // parsed again, because `identical bytes` is a claim about a copy while
    // `parses as a backup` is a claim about a backup — and the parse is what
    // recomputes the checksum over the payload and compares it against the one
    // the envelope states, refusing the file when they disagree. The counts in
    // the confirmation come from *this* parse, so what the user is shown is what
    // the file on their disk actually holds.
    final ParsedBackup readBackup;
    try {
      readBackup = BackupFormat.parse(utf8.decode(readBack));
    } on BackupFormatException {
      return const ExternalSaveReport.failed(ExternalSaveProblem.invalid);
    }

    // The size comes from the folder's own description of the document. Zero is
    // different from merely disagreeing: a document the provider reports as
    // empty, after a write that claimed to succeed, is a failure even though the
    // bytes read back.
    if (document.sizeBytes == 0) {
      return const ExternalSaveReport.failed(ExternalSaveProblem.incomplete);
    }
    final int providerSize = document.sizeBytes;

    return ExternalSaveReport.saved(
      displayName: document.displayName,
      identifier: document.identifier,
      bytes: readBack.length,
      providerSize: providerSize,
      preview: BackupValidator.validate(
        readBackup,
        currentSchemaVersion: AppDatabase.currentSchemaVersion,
      ).preview,
    );
  }

  /// What a failure inside the folder means, to the save that was running.
  static ExternalSaveProblem _folderProblemFor(FolderException error) =>
      switch (error.failure) {
        FolderFailure.unavailable => ExternalSaveProblem.unavailable,
        FolderFailure.readOnly => ExternalSaveProblem.write,
        FolderFailure.identifier => ExternalSaveProblem.write,
        FolderFailure.forbidden => ExternalSaveProblem.write,
        FolderFailure.io => ExternalSaveProblem.write,
      };

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
