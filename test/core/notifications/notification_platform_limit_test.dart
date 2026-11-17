import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';

/// How many reminders each platform is asked to hold.
///
/// Android's alarm ceiling is far above what the app needs; iOS silently drops
/// anything past 64 pending notifications, so it is asked for fewer. What must
/// not differ is *which* reminders: the choice is the soonest by time and id on
/// both, so the first sixty are the same sixty, with the same ids and the same
/// moments. A change here that renumbered or re-timed a notification would
/// strand every alarm already armed on a phone.
void main() {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  final DateTime now = DateTime(2026, 11, 15, 8);

  List<ComposedNotification> desired(int count) => <ComposedNotification>[
        for (int i = 0; i < count; i++)
          ComposedNotification(
            // Distinct and stable, like a real notification's id.
            id: 500 + i,
            title: 'reminder $i',
            body: 'body $i',
            payload: 'debt:d$i',
            // Deliberately given out of time order, so the selection has to
            // sort rather than take the first N of the list.
            when: now.add(Duration(minutes: (i * 37) % count)),
            kind: NotificationKind.debtDueSoon,
            priority: NotificationPriority.soon,
          ),
      ];

  /// One pass of the real service against the fake platform.
  Future<({NotificationSyncResult result, Set<int> held})> syncOn(
    TargetPlatform platform,
    List<ComposedNotification> wanted,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      final FakeNotificationGateway gateway = FakeNotificationGateway();
      final NotificationService service =
          NotificationService(gateway: gateway);
      await service.initialize(localizations: l10n);
      final NotificationSyncResult result = await service.sync(wanted);
      return (
        result: result,
        held: <int>{for (final FakeScheduledNotification n in gateway.held.values) n.id},
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  test('the limit is 400 on Android and 60 on iOS', () {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(NotificationService.maxScheduledForPlatform, 400);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(NotificationService.maxScheduledForPlatform, 60);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('the first sixty ids are the same sixty on both platforms', () async {
    final List<ComposedNotification> wanted = desired(100);
    final ({NotificationSyncResult result, Set<int> held}) android =
        await syncOn(TargetPlatform.android, wanted);
    final ({NotificationSyncResult result, Set<int> held}) ios =
        await syncOn(TargetPlatform.iOS, wanted);

    expect(android.result.desired, 100);
    expect(android.result.armed, 100);
    expect(android.result.droppedByCap, 0);
    expect(ios.result.armed, 60);
    expect(ios.result.droppedByCap, 40);
    expect(android.held, hasLength(100));
    expect(ios.held, hasLength(60));

    // The same sixty, not merely sixty of them.
    final List<int> androidFirstSixty = NotificationService.selectArmed(wanted)
        .take(60)
        .map((ComposedNotification n) => n.id)
        .toList();
    expect(
      ios.result.armedIds.toList()..sort(),
      androidFirstSixty.toList()..sort(),
      reason: 'iOS must arm the soonest sixty, exactly as Android would',
    );
    // And the ids are the planned ones, with their planned moments.
    final Map<int, DateTime> byId = <int, DateTime>{
      for (final ComposedNotification n in wanted) n.id: n.when,
    };
    for (final int id in ios.result.armedIds) {
      final ComposedNotification original = wanted.firstWhere(
        (ComposedNotification n) => n.id == id,
      );
      expect(byId[id], original.when);
    }
  });

  test('a short plan is armed whole on iOS', () async {
    final List<ComposedNotification> wanted = desired(12);
    final ({NotificationSyncResult result, Set<int> held}) ios =
        await syncOn(TargetPlatform.iOS, wanted);
    expect(ios.result.armed, 12);
    expect(ios.result.droppedByCap, 0);
  });
}
