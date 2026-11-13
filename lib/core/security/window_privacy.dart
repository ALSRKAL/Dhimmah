import 'package:flutter/services.dart';

/// Keeps the app's window out of screenshots and the recent-apps thumbnail.
///
/// On Android this sets `FLAG_SECURE` on the activity's window. iOS has no
/// equivalent a third-party app may use, so there the call is a no-op and the
/// lock gate's own cover does the work: it is drawn the moment the app stops
/// being the active one, which is before iOS takes the picture it shows in the
/// app switcher.
///
/// Only ever asked for while the app lock is on. A user who has not asked for
/// a lock has not asked to lose screenshots either, and a debt app is one where
/// people do send each other screenshots.
abstract final class WindowPrivacy {
  const WindowPrivacy._();

  /// The same name on both sides of the bridge; pinned by
  /// `test/platform/android_setup_test.dart`.
  static const String channelName = 'com.dhimmah.dhimmah/privacy';

  static const MethodChannel _channel = MethodChannel(channelName);

  /// Never throws. A platform with no implementation — iOS, a desktop build, a
  /// widget test — simply has nothing to set, and a failure here must not
  /// become a reason the lock itself does not come up.
  static Future<void> setSecure({required bool secure}) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on MissingPluginException {
      // No native side on this platform.
    } on PlatformException {
      // The window refused; the lock and its cover still stand.
    }
  }
}
