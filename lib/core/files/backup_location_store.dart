import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_location.dart';

/// Where the app remembers its backup folder between launches.
///
/// A small JSON file in the app's own documents directory, rather than a column
/// in the settings table — and that is a deliberate trade, not an oversight. The
/// schema version is stamped into every backup file a build writes
/// (`BackupService` takes it from the database), so adding a settings column
/// would bump the version on a change that has nothing to do with the ledger's
/// data, and backups from the previous build would then be refused by a new one
/// for a reason no user could see.
///
/// The file dies with the app, which is what the product wants anyway: the
/// recovery artifact is the `.dhimmah` file in the user's folder, not the
/// permission to reach it. After a reinstall the app offers to re-authorize the
/// folder rather than pretending the old grant survived.
class BackupLocationStore {
  const BackupLocationStore();

  static const String fileName = 'dhimmah_backup_location.json';

  Future<File> _file() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<BackupLocation?> read() async {
    try {
      final String text = await (await _file()).readAsString();
      final Object? decoded = jsonDecode(text);
      return BackupLocation.fromJson(decoded is Map ? decoded.cast<Object?, Object?>() : null);
    } on FileSystemException {
      return null;
    } on FormatException {
      // A settings file this app cannot read is not a reason to refuse to run:
      // the folder is simply not configured, and the user is asked again.
      return null;
    }
  }

  Future<void> write(BackupLocation location) async {
    final File file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(location.toJson()),
      flush: true,
    );
  }

  Future<void> clear() async {
    final File file = await _file();
    if (await file.exists()) await file.delete();
  }
}
