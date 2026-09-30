import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which language the app opens in, decided without a phone.
///
/// The rule is the phone's own: its languages are in order of preference, and
/// the first one Dhimmah ships wins. Only when none of them is Arabic or English
/// does the app choose, and it chooses English.
void main() {
  group('the phone decides', () {
    test('an Arabic phone opens in Arabic and an English one in English', () {
      expect(AppLanguage.fromDevice(<String>['ar']), AppLanguage.arabic);
      expect(AppLanguage.fromDevice(<String>['en']), AppLanguage.english);
    });

    test(
      'every regional Arabic is Arabic, every regional English is English',
      () {
        for (final String tag in <String>['ar-YE', 'ar_SA', 'AR-eg', ' ar ']) {
          expect(AppLanguage.tryParse(tag), AppLanguage.arabic, reason: tag);
        }
        for (final String tag in <String>['en-US', 'en_IN', 'EN-gb']) {
          expect(AppLanguage.tryParse(tag), AppLanguage.english, reason: tag);
        }
      },
    );

    test(
      'the first shipped language on the list wins, not the first entry',
      () {
        // Someone who reads French first and Arabic second gets Arabic.
        expect(
          AppLanguage.fromDevice(<String>['fr', 'ar', 'en']),
          AppLanguage.arabic,
        );
        expect(
          AppLanguage.fromDevice(<String>['en', 'ar']),
          AppLanguage.english,
          reason: 'the order is the person’s, and English came first',
        );
      },
    );

    test('a phone in neither language opens in English', () {
      expect(AppLanguage.fromDevice(<String>['hi']), AppLanguage.english);
      expect(AppLanguage.fromDevice(<String>['ur', 'fa']), AppLanguage.english);
      expect(AppLanguage.fromDevice(const <String>[]), AppLanguage.english);
      expect(AppLanguage.fallback, AppLanguage.english);
    });

    test('a tag that only starts like a shipped language is not one', () {
      // `arn` is Mapudungun and `eng` is not a two-letter subtag at all; a
      // prefix match used to accept anything beginning with the letters.
      expect(AppLanguage.tryParse('arn'), isNull);
      expect(AppLanguage.tryParse('eng'), isNull);
      expect(AppLanguage.tryParse(''), isNull);
      expect(AppLanguage.tryParse(null), isNull);
    });
  });

  group('the preference', () {
    test('a new install follows the phone', () {
      expect(AppSettings.initial.languagePreference, LanguagePreference.system);
      expect(AppSettings.initial.languagePreference.followsDevice, isTrue);
    });

    test('following the phone gives whatever the phone gives', () {
      for (final AppLanguage device in AppLanguage.values) {
        expect(LanguagePreference.system.resolve(device), device);
      }
    });

    test('a chosen language ignores the phone', () {
      for (final AppLanguage device in AppLanguage.values) {
        expect(LanguagePreference.arabic.resolve(device), AppLanguage.arabic);
        expect(LanguagePreference.english.resolve(device), AppLanguage.english);
      }
    });

    test('every language has a preference that pins it, and back', () {
      for (final AppLanguage language in AppLanguage.values) {
        expect(LanguagePreference.of(language).language, language);
        expect(LanguagePreference.of(language).followsDevice, isFalse);
      }
      expect(LanguagePreference.system.language, isNull);
    });

    test('the other language is a toggle', () {
      for (final AppLanguage language in AppLanguage.values) {
        expect(language.other, isNot(language));
        expect(language.other.other, language);
      }
    });

    test('stored names are the ones the database already holds', () {
      // Every row written before the preference existed says `arabic` or
      // `english`; those must still read as the same choice.
      expect(
        LanguagePreference.values.byName('arabic'),
        LanguagePreference.arabic,
      );
      expect(
        LanguagePreference.values.byName('english'),
        LanguagePreference.english,
      );
      expect(
        LanguagePreference.values.byName('system'),
        LanguagePreference.system,
      );
    });
  });
}
