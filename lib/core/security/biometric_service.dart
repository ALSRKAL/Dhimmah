import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Why a biometric prompt could not be used.
enum BiometricAvailability {
  /// Ready to prompt.
  available,

  /// The device has no fingerprint sensor or face unlock.
  notSupported,

  /// Hardware exists but the user has not enrolled anything.
  notEnrolled,

  /// Desktop or web, where Dhimmah does not offer biometric unlock.
  unsupportedPlatform,
}

/// What came back from a biometric prompt.
///
/// Three outcomes rather than a bool, because two of them are the user changing
/// their mind and one is the platform refusing. Collapsing them is how a broken
/// fingerprint reader comes to look exactly like a working one the user
/// dismissed: the button does nothing and says nothing.
enum BiometricOutcome {
  /// The user confirmed.
  success,

  /// The user dismissed the prompt, the system took it away, or nothing was
  /// recognised. Nothing to report — they can try again or use the PIN.
  cancelled,

  /// The platform would not show a prompt at all: no sensor, nothing enrolled,
  /// an activity that cannot host one, or too many attempts. Worth saying out
  /// loud, because otherwise the button is dead.
  unavailable,
}

/// Thin wrapper over `local_auth`.
///
/// Kept separate from [PinService] on purpose: biometrics are a convenience
/// layer on top of the PIN, never a replacement. Turning biometrics off always
/// leaves a working PIN behind, so a user can never lock themselves out of their
/// own records.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<BiometricAvailability> availability() async {
    if (!_isMobile) return BiometricAvailability.unsupportedPlatform;
    try {
      if (!await _auth.isDeviceSupported()) {
        return BiometricAvailability.notSupported;
      }
      final List<BiometricType> enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isEmpty) return BiometricAvailability.notEnrolled;
      return BiometricAvailability.available;
    } on Object {
      return BiometricAvailability.notSupported;
    }
  }

  /// Whether biometric unlock should be offered in Settings.
  Future<bool> get isUsable async =>
      await availability() == BiometricAvailability.available;

  /// Prompts for a biometric confirmation.
  ///
  /// Never throws. The caller falls back to the PIN pad on anything but
  /// [BiometricOutcome.success].
  Future<BiometricOutcome> authenticate({
    required String reason,
    bool biometricOnly = true,
  }) async {
    if (!_isMobile) return BiometricOutcome.unavailable;
    try {
      final bool ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        // A prompt that outlived the foreground would unlock a screen nobody is
        // looking at; the lock engages the moment the app is left.
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.cancelled;
    } on LocalAuthException catch (error) {
      _reportRefusal(error);
      return outcomeFor(error.code);
    } on Object catch (error) {
      _reportRefusal(error);
      return BiometricOutcome.unavailable;
    }
  }

  /// Classifies a refusal.
  ///
  /// Which side of the line a code falls on is the whole point of this enum:
  /// only [BiometricOutcome.unavailable] earns a message, so a user who simply
  /// dismissed the prompt is not told something is wrong.
  ///
  /// Public so the classification can be tested without a fingerprint reader.
  /// The switch is exhaustive rather than defaulted, so a code added by a future
  /// `local_auth` is a compile error here rather than a silent misclassification.
  @visibleForTesting
  static BiometricOutcome outcomeFor(LocalAuthExceptionCode code) {
    switch (code) {
      // They changed their mind, or the system took the prompt away, or a prompt
      // was already up and this call had nothing to add.
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
      case LocalAuthExceptionCode.authInProgress:
      // The system offered a fallback and they took it. The PIN pad is already
      // behind the prompt, so this needs no message either.
      case LocalAuthExceptionCode.userRequestedFallback:
        return BiometricOutcome.cancelled;

      // No prompt could be shown, or none can succeed.
      //
      // `uiUnavailable` is the one that matters here: `local_auth_android`
      // reports it when the foreground activity is not a `FragmentActivity`,
      // which `androidx.biometric` requires. A build of this app shipped with a
      // `FlutterActivity`, so every prompt was refused — and this wrapper turned
      // the refusal into a plain `false`, which made a dead fingerprint button
      // indistinguishable from one the user had dismissed.
      case LocalAuthExceptionCode.uiUnavailable:
      case LocalAuthExceptionCode.noCredentialsSet:
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noBiometricHardware:
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return BiometricOutcome.unavailable;
    }
  }

  /// Records a refusal where a developer will see it, without telling the user
  /// something went wrong with their ledger.
  void _reportRefusal(Object error) {
    if (kDebugMode) {
      debugPrint('Biometric prompt refused: $error');
    }
  }
}
