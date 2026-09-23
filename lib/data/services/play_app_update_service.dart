import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/services/app_update_service.dart';

/// Google Play's own in-app update system, through the official Play library.
///
/// The app does not download an APK, does not ask a server for a version, and
/// does not install anything itself. It asks the Play Store app, through
/// `com.google.android.play:app-update`, what it would install, and hands the
/// whole download-and-install flow back to Play. That is the only route that is
/// allowed to update an app on a modern Android device, and it is also the only
/// one that respects the user's own Play settings — over mobile data, over
/// metered connections, on a device Play has not yet rolled the release out to.
///
/// Everything below the channel is Kotlin, in
/// `android/app/src/main/kotlin/com/dhimmah/dhimmah/AppUpdateChannel.kt`.
class PlayAppUpdateService implements AppUpdateService {
  PlayAppUpdateService({MethodChannel? channel, EventChannel? events})
      : _channel = channel ?? const MethodChannel(methodChannelName),
        _events = events ?? const EventChannel(eventChannelName);

  /// The channel names are asserted against the Kotlin side by
  /// `test/platform/android_setup_test.dart`: a typo here is invisible until a
  /// device reports "MissingPluginException", which reads like a build problem
  /// rather than a name mismatch.
  static const String methodChannelName = 'dhimmah/app_update';
  static const String eventChannelName = 'dhimmah/app_update/events';

  final MethodChannel _channel;
  final EventChannel _events;

  Stream<AppUpdateEvent>? _updates;

  @override
  Future<AppUpdateInfo?> check() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMapMethod<Object?, Object?>('check');
      if (result == null) return null;
      // Nothing to offer is not a failure and not an event: it is the ordinary
      // case, and the caller shows nothing for it. Play says so with
      // `updateAvailability`, which the Kotlin side has already turned into an
      // empty result.
      if (result['available'] != true) return null;
      return _fromMap(result);
    } on PlatformException {
      // A device without Play, a Play Store that is updating itself, a check
      // that timed out — all of them mean "no update to offer right now". The
      // ledger must keep working, so this is swallowed rather than surfaced.
      return null;
    } on MissingPluginException {
      // A build without the Android side, which is every unit test and any
      // platform that is not Android.
      return null;
    }
  }

  @override
  Future<bool> startFlexible(AppUpdateInfo info) =>
      _invokeBool('startFlexible', info);

  @override
  Future<bool> startImmediate(AppUpdateInfo info) =>
      _invokeBool('startImmediate', info);

  @override
  Future<bool> complete() => _invokeBool('complete', null);

  Future<bool> _invokeBool(String method, AppUpdateInfo? info) async {
    try {
      final bool? started = await _channel.invokeMethod<bool>(
        method,
        info == null ? null : <String, Object?>{
          'availableVersionCode': info.availableVersionCode,
        },
      );
      return started ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Stream<AppUpdateEvent> get updates => _updates ??= _events
      .receiveBroadcastStream()
      .map(_fromEvent)
      .handleError((Object _) {
        // Play's listener is best-effort: a stream error must not take the app
        // down, and the next check will report the real state.
      })
      .where((AppUpdateEvent? event) => event != null)
      .cast<AppUpdateEvent>();

  /// Reads the map the Kotlin side sends.
  ///
  /// Every field is defensive: this crosses a platform boundary, and a missing
  /// key must mean "unknown" rather than a crash in a system the user never
  /// asked for.
  static AppUpdateInfo _fromMap(Map<Object?, Object?> map) {
    int intOf(String key) {
      final Object? value = map[key];
      return value is int ? value : 0;
    }

    return AppUpdateInfo(
      availableVersionCode: intOf('availableVersionCode'),
      updatePriority: intOf('updatePriority'),
      stalenessDays: map['stalenessDays'] is int ? map['stalenessDays']! as int : null,
      flexibleAllowed: map['flexibleAllowed'] == true,
      immediateAllowed: map['immediateAllowed'] == true,
      bytesDownloaded: intOf('bytesDownloaded'),
      totalBytesToDownload: intOf('totalBytesToDownload'),
    );
  }

  /// Reads one install-state report.
  ///
  /// The phase arrives as the name of Play's own `InstallStatus`, mapped on the
  /// Kotlin side; an unknown name is ignored rather than treated as an error,
  /// because a future version of the library may report a status this build has
  /// never heard of.
  static AppUpdateEvent? _fromEvent(Object? event) {
    if (event is! Map) return null;
    final Map<Object?, Object?> map = event.cast<Object?, Object?>();

    final AppUpdatePhase? phase = switch (map['phase']) {
      'downloading' => AppUpdatePhase.downloading,
      'downloaded' => AppUpdatePhase.downloaded,
      'failed' => AppUpdatePhase.failed,
      'installed' => AppUpdatePhase.idle,
      'cancelled' => AppUpdatePhase.idle,
      _ => null,
    };
    if (phase == null) return null;

    return AppUpdateEvent(
      phase: phase,
      info: map['available'] == true ? _fromMap(map) : null,
    );
  }
}
