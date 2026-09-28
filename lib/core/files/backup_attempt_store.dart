import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/services/backup_attempts.dart';

/// Where the app remembers how its own backup attempts went.
///
/// A small JSON file in the app's private documents directory, beside the folder
/// location and for the same reason: it is state *about this installation*, not
/// about the user's ledger, and it must not travel inside a backup. A backup
/// carries records and settings; how many times this phone's write failed is
/// neither, and restoring it onto another device would be describing that device
/// with another one's history.
///
/// It dies with the app, which is also the honest outcome: after a reinstall the
/// app has made no attempts, and it says so.
class BackupAttemptStore {
  const BackupAttemptStore({Directory? directory}) : _override = directory;

  static const String fileName = 'dhimmah_backup_attempts.json';

  /// Where the file goes in tests, which must not write into the real documents
  /// directory. Null means the app's own documents directory, as in
  /// [BackupService].
  final Directory? _override;

  Future<File> file() async {
    final Directory dir = _override ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<BackupAttempts> read() async {
    try {
      final String text = await (await file()).readAsString();
      return BackupAttempts.fromJson(jsonDecode(text));
    } on FileSystemException {
      return BackupAttempts.none;
    } on FormatException {
      // A file this app cannot read is not a reason to refuse to run, and it is
      // certainly not a reason to claim a backup succeeded. One attempt sooner
      // than strictly necessary is the whole cost.
      return BackupAttempts.none;
    }
  }

  /// Writes the state, and never lets a failure to write it matter.
  ///
  /// Losing this file costs one extra attempt later, so a write that fails here
  /// must not be able to fail the snapshot that produced it — that would turn a
  /// bookkeeping problem into the loss of a backup.
  Future<void> write(BackupAttempts attempts) async {
    try {
      await (await file()).writeAsString(
        const JsonEncoder.withIndent('  ').convert(attempts.toJson()),
        flush: true,
      );
    } on Object {
      // Deliberately swallowed; see above.
    }
  }

  Future<void> clear() async {
    try {
      final File target = await file();
      if (await target.exists()) await target.delete();
    } on Object {
      // Same reasoning as `write`.
    }
  }
}
