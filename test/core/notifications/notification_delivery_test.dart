import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';

/// The delivery policy: what gets armed, what gets cancelled, and what is left
/// alone.
///
/// Everything here runs against [FakeNotificationGateway], which is the point of
/// the gateway split — these are the rules that decide whether a user can trust
/// a reminder, and they are checked without a phone.
void main() {
  late FakeNotificationGateway platform;
  late NotificationService service;
  late NotificationComposer composer;

  final DateTime now = DateTime(2026, 9, 25, 8);
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    platform = FakeNotificationGateway();
    service = NotificationService(gateway: platform);
    composer = NotificationComposer(
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    );
    await service.initialize(localizations: l10n);
  });

  /// A reminder for a record, at a given moment.
  NotificationIntent intent({
    required String id,
    required DateTime when,
    NotificationKind kind = NotificationKind.debtDueSoon,
  }) =>
      NotificationIntent(
        kind: kind,
        when: when,
        payload: 'debt:$id',
        personName: 'أحمد',
        amount: const Money(150000, AppCurrency.inr),
        direction: DebtDirection.iOwe,
      );

  List<ComposedNotification> composed(List<NotificationIntent> intents) =>
      composer.composeAll(intents);

  group('scheduling is idempotent', () {
    test('one record, one notification, however many passes', () async {
      final List<ComposedNotification> desired =
          composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]);

      final NotificationSyncResult first = await service.sync(desired);
      final NotificationSyncResult second = await service.sync(desired);
      final NotificationSyncResult third = await service.sync(desired);

      expect(first.scheduled, 1);
      expect(first.cancelled, 0);
      expect(
        second.scheduled,
        0,
        reason: 'the second pass finds it already armed and does nothing',
      );
      expect(third.scheduled, 0);
      expect(platform.held, hasLength(1));
      expect(platform.armedPayloads, <String>{'debt:a'});
    });

    test('two records due at the same moment stay two notifications', () async {
      final DateTime due = now.add(const Duration(days: 2));
      await service.sync(
        composed(<NotificationIntent>[
          intent(id: 'a', when: due),
          intent(id: 'b', when: due),
        ]),
      );

      expect(platform.held, hasLength(2));
      expect(
        platform.held.keys.toSet(),
        hasLength(2),
        reason: 'two records never share an id',
      );
      expect(platform.armedPayloads, <String>{'debt:a', 'debt:b'});
    });
  });

  group('a changed reminder replaces itself', () {
    test('a new moment cancels the old notification and arms the new one',
        () async {
      final NotificationIntent before = intent(id: 'a', when: now.add(const Duration(days: 1)));
      await service.sync(composed(<NotificationIntent>[before]));
      final int firstId = platform.held.keys.single;

      final NotificationIntent after = intent(id: 'a', when: now.add(const Duration(days: 3)));
      final NotificationSyncResult result =
          await service.sync(composed(<NotificationIntent>[after]));

      expect(result.cancelled, 1, reason: 'the old moment is gone');
      expect(result.scheduled, 1);
      expect(platform.held, hasLength(1), reason: 'and never both');
      expect(platform.cancelled, <int>[firstId]);
    });

    test('dropping a reminder leaves nothing armed', () async {
      await service.sync(
        composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]),
      );
      expect(platform.held, hasLength(1));

      final NotificationSyncResult result =
          await service.sync(const <ComposedNotification>[]);

      expect(result.cancelled, 1);
      expect(platform.held, isEmpty);
    });
  });

  group('the shade is the user’s, not ours', () {
    test('reconciling never cancels everything', () async {
      await service.sync(
        composed(<NotificationIntent>[
          intent(id: 'a', when: now.add(const Duration(days: 1))),
          intent(id: 'b', when: now.add(const Duration(days: 2))),
        ]),
      );
      // A second record changes; the first is untouched.
      await service.sync(
        composed(<NotificationIntent>[
          intent(id: 'a', when: now.add(const Duration(days: 1))),
          intent(id: 'b', when: now.add(const Duration(days: 5))),
        ]),
      );

      expect(
        platform.cancelAllPendingCalls,
        0,
        reason: 'cancelAll also clears the notifications already delivered, '
            'which is the user’s history',
      );
      expect(platform.cancelled, hasLength(1), reason: 'only what changed');
    });

    test('switching reminders off cancels the pending set once', () async {
      await service.sync(
        composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]),
      );
      final NotificationSyncResult result =
          await service.sync(const <ComposedNotification>[]);
      expect(result.cancelled, 1);
      expect(platform.held, isEmpty);
    });
  });

  group('the cap', () {
    test('arms the soonest and reports what it left for later', () async {
      final List<NotificationIntent> many = <NotificationIntent>[
        for (int i = 0; i < NotificationService.maxScheduled + 50; i++)
          intent(id: 'd$i', when: now.add(Duration(days: i + 1))),
      ];

      final NotificationSyncResult result = await service.sync(composed(many));

      expect(result.desired, NotificationService.maxScheduled + 50);
      expect(result.armed, NotificationService.maxScheduled);
      expect(result.droppedByCap, 50);
      expect(platform.held, hasLength(NotificationService.maxScheduled));
      // The earliest moments are the ones that survive the cap.
      expect(platform.armed.first.when, now.add(const Duration(days: 1)));
      expect(
        platform.armed.last.when,
        now.add(Duration(days: NotificationService.maxScheduled)),
      );
    });

    test('a later pass with fewer records cancels the surplus', () async {
      await service.sync(
        composed(<NotificationIntent>[
          for (int i = 0; i < 5; i++)
            intent(id: 'd$i', when: now.add(Duration(days: i + 1))),
        ]),
      );
      expect(platform.held, hasLength(5));

      await service.sync(
        composed(<NotificationIntent>[
          intent(id: 'd0', when: now.add(const Duration(days: 1))),
        ]),
      );
      expect(platform.held, hasLength(1));
    });
  });

  group('permission', () {
    test('nothing is armed while notifications are denied', () async {
      platform.enabled = false;
      await service.refreshEnvironment();

      final NotificationSyncResult result = await service.sync(
        composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]),
      );

      expect(result.blocked, isTrue);
      expect(platform.held, isEmpty);
      expect(platform.armedPayloads, isEmpty);
    });

    test('granting it is noticed and the set is rebuilt', () async {
      platform.enabled = false;
      await service.refreshEnvironment();
      expect(service.permission, NotificationPermission.denied);

      platform.enabled = true;
      final NotificationEnvironment environment =
          await service.refreshEnvironment();

      expect(environment.changed, isTrue);
      expect(environment.mustReschedule, isTrue);
      expect(service.permission, NotificationPermission.granted);
      expect(
        await service.permissionChanges.first,
        NotificationPermission.granted,
        reason: 'the screens that speak about reminders watch this',
      );
    });

    test('revoking it stops the app arming anything', () async {
      await service.sync(
        composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]),
      );
      expect(platform.held, hasLength(1));

      platform.enabled = false;
      final NotificationEnvironment environment =
          await service.refreshEnvironment();
      expect(environment.changed, isTrue);
      expect(
        environment.mustReschedule,
        isFalse,
        reason: 'a revoked permission leaves nothing to rebuild',
      );

      await service.sync(
        composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]),
      );
      expect(platform.held, isEmpty);
    });

    test('asking is idempotent and reports the platform’s answer', () async {
      platform.enabled = false;
      expect(await service.requestPermission(), NotificationPermission.denied);
      platform.enabled = true;
      expect(await service.requestPermission(), NotificationPermission.granted);
      expect(platform.permissionRequests, 2);
    });
  });

  group('the timezone', () {
    test('a change is noticed and asks for a rebuild', () async {
      final NotificationEnvironment first = await service.refreshEnvironment();
      expect(first.changed, isFalse, reason: 'nothing changed yet');

      platform.timezone = 'Europe/London';
      final NotificationEnvironment second = await service.refreshEnvironment();

      expect(second.changed, isTrue);
      expect(second.mustReschedule, isTrue);
      expect(
        platform.initializeCalls,
        2,
        reason: 'the location has to be re-read, or "20:00" means the old one',
      );
    });

    test('an unchanged zone costs nothing', () async {
      await service.refreshEnvironment();
      final NotificationEnvironment again = await service.refreshEnvironment();
      expect(again.changed, isFalse);
      expect(platform.initializeCalls, 1);
    });
  });

  group('the cold start', () {
    test('a tap that launched the app is held until something is listening',
        () async {
      final FakeNotificationGateway cold =
          FakeNotificationGateway(launch: 'debt:abc');
      final NotificationService fresh = NotificationService(gateway: cold);
      await fresh.initialize(localizations: l10n);

      // Nothing is listening yet, which is exactly the cold-start case.
      expect(fresh.takeLaunchPayload(), 'debt:abc');
      expect(fresh.takeLaunchPayload(), isNull, reason: 'consumed once');
    });

    test('a tap while the app runs arrives on the stream', () async {
      final Future<String> tap = service.taps.first;
      platform.tap('obligation:xyz');
      expect(await tap, 'obligation:xyz');
    });
  });

  group('failure handling', () {
    test('one refused notification does not stop the rest', () async {
      // A platform that refuses an alarm (Samsung's 500-alarm ceiling throws)
      // must not take the save down with it: the ledger is already written.
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      platform.scheduleFailure = Exception('alarm limit reached');
      final List<ComposedNotification> desired = composed(<NotificationIntent>[
        intent(id: 'a', when: now.add(const Duration(days: 1))),
        intent(id: 'b', when: now.add(const Duration(days: 2))),
      ]);

      final NotificationSyncResult result = await service.sync(desired);

      expect(result.scheduled, 0);
      expect(
        reported,
        hasLength(2),
        reason: 'each refusal is reported, and neither stops the other',
      );
      expect(reported.first.library, 'dhimmah notifications');
      expect(platform.held, isEmpty);
    });

    test('a platform that cannot schedule arms nothing, and says so', () async {
      final NotificationService desktop = NotificationService(
        gateway: FakeNotificationGateway(supported: false),
      );
      await desktop.initialize(localizations: l10n);

      expect(desktop.supportsScheduling, isFalse);
      final NotificationSyncResult result = await desktop.sync(
        composed(<NotificationIntent>[intent(id: 'a', when: now.add(const Duration(days: 1)))]),
      );
      expect(result.blocked, isTrue);
      expect(desktop.permission, NotificationPermission.unsupported);
    });
  });
}
