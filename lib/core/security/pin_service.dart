import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How a PIN is verified once it has been set.
///
/// A four-to-six digit PIN has so little entropy that no hash can make it
/// expensive to brute force; what actually protects the user is that the digest
/// lives in the platform keystore (not in the database file, not in a backup) and
/// that attempts are rate limited by [PinService]. The key stretching below
/// raises the cost of an offline attack on a leaked keystore, and the random
/// per-install salt stops one user's digest from confirming another's PIN.
///
/// The PIN itself is never written anywhere — not to the database, not to
/// preferences, not to logs.
class PinService {
  PinService({FlutterSecureStorage? storage, Random? random})
      : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random.secure();

  final FlutterSecureStorage _storage;
  final Random _random;

  static const String _keyHash = 'dhimmah.pin.hash';
  static const String _keySalt = 'dhimmah.pin.salt';
  static const String _keyIterations = 'dhimmah.pin.iterations';
  static const String _keyFailures = 'dhimmah.pin.failures';
  static const String _keyLockedUntil = 'dhimmah.pin.locked_until';

  /// Key-stretching rounds. Chosen so verification stays well under a tenth of a
  /// second on a low-end phone while making a leaked digest costly to attack.
  static const int defaultIterations = 20000;

  /// The PIN length Dhimmah accepts.
  static const int pinLength = 4;

  /// Failed attempts allowed before the entry screen starts delaying.
  static const int attemptsBeforeDelay = 5;

  /// Whether a PIN has been set.
  Future<bool> isConfigured() async {
    final String? hash = await _storage.read(key: _keyHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets or replaces the PIN.
  Future<void> setPin(String pin) async {
    final String salt = _generateSalt();
    final String hash = _derive(pin, salt, defaultIterations);
    await _storage.write(key: _keySalt, value: salt);
    await _storage.write(key: _keyIterations, value: defaultIterations.toString());
    await _storage.write(key: _keyHash, value: hash);
    await _clearFailures();
  }

  /// Verifies [pin], recording the attempt either way.
  Future<PinVerification> verify(String pin) async {
    final String? storedHash = await _storage.read(key: _keyHash);
    final String? salt = await _storage.read(key: _keySalt);
    if (storedHash == null || salt == null) {
      return const PinVerification(accepted: false, configured: false);
    }

    final Duration remaining = await lockoutRemaining();
    if (remaining > Duration.zero) {
      return PinVerification(
        accepted: false,
        configured: true,
        lockoutRemaining: remaining,
      );
    }

    final int iterations =
        int.tryParse(await _storage.read(key: _keyIterations) ?? '') ??
            defaultIterations;
    final String candidate = _derive(pin, salt, iterations);

    if (_constantTimeEquals(candidate, storedHash)) {
      await _clearFailures();
      return const PinVerification(accepted: true, configured: true);
    }

    final int failures = await _recordFailure();
    return PinVerification(
      accepted: false,
      configured: true,
      failures: failures,
      lockoutRemaining: await lockoutRemaining(),
    );
  }

  /// Removes the PIN and the attempt history.
  Future<void> clear() async {
    await _storage.delete(key: _keyHash);
    await _storage.delete(key: _keySalt);
    await _storage.delete(key: _keyIterations);
    await _clearFailures();
  }

  /// How long the user must wait before trying again.
  Future<Duration> lockoutRemaining() async {
    final String? raw = await _storage.read(key: _keyLockedUntil);
    if (raw == null) return Duration.zero;
    final int? until = int.tryParse(raw);
    if (until == null) return Duration.zero;
    final DateTime moment =
        DateTime.fromMillisecondsSinceEpoch(until, isUtc: true);
    final Duration remaining = moment.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<int> _recordFailure() async {
    final int failures =
        (int.tryParse(await _storage.read(key: _keyFailures) ?? '') ?? 0) + 1;
    await _storage.write(key: _keyFailures, value: failures.toString());

    if (failures >= attemptsBeforeDelay) {
      // Back off gently: a few seconds after five misses, doubling up to a
      // minute. Long enough to make guessing impractical, short enough that a
      // forgetful user is not locked out of their own ledger.
      final int steps = failures - attemptsBeforeDelay;
      final int seconds = min(60, 5 * (1 << min(steps, 4)));
      final DateTime until =
          DateTime.now().toUtc().add(Duration(seconds: seconds));
      await _storage.write(
        key: _keyLockedUntil,
        value: until.millisecondsSinceEpoch.toString(),
      );
    }
    return failures;
  }

  Future<void> _clearFailures() async {
    await _storage.delete(key: _keyFailures);
    await _storage.delete(key: _keyLockedUntil);
  }

  String _generateSalt() {
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Iterated HMAC-SHA256 over the salt, which is the standard way to slow a
  /// dictionary attack without pulling in a native dependency.
  static String _derive(String pin, String salt, int iterations) {
    final List<int> key = utf8.encode(salt);
    List<int> block = utf8.encode('$salt:$pin');
    for (int round = 0; round < iterations; round++) {
      block = Hmac(sha256, key).convert(block).bytes;
    }
    return base64Url.encode(block);
  }

  /// Compares without leaking where the first difference is.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// The outcome of one PIN attempt.
class PinVerification {
  const PinVerification({
    required this.accepted,
    required this.configured,
    this.failures = 0,
    this.lockoutRemaining = Duration.zero,
  });

  final bool accepted;

  /// False when no PIN has ever been set.
  final bool configured;

  final int failures;
  final Duration lockoutRemaining;

  bool get isLockedOut => lockoutRemaining > Duration.zero;

  /// Attempts left before the delay starts.
  int get attemptsLeft {
    final int left = PinService.attemptsBeforeDelay - failures;
    return left < 0 ? 0 : left;
  }
}
