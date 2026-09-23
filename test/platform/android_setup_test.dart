import 'dart:io';

import 'package:dhimmah/core/security/biometric_service.dart';
import 'package:dhimmah/data/services/play_app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

/// Platform configuration that no Dart test can otherwise see.
///
/// Both of these were wrong in a build that shipped: the manifest permission was
/// present but the activity was a `FlutterActivity`, so every biometric prompt
/// was refused by `androidx.biometric` before it could be shown. The Dart code
/// was correct, the analyser was clean, and the only symptom was a fingerprint
/// button that did nothing — which is why the fix is pinned here.
void main() {
  final File activity = File(
    'android/app/src/main/kotlin/com/dhimmah/dhimmah/MainActivity.kt',
  );

  group('Android setup', () {

    test('the activity can host a biometric prompt', () {
      expect(
        activity.existsSync(),
        isTrue,
        reason: 'MainActivity.kt has moved; update this test with it',
      );
      final String source = activity.readAsStringSync();

      // `androidx.biometric` shows its prompt through a fragment and refuses to
      // run otherwise: local_auth_android returns NOT_FRAGMENT_ACTIVITY, which
      // surfaces as LocalAuthExceptionCode.uiUnavailable. Nothing in Dart
      // reveals this, so it is asserted from the declaration itself.
      expect(
        source,
        contains('FlutterFragmentActivity'),
        reason: 'MainActivity must extend FlutterFragmentActivity, not '
            'FlutterActivity, or every biometric prompt is refused',
      );
      expect(
        source,
        isNot(contains('FlutterActivity()')),
        reason: 'a bare FlutterActivity cannot host the biometric prompt',
      );
    });

    test('the biometric permission is declared', () {
      final String manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(
        manifest,
        contains('android.permission.USE_BIOMETRIC'),
        reason: 'local_auth needs USE_BIOMETRIC to reach the sensor',
      );
    });
  });

  group('in-app updates', () {
    final File channel = File(
      'android/app/src/main/kotlin/com/dhimmah/dhimmah/AppUpdateChannel.kt',
    );

    test('the channel names agree on both sides of the bridge', () {
      // A typo in either name is invisible until a device reports
      // MissingPluginException, which reads like a build problem rather than a
      // mismatch. The Dart constants are the ones the Kotlin file must carry.
      expect(channel.existsSync(), isTrue);
      final String source = channel.readAsStringSync();
      expect(source, contains('"${PlayAppUpdateService.methodChannelName}"'));
      expect(source, contains('"${PlayAppUpdateService.eventChannelName}"'));
    });

    test('it uses the per-feature Play library, not the retired bundle', () {
      final String gradle =
          File('android/app/build.gradle.kts').readAsStringSync();
      expect(
        gradle,
        contains('com.google.android.play:app-update'),
        reason: 'the update flow has to go through Google Play\'s own library',
      );
      expect(
        gradle,
        isNot(contains('com.google.android.play:core:')),
        reason: 'the old monolithic Play Core was split up and is superseded',
      );
    });

    test('the activity wires both channels and the result launcher', () {
      final String source = activity.readAsStringSync();
      for (final String needed in <String>[
        'AppUpdateChannel.METHOD_CHANNEL',
        'AppUpdateChannel.EVENT_CHANNEL',
        'registerForActivityResult',
        'configureFlutterEngine',
      ]) {
        expect(source, contains(needed), reason: '$needed is missing');
      }
      // The launcher has to be registered before the activity starts, so a
      // registration inside the first update check would crash on it.
      expect(
        source,
        contains('StartIntentSenderForResult'),
        reason: 'Play reports the update flow back through an IntentSender',
      );
    });

    test('the update path cannot reach the ledger', () {
      // The strongest thing that can be said about a feature that must not touch
      // user data is that it has no way to. An update replaces the app; it must
      // never migrate, clear, rebuild or read a database, and a prompt must
      // never know what is in one. This asserts the structure rather than
      // trusting the intent: none of the four files on the update path can name
      // the database, a repository or the ledger service.
      for (final String file in <String>[
        'lib/domain/services/app_update_service.dart',
        'lib/data/services/play_app_update_service.dart',
        'lib/app/app_update_controller.dart',
        'lib/core/widgets/app_update_card.dart',
      ]) {
        final String source = File(file).readAsStringSync();
        for (final String forbidden in <String>[
          'app_database',
          'ledger_service',
          'ledger_queries',
          'repositories/',
        ]) {
          expect(
            source,
            isNot(contains(forbidden)),
            reason: '$file reaches $forbidden, which the update system must '
                'have no way to touch',
          );
        }
      }
    });

    test('nothing asks a server for a version', () {
      // The whole point of using Play's own system: the app makes no network
      // call of its own to find out about an update, and sends nothing.
      final String dart = File(
        'lib/data/services/play_app_update_service.dart',
      ).readAsStringSync();
      for (final String forbidden in <String>[
        'http://',
        'https://',
        'HttpClient',
        'package:http',
        'dio',
      ]) {
        expect(
          dart,
          isNot(contains(forbidden)),
          reason: 'the update check must not reach the network itself',
        );
      }
    });
  });

  group('refusal classification', () {
    // The distinction that matters: a user who dismissed the prompt must not be
    // told the feature is broken, and a platform that refused must not be
    // reported as a user cancel — which is exactly how the shipped bug hid.
    test('a refusal that no prompt could fix is reported as unavailable', () {
      for (final LocalAuthExceptionCode code in <LocalAuthExceptionCode>[
        // What a FlutterActivity produces.
        LocalAuthExceptionCode.uiUnavailable,
        LocalAuthExceptionCode.noCredentialsSet,
        LocalAuthExceptionCode.noBiometricsEnrolled,
        LocalAuthExceptionCode.noBiometricHardware,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
        LocalAuthExceptionCode.temporaryLockout,
        LocalAuthExceptionCode.biometricLockout,
        LocalAuthExceptionCode.deviceError,
        LocalAuthExceptionCode.unknownError,
      ]) {
        expect(
          BiometricService.outcomeFor(code),
          BiometricOutcome.unavailable,
          reason: '${code.name} leaves the user with a dead button, so it has '
              'to be said out loud',
        );
      }
    });

    test('the user changing their mind is not an error', () {
      for (final LocalAuthExceptionCode code in <LocalAuthExceptionCode>[
        LocalAuthExceptionCode.userCanceled,
        LocalAuthExceptionCode.systemCanceled,
        LocalAuthExceptionCode.timeout,
        LocalAuthExceptionCode.authInProgress,
        LocalAuthExceptionCode.userRequestedFallback,
      ]) {
        expect(
          BiometricService.outcomeFor(code),
          BiometricOutcome.cancelled,
          reason: '${code.name} is not a failure the user needs told about',
        );
      }
    });
  });
}
