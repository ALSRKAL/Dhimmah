import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/app_update_service.dart';

/// What the update system is doing, as one value.
///
/// One field rather than a handful of booleans, because the states are a
/// sequence and not a set: a download cannot be running before it was started,
/// and it cannot be ready to install before it finished. The impossible
/// combinations are what let a second tap start a second download.
@immutable
class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.info,
    this.dismissed = false,
  });

  final AppUpdatePhase phase;

  /// What Play reported, when it reported anything.
  final AppUpdateInfo? info;

  /// Whether the user has waved this update away.
  ///
  /// Held in memory for the session rather than written to settings: "later"
  /// means later, not never, and a stored dismissal is how an app ends up never
  /// offering an update again.
  final bool dismissed;

  /// Whether anything should be drawn.
  ///
  /// A finished download is shown even after a dismissal: the bytes are already
  /// on the device, and hiding the button that installs them would leave a
  /// pending update with no way to finish it.
  bool get isVisible =>
      info != null &&
      (phase == AppUpdatePhase.available ||
          phase == AppUpdatePhase.downloading ||
          phase == AppUpdatePhase.downloaded) &&
      (!dismissed || phase == AppUpdatePhase.downloaded);

  /// Whether an action is in flight, so the button can be disabled.
  bool get isBusy =>
      phase == AppUpdatePhase.downloading || phase == AppUpdatePhase.checking;

  AppUpdateState copyWith({
    AppUpdatePhase? phase,
    AppUpdateInfo? info,
    bool? dismissed,
  }) {
    return AppUpdateState(
      phase: phase ?? this.phase,
      info: info ?? this.info,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// The update system's single point of contact with the app.
///
/// No screen calls Play. They read this and call its three actions, which is
/// what keeps "is there an update" out of a `build()`: the state changes only
/// when this class decides to look, and it decides on a clock rather than on a
/// frame.
class AppUpdateController extends Notifier<AppUpdateState>
    with WidgetsBindingObserver {
  /// How long to wait before looking again.
  ///
  /// Play throttles update checks itself, so asking more often than this cannot
  /// discover an update any sooner — it only spends the user's battery. Six
  /// hours means a phone opened twenty times a day asks four times.
  ///
  /// There is deliberately no timer behind this. A timer would keep the app
  /// awake for a case that does not happen on a phone — a session left in the
  /// foreground for hours without a single pause — and a phone that is used at
  /// all is resumed far more often than every six hours, which is when the next
  /// look happens anyway.
  static const Duration checkInterval = Duration(hours: 6);

  StreamSubscription<AppUpdateEvent>? _installState;
  DateTime? _lastCheck;
  bool _checking = false;
  bool _starting = false;
  bool _installing = false;
  bool _disposed = false;

  AppUpdateService get _service => ref.read(appUpdateServiceProvider);

  @override
  AppUpdateState build() {
    // The controller watches the app's lifecycle itself rather than relying on a
    // screen to forward events: the update prompt has to survive navigation, and
    // a listener owned by a screen would be created and disposed as the user
    // moves around.
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _disposed = true;
      _installState?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    return const AppUpdateState();
  }

  /// Looks for an update, once, without blocking anything.
  ///
  /// Called after the first frame and on resume; never from a build. A call
  /// while a check is in flight, or inside [checkInterval], does nothing — which
  /// is what makes it safe to call from a lifecycle event that fires several
  /// times in a row.
  Future<void> checkIfDue({bool force = false}) async {
    if (_disposed || _checking) return;
    if (!force) {
      final DateTime? last = _lastCheck;
      if (last != null && DateTime.now().difference(last) < checkInterval) {
        return;
      }
    }

    _checking = true;
    state = state.copyWith(phase: AppUpdatePhase.checking);
    try {
      final AppUpdateInfo? info = await _service.check();
      _lastCheck = DateTime.now();
      if (_disposed) return;

      if (info == null) {
        state = const AppUpdateState();
        return;
      }

      state = AppUpdateState(
        phase: info.flexibleAllowed || info.immediateAllowed
            ? AppUpdatePhase.available
            : AppUpdatePhase.downloaded,
        info: info,
      );
      _listenForInstallState();
    } on Object {
      // Nothing here is worth telling the user about: a check that failed is not
      // a problem they have, and the ledger does not depend on it.
      if (!_disposed) state = const AppUpdateState();
    } finally {
      _checking = false;
    }
  }

  /// Starts the update the user asked for.
  ///
  /// One action rather than two, because choosing between the quiet flow and the
  /// blocking one is a policy decision that belongs here — [AppUpdateInfo.
  /// isUrgent] together with Play's own answer about what this install allows —
  /// and not something each call site decides for itself.
  Future<void> start() async {
    final AppUpdateInfo? info = state.info;
    if (_disposed || _starting || info == null) return;
    if (state.phase != AppUpdatePhase.available) return;

    // The guard is a field and not the phase, and it is set *before* the first
    // await. Three taps in the same frame all read the same state — the phase
    // only moves once Play answers — so a check on the phase alone let every one
    // of them through and started three downloads. This is the whole reason the
    // state machine exists.
    _starting = true;
    try {
      final bool immediate = info.isUrgent && info.immediateAllowed;
      final bool started = immediate
          ? await _service.startImmediate(info)
          : await _service.startFlexible(info);
      if (_disposed) return;

      if (!started) {
        // Play refused — most often because this copy was not installed by Play,
        // which is every sideloaded build. Saying so would be telling the user
        // about the build rather than about their app, so the prompt simply goes.
        state = const AppUpdateState();
        return;
      }

      // Play owns both flows from here: it shows its own progress, and for an
      // immediate update it takes the screen. The app's job is to listen.
      state = state.copyWith(phase: AppUpdatePhase.downloading);
      _listenForInstallState();
    } finally {
      _starting = false;
    }
  }

  /// Installs a download that has finished.
  Future<void> install() async {
    // Once per session, and never twice. `completeUpdate` hands the install to
    // Play, which restarts the app; a second call would be asking Play to
    // install something it is already installing.
    if (_disposed || _installing || state.phase != AppUpdatePhase.downloaded) {
      return;
    }
    _installing = true;
    await _service.complete();
  }

  /// Hides the prompt for now.
  ///
  /// The download is not stopped and the update is not cancelled: "later" means
  /// "not in front of me".
  void dismiss() {
    if (_disposed) return;
    state = state.copyWith(dismissed: true);
  }

  /// The app came back to the foreground.
  ///
  /// The only lifecycle event that triggers a look. Pausing, hiding and
  /// detaching do nothing: there is no one to show anything to.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) return;
    // A download that was running when the app went away has to be picked up
    // where Play left it, so a resume during one looks immediately. Otherwise
    // the throttle stands, which is what stops a series of resumes from becoming
    // a series of checks.
    unawaited(checkIfDue(force: _pending));
  }

  /// Whether a resume should look straight away.
  bool get _pending =>
      state.phase == AppUpdatePhase.downloading ||
      state.phase == AppUpdatePhase.downloaded;

  /// Attaches to Play's install listener, once.
  void _listenForInstallState() {
    _installState ??= _service.updates.listen(_onInstallState);
  }

  void _onInstallState(AppUpdateEvent event) {
    if (_disposed) return;
    switch (event.phase) {
      case AppUpdatePhase.downloading:
        state = state.copyWith(
          phase: AppUpdatePhase.downloading,
          info: event.info ?? state.info,
        );
      case AppUpdatePhase.downloaded:
        // A finished download is worth showing even to someone who said "later".
        state = state.copyWith(
          phase: AppUpdatePhase.downloaded,
          info: event.info ?? state.info,
          dismissed: false,
        );
      case AppUpdatePhase.failed:
        state = const AppUpdateState();
      case AppUpdatePhase.idle:
      case AppUpdatePhase.checking:
      case AppUpdatePhase.available:
        break;
    }
  }
}

/// The update service.
///
/// Overridden in `main` with the Play implementation and in tests with a fake,
/// which is what lets the whole state machine be exercised without Google Play —
/// including the failure paths, which a real Play install cannot be made to
/// produce on demand.
final Provider<AppUpdateService> appUpdateServiceProvider =
    Provider<AppUpdateService>(
  (Ref ref) => throw UnimplementedError(
    'appUpdateServiceProvider must be overridden — see main.dart',
  ),
);

final NotifierProvider<AppUpdateController, AppUpdateState>
    appUpdateControllerProvider =
    NotifierProvider<AppUpdateController, AppUpdateState>(
  AppUpdateController.new,
);
