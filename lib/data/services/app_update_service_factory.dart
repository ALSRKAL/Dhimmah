import 'package:flutter/foundation.dart';

import '../../domain/services/app_update_service.dart';
import 'play_app_update_service.dart';
import 'unsupported_app_update_service.dart';

/// The update service the platform can actually honour.
///
/// Google Play's in-app updates are an Android library; iOS has no equivalent
/// an app can drive. Every other platform — a desktop build, a test — is
/// treated the same way, rather than falling into an `else` that assumes
/// Android. The choice is made once, in `main`, so no screen decides it again.
AppUpdateService platformAppUpdateService({TargetPlatform? platform}) {
  final TargetPlatform target = platform ?? defaultTargetPlatform;
  return switch (target) {
    TargetPlatform.android => PlayAppUpdateService(),
    TargetPlatform.iOS => const UnsupportedAppUpdateService(),
    _ => const UnsupportedAppUpdateService(),
  };
}
