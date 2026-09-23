import 'dart:async';

import 'package:dhimmah/domain/services/app_update_service.dart';

/// A Play install, without Play.
///
/// The update layer's job is to decide *when* to look, *what* to offer and *how*
/// to react to what Play says. None of that needs the Play Store, and the parts
/// that matter most — a refused flow, a failed download, a resume in the middle
/// of one — cannot be produced on demand by a real install. So the state machine
/// is tested against this, and the real Play flow is verified by hand on a
/// device (see README, 'Publishing').
class FakeAppUpdateService implements AppUpdateService {
  FakeAppUpdateService({this.info});

  /// What `check` reports. Null means "nothing to offer", which is also what a
  /// device without Play reports.
  AppUpdateInfo? info;

  /// Whether Play accepts the flows. False is the sideloaded case.
  bool acceptsFlows = true;

  /// Whether `complete` reports success.
  bool completes = true;

  /// When set, `check` throws it — the device-without-Play case.
  Object? checkError;

  int checkCount = 0;
  int flexibleStarts = 0;
  int immediateStarts = 0;
  int completes_ = 0;

  final StreamController<AppUpdateEvent> _events =
      StreamController<AppUpdateEvent>.broadcast();

  @override
  Future<AppUpdateInfo?> check() async {
    checkCount++;
    if (checkError != null) throw checkError!;
    return info;
  }

  @override
  Future<bool> startFlexible(AppUpdateInfo info) async {
    flexibleStarts++;
    return acceptsFlows;
  }

  @override
  Future<bool> startImmediate(AppUpdateInfo info) async {
    immediateStarts++;
    return acceptsFlows;
  }

  @override
  Future<bool> complete() async {
    completes_++;
    return completes;
  }

  @override
  Stream<AppUpdateEvent> get updates => _events.stream;

  /// Reports what Play's install listener would report.
  void emit(AppUpdateEvent event) => _events.add(event);

  Future<void> dispose() => _events.close();
}

/// An update Play would offer.
AppUpdateInfo offer({
  int availableVersionCode = 2,
  int updatePriority = 0,
  bool flexible = true,
  bool immediate = false,
  int bytesDownloaded = 0,
  int totalBytesToDownload = 0,
}) {
  return AppUpdateInfo(
    availableVersionCode: availableVersionCode,
    updatePriority: updatePriority,
    flexibleAllowed: flexible,
    immediateAllowed: immediate,
    bytesDownloaded: bytesDownloaded,
    totalBytesToDownload: totalBytesToDownload,
  );
}
