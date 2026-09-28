import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/backup_format.dart';
import 'document_save_channel.dart';

/// The user's own storage, behind one interface.
///
/// Dhimmah never asks for broad filesystem access. Every direction goes through
/// the platform's own chooser, which is what keeps the promise that the app can
/// only see a file the user handed it:
///
/// * **Saving a copy** uses Android's document creation flow, so the user picks
///   the folder and the app writes that one document. This is the way a backup
///   leaves the app: it does not depend on which other applications happen to be
///   installed.
/// * **Reading a backup** uses the Storage Access Framework, so the user picks
///   the file and the app receives read access to that one document.
/// * **Sending a copy on** is a share, which is a different thing: it asks
///   another application to take a copy, and it is offered as a convenience
///   rather than as the way to keep a backup.
abstract interface class FileGateway {
  /// The file the user picked, or null when they cancelled.
  ///
  /// [initialDirectory] is a hint about where to start — the remembered backup
  /// folder, so restore opens where the backups live. It is a hint and nothing
  /// more: providers ignore it at their discretion, and a picker that starts
  /// somewhere else is not a failure.
  ///
  /// Returns a path the app can read immediately: the picker's grant lasts for
  /// this session, and a backup is read once and copied into the app's own
  /// storage, so nothing depends on the grant surviving a restart.
  Future<String?> pickBackupFile({String? initialDirectory});

  /// Asks the user where a new backup document should be created.
  ///
  /// Null means they changed their mind, which is not a failure. Anything else
  /// is a [SaveTarget], and the only way to touch the document — including to
  /// read it back afterwards — is through it.
  Future<SaveTarget?> createSaveTarget({required String suggestedName});

  /// Offers the file to the system share sheet.
  Future<void> shareFile(String path, {String? subject});
}

/// A document the user chose to save a backup into.
///
/// The backup system writes through this and never learns what is on the other
/// end: a filesystem path, a `content://` document, or whatever a future platform
/// invents. The identifier stays opaque, and every operation goes back through
/// the same channel that produced it — which is why nothing here is a `File`.
abstract interface class SaveTarget {
  /// What the provider says the document is called.
  ///
  /// Not the name that was suggested: Android may have changed it, and the app
  /// reports what is actually there.
  String get displayName;

  /// Opaque handle, for diagnostics and for going back to the document.
  String get identifier;

  /// Writes the whole payload, then flushes and closes it. Returns the number
  /// of bytes written.
  Future<int> write(List<int> bytes);

  /// Reads the document back, for verification.
  Future<List<int>> read();

  /// The size the provider reports, when it reports one.
  Future<int?> size();
}

/// The real gateway: `file_selector` for reading, the document channel for
/// saving, `share_plus` for sending a copy on.
class PlatformFileGateway implements FileGateway {
  const PlatformFileGateway({
    Future<XFile?> Function({
    List<XTypeGroup> acceptedTypeGroups,
    String? initialDirectory,
  })? open,
  }) : _open = open ?? openFile;

  /// How the document is opened. Injectable so a test can see what the picker
  /// was actually asked for — the filter is the part that broke, and it is not
  /// observable from the outside once the platform has answered.
  final Future<XFile?> Function({
    List<XTypeGroup> acceptedTypeGroups,
    String? initialDirectory,
  }) _open;

  @override
  Future<String?> pickBackupFile({String? initialDirectory}) async {
    // No type filter, deliberately.
    //
    // The picker used to ask for `extensions: ['dhimmah']` and the two MIME
    // types a provider might report. On Android those become an intent filter,
    // and a document whose provider reports something else — an unknown
    // extension is usually reported as `application/octet-stream`, but some
    // providers say `text/plain`, or their own type — is *hidden*: the picker
    // opens and looks empty, which is exactly what the user saw.
    //
    // The extension was never evidence anyway. What makes a file a backup is its
    // content, and that is checked afterwards: the envelope has to name Dhimmah,
    // the checksum has to match the payload, and the rows have to hold together.
    // So the picker shows every document the user could choose, and the file is
    // judged by what it is rather than by what it is called.
    const XTypeGroup group = XTypeGroup(label: 'Dhimmah backup');
    final XFile? file = await _open(
      acceptedTypeGroups: <XTypeGroup>[group],
      initialDirectory: initialDirectory,
    );
    return file?.path;
  }

  @override
  Future<SaveTarget?> createSaveTarget({required String suggestedName}) async {
    final ChosenDocument? chosen = await DocumentSaveChannel.createDocument(
      suggestedName: suggestedName,
    );
    return chosen == null ? null : _ChannelSaveTarget(chosen);
  }

  @override
  Future<void> shareFile(String path, {String? subject}) {
    return SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)], subject: subject),
    );
  }
}

/// A document reached through the platform channel, so nothing above this file
/// has to know it is a `content://` URI.
class _ChannelSaveTarget implements SaveTarget {
  const _ChannelSaveTarget(this.chosen);

  final ChosenDocument chosen;

  @override
  String get displayName => chosen.displayName;

  @override
  String get identifier => chosen.identifier;

  @override
  Future<int> write(List<int> bytes) =>
      DocumentSaveChannel.write(identifier: identifier, bytes: bytes);

  @override
  Future<List<int>> read() => DocumentSaveChannel.read(identifier: identifier);

  @override
  Future<int?> size() async =>
      (await DocumentSaveChannel.metadata(identifier: identifier)).sizeBytes;
}

/// The file name a user sees when a backup is shared or saved.
String backupFileName(String path) {
  final int cut = path.lastIndexOf('/');
  return cut < 0 ? path : path.substring(cut + 1);
}

/// The extension the picker filters on, without the dot.
String get backupExtension => BackupFormat.extension.substring(1);
