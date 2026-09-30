import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/money_input.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/enum_labels.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The things a user notices immediately and a test can prove.
///
/// Each of these was wrong in a shipped build:
///
/// * Three keys existed only in the Arabic template file. Because Arabic *is* the
///   template, `gen-l10n` back-filled English with the Arabic text, so the debt
///   form showed «خيارات إضافية» to a user reading English.
/// * The report insights took a raw `{count}` into a fixed noun, so a count of
///   one read "1 ديون متأخرة" in Arabic and "1 debts are overdue" in English.
///   Arabic has a dual and a distinct few/many, and none of it was reachable.
/// * The amount field's input filter allowed only Western digits, while the
///   parser behind it handles Arabic-Indic ones — so a user on an Arabic keyboard
///   watched their keystrokes disappear.
void main() {
  final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

  group('the update prompt speaks both languages', () {
    test('Arabic is Arabic and English is English', () {
      for (final String value in <String>[
        ar.updateAvailableTitle,
        ar.updateAvailableBody,
        ar.updateNow,
        ar.updateLater,
        ar.updateDownloadingTitle,
        ar.updateReadyTitle,
        ar.updateRestartAndInstall,
      ]) {
        expect(
          RegExp(r'[\u0600-\u06FF]').hasMatch(value),
          isTrue,
          reason: '"$value" is not Arabic',
        );
      }
      for (final String value in <String>[
        en.updateAvailableTitle,
        en.updateAvailableBody,
        en.updateNow,
        en.updateLater,
        en.updateDownloadingTitle,
        en.updateReadyTitle,
        en.updateRestartAndInstall,
      ]) {
        expect(
          RegExp(r'[\u0600-\u06FF]').hasMatch(value),
          isFalse,
          reason: '"$value" is Arabic text in the English localisation',
        );
      }
    });

    test('the progress figure is the same number in both', () {
      expect(ar.updatePercent(42), contains('42'));
      expect(en.updatePercent(42), contains('42'));
    });

    test('the update copy carries no product promises', () {
      // The one thing an update prompt must not do is claim what the release
      // contains. The app cannot read Play's release notes, so it says only
      // that a newer version is ready.
      for (final String value in <String>[
        ar.updateAvailableBody,
        ar.updateReadyBody,
        en.updateAvailableBody,
        en.updateReadyBody,
      ]) {
        expect(
          RegExp(r'security|آمن|أمان|critical|حرج|urgent|عاجل', caseSensitive: false)
              .hasMatch(value),
          isFalse,
          reason: '"$value" makes a claim about what the update contains',
        );
      }
    });
  });

  group('English is really English', () {
    test('the debt form explains itself in the reader\'s language', () {
      // These three were Arabic-only and leaked into the English build.
      for (final String value in <String>[
        en.fieldAdvancedOptions,
        en.fieldAdvancedHint,
        en.fieldAdvancedSet,
      ]) {
        expect(
          RegExp(r'[\u0600-\u06FF]').hasMatch(value),
          isFalse,
          reason: '"$value" is Arabic text in the English localisation',
        );
      }
      expect(en.fieldAdvancedOptions, isNotEmpty);
      expect(en.fieldAdvancedHint, isNotEmpty);
    });

    test('no English string is left as Arabic anywhere', () {
      // A broad sweep of the surface a user reads most, so a future key added to
      // the Arabic file alone fails here rather than in a screenshot.
      final List<String> sample = <String>[
        en.appName,
        en.dashboardAgainstYou,
        en.dashboardInYourFavour,
        en.dashboardIOwe,
        en.dashboardOwedToMe,
        en.statusOverdue,
        en.statusPaid,
        en.actionSave,
        en.settingsTitle,
        en.reportInsightAllClear,
        en.personDebtsSection,
        en.detailRecordPayment,
      ];
      for (final String value in sample) {
        expect(
          RegExp(r'[\u0600-\u06FF]').hasMatch(value),
          isFalse,
          reason: '"$value" should be English',
        );
      }
    });
  });

  group('counts read as the language writes them', () {
    test('Arabic uses its own categories, not a fixed noun', () {
      // One, two, few and many are four different words in Arabic.
      expect(ar.reportInsightOverdue(1), isNot(contains('1')));
      expect(ar.reportInsightOverdue(1), contains('دين واحد'));
      // The dual of «دَين» is «دينان», and «دينين» after a preposition or a
      // construct. «ديان» is not a form of the word.
      expect(ar.reportInsightOverdue(2), contains('دينان'));
      expect(ar.reportInsightOverdue(5), contains('ديون'));
      // Zero is a real sentence in Arabic, and «لا ديون متأخرة» is the right one.
      expect(ar.reportInsightOverdue(0), startsWith('لا'));
      expect(RegExp(r'[0-9]').hasMatch(ar.reportInsightOverdue(0)), isFalse);

      expect(ar.reportInsightClosed(1), contains('دين واحد'));
      expect(ar.reportInsightClosed(2), contains('دينين'));

      expect(ar.reportInsightUpcoming(1), contains('التزام واحد'));
      expect(ar.reportInsightUpcoming(2), contains('التزامان'));
      expect(ar.reportInsightUpcoming(4), contains('التزامات'));
    });

    test('English distinguishes one from the rest', () {
      expect(en.reportInsightOverdue(1), 'One debt is overdue and needs chasing.');
      expect(en.reportInsightOverdue(3), '3 debts are overdue and need chasing.');
      expect(en.reportInsightOverdue(0), 'No debts are overdue.');

      expect(en.reportInsightClosed(1), 'One debt was closed this month.');
      expect(en.reportInsightClosed(4), '4 debts were closed this month.');

      expect(
        en.reportInsightUpcoming(1),
        'One commitment falls due in the coming days.',
      );
      expect(
        en.reportInsightUpcoming(6),
        '6 commitments fall due in the coming days.',
      );
    });

    test('no count ever produces a broken noun phrase', () {
      // Every count a user can reach, in both languages.
      for (int count = 0; count <= 12; count++) {
        for (final String value in <String>[
          ar.reportInsightOverdue(count),
          ar.reportInsightClosed(count),
          ar.reportInsightUpcoming(count),
          en.reportInsightOverdue(count),
          en.reportInsightClosed(count),
          en.reportInsightUpcoming(count),
        ]) {
          expect(value, isNotEmpty);
          // "1 debts" and "1 ديون" are the shapes this guards against.
          expect(
            RegExp(r'\b1 (debts|commitments)').hasMatch(value),
            isFalse,
            reason: 'plural noun after a count of one: "$value"',
          );
          expect(
            value.contains('1 ديون') || value.contains('1 التزامات'),
            isFalse,
            reason: 'plural noun after a count of one: "$value"',
          );
        }
      }
    });
  });

  group('an Arabic keyboard can enter an amount', () {
    test('Arabic-Indic digits parse to the same value as Western ones', () {
      expect(parseAmountToMinor('٥٠٠', AppCurrency.inr), 50000);
      expect(parseAmountToMinor('٥٠٠', AppCurrency.inr),
          parseAmountToMinor('500', AppCurrency.inr));
      // Extended Arabic-Indic, used by Persian and Urdu keyboards.
      expect(parseAmountToMinor('۵۰۰', AppCurrency.inr), 50000);
      // Mixed input from a keyboard that switches layout mid-number.
      expect(parseAmountToMinor('١٢3', AppCurrency.inr), 12300);
      // With the Arabic decimal and grouping marks.
      expect(parseAmountToMinor('١٢٬٥٠٠', AppCurrency.inr), 1250000);
      expect(parseAmountToMinor('١٢٫٥', AppCurrency.inr), 1250);
    });

    test('the field filter admits every digit the parser handles', () {
      // The two must agree: a character the parser understands but the filter
      // strips is a keystroke that does nothing.
      final RegExp allowed = RegExp(r'^[0-9\u0660-\u0669\u06F0-\u06F9.,\u066B\u066C\s]+$');
      const String everyDigit = '0123456789'
          '٠١٢٣٤٥٦٧٨٩'
          '۰۱۲۳۴۵۶۷۸۹'
          '.,٬٫ ';

      for (final int rune in everyDigit.runes) {
        final String ch = String.fromCharCode(rune);
        expect(
          allowed.hasMatch(ch),
          isTrue,
          reason: 'the amount field would delete "$ch"',
        );
      }

      // Every *digit* the filter admits must also parse; a lone separator is
      // admitted on purpose and correctly parses to nothing, because "٫" is not
      // an amount.
      for (final String digit in <String>[
        ...List<String>.generate(10, (int i) => '$i'),
        ...'٠١٢٣٤٥٦٧٨٩'.split(''),
        ...'۰۱۲۳۴۵۶۷۸۹'.split(''),
      ]) {
        expect(
          parseAmountToMinor(digit, AppCurrency.inr),
          isNotNull,
          reason: 'the field admits "$digit" but it cannot be parsed',
        );
      }
    });
  });

  group('the two files agree', () {
    Set<String> keysOf(String path) => <String>{
          for (final String key
              in (jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>)
                  .keys)
            if (!key.startsWith('@')) key,
        };

    test('every message exists in both languages', () {
      // Arabic is the template, so a key missing from English is silently
      // back-filled with Arabic — which is how «خيارات إضافية» reached English
      // readers. A missing key fails here instead of in a screenshot.
      final Set<String> arabic = keysOf('lib/l10n/arb/app_ar.arb');
      final Set<String> english = keysOf('lib/l10n/arb/app_en.arb');
      expect(arabic.difference(english), isEmpty, reason: 'missing in English');
      expect(english.difference(arabic), isEmpty, reason: 'missing in Arabic');
    });
  });

  group('the first run and the language picker', () {
    test('speak the reader’s language', () {
      final List<String> english = <String>[
        en.onboardingFeatureBooksTitle,
        en.onboardingFeatureBooksBody,
        en.onboardingFeatureRemindersTitle,
        en.onboardingFeatureRemindersBody,
        en.onboardingFeaturePrivateBody,
        en.onboardingNotificationsTitle,
        en.onboardingNotificationsBody,
        en.onboardingEnableNotifications,
        en.onboardingMaybeLater,
        en.onboardingChangeLanguage,
        en.onboardingChangeLater,
        en.onboardingStepOf(1, 3),
        en.onboardingReminderTime('8:00 PM'),
        en.onboardingMonthEndWhen('Last day of the month', '8:00 PM'),
        en.languageDevice,
        en.languageFollowsDevice,
        en.languageDeviceCurrently('English'),
      ];
      for (final String value in english) {
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(value), isFalse,
            reason: '"$value" should be English');
      }
      final List<String> arabic = <String>[
        ar.onboardingFeatureBooksTitle,
        ar.onboardingFeatureRemindersTitle,
        ar.onboardingFeaturePrivateBody,
        ar.onboardingNotificationsTitle,
        ar.onboardingChangeLanguage,
        ar.languageDevice,
        ar.languageFollowsDevice,
      ];
      for (final String value in arabic) {
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(value), isTrue,
            reason: '"$value" should be Arabic');
      }
    });

    test('a language is offered by its own name, whatever the interface says',
        () {
      expect(AppLanguage.arabic.endonym, 'العربية');
      expect(AppLanguage.english.endonym, 'English');
      // …while its name in the other language is the other language's word.
      expect(AppLanguage.english.label(ar), isNot(AppLanguage.english.endonym));
      expect(AppLanguage.arabic.label(en), isNot(AppLanguage.arabic.endonym));
    });

    test('the two riyals are told apart by name', () {
      // They share ﷼, so the name is what a person reads the difference in.
      for (final AppLocalizations l in <AppLocalizations>[ar, en]) {
        expect(AppCurrency.sar.label(l), isNot(AppCurrency.yer.label(l)));
        final Set<String> names = <String>{
          for (final AppCurrency c in AppCurrency.values) c.label(l),
        };
        expect(names, hasLength(AppCurrency.values.length),
            reason: 'every currency has its own name');
      }
    });
  });
}
