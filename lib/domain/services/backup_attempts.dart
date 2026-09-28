/// What the app knows about its own backup attempts.
///
/// Deliberately *not* a dirty flag for the ledger: whether the *data* has
/// changed is answered by the records themselves, and a flag would be lost by
/// the same crash that makes a backup matter. This is the other half — how the
/// app's *attempts* went — which the records cannot answer, because a snapshot
/// that failed leaves no trace in the ledger at all.
///
/// It lives in its own small file rather than in the database, for the reason
/// the folder location does: adding a column would bump the schema version that
/// is stamped into every backup file, and backups from the previous build would
/// then be refused over a change that has nothing to do with the user's data.
library;

/// Why an automatic snapshot did not happen.
///
/// A code, never a sentence and never an exception's text: the sentence is the
/// screen's job and has to be translatable, and an exception's message can carry
/// a path or a provider name that means nothing to the person reading it.
///
/// These are the ways the app's *own* write can fail. A folder that cannot be
/// reached is not one of them: the automatic snapshot is written inside the app
/// and never touches the user's folder, so a revoked grant or a missing folder
/// belongs to the protection status, not here.
enum BackupFailure {
  /// The file could not be written: no space, no permission on the app's own
  /// directory, a write that ended early.
  storage,

  /// The file was written and did not come back as the snapshot that was meant.
  verification,

  /// The ledger could not be read. Rare, and the one failure that is about the
  /// data rather than about the file.
  database,

  /// Something this build has no name for. Recorded rather than swallowed, so
  /// the state can still say that something is wrong.
  unknown,
}

/// How long the app waits before trying again, and when it stops trying often.
///
/// Two failures in a row are usually the same failure, and a retry loop over a
/// failing write is how a full disk becomes a flat battery — so the wait doubles
/// each time up to a ceiling. Past [giveUpAfter] the app is out of ideas on its
/// own: it keeps trying, but no more often than the ceiling, and the state is
/// reported as needing attention rather than as normal.
class BackupBackoff {
  const BackupBackoff._();

  /// The wait after the first failure.
  static const Duration base = Duration(minutes: 2);

  /// The longest wait between attempts, however many have failed.
  static const Duration cap = Duration(hours: 1);

  /// How many failures in a row make this the user's business rather than a
  /// blip. Five tries over roughly a quarter of an hour is not a coincidence.
  static const int giveUpAfter = 5;

  /// The wait after [consecutiveFailures] failures. Zero or fewer means none.
  static Duration delayFor(int consecutiveFailures) {
    if (consecutiveFailures <= 0) return Duration.zero;
    // Doubling from the base, capped. The shift is bounded before it is used:
    // `1 << 40` is a number, but multiplying a Duration by it is not something
    // this needs to find out about at runtime.
    final int steps = (consecutiveFailures - 1).clamp(0, 30);
    final Duration grown = base * (1 << steps);
    return grown > cap ? cap : grown;
  }

  /// When the next attempt may be made, or null when one may be made now.
  static DateTime? nextAttemptAt(DateTime after, int consecutiveFailures) {
    final Duration delay = delayFor(consecutiveFailures);
    if (delay == Duration.zero) return null;
    return after.add(delay);
  }
}

/// The outcome of the attempts made so far.
class BackupAttempts {
  const BackupAttempts({
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.consecutiveFailures = 0,
    this.lastFailure,
    this.nextAttemptAt,
  });

  /// Nothing has been attempted yet — a fresh install, or a state that was
  /// cleared because the situation changed.
  static const BackupAttempts none = BackupAttempts();

  /// When the app last tried, whether or not it worked.
  final DateTime? lastAttemptAt;

  /// When the app last wrote a snapshot it could verify. This is the honest
  /// answer to "when did your data last get out of the app", and it is what the
  /// protection status reports.
  final DateTime? lastSuccessAt;

  /// Attempts since the last success. Reset to zero by one that works.
  final int consecutiveFailures;

  /// Why the last attempt failed, when it did.
  final BackupFailure? lastFailure;

  /// The earliest moment another attempt is worth making. Null means now.
  final DateTime? nextAttemptAt;

  /// True once the app has failed enough times in a row that the user should be
  /// told, rather than the app quietly trying on its own.
  bool get needsAttention => consecutiveFailures >= BackupBackoff.giveUpAfter;

  /// Whether an attempt may be made at [now].
  bool isDueAt(DateTime now) {
    final DateTime? next = nextAttemptAt;
    return next == null || !next.isAfter(now);
  }

  /// Whether the wait is still running at [now].
  bool isWaitingAt(DateTime now) => !isDueAt(now);

  /// The same state, after an attempt that produced a verifiable snapshot.
  ///
  /// The failures, the reason and the wait are left off rather than set to
  /// zero-and-null: those are the defaults, and a success *is* the state of
  /// having none of them.
  BackupAttempts succeeded(DateTime at) => BackupAttempts(
        lastAttemptAt: at,
        lastSuccessAt: at,
      );

  /// The same state, after an attempt that failed.
  BackupAttempts failed(DateTime at, BackupFailure failure) {
    final int failures = consecutiveFailures + 1;
    return BackupAttempts(
      lastAttemptAt: at,
      lastSuccessAt: lastSuccessAt,
      consecutiveFailures: failures,
      lastFailure: failure,
      nextAttemptAt: BackupBackoff.nextAttemptAt(at, failures),
    );
  }

  /// The same state, after something happened that makes the old failures
  /// irrelevant — the user chose a folder, re-authorized one, asked for a check,
  /// or saved a copy by hand. The record of *when it last worked* is kept: that
  /// is a fact about the data, and clearing it would misreport the ledger.
  BackupAttempts cleared() => BackupAttempts(
        lastAttemptAt: lastAttemptAt,
        lastSuccessAt: lastSuccessAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'lastAttemptAt': lastAttemptAt?.toIso8601String(),
        'lastSuccessAt': lastSuccessAt?.toIso8601String(),
        'consecutiveFailures': consecutiveFailures,
        'lastFailure': lastFailure?.name,
        'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      };

  /// Reads a stored state, treating anything unreadable as "no attempt yet".
  ///
  /// A file this app cannot parse is not a reason to refuse to run, and it is
  /// certainly not a reason to claim a backup succeeded: the worst that happens
  /// is one attempt sooner than strictly necessary.
  static BackupAttempts fromJson(Object? decoded) {
    if (decoded is! Map) return none;
    final Object? failures = decoded['consecutiveFailures'];
    final Object? failure = decoded['lastFailure'];
    return BackupAttempts(
      lastAttemptAt: _time(decoded['lastAttemptAt']),
      lastSuccessAt: _time(decoded['lastSuccessAt']),
      consecutiveFailures: failures is int && failures >= 0 ? failures : 0,
      lastFailure: failure is String ? _failureNamed(failure) : null,
      nextAttemptAt: _time(decoded['nextAttemptAt']),
    );
  }

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static BackupFailure? _failureNamed(String name) {
    for (final BackupFailure failure in BackupFailure.values) {
      if (failure.name == name) return failure;
    }
    // A code written by a newer build. It is still a failure, and saying so is
    // the honest thing: the alternative is a state that reports everything fine.
    return BackupFailure.unknown;
  }

  @override
  String toString() => 'BackupAttempts(lastSuccess: $lastSuccessAt, '
      'failures: $consecutiveFailures/${BackupBackoff.giveUpAfter}, '
      'lastFailure: ${lastFailure?.name}, next: $nextAttemptAt)';
}
