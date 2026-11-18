import 'package:dhimmah/data/services/app_update_service_factory.dart';
import 'package:dhimmah/data/services/play_app_update_service.dart';
import 'package:dhimmah/data/services/unsupported_app_update_service.dart';
import 'package:dhimmah/domain/services/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which update system a platform gets.
///
/// Google Play's in-app updates are an Android library. iOS cannot drive the
/// App Store, so it gets a service that never has anything to offer — and the
/// card on the dashboard stays hidden because there is no state to show.
void main() {
  const AppUpdateInfo info = AppUpdateInfo(
    availableVersionCode: 42,
    updatePriority: 0,
  );

  test('Android gets Play', () {
    expect(
      platformAppUpdateService(platform: TargetPlatform.android),
      isA<PlayAppUpdateService>(),
    );
  });

  test('iOS gets the service that does nothing', () {
    expect(
      platformAppUpdateService(platform: TargetPlatform.iOS),
      isA<UnsupportedAppUpdateService>(),
    );
  });

  test('any other platform is treated like iOS, never assumed Android', () {
    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      expect(
        platformAppUpdateService(platform: platform),
        isA<UnsupportedAppUpdateService>(),
        reason: '$platform must not claim an update it cannot install',
      );
    }
  });

  test('the no-op service never offers, starts or streams anything', () async {
    const UnsupportedAppUpdateService service = UnsupportedAppUpdateService();
    expect(await service.check(), isNull);
    expect(await service.startFlexible(info), isFalse);
    expect(await service.startImmediate(info), isFalse);
    expect(await service.complete(), isFalse);
    expect(await service.updates.isEmpty, isTrue);
  });
}
