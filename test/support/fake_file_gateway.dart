import 'dart:convert';

import 'package:dhimmah/core/files/document_save_channel.dart';
import 'package:dhimmah/core/files/file_gateway.dart';

/// The system picker, the document chooser and the share sheet, answered by the
/// test.
///
/// The chooser is the interesting one. A test can make it cancel, and it can
/// make the document misbehave the way a real provider does — refuse the write,
/// keep fewer bytes than it was given, hand back something else entirely —
/// because those are the cases where a save that reported success would be a
/// lie.
class FakeFileGateway implements FileGateway {
  FakeFileGateway({this.pick, this.destination});

  /// What the picker returns: a path, or null when the user cancels.
  String? pick;

  /// The document the chooser will offer, or null when the user cancels.
  FakeSaveTarget? destination;

  /// Every path handed to the share sheet, in order.
  final List<String> shared = <String>[];

  int picks = 0;
  int savePrompts = 0;

  /// The name the app suggested for the document, as the platform would see it.
  String? suggestedName;

  /// Where the app asked the picker to start, as the platform would see it.
  String? initialDirectory;

  @override
  Future<String?> pickBackupFile({String? initialDirectory}) async {
    picks++;
    this.initialDirectory = initialDirectory;
    return pick;
  }

  @override
  Future<SaveTarget?> createSaveTarget({required String suggestedName}) async {
    savePrompts++;
    this.suggestedName = suggestedName;
    return destination;
  }

  @override
  Future<void> shareFile(String path, {String? subject}) async {
    shared.add(path);
  }
}

/// A document that behaves the way a provider does — including badly.
///
/// By default it is well behaved: what is written can be read back byte for
/// byte, and it reports its size. Each setting breaks exactly one part of that,
/// so a test can point at the step it means.
class FakeSaveTarget implements SaveTarget {
  FakeSaveTarget({
    this.displayName = 'dhimmah-manual.dhimmah',
    this.identifier = 'content://test/backup',
    this.writeShortBy = 0,
    this.refuseWrite = false,
    this.refuseRead = false,
    this.corruptOnRead = false,
    this.reportSize,
    this.sizeIsZero = false,
  });

  @override
  final String displayName;

  @override
  final String identifier;

  /// Writes fewer bytes than it was given, as a stream that ended early would.
  final int writeShortBy;

  /// Refuses the write: no space, no permission, a stream that will not open.
  final bool refuseWrite;

  /// Refuses to read the document back.
  final bool refuseRead;

  /// Reads back as different content — what a document something else rewrote
  /// between the write and the check would look like.
  final bool corruptOnRead;

  /// The size the provider reports, when it should differ from what was written.
  final int? reportSize;

  /// Reports a zero size after a write that claimed to succeed.
  final bool sizeIsZero;

  /// What was actually written, so a test can assert on the bytes.
  List<int>? written;

  int writes = 0;
  int reads = 0;

  @override
  Future<int> write(List<int> bytes) async {
    writes++;
    if (refuseWrite) {
      throw const DocumentException(
        DocumentFailure.io,
        'the destination refused the write',
      );
    }
    written = List<int>.from(bytes);
    return bytes.length - writeShortBy;
  }

  @override
  Future<List<int>> read() async {
    reads++;
    if (refuseRead) {
      throw const DocumentException(
        DocumentFailure.io,
        'the document could not be read back',
      );
    }
    if (corruptOnRead) {
      // Valid JSON, wrong backup, and *the same length as what was written* — so
      // a length check alone would pass it. This is the case the byte comparison
      // exists for.
      final List<int> tampered =
          utf8.encode('{"format":"dhimmah-backup","tampered":true}');
      final int length = written?.length ?? tampered.length;
      if (tampered.length >= length) return tampered;
      return <int>[...tampered, ...List<int>.filled(length - tampered.length, 0x20)];
    }
    return List<int>.from(written ?? const <int>[]);
  }

  @override
  Future<int?> size() async {
    if (sizeIsZero) return 0;
    return reportSize ?? written?.length;
  }
}
