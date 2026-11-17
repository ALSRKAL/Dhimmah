import 'dart:async';

import '../../domain/services/app_update_service.dart';

/// The update system on a platform that has none.
///
/// Dhimmah updates itself through Google Play's own in-app update library, and
/// only through it: the app asks no server for a version and downloads no APK.
/// iOS has no equivalent — the App Store updates an app between launches, and
/// an app cannot drive that itself — so the honest implementation is one that
/// never has anything to offer. The card that draws an update reads the same
/// controller as everywhere else and stays hidden because there is no state to
/// show.
class UnsupportedAppUpdateService implements AppUpdateService {
  const UnsupportedAppUpdateService();

  @override
  Future<AppUpdateInfo?> check() async => null;

  @override
  Future<bool> startFlexible(AppUpdateInfo info) async => false;

  @override
  Future<bool> startImmediate(AppUpdateInfo info) async => false;

  @override
  Future<bool> complete() async => false;

  @override
  Stream<AppUpdateEvent> get updates => const Stream<AppUpdateEvent>.empty();
}
