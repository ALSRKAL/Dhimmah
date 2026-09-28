/// Reads, checks and validates a backup file on a worker isolate.
///
/// The measured reason this exists: decoding, checksumming and validating a
/// 3.2 MB file is ~1.1 s of uninterrupted work, and on the frame thread that is
/// a visible freeze. Handing the *path* — not the contents — to a worker means
/// nothing large is copied in, and the worker's result is transferred rather than
/// copied out when it exits, which was measured at 391 ms for the same file.
///
/// Three rules shape the protocol:
///
/// * **The database is not involved.** A worker only ever sees a path and a
///   schema version; the SQLite connection stays on the main isolate, where the
///   transaction and the rest of the app already live.
/// * **It cannot hang the app.** The isolate is spawned with exit and error
///   handlers, so a worker that dies without answering still completes the
///   future, and there is a timeout on top of it. Either way the caller falls
///   back to doing the work inline: an unavailable worker costs time, never a
///   stuck restore.
/// * **It cannot change the answer.** The worker runs the same functions the
///   inline path runs — `BackupFormat.parseEnvelope` and `BackupValidator` — so
///   the verdict and the payload are identical by construction, which the tests
///   assert by comparing both paths on the same file.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../domain/services/backup_format.dart';
import '../../domain/services/backup_progress.dart';
import '../../domain/services/backup_validation.dart';

/// What the worker is asked to do.
class _Request {
  const _Request({
    required this.reply,
    required this.path,
    required this.schemaVersion,
  });

  final SendPort reply;
  final String path;
  final int schemaVersion;
}

/// A step of the work, reported as it starts.
class _Progress {
  const _Progress(this.step);

  final RestoreStep step;
}

/// The worker's answer.
class _Opened {
  const _Opened({required this.backup, required this.validation});

  final ParsedBackup backup;
  final BackupValidation validation;
}

/// A refusal, with the reason intact so the caller can tell a damaged file from
/// a file from a newer app.
class _Refused {
  const _Refused(this.error);

  final BackupFormatException error;
}

/// The worker's entry point.
///
/// Top level and taking one argument, because that is what an isolate can be
/// started with. Everything it touches is a pure function of the file.
void _openOnWorker(_Request request) {
  final SendPort reply = request.reply;
  try {
    reply.send(const _Progress(RestoreStep.reading));
    final File file = File(request.path);
    if (!file.existsSync()) {
      Isolate.exit(
        reply,
        const _Refused(BackupFormatException(BackupProblem.unreadableEnvelope)),
      );
    }
    final String text = file.readAsStringSync();

    reply.send(const _Progress(RestoreStep.decoding));
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      Isolate.exit(
        reply,
        const _Refused(BackupFormatException(BackupProblem.notJson)),
      );
    }

    reply.send(const _Progress(RestoreStep.checking));
    final ParsedBackup backup = BackupFormat.parseEnvelope(decoded);
    if (backup.encrypted) {
      Isolate.exit(
        reply,
        const _Refused(BackupFormatException(BackupProblem.encrypted)),
      );
    }

    reply.send(const _Progress(RestoreStep.validating));
    Isolate.exit(
      reply,
      _Opened(
        backup: backup,
        validation: BackupValidator.validate(
          backup,
          currentSchemaVersion: request.schemaVersion,
        ),
      ),
    );
  } on BackupFormatException catch (error) {
    Isolate.exit(reply, _Refused(error));
  } on Object {
    // Anything else is reported as an unreadable file: the worker is not the
    // place to classify failures, and the caller treats "no usable answer" as
    // "do it inline" anyway.
    Isolate.exit(
      reply,
      _Refused(BackupFormatException(BackupProblem.unreadablePayload)),
    );
  }
}

/// Opens a backup file on a worker isolate, or returns null if it could not run.
///
/// [onStep] is called from the worker's progress messages, so the screen keeps
/// naming the real step. A null return is not a failure of the file: it means
/// the worker was unavailable or too slow, and the caller should do the work
/// itself.
Future<({ParsedBackup backup, BackupValidation validation})?> openOnWorker({
  required String path,
  required int schemaVersion,
  void Function(RestoreStep step)? onStep,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final ReceivePort replies = ReceivePort();
  final Completer<Object?> answered = Completer<Object?>();
  Isolate? worker;
  try {
    worker = await Isolate.spawn<_Request>(
      _openOnWorker,
      _Request(reply: replies.sendPort, path: path, schemaVersion: schemaVersion),
      // A worker that dies without answering, or fails to start, still completes
      // the future below — the one thing this must never do is wait forever.
      onExit: replies.sendPort,
      onError: replies.sendPort,
    );
    replies.listen((Object? message) {
      if (answered.isCompleted) return;
      if (message is _Progress) {
        onStep?.call(message.step);
        return;
      }
      answered.complete(message);
    });

    final Object? message = await answered.future.timeout(timeout);
    if (message is _Opened) {
      return (backup: message.backup, validation: message.validation);
    }
    if (message is _Refused) throw message.error;
    // Exit or error without an answer.
    return null;
  } on TimeoutException {
    return null;
  } on Object {
    // Spawning failed (a platform without isolates, a resource limit).
    return null;
  } finally {
    replies.close();
    worker?.kill(priority: Isolate.immediate);
  }
}
