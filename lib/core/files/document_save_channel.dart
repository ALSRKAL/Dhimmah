import 'package:flutter/services.dart';

/// Why a document operation did not happen.
///
/// The platform reports these as codes; the app turns them into a sentence for
/// the user and never shows one of these names.
enum DocumentFailure {
  /// The payload was empty, and an empty document is never written.
  empty,

  /// The provider or the storage refused: no space, no permission, a stream
  /// that could not be opened, a write that ended early.
  io,

  /// The identifier the platform returned cannot be used.
  identifier,

  /// The platform has no implementation — a desktop build, or a channel that
  /// was not registered.
  unavailable,
}

class DocumentException implements Exception {
  const DocumentException(this.failure, [this.detail]);

  final DocumentFailure failure;
  final String? detail;

  @override
  String toString() => 'DocumentException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// A document the user chose, described by the provider rather than by us.
class ChosenDocument {
  const ChosenDocument({
    required this.identifier,
    required this.displayName,
    required this.sizeBytes,
  });

  /// Opaque: a `content://` URI on Android. Nothing outside this file may
  /// assume it is a path.
  final String identifier;

  /// What the provider says the document is called — it may differ from the
  /// name that was suggested, and the provider is the authority.
  final String displayName;

  /// The size the provider reports, when it reports one at all.
  final int? sizeBytes;
}

/// Android's "create a document and tell me where" flow, and the content
/// operations that go with it.
///
/// The app's own backup directory is a filesystem path, but a document the user
/// saves is not: Android hands back a `content://` URI, and `dart:io` cannot open
/// one. Everything that touches such a document therefore goes back over this
/// channel — writing the bytes, reading them back for verification, and asking
/// the provider what it holds.
///
/// Why a channel at all: the installed `file_selector_android` (0.5.2+11) has no
/// `ACTION_CREATE_DOCUMENT` anywhere in it — `getSaveLocation` falls through to
/// the platform interface's unimplemented default — so there is no plugin route
/// to a user-chosen save location. This is the narrow bridge for exactly that,
/// and nothing else.
///
/// The MIME type is part of the contract with the Kotlin side, which registers
/// the create contract with it; `test/platform/android_setup_test.dart` pins the
/// two together.
class DocumentSaveChannel {
  const DocumentSaveChannel._();

  static const String methodChannelName = 'dhimmah/backup_file';

  /// The type every provider accepts for a format none of them knows.
  ///
  /// A made-up `application/vnd.dhimmah` is refused by providers that do not
  /// recognise it, which is the same mistake that made the restore picker look
  /// empty. `.dhimmah` is identified by its *content*, which the app checks.
  static const String mimeType = 'application/octet-stream';

  static const MethodChannel _channel = MethodChannel(methodChannelName);

  /// Asks the user where the document should live.
  ///
  /// Returns null when they backed out. Backing out is an answer, not a
  /// failure, and it is reported as one.
  static Future<ChosenDocument?> createDocument({
    required String suggestedName,
  }) async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('createDocument', <String, Object?>{
        'name': suggestedName,
      });
      if (result == null) return null;
      return _documentFrom(result);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const DocumentException(DocumentFailure.unavailable);
    }
  }

  /// Writes the whole document. Returns how many bytes the platform wrote.
  static Future<int> write({
    required String identifier,
    required List<int> bytes,
  }) async {
    try {
      final int written = await _channel.invokeMethod<int>('write', <String, Object?>{
        'uri': identifier,
        'bytes': Uint8List.fromList(bytes),
      }) ??
          0;
      return written;
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const DocumentException(DocumentFailure.unavailable);
    }
  }

  /// Reads the document back, so a copy can be verified rather than assumed.
  static Future<Uint8List> read({required String identifier}) async {
    try {
      final Uint8List? bytes =
          await _channel.invokeMethod<Uint8List>('read', <String, Object?>{
        'uri': identifier,
      });
      return bytes ?? Uint8List(0);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const DocumentException(DocumentFailure.unavailable);
    }
  }

  /// What the provider reports about the document.
  static Future<ChosenDocument> metadata({required String identifier}) async {
    try {
      final Map<Object?, Object?>? result = await _channel
          .invokeMapMethod<Object?, Object?>('metadata', <String, Object?>{
        'uri': identifier,
      });
      if (result == null) {
        throw const DocumentException(DocumentFailure.identifier);
      }
      return _documentFrom(result);
    } on PlatformException catch (error) {
      throw _failureFor(error);
    } on MissingPluginException {
      throw const DocumentException(DocumentFailure.unavailable);
    }
  }

  static ChosenDocument _documentFrom(Map<Object?, Object?> map) {
    final Object? identifier = map['uri'];
    if (identifier is! String || identifier.isEmpty) {
      throw const DocumentException(DocumentFailure.identifier);
    }
    final Object? size = map['size'];
    return ChosenDocument(
      identifier: identifier,
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty ?? false
          ? (map['displayName']! as String)
          : 'backup',
      sizeBytes: size is int ? size : null,
    );
  }

  static DocumentException _failureFor(PlatformException error) {
    final DocumentFailure failure = switch (error.code) {
      'empty_bytes' => DocumentFailure.empty,
      'bad_uri' => DocumentFailure.identifier,
      'cancelled' => DocumentFailure.identifier,
      _ => DocumentFailure.io,
    };
    return DocumentException(failure, error.message);
  }
}
