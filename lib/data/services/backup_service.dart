import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Expression, Table, TableInfo, TypedResult;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/services/backup_format.dart';
import '../../domain/services/backup_progress.dart';
import '../../domain/services/backup_validation.dart';
import '../backup/backup_codec.dart';
import '../backup/backup_worker.dart';
import '../backup/table_reader.dart';
import '../database/app_database.dart';

/// How a backup came to exist. The kind is metadata, not identity: it decides
/// which retention rule applies and how the file is labelled in the list.
enum BackupKind {
  /// Taken automatically, coalesced, by the app itself.
  auto('auto'),

  /// Taken because the user asked.
  manual('manual'),

  /// Taken automatically *before* a restore or a merge, so the state that was
  /// replaced can always be brought back.
  safety('safety');

  const BackupKind(this.label);

  final String label;

  static BackupKind fromLabel(String? label) {
    for (final BackupKind kind in BackupKind.values) {
      if (kind.label == label) return kind;
    }
    return BackupKind.manual;
  }
}

/// A snapshot on disk, described from its name and its size alone.
///
/// Listing costs a directory read: the timestamp and the kind are in the file
/// name on purpose, so the list never has to open a multi-megabyte file to draw
/// a row. The full facts — counts, schema version, whether the checksum matches —
/// are read when the user picks one.
class BackupFileInfo {
  const BackupFileInfo({
    required this.path,
    required this.kind,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final BackupKind kind;
  final DateTime createdAt;
  final int sizeBytes;

  String get name => p.basename(path);

  File get file => File(path);
}

/// Everything a restore or a merge did, in the user's terms.
class RestoreReport {
  const RestoreReport({
    required this.mode,
    required this.inserted,
    required this.replaced,
    required this.skipped,
    required this.conflicts,
    required this.warnings,
    required this.safetyBackupPath,
    required this.counts,
  });

  final RestoreMode mode;

  /// Rows added because the app had never seen them.
  final int inserted;

  /// Rows the incoming file replaced with a newer version.
  final int replaced;

  /// Rows that were already identical — the idempotency count.
  final int skipped;

  /// Rows where both sides had a different version and the incoming one was not
  /// newer. Nothing was lost: the local row was kept and is listed here.
  final List<BackupIssue> conflicts;

  final List<BackupIssue> warnings;

  /// The snapshot taken before anything was written, so the user can go back.
  final String? safetyBackupPath;

  /// Rows per table after the restore.
  final Map<String, int> counts;

  int get totalWritten => inserted + replaced;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Which way the incoming file is applied.
enum RestoreMode {
  /// The file becomes the ledger: what is here now is replaced, after a safety
  /// snapshot.
  replace,

  /// The file is folded into the ledger: records it has that this device does
  /// not are added, newer versions win, and anything ambiguous is reported
  /// rather than guessed at.
  merge,
}

/// Creates, lists, reads and deletes backup files.
///
/// The rules that shape it:
///
/// * **A snapshot is consistent.** Every table is read inside one database
///   transaction, so a backup cannot catch a half-applied write.
/// * **A write is atomic.** The bytes go to a temporary file, are flushed, and
///   are then renamed over the target. A crash leaves the previous backup
///   intact — the old file is never deleted before the new one exists.
/// * **A file is self-describing.** Metadata, schema version and a checksum
///   travel with the payload, so a backup found on another device, in a cloud
///   folder, or next week can still say what it is.
class BackupService {
  BackupService({
    required AppDatabase database,
    required this.appVersion,
    required this.clock,
    Directory? directory,
  })  : _db = database,
        _directoryOverride = directory;


  final AppDatabase _db;

  /// The running app's version, recorded in every file so a backup says which
  /// build wrote it.
  final String appVersion;

  /// Injected so tests can put a backup on a known timestamp.
  final DateTime Function() clock;

  final Directory? _directoryOverride;

  /// How many automatic snapshots are kept. The oldest is dropped when a new
  /// one would exceed it — deliberately a small number: snapshots exist to cover
  /// the last few mistakes, not to archive history, and every one of them costs
  /// storage on the device.
  ///
  /// The number is a judgement about *this* app's files, which are tens of
  /// kilobytes for a real ledger and a few megabytes at the far end of what the
  /// scale tests exercise — so five of them are still smaller than one photo, and
  /// the cost of the policy is the review points it buys, not the space.
  static const int autoRetention = 5;

  /// How many pre-restore snapshots are kept.
  static const int safetyRetention = 3;

  /// The fewest snapshots the app will ever leave behind.
  ///
  /// Two, and the reason is not sentimental: the newest is what a restore would
  /// use, and the one before it is what makes "that was the wrong restore" a
  /// recoverable statement rather than a regret. A retention policy that could
  /// take the count to one would be one file away from being a policy that can
  /// take it to none.
  static const int fewestKept = 2;

  /// Where the app keeps its own snapshots: inside the app's private files, next
  /// to the database, so nothing else on the device can read them.
  Future<Directory> directory() async {
    final Directory base = _directoryOverride ??
        Directory(p.join((await getApplicationDocumentsDirectory()).path, 'backups'));
    if (!await base.exists()) await base.create(recursive: true);
    return base;
  }

  /// Reads the whole ledger in one transaction and writes it as a backup.
  ///
  /// Returns the file written and the parsed backup, so a caller can report the
  /// counts without reading the file back.
  Future<({File file, ParsedBackup backup})> create({
    required BackupKind kind,
    Directory? into,
    DateTime? now,
    void Function(BackupStep step)? onStep,
    void Function(int rowsRead)? onProgress,
  }) async {
    final DateTime at = now ?? clock();
    final Directory dir = into ?? await directory();

    await reportStep(onStep, BackupStep.reading);
    // The tables are read in pages, and the loop turns between them: a single
    // `SELECT` over the payments table is one long synchronous stretch of row
    // mapping on the thread that draws the screen, which is what made a backup
    // of a large ledger look like a frozen app. See `TableReader`.
    final TableReader reader =
        TableReader(database: _db, onProgress: onProgress);

    // One transaction, so every table is read from the same consistent state.
    final Map<String, List<Map<String, Object?>>> tables =
        await _db.transaction(() async {
      final List<PersonRow> people = await reader.people();
      final List<DebtRow> debts = await reader.debts();
      final List<DebtPersonRow> links = await reader.links();
      final List<PaymentRow> payments = await reader.payments();
      final List<ObligationRow> obligations = await reader.obligations();
      final List<ObligationOccurrenceRow> occurrences =
          await reader.occurrences();
      final List<ReminderRow> reminders = await reader.reminders();
      final List<MonthlySummaryRow> summaries = await reader.summaries();
      final List<ActivityEntryRow> activity =
          await reader.activity(limit: BackupFormat.activityLimit);

      return <String, List<Map<String, Object?>>>{
        'people': people.map(BackupCodec.person).toList(),
        'debts': debts.map(BackupCodec.debt).toList(),
        'debtPeople': links.map(BackupCodec.link).toList(),
        'payments': payments.map(BackupCodec.payment).toList(),
        'obligations': obligations.map(BackupCodec.obligation).toList(),
        'obligationOccurrences':
            occurrences.map(BackupCodec.occurrence).toList(),
        'reminders': reminders.map(BackupCodec.reminder).toList(),
        'monthlySummaries': summaries.map(BackupCodec.summary).toList(),
        'activity': activity.map(BackupCodec.activity).toList(),
      };
    });

    await reportStep(onStep, BackupStep.building);
    final int activityOmitted = await _activityOmitted(tables['activity']!.length);
    final Setting? settingsRow = await _db.settingsDao.get();

    await reportStep(onStep, BackupStep.hashing);
    // The same map goes into the file and into the read-back check below, so the
    // two can never describe different things.
    final Map<String, int> counts = <String, int>{
      for (final MapEntry<String, List<Map<String, Object?>>> entry
          in tables.entries)
        entry.key: entry.value.length,
    };
    // One pass: the payload, its bytes, and the digest of those bytes. The
    // builder writes every key sorted, so what it returns is already canonical
    // and encoding it once is enough — the separate canonicalising pass would
    // copy every row of the ledger a second time on the thread that draws the
    // screen. The builder's canonicality is asserted by test.
    final CanonicalPayload canonical = BackupFormat.build(
      schemaVersion: _db.schemaVersion,
      tables: tables,
      settings: settingsRow == null
          ? const <String, Object?>{}
          : BackupCodec.settings(settingsRow),
      counts: counts,
      truncated: activityOmitted > 0
          ? <String, Object?>{
              'activity': <String, Object?>{
                'kept': tables['activity']!.length,
                'omitted': activityOmitted,
              },
            }
          : const <String, Object?>{},
    );

    await reportStep(onStep, BackupStep.writing);
    final String envelopeText = BackupFormat.wrap(
      payloadJson: canonical.text,
      checksum: canonical.digest,
      appVersion: appVersion,
      createdAt: at,
      kind: kind.label,
    );
    File file;
    try {
      file = await _writeAtomic(dir, kind, at, envelopeText);
    } on Object {
      // A full disk is the one failure the app can do something about. What it
      // can give back is the copies it is keeping beyond the minimum it promised
      // to keep — never a manual one, never the newest, never below that floor —
      // and then it tries once more. If giving space back did not help, the
      // failure is real and is reported as it stands.
      final bool freed = await _freeForOneMore();
      if (!freed) rethrow;
      file = await _writeAtomic(dir, kind, at, envelopeText);
    }

    await reportStep(onStep, BackupStep.verifying);
    final ParsedBackup verified = await _verifyWritten(
      file: file,
      expectedDigest: canonical.digest,
      expectedCounts: counts,
    );

    await reportStep(onStep, BackupStep.retaining);
    await _retain(dir);
    return (file: file, backup: verified);
  }

  /// Proves the file on the disk is the snapshot that was meant to be written.
  ///
  /// A `write` that returned without throwing is not evidence that the bytes are
  /// there. The rename can land on a full volume, a stream can end early, a
  /// filesystem can hand back something other than what was flushed — and the
  /// result is a file with the right name, a plausible size, and a payload that
  /// will not restore. Reporting that as a saved backup is worse than reporting
  /// nothing, because it is the moment the user stops worrying.
  ///
  /// The judgement itself is [BackupFormat.checkReadBack], which is pure;
  /// this only does the I/O and the cleanup. On any complaint the file is
  /// removed: a snapshot that cannot be restored is not a snapshot, and leaving
  /// it would both mislead the user and age a good one out under retention. The
  /// previous snapshot is untouched either way — the same contract the folder's
  /// save already keeps, and the reason its confirmation can be trusted.
  Future<ParsedBackup> _verifyWritten({
    required File file,
    required String expectedDigest,
    required Map<String, int> expectedCounts,
  }) async {
    try {
      final String text = await file.readAsString();
      final BackupProblem? problem = BackupFormat.checkReadBack(
        text,
        expectedDigest: expectedDigest,
        expectedCounts: expectedCounts,
      );
      if (problem != null) throw BackupFormatException(problem);
      return BackupFormat.parse(text);
    } on Object {
      try {
        if (await file.exists()) await file.delete();
      } on Object {
        // A file that cannot be removed is not something this can fix here.
      }
      rethrow;
    }
  }

  /// True when there is nothing to back up yet.
  ///
  /// Asked at every app resume and before every restore, so it does not read a
  /// table to answer it: one row is fetched, or none, and the database stops
  /// there.
  ///
  /// Reminders count. A ledger that held only reminders used to be "empty":
  /// it was never snapshotted, and a restore replaced it without a safety copy.
  Future<bool> isEmpty() async {
    for (final TableInfo<Table, dynamic> table in <TableInfo<Table, dynamic>>[
      _db.people,
      _db.debts,
      _db.obligations,
      _db.reminders,
    ]) {
      if (await _hasAny(table)) return false;
    }
    return true;
  }

  /// True when [table] holds at least one row.
  Future<bool> _hasAny(TableInfo<Table, dynamic> table) async {
    final TypedResult? row = await (_db.selectOnly(table)
          ..addColumns(<Expression<Object>>[table.$columns.first])
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// The snapshots on disk, newest first.
  Future<List<BackupFileInfo>> list() async {
    final Directory dir = await directory();
    if (!await dir.exists()) return const <BackupFileInfo>[];
    final List<BackupFileInfo> out = <BackupFileInfo>[];
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File) continue;
      final BackupFileInfo? info = _describe(entity);
      if (info != null) out.add(info);
    }
    out.sort((BackupFileInfo a, BackupFileInfo b) =>
        b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// The newest snapshot of any kind, for the "last backup" line.
  Future<BackupFileInfo?> latest() async {
    final List<BackupFileInfo> all = await list();
    return all.isEmpty ? null : all.first;
  }

  /// Parses a file, checking its checksum. Throws [BackupFormatException].
  Future<ParsedBackup> read(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw const BackupFormatException(BackupProblem.unreadableEnvelope);
    }
    return BackupFormat.parse(await file.readAsString());
  }

  /// Parses and validates a file: what the restore screen shows before it offers
  /// to change anything.
  ///
  /// [onStep] is called as each part of the work begins. The parts are told
  /// apart — reading, decoding, checking the checksum, applying the rules —
  /// because that is what actually happens, and because "validating" taking
  /// thirty seconds is a different problem from "reading" taking thirty seconds.
  ///
  /// This is [open] with the rows dropped, for a caller that only wants the
  /// verdict.
  Future<BackupValidation> inspect(
    String path, {
    void Function(RestoreStep step)? onStep,
  }) async =>
      (await open(path, onStep: onStep)).validation;

  /// Reads, checks and validates a file in one pass.
  ///
  /// The work happens on a worker isolate, because decoding, checksumming and
  /// validating a multi-megabyte file is over a second of uninterrupted work and
  /// that is a freeze the user can see. The file is read *there* — only its path
  /// crosses the isolate boundary — and the result comes back by transfer.
  ///
  /// If the worker cannot run, the same work is done here. That is the whole
  /// safety argument: an unavailable worker costs time, never a restore. Both
  /// paths run the same functions, so they cannot disagree, which
  /// `test/data/backup_worker_test.dart` asserts on the same file.
  Future<({ParsedBackup backup, BackupValidation validation})> open(
    String path, {
    void Function(RestoreStep step)? onStep,
  }) async {
    final ({ParsedBackup backup, BackupValidation validation})? offThread =
        await openOnWorker(
      path: path,
      schemaVersion: _db.schemaVersion,
      onStep: onStep,
    );
    if (offThread != null) return offThread;
    return openInline(path, onStep: onStep);
  }

  /// The same work on this isolate: the reference path, and the fallback used
  /// when a worker is unavailable.
  Future<({ParsedBackup backup, BackupValidation validation})> openInline(
    String path, {
    void Function(RestoreStep step)? onStep,
  }) async {
    await reportStep(onStep, RestoreStep.reading);
    final File file = File(path);
    if (!await file.exists()) {
      throw const BackupFormatException(BackupProblem.unreadableEnvelope);
    }
    final String text = await file.readAsString();

    await reportStep(onStep, RestoreStep.decoding);
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupFormatException(BackupProblem.notJson);
    }

    // The envelope is checked — including the checksum over the payload — before
    // the rules run, so a damaged file is refused for being damaged rather than
    // reported as a ledger with strange numbers in it.
    await reportStep(onStep, RestoreStep.checking);
    final ParsedBackup backup = BackupFormat.parseEnvelope(decoded);
    if (backup.encrypted) {
      throw const BackupFormatException(BackupProblem.encrypted);
    }

    await reportStep(onStep, RestoreStep.validating);
    return (
      backup: backup,
      validation: BackupValidator.validate(
        backup,
        currentSchemaVersion: _db.schemaVersion,
      ),
    );
  }

  Future<void> delete(String path) async {
    final File file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// The bytes to hand to a share sheet or a save dialog.
  Future<List<int>> bytes(String path) => File(path).readAsBytes();

  // --- Internals ------------------------------------------------------------

  Future<int> _activityOmitted(int kept) async {
    if (kept < BackupFormat.activityLimit) return 0;
    final int total = await _db.activityDao.countAll();
    return total > kept ? total - kept : 0;
  }

  /// Writes through a temporary file and renames it into place.
  ///
  /// The order matters and is the whole point: the old backup is still there
  /// while the new one is being written, so a crash, a full disk or a killed
  /// process leaves the last known good file untouched. Only a completed,
  /// flushed file is ever given the real name.
  Future<File> _writeAtomic(
    Directory dir,
    BackupKind kind,
    DateTime at,
    String contents,
  ) async {
    final String stamp = _stamp(at);
    final String base = 'dhimmah-${kind.label}-$stamp';
    // Two snapshots inside one second — a tap landing on the same second as an
    // automatic one, or a device whose clock does not advance — must not become
    // one file. The second gets a suffix and both are listed: losing a snapshot
    // because of its name is losing data for no reason at all.
    File target = File(p.join(dir.path, '$base${BackupFormat.extension}'));
    for (int suffix = 2; await target.exists(); suffix++) {
      target = File(p.join(dir.path, '$base-$suffix${BackupFormat.extension}'));
    }
    final File temporary = File('${target.path}.tmp');
    try {
      final RandomAccessFile handle = await temporary.open(mode: FileMode.write);
      try {
        await handle.writeString(contents);
        await handle.flush();
      } finally {
        await handle.close();
      }
      await temporary.rename(target.path);
    } on Object {
      // Whatever went wrong — no space, no permission — the temporary file goes
      // away and the previous backup stays exactly where it was.
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } on Object {
          // Nothing more can be done about a file we cannot remove.
        }
      }
      rethrow;
    }
    return target;
  }

  /// Applies the retention policy, newest kept.
  ///
  /// The rules are stated here rather than left implicit in the arithmetic,
  /// because each of them is a promise to the user and only one of them is about
  /// saving space:
  ///
  /// 1. a **manual** snapshot is never deleted — the user asked for it, and a
  ///    copy the app removes on its own is not a copy anyone can rely on;
  /// 2. the **newest** snapshot of each kind is never deleted, whatever the
  ///    counts say. It is the one a restore would offer first;
  /// 3. at least [fewestKept] snapshots survive whenever there were that many —
  ///    so there is always one to go back *to*, not only one to go back to;
  /// 4. only then does the count matter: the oldest automatic snapshots beyond
  ///    [autoRetention] go, then the oldest safety ones beyond
  ///    [safetyRetention], oldest first.
  ///
  /// Everything in that list runs on every snapshot, and the whole policy is
  /// bounded: the app holds a few dozen kilobytes per snapshot and never grows
  /// without limit.
  Future<void> _retain(Directory dir) async {
    final List<BackupFileInfo> all = await list();
    // `.tmp` files are never listed, so a crash mid-write cannot make a
    // half-written file look like a backup.
    await _discardAbandonedTemporaries(dir);
    await _dropCandidates(_candidates(all), all.length);
  }

  /// What may be removed, in the order it should go: the oldest automatic
  /// snapshots beyond the count first, then the oldest safety ones.
  ///
  /// Newest-first in, oldest-first out. Manual snapshots are never in the list,
  /// and neither is the newest of any kind.
  static List<BackupFileInfo> _candidates(List<BackupFileInfo> newestFirst) {
    return <BackupFileInfo>[
      ..._beyondCount(newestFirst, BackupKind.auto, autoRetention),
      ..._beyondCount(newestFirst, BackupKind.safety, safetyRetention),
    ];
  }

  /// The snapshots of one kind that the count says are surplus, oldest first.
  ///
  /// The newest of the kind is dropped from the front of the result before it is
  /// returned, so rule 2 holds even if a count is ever set to zero.
  static List<BackupFileInfo> _beyondCount(
    List<BackupFileInfo> newestFirst,
    BackupKind kind,
    int keep,
  ) {
    final List<BackupFileInfo> ofKind =
        newestFirst.where((BackupFileInfo f) => f.kind == kind).toList();
    final int protectedCount = keep < 1 ? 1 : keep;
    if (ofKind.length <= protectedCount) return const <BackupFileInfo>[];
    final List<BackupFileInfo> surplus = ofKind.sublist(protectedCount);
    return surplus.reversed.toList();
  }

  /// Deletes from [candidates] while leaving at least [fewestKept] of [total].
  Future<void> _dropCandidates(
    List<BackupFileInfo> candidates,
    int total, {
    int floor = fewestKept,
  }) async {
    int allowed = total - floor;
    for (final BackupFileInfo info in candidates) {
      if (allowed <= 0) return;
      await _deleteQuietly(info);
      allowed--;
    }
  }

  /// Gives back the snapshots the app is holding beyond its safe minimum, so a
  /// write that failed for want of room can be tried again.
  ///
  /// A full disk is the one failure the app can do something about, and the
  /// something is to hand back the copies it is keeping beyond the minimum it
  /// promised to keep. It never touches a manual snapshot, never the newest of a
  /// kind, and never goes below [fewestKept] — so a device that cannot write is
  /// a device whose backups are still restorable. Returns whether anything was
  /// actually freed, because a retry after freeing nothing is just a second wait.
  Future<bool> _freeForOneMore() async {
    final List<BackupFileInfo> all = await list();
    if (all.length <= fewestKept) return false;
    final List<BackupFileInfo> candidates = _candidates(all);
    if (candidates.isEmpty) {
      // Nothing surplus by kind, but there is room to give: the oldest
      // automatic snapshot, or failing that the oldest safety one. Never a
      // manual one, and never the newest overall.
      final List<BackupFileInfo> droppable = all
          .where((BackupFileInfo f) => f.kind != BackupKind.manual)
          .toList()
          .reversed
          .toList();
      if (droppable.isNotEmpty) candidates.add(droppable.first);
    }
    if (candidates.isEmpty) return false;
    final int before = all.length;
    await _dropCandidates(candidates, before);
    return (await list()).length < before;
  }

  Future<void> _deleteQuietly(BackupFileInfo info) async {
    try {
      await info.file.delete();
    } on Object {
      // A file we cannot delete is not a reason to fail the backup we just
      // wrote.
    }
  }

  /// Removes half-written files left behind by a process that died mid-write.
  ///
  /// A file only receives a snapshot's name after it is complete and flushed, so
  /// anything still wearing the temporary suffix belongs to a write that never
  /// finished and can never become a backup. Removing it is safe by
  /// construction; leaving it means every killed process costs the user storage
  /// forever, quietly.
  Future<void> _discardAbandonedTemporaries(Directory dir) async {
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.tmp')) continue;
      try {
        await entity.delete();
      } on Object {
        // A file that will not go is not a reason to fail the snapshot that was
        // just written.
      }
    }
  }

  /// Reads a name back into a snapshot description, or null if it is not one.
  BackupFileInfo? _describe(File file) {
    final String name = p.basename(file.path);
    if (!name.startsWith('dhimmah-') || !name.endsWith(BackupFormat.extension)) {
      return null;
    }
    final String middle = name.substring(
      'dhimmah-'.length,
      name.length - BackupFormat.extension.length,
    );
    final int separator = middle.indexOf('-');
    if (separator <= 0) return null;
    final DateTime? at = _parseStamp(middle.substring(separator + 1));
    if (at == null) return null;
    return BackupFileInfo(
      path: file.path,
      kind: BackupKind.fromLabel(middle.substring(0, separator)),
      createdAt: at,
      sizeBytes: file.lengthSync(),
    );
  }

  static String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    // Milliseconds are in the name because the name *is* the moment the app
    // compares against: "has anything changed since the last snapshot?" reads
    // the newest file's name, and a name accurate only to the second makes every
    // record written in that same second look newer than the snapshot that
    // already contains it. The user sees the result of that as the status
    // flipping to "changes are not saved yet" the instant after a save.
    return '${at.year}${two(at.month)}${two(at.day)}'
        'T${two(at.hour)}${two(at.minute)}${two(at.second)}'
        '${at.millisecond.toString().padLeft(3, '0')}';
  }

  static DateTime? _parseStamp(String stamp) {
    // Milliseconds are optional so that files written before they were added
    // still list, still restore, and still count as snapshots — they are simply
    // read as having been taken at the start of their second.
    //
    // The trailing group is the collision suffix: two snapshots inside one
    // millisecond are two files, and the second carries `-2`.
    final RegExpMatch? match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(\d{3})?(?:-\d+)?$',
    ).firstMatch(stamp);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
      match.group(7) == null ? 0 : int.parse(match.group(7)!),
    );
  }
}

