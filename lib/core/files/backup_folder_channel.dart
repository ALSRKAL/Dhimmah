import 'package:flutter/services.dart';

/// Why an operation on the user's backup folder did not happen.
///
/// A revoked grant, a provider that vanished and a folder that only reads are
/// different situations with different answers, so they are carried separately
/// rather than flattened into one error.
enum FolderFailure {
  /// The platform has no folder flow — a desktop build, or an unregistered
  /// channel.
  unavailable,

  /// The provider or storage refused the operation.
  io,

  /// The identifier cannot be used at all.
  identifier,

  /// The standing grant is gone: revoked by the user or withdrawn by the
  /// provider. The answer is to re-authorize, not to retry blindly.
  forbidden,

  /// The folder exists but will not accept writes.
  readOnly,
}

class FolderException implements Exception {
  const FolderException(this.failure, [this.detail]);

  final FolderFailure failure;
  final String? detail;

  @override
  String toString() => 'FolderException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// One document in the user's folder, as the provider describes it.
class FolderDocument {
  const FolderDocument({
    required this.identifier,
    required this.displayName,
    required this.sizeBytes,
    required this.modifiedAt,
    this.mimeType,
  });

  final String identifier;
  final String displayName;
  final int sizeBytes;
  final DateTime? modifiedAt;
  final String? mimeType;
}

/// The platform's own directory access, behind one surface.
///
/// On Android this is the Storage Access Framework over a persisted tree URI:
/// `ACTION_OPEN_DOCUMENT_TREE` to choose the folder, `DocumentsContract` to
/// create, list, write, read and delete inside it. Nothing outside this file may
/// know that, and nothing may ever turn one of these identifiers into a path —
/// the mission-critical rule is that a tree URI is not a filesystem path and
/// behaves like one on some providers only.
///
/// The Kotlin side registers `dhimmah/backup_file` and takes the persistable
/// permission when the user chooses; both are pinned by
/// `test/platform/android_setup_test.dart`.
class BackupFolderChannel {
  const BackupFolderChannel._();

  static const String methodChannelName = 'dhimmah/backup_file';

  /// The subfolder the app keeps its portable backups in, on every platform.
  static const String folderName = 'Dhimmah Backups';

  static const MethodChannel _channel = MethodChannel(methodChannelName);

  /// Asks the user to choose a folder. Null means they backed out.
  static Future<ChosenFolderDocument?> chooseFolder() async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('chooseFolder');
      if (result == null) return null;
      return _folderFrom(result);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Makes [name] inside the folder, returning what the provider created.
  static Future<ChosenFolderDocument> createFolder({
    required String identifier,
    String name = folderName,
  }) async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('createFolder', <String, Object?>{
        'uri': identifier,
        'name': name,
      });
      if (result == null) {
        throw const FolderException(FolderFailure.io, 'no folder was created');
      }
      return _folderFrom(result);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Writes a document named [name] into the folder, replacing one of the same
  /// name. Answers with the document as the provider now has it.
  static Future<WrittenDocument> writeDocument({
    required String identifier,
    required String name,
    required List<int> bytes,
  }) async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('writeDocument', <String, Object?>{
        'uri': identifier,
        'name': name,
        'bytes': bytes,
      });
      if (result == null) {
        throw const FolderException(FolderFailure.io, 'nothing was written');
      }
      return WrittenDocument(
        identifier: result['uri']! as String,
        displayName: (result['displayName'] ?? name) as String,
        sizeBytes: (result['size'] as num?)?.toInt() ?? 0,
        bytesWritten: (result['bytes'] as num?)?.toInt() ?? 0,
        replacedExisting: result['replaced'] == true,
      );
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Reads a document back. This is how a saved copy is verified.
  static Future<List<int>> readDocument({required String identifier}) async {
    try {
      final Uint8List? bytes =
          await _channel.invokeMethod<Uint8List>('readDocument', <String, Object?>{
        'uri': identifier,
      });
      return bytes ?? Uint8List(0);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Every child of the folder, as the provider describes it.
  static Future<List<FolderDocument>> listDocuments({
    required String identifier,
  }) async {
    try {
      final List<Object?>? result = await _channel
          .invokeListMethod<Object?>('listDocuments', <String, Object?>{
        'uri': identifier,
      });
      return <FolderDocument>[
        for (final Object? entry in result ?? const <Object?>[])
          if (entry is Map<Object?, Object?>)
            FolderDocument(
              identifier: entry['uri']! as String,
              displayName: (entry['displayName'] ?? '') as String,
              sizeBytes: (entry['size'] as num?)?.toInt() ?? 0,
              modifiedAt: (entry['lastModified'] as num?) == null ||
                      (entry['lastModified'] as num).toInt() <= 0
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      (entry['lastModified']! as num).toInt(),
                    ),
              mimeType: entry['mimeType'] as String?,
            ),
      ];
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Removes one document from the folder.
  static Future<void> deleteDocument({required String identifier}) async {
    try {
      await _channel.invokeMethod<void>('deleteDocument', <String, Object?>{
        'uri': identifier,
      });
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Proves the folder can be written to, by writing, reading and removing a
  /// probe file.
  static Future<void> verifyWritable({required String identifier}) async {
    try {
      await _channel.invokeMethod<void>('verifyWritable', <String, Object?>{
        'uri': identifier,
      });
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// What the provider says about the folder now, and whether the grant holds.
  static Future<ChosenFolderDocument> describeFolder({
    required String identifier,
  }) async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('describeFolder', <String, Object?>{
        'uri': identifier,
      });
      if (result == null) {
        throw const FolderException(FolderFailure.identifier);
      }
      return _folderFrom(result);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  /// Gives the folder back, when the user has chosen a different one.
  static Future<void> releaseFolder({required String identifier}) async {
    try {
      await _channel.invokeMethod<void>('releaseFolder', <String, Object?>{
        'uri': identifier,
      });
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const FolderException(FolderFailure.unavailable);
    }
  }

  static ChosenFolderDocument _folderFrom(Map<Object?, Object?> map) {
    final Object? identifier = map['uri'];
    if (identifier is! String || identifier.isEmpty) {
      throw const FolderException(FolderFailure.identifier);
    }
    final Object? size = map['size'];
    final Object? persisted = map['persisted'];
    return ChosenFolderDocument(
      identifier: identifier,
      displayName: ((map['displayName'] as String?)?.trim().isNotEmpty ?? false)
          ? map['displayName']! as String
          : 'backup',
      sizeBytes: size is int ? size : null,
      isPersisted: persisted is bool ? persisted : true,
    );
  }

  static FolderException _failureFor(PlatformException error) {
    final FolderFailure failure = switch (error.code) {
      'bad_uri' => FolderFailure.identifier,
      'forbidden' => FolderFailure.forbidden,
      'cancelled' => FolderFailure.identifier,
      'read_only' => FolderFailure.readOnly,
      _ => FolderFailure.io,
    };
    return FolderException(failure, error.message);
  }
}

/// A folder the platform has handed over.
class ChosenFolderDocument {
  const ChosenFolderDocument({
    required this.identifier,
    required this.displayName,
    required this.isPersisted,
    this.sizeBytes,
  });

  final String identifier;
  final String displayName;
  final int? sizeBytes;

  /// Whether the platform granted standing access, so the folder will still be
  /// reachable after the process ends.
  final bool isPersisted;
}

/// The result of writing one document into the folder.
class WrittenDocument {
  const WrittenDocument({
    required this.identifier,
    required this.displayName,
    required this.sizeBytes,
    required this.bytesWritten,
    required this.replacedExisting,
  });

  final String identifier;
  final String displayName;
  final int sizeBytes;
  final int bytesWritten;
  final bool replacedExisting;
}
