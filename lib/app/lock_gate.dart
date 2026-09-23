import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/security/biometric_service.dart';
import '../core/security/pin_service.dart';
import '../core/theme/app_palette.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/dhimmah_logo.dart';
import '../core/widgets/pin_keypad.dart';
import '../l10n/generated/app_localizations.dart';

/// Covers the app while the lock is engaged.
///
/// Re-locks the moment the app leaves the foreground rather than after a timeout:
/// a personal ledger sitting open on a shared desk is exactly the situation the
/// lock exists to prevent.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _biometricPrompted = false;

  /// Whether a PIN actually exists in the keystore.
  ///
  /// Null until the check completes. The lock may only engage once we know a
  /// credential exists to satisfy it.
  bool? _pinConfigured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPinConfigured();
  }

  /// A lock with no key must never engage.
  ///
  /// `lockEnabled` lives in the database; the PIN digest lives in the Android
  /// keystore, which never leaves the device and is never restored. So a ledger
  /// that arrives on a new phone — restored from a backup, or transferred — has
  /// the flag set and no digest, and the PIN pad it raises can never be
  /// satisfied by any input. The user is locked out of records they can see
  /// sitting behind the screen, with no way forward but uninstalling, which
  /// deletes exactly what they were trying to reach.
  ///
  /// Opening the ledger is the lesser harm, and the flag is corrected so the
  /// state stops lying about itself.
  Future<void> _checkPinConfigured() async {
    final bool configured;
    try {
      configured = await ref.read(pinServiceProvider).isConfigured();
    } on Object catch (error) {
      // A keystore that cannot be read is not the same as one that is empty, and
      // the difference decides which way to fail. "Definitely no credential"
      // opens the ledger; "could not tell" leaves the lock exactly as it was, so
      // a transient platform failure can never be a way past the lock. Either
      // way the exception stops here: throwing from `initState` took the whole
      // app down, which the widget tests caught first.
      if (kDebugMode) debugPrint('Dhimmah: could not read the PIN state: $error');
      return;
    }
    if (!mounted) return;
    if (!configured) {
      final bool lockEnabled =
          ref.read(effectiveSettingsProvider).lockEnabled;
      if (lockEnabled) {
        await ref.read(settingsControllerProvider).setLockEnabled(false);
      }
    }
    if (!mounted) return;
    setState(() => _pinConfigured = configured);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    // Leaving the foreground re-engages the lock; coming back asks to unlock
    // again, and may offer biometrics once.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_unlocked) setState(() => _unlocked = false);
      _biometricPrompted = false;
    } else if (state == AppLifecycleState.resumed) {
      // A day may have passed while the app was backgrounded.
      ref.read(todayProvider.notifier).refresh();
      _offerBiometrics();
    }
  }

  /// The prompt the app raises on its own when the lock appears.
  ///
  /// Stays silent on anything but success: the user did not ask for this, and
  /// the PIN pad is already in front of them.
  Future<void> _offerBiometrics() async {
    if (_biometricPrompted || _unlocked) return;
    final bool enabled = ref.read(effectiveSettingsProvider).biometricEnabled;
    if (!enabled) return;
    _biometricPrompted = true;
    final BiometricService biometrics = ref.read(biometricServiceProvider);
    final BiometricOutcome outcome = await biometrics.authenticate(
      reason: AppLocalizations.of(context).lockBiometricReason,
    );
    if (!mounted || outcome != BiometricOutcome.success) return;
    setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    final bool lockEnabled = ref.watch(
      settingsProvider.select(
        (AsyncValue<dynamic> value) =>
            (value.value?.lockEnabled as bool?) ?? false,
      ),
    );

    // `_pinConfigured == null` is the moment before the keystore has been read;
    // showing the ledger for that instant is better than flashing a lock screen
    // that may turn out to be unsatisfiable.
    if (!lockEnabled || _unlocked || _pinConfigured == false) {
      return widget.child;
    }

    // Offer biometrics on the first frame of the lock too, not only on resume.
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerBiometrics());

    return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
  }
}

/// The full-screen PIN prompt.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({required this.onUnlocked, super.key});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<int> _digits = <int>[];
  String? _error;
  bool _busy = false;

  int get _length => PinService.pinLength;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final bool biometricEnabled =
        ref.watch(effectiveSettingsProvider).biometricEnabled;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(),
            const DhimmahLogo(size: 64),
            const SizedBox(height: AppSpacing.xl),
            Text(localizations.lockTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.lockEnterPin,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxl),
            PinDots(
              filled: _digits.length,
              length: _length,
              error: _error != null,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: _error == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: palette.overdue),
                      ),
                    ),
            ),
            const Spacer(),
            PinKeypad(
              onDigit: _busy ? null : _pushDigit,
              onBackspace: _busy ? null : _popDigit,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (biometricEnabled)
              TextButton.icon(
                onPressed: _busy ? null : _useBiometrics,
                icon: const Icon(Icons.fingerprint, size: 20),
                label: Text(localizations.lockUseBiometric),
              )
            else
              const SizedBox(height: 48),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _pushDigit(int digit) {
    if (_digits.length >= _length) return;
    setState(() {
      _digits.add(digit);
      _error = null;
    });
    if (_digits.length == _length) _submit();
  }

  void _popDigit() {
    if (_digits.isEmpty) return;
    setState(() {
      _digits.removeLast();
      _error = null;
    });
  }

  Future<void> _submit() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _busy = true);
    final PinVerification result =
        await ref.read(pinServiceProvider).verify(_digits.join());
    if (!mounted) return;

    if (result.accepted) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      _digits.clear();
      _error = result.isLockedOut
          ? localizations.lockTooManyAttempts
          : localizations.lockWrongPin;
    });
  }

  /// The button the user pressed, so it answers.
  ///
  /// A refusal has to say so. Silence here is what a broken fingerprint reader
  /// and a working one look like from the outside.
  Future<void> _useBiometrics() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final BiometricOutcome outcome =
        await ref.read(biometricServiceProvider).authenticate(
              reason: localizations.lockBiometricReason,
            );
    if (!mounted) return;
    if (outcome == BiometricOutcome.success) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _busy = false;
      // Cancelling is a choice and gets no complaint.
      _error = outcome == BiometricOutcome.unavailable
          ? localizations.biometricUnavailable
          : null;
    });
  }
}
