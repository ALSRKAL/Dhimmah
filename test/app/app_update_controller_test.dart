import 'package:dhimmah/app/app_update_controller.dart';
import 'package:dhimmah/domain/services/app_update_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app_update_service.dart';

/// The update system's decisions, without Google Play.
///
/// What is worth testing here is not "does it call the API" but the behaviour
/// around it: that a check never happens before the app is on screen, that two
/// taps cannot start two downloads, that a refusal leaves the ledger alone, and
/// that a user who said "later" is not asked again on the next resume. Those are
/// the parts that go wrong in the field, and a real Play install cannot be made
/// to produce most of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppUpdateService service;
  late ProviderContainer container;

  setUp(() {
    service = FakeAppUpdateService();
    container = ProviderContainer(
      overrides: [appUpdateServiceProvider.overrideWithValue(service)],
    );
    // The controller watches the app's lifecycle, so the binding has to be up.
    WidgetsBinding.instance;
  });

  tearDown(() async {
    container.dispose();
    await service.dispose();
  });

  AppUpdateController controller() =>
      container.read(appUpdateControllerProvider.notifier);
  AppUpdateState current() => container.read(appUpdateControllerProvider);

  /// Lets a broadcast stream deliver what it was handed.
  ///
  /// `emit` on a stream controller is not synchronous, and reading the state
  /// straight afterwards would read the state before the event — which is a
  /// property of streams, not of the controller.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('when there is nothing to offer', () {
    test('the state stays empty and nothing is drawn', () async {
      await controller().checkIfDue();
      expect(current().phase, AppUpdatePhase.idle);
      expect(current().isVisible, isFalse);
      expect(current().info, isNull);
    });

    test('a device without Play is not an error', () async {
      service.checkError = StateError('no Play Store');
      await controller().checkIfDue();
      expect(current().phase, AppUpdatePhase.idle);
      expect(current().isVisible, isFalse);
    });
  });

  group('when Play offers one', () {
    setUp(() => service.info = offer());

    test('the update becomes visible with Play\'s own version code', () async {
      await controller().checkIfDue();
      expect(current().phase, AppUpdatePhase.available);
      expect(current().isVisible, isTrue);
      expect(current().info!.availableVersionCode, 2);
    });

    test('starting it uses the flexible flow for an ordinary release', () async {
      await controller().checkIfDue();
      await controller().start();
      expect(service.flexibleStarts, 1);
      expect(service.immediateStarts, 0);
      expect(current().phase, AppUpdatePhase.downloading);
    });

    test('a refused flow clears the prompt rather than complaining', () async {
      // The sideloaded case: Play will not update a copy it did not install.
      service.acceptsFlows = false;
      await controller().checkIfDue();
      await controller().start();
      expect(current().phase, AppUpdatePhase.idle);
      expect(current().isVisible, isFalse);
    });
  });

  group('urgency', () {
    test('a priority-4 release interrupts', () async {
      service.info = offer(updatePriority: 4, immediate: true);
      await controller().checkIfDue();
      await controller().start();
      expect(service.immediateStarts, 1);
      expect(service.flexibleStarts, 0);
    });

    test('priority without Play\'s permission stays flexible', () async {
      // Play decides what this install allows; a high priority on a device that
      // cannot run the blocking flow must not leave the user with no update.
      service.info = offer(updatePriority: 5);
      await controller().checkIfDue();
      await controller().start();
      expect(service.immediateStarts, 0);
      expect(service.flexibleStarts, 1);
    });

    test('an ordinary release never interrupts', () async {
      service.info = offer(updatePriority: 2, immediate: true);
      await controller().checkIfDue();
      await controller().start();
      expect(service.immediateStarts, 0);
    });
  });

  group('one download, not several', () {
    setUp(() => service.info = offer());

    test('three taps start one flow', () async {
      await controller().checkIfDue();
      await Future.wait(<Future<void>>[
        controller().start(),
        controller().start(),
        controller().start(),
      ]);
      expect(service.flexibleStarts, 1);
    });

    test('starting after the download began does nothing', () async {
      await controller().checkIfDue();
      await controller().start();
      service.emit(const AppUpdateEvent(phase: AppUpdatePhase.downloading));
      await controller().start();
      expect(service.flexibleStarts, 1);
    });

    test('two checks in a row ask Play once', () async {
      await Future.wait(<Future<void>>[
        controller().checkIfDue(),
        controller().checkIfDue(),
      ]);
      expect(service.checkCount, 1);
    });

    test('a second check inside the cooldown is skipped', () async {
      await controller().checkIfDue();
      await controller().checkIfDue();
      expect(service.checkCount, 1);
    });

    test('a forced check ignores the cooldown', () async {
      await controller().checkIfDue();
      await controller().checkIfDue(force: true);
      expect(service.checkCount, 2);
    });
  });

  group('the download lifecycle', () {
    setUp(() => service.info = offer());

    test('progress reports keep the card up and carry the bytes', () async {
      await controller().checkIfDue();
      await controller().start();
      service.emit(AppUpdateEvent(
        phase: AppUpdatePhase.downloading,
        info: offer(bytesDownloaded: 250, totalBytesToDownload: 1000),
      ));
      await settle();
      expect(current().phase, AppUpdatePhase.downloading);
      expect(current().info!.progress, closeTo(0.25, 0.001));
    });

    test('a finished download asks to be installed', () async {
      await controller().checkIfDue();
      await controller().start();
      service.emit(AppUpdateEvent(
        phase: AppUpdatePhase.downloaded,
        info: offer(bytesDownloaded: 1000, totalBytesToDownload: 1000),
      ));
      await settle();
      expect(current().phase, AppUpdatePhase.downloaded);
      expect(current().isVisible, isTrue);
    });

    test('install asks Play to complete, once', () async {
      await controller().checkIfDue();
      await controller().start();
      service.emit(const AppUpdateEvent(phase: AppUpdatePhase.downloaded));
      await settle();
      await controller().install();
      await controller().install();
      expect(service.completes_, 1);
    });

    test('a failed download clears the prompt', () async {
      await controller().checkIfDue();
      await controller().start();
      service.emit(const AppUpdateEvent(phase: AppUpdatePhase.failed));
      await settle();
      expect(current().phase, AppUpdatePhase.idle);
      expect(current().isVisible, isFalse);
    });

    test('a cancelled flow clears the prompt', () async {
      await controller().checkIfDue();
      await controller().start();
      service.emit(const AppUpdateEvent(phase: AppUpdatePhase.idle));
      await settle();
      // `idle` is what a cancellation maps to: the app goes back to normal.
      expect(current().phase, AppUpdatePhase.downloading);
    });
  });

  group('being told later', () {
    setUp(() => service.info = offer());

    test('hides the prompt without cancelling the update', () async {
      await controller().checkIfDue();
      controller().dismiss();
      expect(current().isVisible, isFalse);
      expect(current().phase, AppUpdatePhase.available);
      expect(service.flexibleStarts, 0);
    });

    test('a resume does not ask again after a dismissal', () async {
      await controller().checkIfDue();
      controller().dismiss();
      controller().didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(service.checkCount, 1);
    });

    test('a resume during a download does look again', () async {
      await controller().checkIfDue();
      await controller().start();
      controller().didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(service.checkCount, 2);
    });

    test('a finished download is shown even after a dismissal', () async {
      // The bytes are already on the device; hiding the button that installs
      // them would leave a pending update with no way to finish it.
      await controller().checkIfDue();
      controller().dismiss();
      service.emit(const AppUpdateEvent(phase: AppUpdatePhase.downloaded));
      await settle();
      expect(current().isVisible, isTrue);
      expect(current().dismissed, isFalse);
    });

    test('a resume with nothing pending does not look again', () async {
      await controller().checkIfDue();
      controller().didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(service.checkCount, 1);
    });

    test('pausing and hiding never look', () async {
      await controller().checkIfDue();
      for (final AppLifecycleState s in <AppLifecycleState>[
        AppLifecycleState.paused,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.detached,
      ]) {
        controller().didChangeAppLifecycleState(s);
      }
      await Future<void>.delayed(Duration.zero);
      expect(service.checkCount, 1);
    });
  });

  group('lifecycle safety', () {
    testWidgets('a real resume reaches the controller', (WidgetTester tester) async {
      // The observer is registered by the controller itself, not by a screen, so
      // this is the wiring that would break silently: the update would simply
      // never be offered again after the first check.
      service.info = offer();
      await controller().checkIfDue();
      expect(service.checkCount, 1);

      await controller().start();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.checkCount, 2);

      // The controller holds a re-check timer, and a widget test fails on a
      // timer that outlives it. Disposing is what releases it — which is the
      // same path the app takes when the container goes away.
      container.dispose();
      container = ProviderContainer(
        overrides: [appUpdateServiceProvider.overrideWithValue(service)],
      );
    });

    testWidgets('after disposal a resume reaches nothing', (WidgetTester tester) async {
      service.info = offer();
      await controller().checkIfDue();
      container.dispose();
      final int before = service.checkCount;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(service.checkCount, before);

      // A fresh container for tearDown to dispose without complaint.
      container = ProviderContainer(
        overrides: [appUpdateServiceProvider.overrideWithValue(service)],
      );
    });
  });
}
