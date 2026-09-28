import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';

import '../../core/files/backup_attempt_store.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/services/backup_attempts.dart';
import '../../domain/services/backup_format.dart';
import '../database/app_database.dart';
import 'backup_service.dart';

/// Why a snapshot is being taken, in the user's terms.
enum BackupTrigger {
  /// The user asked for one.
  manual,

  /// Changes have accumulated and the app is leaving the foreground.
  onPause,

  /// The user has been working, changes are waiting, and the last snapshot is
  /// old enough to be replaced.
  inSession,

  /// The last snapshot is old enough that a fresh one is worth having.
  periodic,
}

/// Decides when the app takes its own snapshot, and takes it.
///
/// The policy is deliberately *not* a timer, and deliberately not "one backup
/// per save". It is built on one question the database can answer on its own:
/// **has anything changed since the last snapshot?** No dirty flag is stored,
/// because a flag can be lost by the same crash that makes the backup matter —
/// the records themselves are the evidence, so a backup taken after an unclean
/// shutdown is still taken.
///
/// Given that, a snapshot is due when:
///
/// * **at least [mutationThreshold] records** have changed since the last
///   snapshot, whatever the interval — a burst of editing is worth capturing
///   even if it is recent;
/// * the last snapshot is at least [minInterval] old and the app is **leaving
///   the foreground** — the one moment when writing a few megabytes cannot be
///   seen, because the user is leaving;
/// * the last snapshot is at least [minInterval] old, the user is still working,
///   and **nothing has been written for [quietPeriod]** — so a long session
///   keeps producing recovery points instead of waiting for the user to leave.
///   The quiet period is what keeps that from landing in the middle of a save.
///
/// Work happens only at those moments, which are the moments when a few hundred
/// milliseconds of file writing cannot be seen: never mid-edit, never on a
/// frame the user is waiting for.
///
/// What happens when a snapshot *fails* is the other half, and it is not this
/// policy's business: see [BackupAttempts] and [BackupBackoff]. A failure is
/// recorded, the next attempt is pushed further out each time, and past a
/// threshold the state stops calling it a blip — because a retry loop over a
/// failing write is how a full disk becomes a flat battery.
class BackupCoordinator {
  BackupCoordinator({
    required AppDatabase database,
    required this.backups,
    required this.settings,
    required this.clock,
    BackupAttemptStore attempts = const BackupAttemptStore(),
  })  : _db = database,
        _attemptStore = attempts;

  final AppDatabase _db;

  /// Where snapshots are written and read.
  final BackupService backups;

  /// Read fresh on every decision, so the switch in Settings takes effect at
  /// the next boundary rather than at the next launch.
  final AppSettings Function() settings;

  final DateTime Function() clock;

  final BackupAttemptStore _attemptStore;

  /// The shortest gap between two automatic snapshots.
  static const Duration minInterval = Duration(minutes: 15);

  /// How long a ledger may go without a fresh snapshot while being used.
  static const Duration maxAge = Duration(hours: 24);

  /// How many changed records make a snapshot worth taking on their own.
  static const int mutationThreshold = 20;

  /// How long the ledger must have been left alone before the app will write a
  /// snapshot while the user is still in it.
  ///
  /// A write is not instant, and the moment to start one is after the user has
  /// stopped causing writes — otherwise the snapshot and the user's save compete
  /// for the same disk and the same frame.
  static const Duration quietPeriod = Duration(seconds: 5);

  StreamSubscription<Set<TableUpdate>>? _updates;
  /// The snapshot currently being written, if any.
  ///
  /// The claim is made *before* the first await rather than by a flag checked
  /// afterwards: two calls that both read `false` and then both proceed are not
  /// a guard, they are a race with extra steps. Because the future is shared,
  /// every caller is also told the same thing — the answer to "has it been
  /// saved?" cannot depend on which caller asked.
  Future<BackupFileInfo?>? _inFlight;

  /// When the ledger was last changed, as far as this process has seen.
  ///
  /// Null before the first change of the session, which is the honest answer:
  /// nothing has been observed to change, so there is nothing to wait for.
  ///
  /// This replaced a counter of table updates that nothing ever read. A count
  /// would have been the wrong signal anyway — the policy needs to know *when*
  /// the last change was, not how many there have been, because what it is
  /// protecting is the moment a write can start.
  DateTime? _lastChangeAt;

  BackupAttempts _attempts = BackupAttempts.none;
  Future<void>? _loaded;

  /// How the app's own attempts have gone. Read by the status model.
  ///
  /// Before [ready] has completed this is [BackupAttempts.none], which is the
  /// state of a fresh install. It is deliberately not what a caller should
  /// report: whoever shows this to the user waits for [ready] first.
  BackupAttempts get attempts => _attempts;

  /// Completes once what was stored last launch has been read.
  Future<void> get ready => _loaded ?? Future<void>.value();

  /// Watches the data tables, and reads back how the last attempts went.
  ///
  /// The subscription does not take the snapshot: it only notes *when* the
  /// ledger last changed, so that a snapshot while the user is working can wait
  /// for a pause. The snapshot itself happens at a boundary.
  void start() {
    _updates ??= _db
        .tableUpdates(TableUpdateQuery.onAllTables(<TableInfo<Table, dynamic>>[
      _db.people,
      _db.debts,
      _db.debtPeople,
      _db.payments,
      _db.obligations,
      _db.obligationOccurrences,
      _db.reminders,
    ]))
        .listen((Set<TableUpdate> _) => _lastChangeAt = clock());
    _loaded ??= _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    try {
      _attempts = await _attemptStore.read();
    } on Object {
      // A bookkeeping file that cannot be read must never be able to stop a
      // backup. The worst that comes of this is one attempt sooner than the
      // wait would have allowed, and the state still reports what it knows.
      _attempts = BackupAttempts.none;
    }
  }

  Future<void> dispose() async {
    await _updates?.cancel();
    _updates = null;
  }

  /// Forgets the record of failed attempts, without forgetting when a snapshot
  /// last worked.
  ///
  /// Called when something happens that makes the old failures irrelevant: the
  /// user chose a folder, re-authorized one, asked for a check, or saved a copy
  /// by hand. Without it, a device that failed five times while a folder was
  /// missing would keep waiting an hour between attempts after the folder came
  /// back.
  Future<void> forgetFailures() async {
    _attempts = _attempts.cleared();
    await _attemptStore.write(_attempts);
  }

  /// Whether the wait after a failure has run out at [now].
  bool _mayAttempt(DateTime now) => _attempts.isDueAt(now);

  /// What, if anything, is worth doing at this moment.
  Future<BackupTrigger?> dueTrigger({required bool leavingForeground}) async {
    if (!settings().backupAutoEnabled) return null;
    // An install with nothing in it has nothing worth keeping, and a snapshot
    // of an empty ledger on first launch would only be noise in the list.
    if (await backups.isEmpty()) return null;

    final BackupFileInfo? last = await backups.latest();
    final DateTime now = clock();

    if (last == null) return BackupTrigger.periodic;
    // A snapshot dated in the future — a clock that was wrong, or was corrected
    // — cannot say whether it is up to date: every record in the ledger looks
    // older than it, so nothing ever counts as changed. Rather than treating
    // that as "saved", which is a claim made on evidence that cannot be true,
    // the next boundary takes a fresh one. One extra snapshot costs a file; the
    // alternative costs the user their most recent work.
    if (last.createdAt.isAfter(now)) return BackupTrigger.periodic;

    final Duration age = now.difference(last.createdAt);
    final int changed = await changedRecordsSince(last.createdAt);
    if (changed == 0) return null;

    // A burst is worth capturing now, whatever the interval.
    if (changed >= mutationThreshold) return BackupTrigger.onPause;
    if (age < minInterval) return null;

    if (leavingForeground) return BackupTrigger.onPause;

    // Still in the app. Writing while the user is working is only acceptable if
    // they have stopped causing writes; otherwise the snapshot competes with the
    // save that triggered it, for the same disk and the same frame.
    final DateTime? changedAt = _lastChangeAt;
    if (changedAt != null && now.difference(changedAt) < quietPeriod) return null;

    // The name says which of the two reasons this is: a ledger that has gone a
    // day without a snapshot, or a working session that has earned a new
    // recovery point.
    if (age >= maxAge) return BackupTrigger.periodic;
    return BackupTrigger.inSession;
  }

  /// How many records the newest snapshot may not contain.
  ///
  /// Zero means the snapshot holds everything the ledger does; anything else
  /// means the user's most recent work is not in a file yet. This is what the
  /// settings screen reports, and it is deliberately the same computation the
  /// decision above uses — a status card that disagrees with the policy that
  /// writes the snapshots is worse than no status card.
  ///
  /// A snapshot dated in the future counts as one pending change, for the reason
  /// given above: the question cannot be answered from it, and "cannot answer"
  /// must never be shown as "nothing to save".
  Future<int> pendingChanges() async {
    final BackupFileInfo? last = await backups.latest();
    if (last == null) return 1;
    if (last.createdAt.isAfter(clock())) return 1;
    return changedRecordsSince(last.createdAt);
  }

  /// Takes a snapshot if one is due, and returns what it wrote.
  ///
  /// Single-flight: while a snapshot is being written, this returns the same
  /// future to everyone who asks, so a pause, a resume and a burst of changes
  /// arriving together produce one file and one answer rather than three files.
  Future<BackupFileInfo?> runIfDue({required bool leavingForeground}) {
    return _inFlight ??=
        _run(leavingForeground).whenComplete(() => _inFlight = null);
  }

  Future<BackupFileInfo?> _run(bool leavingForeground) async {
    // What was stored last launch has to be in hand before the wait is judged,
    // or a device that failed five times yesterday would try again immediately.
    await ready;
    final DateTime now = clock();
    // The wait after a failure is checked before anything is read, so a device
    // that cannot write does not pay for the decision as well.
    if (!_mayAttempt(now)) return null;

    final BackupTrigger? trigger =
        await dueTrigger(leavingForeground: leavingForeground);
    if (trigger == null) return null;

    try {
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.auto);
      await _record(attempts: _attempts.succeeded(clock()));
      return BackupFileInfo(
        path: written.file.path,
        kind: BackupKind.auto,
        createdAt: clock(),
        sizeBytes: await written.file.length(),
      );
    } on BackupFormatException {
      // It was written and did not come back as the snapshot that was meant.
      await _record(attempts: _attempts.failed(clock(), BackupFailure.verification));
      return null;
    } on FileSystemException {
      // No space, no permission on the app's own directory, a write that ended
      // early. The data is in the database and the previous snapshot is still
      // there; the next attempt is further out, and the state says so.
      await _record(attempts: _attempts.failed(clock(), BackupFailure.storage));
      return null;
    } on Object {
      await _record(attempts: _attempts.failed(clock(), BackupFailure.database));
      return null;
    }
  }

  /// Remembers how an attempt went, and never lets that bookkeeping fail the
  /// snapshot that produced it.
  Future<void> _record({required BackupAttempts attempts}) async {
    _attempts = attempts;
    await _attemptStore.write(attempts);
  }

  /// How many records have changed since [since].
  ///
  /// Counted from the records themselves — a row's own `updated_at` is the
  /// honest answer to "did this change?", and it survives a crash that a flag
  /// would not. Activity entries are not counted: they are written *by* the
  /// changes this is measuring, so counting them would make every ledger look
  /// permanently dirty.
  Future<int> changedRecordsSince(DateTime since) async {
    final List<int> counts = await Future.wait<int>(<Future<int>>[
      _countChanged(_db.people, _db.people.updatedAt, since),
      _countChanged(_db.debts, _db.debts.updatedAt, since),
      _countChanged(_db.obligations, _db.obligations.updatedAt, since),
      _countChanged(_db.reminders, _db.reminders.updatedAt, since),
      _countChanged(_db.payments, _db.payments.createdAt, since),
      _countChanged(
        _db.obligationOccurrences,
        _db.obligationOccurrences.updatedAt,
        since,
      ),
      // A link has only the moment it was made, which is the right question for
      // it: a new participant is a change worth backing up.
      _countChanged(_db.debtPeople, _db.debtPeople.createdAt, since),
    ]);
    int total = 0;
    for (final int count in counts) {
      total += count;
    }
    return total;
  }

  Future<int> _countChanged(
    TableInfo<Table, dynamic> table,
    GeneratedColumn<int> column,
    DateTime since,
  ) async {
    // The timestamp columns store epoch milliseconds, so the comparison is
    // numeric — no text parsing, no timezone, and it uses the same value the
    // row itself was written with.
    final Expression<int> count = table.$columns.first.count();
    final TypedResult row = await (_db.selectOnly(table)
          ..addColumns(<Expression<Object>>[count])
          ..where(column.isBiggerThanValue(since.millisecondsSinceEpoch)))
        .getSingle();
    return row.read(count) ?? 0;
  }
}
