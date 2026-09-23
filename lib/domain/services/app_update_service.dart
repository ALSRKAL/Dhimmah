import 'package:meta/meta.dart';

/// Whether an update is being offered, and how far along it is.
///
/// One value rather than a handful of booleans, because the states are a
/// sequence and not a set: a download cannot be in progress before it has been
/// started, and it cannot be ready to install before it has finished. A state
/// machine makes the impossible combinations unrepresentable, which is what
/// stops a second tap starting a second download.
enum AppUpdatePhase {
  /// Nothing to say. Either the app has not looked yet, or it looked and the
  /// installed version is the one Google Play serves.
  idle,

  /// A check is in flight. Only ever entered once at a time.
  checking,

  /// Google Play has a newer version and the user has not started it.
  available,

  /// A flexible update is downloading. The user keeps using the app.
  downloading,

  /// The download finished and the install is waiting for the user.
  downloaded,

  /// An error the user could act on — a check that failed, a download that
  /// stopped. Not shown for anything recoverable by simply trying later.
  failed,
}

/// What Google Play knows about an update.
///
/// Everything here comes from the Play library; nothing is inferred. In
/// particular [availableVersionCode] is Play's own answer, and the app never
/// decides for itself that an update exists by comparing version strings — Play
/// owns update eligibility, and a client that second-guesses it either nags
/// about an update it cannot deliver or hides one it can.
@immutable
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.availableVersionCode,
    required this.updatePriority,
    this.stalenessDays,
    this.flexibleAllowed = false,
    this.immediateAllowed = false,
    this.bytesDownloaded = 0,
    this.totalBytesToDownload = 0,
  });

  /// The version code Play would install, as Play reports it.
  final int availableVersionCode;

  /// `inAppUpdatePriority` from the release, 0–5.
  ///
  /// Play returns the highest priority across every version between the one
  /// installed and the one offered, so a critical fix released two versions ago
  /// still reports its urgency. This is the only signal the app uses to decide
  /// between a quiet prompt and a blocking one.
  final int updatePriority;

  /// Days since the installed version was published, when Play knows.
  final int? stalenessDays;

  /// Whether Play will run a flexible (background) update for this install.
  final bool flexibleAllowed;

  /// Whether Play will run an immediate (blocking) update for this install.
  final bool immediateAllowed;

  final int bytesDownloaded;
  final int totalBytesToDownload;

  /// The fraction downloaded, or null when the total is not known yet.
  double? get progress {
    if (totalBytesToDownload <= 0) return null;
    return (bytesDownloaded / totalBytesToDownload).clamp(0.0, 1.0);
  }

  /// Whether the update is urgent enough to interrupt.
  ///
  /// Four and above. Play's scale is 0–5 and the Play Developer API is the only
  /// way to set it, so a release that must interrupt is a deliberate act by
  /// whoever published it rather than something this app decides.
  bool get isUrgent => updatePriority >= urgentPriority;

  static const int urgentPriority = 4;

  AppUpdateInfo copyWith({
    int? availableVersionCode,
    int? updatePriority,
    int? stalenessDays,
    bool? flexibleAllowed,
    bool? immediateAllowed,
    int? bytesDownloaded,
    int? totalBytesToDownload,
  }) {
    return AppUpdateInfo(
      availableVersionCode: availableVersionCode ?? this.availableVersionCode,
      updatePriority: updatePriority ?? this.updatePriority,
      stalenessDays: stalenessDays ?? this.stalenessDays,
      flexibleAllowed: flexibleAllowed ?? this.flexibleAllowed,
      immediateAllowed: immediateAllowed ?? this.immediateAllowed,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytesToDownload: totalBytesToDownload ?? this.totalBytesToDownload,
    );
  }

  /// What the update layer reports, with no personal data in it.
  ///
  /// The ledger holds names, amounts and notes; none of that belongs in a log
  /// line about an app update, and the update layer never sees it.
  @override
  String toString() => 'AppUpdateInfo(code: $availableVersionCode, '
      'priority: $updatePriority, flexible: $flexibleAllowed, '
      'immediate: $immediateAllowed)';
}

/// Something Play reported about an update already in flight.
///
/// Separate from [AppUpdateInfo] because the phase is the platform's answer, not
/// something the app works out: Play's install listener knows whether a download
/// is running, has finished, or stopped with an error, and inferring that from
/// byte counts would be guessing at a state the platform already names.
@immutable
class AppUpdateEvent {
  const AppUpdateEvent({required this.phase, this.info});

  final AppUpdatePhase phase;

  /// What Play knows about the version being installed, when it says anything.
  final AppUpdateInfo? info;
}

/// The update system as the app sees it.
///
/// An interface rather than a direct call into the platform, for two reasons.
/// The state machine above it can then be tested without Google Play — which is
/// the only way to test the failure paths, since a real Play install cannot be
/// made to fail on demand — and the app keeps working, unchanged, on a device
/// where the Play library is not present at all.
abstract interface class AppUpdateService {
  /// Asks Google Play what it would install.
  ///
  /// Returns null when there is nothing to offer, when the app was not installed
  /// by Play, or when the check failed. All three are the same thing to the
  /// caller: no update prompt.
  Future<AppUpdateInfo?> check();

  /// Asks Play to download and install in the background.
  ///
  /// Returns false when Play refused — for instance because a flexible update is
  /// not allowed for this install — and true when the flow started. The download
  /// itself is reported through [updates].
  Future<bool> startFlexible(AppUpdateInfo info);

  /// Asks Play to run its full-screen update flow.
  Future<bool> startImmediate(AppUpdateInfo info);

  /// Installs a flexible update that has finished downloading.
  ///
  /// Play shows its own progress and restarts the app; nothing after this call
  /// is the app's to draw.
  Future<bool> complete();

  /// Install progress and completion, from Play's own listener.
  ///
  /// Empty on a device without Play, so a listener that simply waits stays
  /// waiting rather than erroring.
  Stream<AppUpdateEvent> get updates;
}
