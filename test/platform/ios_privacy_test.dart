import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The privacy manifest Apple reads at review.
///
/// The app collects nothing and tracks nobody, and the two required-reason APIs
/// it reaches are named with the reason that covers them. This has never been
/// through App Store review — there is no Mac here — so the file is asserted
/// rather than assumed.
void main() {
  final String privacy =
      File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final String project =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  test('declares no tracking and no collected data', () {
    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(privacy),
      isTrue,
    );
    expect(
      RegExp(r'<key>NSPrivacyCollectedDataTypes</key>\s*<array\s*/>\s*<key>')
          .hasMatch(privacy),
      isTrue,
      reason: 'an empty list: the app sends nothing to the developer or a '
          'third party',
    );
  });

  test('gives a reason for every required-reason API the app reaches', () {
    // shared_preferences and flutter_local_notifications read the app's own
    // user defaults; the app reads file timestamps of its own documents.
    expect(privacy, contains('NSPrivacyAccessedAPICategoryUserDefaults'));
    expect(privacy, contains('CA92.1'));
    expect(privacy, contains('NSPrivacyAccessedAPICategoryFileTimestamp'));
    expect(privacy, contains('C617.1'));
    // Nothing asks for free disk space or the boot time.
    expect(privacy, isNot(contains('NSPrivacyAccessedAPICategoryDiskSpace')));
    expect(privacy, isNot(contains('NSPrivacyAccessedAPICategorySystemBootTime')));
  });

  test('is bundled with the app', () {
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
    expect(project, contains('PrivacyInfo.xcprivacy */'));
  });
}
