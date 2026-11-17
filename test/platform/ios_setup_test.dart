import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// iOS configuration that no Dart test can otherwise see.
///
/// None of this has been built on a Mac — there is none here — so these assert
/// the files themselves: the keys Apple reads at review, the strings an Arabic
/// and an English phone will show, the privacy manifest's declarations, and the
/// first frame's colour. They catch a typo and a missing project entry; only a
/// real build can catch a linking or provisioning problem.
void main() {
  final String plist =
      File('ios/Runner/Info.plist').readAsStringSync();
  final String project =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final String storyboard =
      File('ios/Runner/Base.lproj/LaunchScreen.storyboard').readAsStringSync();
  final String colors = File(
    'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
  ).readAsStringSync();

  group('Info.plist', () {
    test('the app opts out of iPad multitasking, as it is one column', () {
      expect(
        RegExp(r'<key>UIRequiresFullScreen</key>\s*<true/>').hasMatch(plist),
        isTrue,
      );
    });

    test('the encryption declaration is still deliberately absent', () {
      // PLAN.md ق12: it waits for the developer's decision.
      expect(plist, isNot(contains('ITSAppUsesNonExemptEncryption')));
    });

    test('both orientations are portrait', () {
      expect(plist, contains('<string>UIInterfaceOrientationPortrait</string>'));
      expect(
        plist,
        isNot(contains('UIInterfaceOrientationLandscape')),
        reason: 'main.dart pins portrait; the plist must agree',
      );
    });
  });

  group('Face ID', () {
    test('has a description in Arabic and English', () {
      for (final String language in <String>['ar', 'en']) {
        final File strings =
            File('ios/Runner/$language.lproj/InfoPlist.strings');
        expect(strings.existsSync(), isTrue, reason: '$language is missing');
        expect(
          strings.readAsStringSync(),
          contains('NSFaceIDUsageDescription'),
          reason: 'Apple reads this key from the localised strings file',
        );
      }
    });

    test('both strings are part of the Runner target', () {
      expect(project, contains('ar.lproj/InfoPlist.strings'));
      expect(project, contains('en.lproj/InfoPlist.strings'));
      expect(project, contains('InfoPlist.strings in Resources'));
      expect(
        RegExp(r'knownRegions = \(\s*ar,').hasMatch(project),
        isTrue,
        reason: 'Arabic has to be a known region for the localisation to ship',
      );
    });
  });

  group('the launch screen', () {
    test('is the app\'s paper in both appearances', () {
      // #F7F5F2 light, #131211 dark, the same values as Android's window.
      expect(colors, contains('"red" : "0.969"'));
      expect(colors, contains('"red" : "0.075"'));
      expect(colors, contains('"appearance" : "luminosity"'));
      expect(colors, contains('"value" : "dark"'));
      expect(storyboard, contains('name="LaunchBackground"'));
      expect(
        storyboard,
        isNot(contains('red="1" green="1" blue="1"')),
        reason: 'the launch screen used to flash white before the app drew',
      );
    });

    test('draws the app\'s mark, not the template placeholder', () {
      // Flutter's template ships a 1×1 transparent PNG. The mark is 120pt at
      // 1×, so its pixel width says which one is there.
      final Uint8List bytes = File(
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
      ).readAsBytesSync();
      final int width =
          (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      expect(width, 120);
      expect(bytes.length, greaterThan(1000));
    });
  });
}
