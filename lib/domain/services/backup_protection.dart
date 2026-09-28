import 'backup_attempts.dart';

/// Whether the user's data is protected, said in one word.
///
/// The app has three layers of facts about a backup — how many snapshots exist,
/// how the folder is, and how the last few attempts went — and none of them is
/// an answer a person can act on. "Eight valid copies and two pending records"
/// is a dashboard; "your data is protected" is an answer. This is where the
/// three become the second thing.
///
/// The order below is the order of the list, and it is not arbitrary: it is
/// **most actionable first**. A situation the user can do something about
/// outranks a situation they cannot, and a situation where their data is
/// genuinely at risk outranks a cosmetic one.
enum BackupProtection {
  /// A snapshot is being written right now. Transient, and never a problem.
  backingUp,

  /// There is no ledger on this device, and there are copies to put back.
  ///
  /// The reinstall case. Almost always the most useful thing the app can say,
  /// and never something to be buried under "some changes are pending".
  recoverable,

  /// There is a ledger here, and there is no copy of it anywhere.
  neverBackedUp,

  /// The app has stopped being able to keep its promise: the folder's permission
  /// was taken back, the folder is gone, or enough attempts have failed in a row
  /// that this is no longer a blip.
  attentionNeeded,

  /// The place the app writes cannot be written to: the folder refuses writes,
  /// or its own snapshots keep failing for want of room.
  storageIssue,

  /// Snapshots are being taken, but they live only inside the app — so deleting
  /// the app would delete them. The durable copy has no home yet.
  noLocation,

  /// Nothing is being taken. The user has copies, and the app will not add to
  /// them on its own, because automatic saving is switched off.
  ///
  /// Found on a real device after an upgrade: a restore carries the settings with
  /// it, so an install can arrive at a new build with automatic saving switched
  /// off and no memory of having chosen that — and the screen said "your data is
  /// protected" while nothing was watching. It outranks [pending] for the same
  /// reason: on its own, waiting changes will never be captured.
  automaticOff,

  /// Changes are waiting to be captured. Not a problem: the app will take them,
  /// and when it is working normally this is not even worth interrupting for.
  pending,

  /// Everything the app promised is true right now.
  protected,
}

/// What the app knows, as plain values.
///
/// Deliberately not the providers' own types: this file is pure Dart with no
/// Flutter and no I/O in it, so every state below can be constructed in a test
/// without a database, a device or a folder. The wiring from the app's state to
/// these values is one small function in the provider layer.
class BackupProtectionInputs {
  const BackupProtectionInputs({
    required this.hasLocalData,
    required this.snapshots,
    required this.folderBackups,
    required this.changedRecords,
    required this.autoEnabled,
    required this.folderConfigured,
    required this.folderRevoked,
    required this.folderUnavailable,
    required this.folderReadOnly,
    required this.attempts,
    this.newestSnapshotAt,
    this.newestFolderCopyAt,
    this.isWorking = false,
  });

  /// Whether the ledger on this device has anything in it.
  final bool hasLocalData;

  /// Snapshots inside the app.
  final int snapshots;

  /// Valid copies in the user's folder, as the folder itself reported.
  final int folderBackups;

  /// Records changed since the newest snapshot.
  final int changedRecords;

  final bool autoEnabled;

  /// Whether a folder has been chosen at all.
  final bool folderConfigured;

  /// The standing grant was taken back, or the folder is no longer there.
  final bool folderRevoked;

  /// The provider answered and the folder could not be used.
  final bool folderUnavailable;

  /// The folder can be read but not written.
  final bool folderReadOnly;

  /// How the app's own attempts have gone.
  final BackupAttempts attempts;

  /// When the newest snapshot inside the app was written, if there is one.
  final DateTime? newestSnapshotAt;

  /// When the newest usable copy in the user's folder was made, if there is one.
  final DateTime? newestFolderCopyAt;

  /// Whether a snapshot is being written at this moment.
  final bool isWorking;

  /// Every copy the user has, wherever it lives.
  int get copies => snapshots + folderBackups;
}

/// The state, and the facts behind it.
///
/// The screen shows [state] and at most two of the facts. Everything else is
/// here for the "protection details" a user can open when they want to know why
/// the app is saying what it is saying — which is the only honest way to be
/// brief: short because the rest is one tap away, not short because it is not
/// known.
class BackupProtectionReport {
  const BackupProtectionReport({
    required this.state,
    required this.lastSuccess,
    required this.copies,
    required this.folderCopies,
    required this.pendingChanges,
    required this.folderConfigured,
    required this.autoEnabled,
    this.lastFailure,
    this.consecutiveFailures = 0,
  });

  final BackupProtection state;

  /// When the data last got into a file that could be read back. Null when it
  /// never has.
  final DateTime? lastSuccess;

  /// How many copies exist across both layers.
  final int copies;

  /// How many of those are in the user's own folder.
  ///
  /// Carried separately because the two layers mean different things to the
  /// user: the app's own snapshots go when the app is uninstalled, and the
  /// folder's stay. A single total would hide exactly that difference.
  final int folderCopies;

  /// How many copies live inside the app: the total, less the folder's.
  int get appCopies => copies - folderCopies;

  /// How many records are not in the newest snapshot yet.
  final int pendingChanges;

  final bool folderConfigured;
  final bool autoEnabled;

  /// Why the last attempt failed, when one did.
  final BackupFailure? lastFailure;
  final int consecutiveFailures;

  /// True when the app can be trusted to capture the next change on its own.
  bool get isAutomatic => autoEnabled;

  /// Whether the user has anything to do. Everything else is the app's job.
  bool get needsUser => switch (state) {
        BackupProtection.attentionNeeded ||
        BackupProtection.storageIssue ||
        BackupProtection.neverBackedUp ||
        BackupProtection.noLocation ||
        BackupProtection.automaticOff =>
          true,
        _ => false,
      };
}

/// The state the app is in, from what it knows.
///
/// Pure: same inputs, same answer, no clock and no I/O. The ordering is the
/// whole of the judgement, and each branch below says why it outranks the ones
/// under it.
BackupProtectionReport protectionFrom(BackupProtectionInputs inputs) {
  final BackupAttempts attempts = inputs.attempts;
  final bool folderBroken =
      inputs.folderRevoked || inputs.folderUnavailable;

  final BackupProtection state;
  if (inputs.isWorking) {
    // Something is happening. Reporting a problem while the app is in the middle
    // of fixing it would be noise at exactly the wrong moment.
    state = BackupProtection.backingUp;
  } else if (!inputs.hasLocalData && inputs.copies > 0) {
    // Nothing here to protect, and everything to put back. This outranks every
    // other state: it is the one moment the user's next act matters, and it is
    // the state a reinstall lands in.
    state = BackupProtection.recoverable;
  } else if (inputs.hasLocalData && inputs.copies == 0) {
    // A ledger with no copy of it anywhere. Outranks a broken folder, because a
    // broken folder is a problem with the protection the user has, and this is
    // the absence of any.
    state = BackupProtection.neverBackedUp;
  } else if (folderBroken || attempts.needsAttention) {
    state = BackupProtection.attentionNeeded;
  } else if (inputs.folderReadOnly || attempts.lastFailure == BackupFailure.storage) {
    state = BackupProtection.storageIssue;
  } else if (!inputs.folderConfigured) {
    // No folder, so nothing the user does will leave this device, and a
    // reinstall would take everything with it. That is the whole condition, not
    // "and there is data": the states where there is something to put *back*
    // are ranked above this one, so what is left here is "there is no durable
    // place for a copy, whether or not there is anything to copy yet".
    //
    // This used to require data in the ledger, and a clean install — empty
    // ledger, no folder, no copies — fell through to `protected`. On the phone
    // that read as a headline saying `بياناتك محمية` above a line saying no copy
    // had ever been made, above a card asking the user to choose a folder: the
    // screen contradicting itself, on the first screen the product ever shows
    // anyone, and answering "why do I need a location?" with "you are protected
    // already".
    state = BackupProtection.noLocation;
  } else if (!inputs.autoEnabled) {
    // Nothing is being added to their copies. Saying "protected" here would be
    // true about the past and false about the future, and it is the present the
    // user is asking about. The condition is deliberately not "and there is
    // data": an install with automatic saving off must never be described as
    // protected, whatever it holds.
    state = BackupProtection.automaticOff;
  } else if (inputs.changedRecords > 0) {
    state = BackupProtection.pending;
  } else {
    state = BackupProtection.protected;
  }

  return BackupProtectionReport(
    state: state,
    lastSuccess: _lastSuccess(inputs),
    copies: inputs.copies,
    folderCopies: inputs.folderBackups,
    pendingChanges: inputs.changedRecords,
    folderConfigured: inputs.folderConfigured,
    autoEnabled: inputs.autoEnabled,
    lastFailure: attempts.lastFailure,
    consecutiveFailures: attempts.consecutiveFailures,
  );
}

/// When the data last reached a readable file.
///
/// The attempt record is the best answer when it exists, because it is written
/// only after a snapshot was read back and proved. The two timestamps are the
/// fallbacks, and they matter for the case the record cannot cover: a device
/// that has just been restored has copies and no attempt history, and reporting
/// "never" there would be false.
///
/// The newest of the two wins rather than either being preferred, because
/// "when did this data last get into a file" is a question about the data, not
/// about which layer answered it.
DateTime? _lastSuccess(BackupProtectionInputs inputs) {
  final DateTime? recorded = inputs.attempts.lastSuccessAt;
  if (recorded != null) return recorded;
  final DateTime? inside = inputs.newestSnapshotAt;
  final DateTime? outside = inputs.newestFolderCopyAt;
  if (inside == null) return outside;
  if (outside == null) return inside;
  return outside.isAfter(inside) ? outside : inside;
}
