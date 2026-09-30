import 'dart:ui' show Locale;

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/region_currency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which currency the place a phone is in uses — from its time zone and its
/// languages, never its location.
void main() {
  group('the time zone names the place', () {
    test('every currency has a place a phone can be in', () {
      // One zone per currency. A currency added without a place here fails,
      // which is the point: it would never be suggested.
      const Map<AppCurrency, String> zones = <AppCurrency, String>{
        AppCurrency.inr: 'Asia/Kolkata',
        AppCurrency.usd: 'America/New_York',
        AppCurrency.sar: 'Asia/Riyadh',
        AppCurrency.aed: 'Asia/Dubai',
        AppCurrency.yer: 'Asia/Aden',
        AppCurrency.eur: 'Europe/Berlin',
        AppCurrency.gbp: 'Europe/London',
      };
      for (final AppCurrency currency in AppCurrency.values) {
        expect(zones, contains(currency), reason: currency.code);
        expect(regionCurrency(timeZone: zones[currency]), currency);
      }
    });

    test('old names and far-off parts count too', () {
      expect(regionCurrency(timeZone: 'Asia/Calcutta'), AppCurrency.inr);
      expect(regionCurrency(timeZone: 'Pacific/Honolulu'), AppCurrency.usd);
      expect(regionCurrency(timeZone: 'America/Puerto_Rico'), AppCurrency.usd);
      expect(regionCurrency(timeZone: 'Atlantic/Canary'), AppCurrency.eur);
      expect(regionCurrency(timeZone: ' Asia/Aden '), AppCurrency.yer);
      expect(
        regionCurrency(timeZone: 'Europe/Sofia'),
        AppCurrency.eur,
        reason: 'Bulgaria has used the euro since 1 January 2026',
      );
    });

    test('it decides over the region the phone is set up for', () {
      // An Indian phone left in American English.
      expect(
        regionCurrency(
          timeZone: 'Asia/Kolkata',
          locales: const <Locale>[Locale('en', 'US')],
        ),
        AppCurrency.inr,
      );
      // A Yemeni phone with its Arabic set to Saudi Arabia.
      expect(
        regionCurrency(
          timeZone: 'Asia/Aden',
          locales: const <Locale>[Locale('ar', 'SA')],
        ),
        AppCurrency.yer,
      );
    });

    test('a place with another currency gets no suggestion, not a guess', () {
      // Cairo is a place, and its pound is not one Dhimmah records in. The
      // phone being in English does not make it American.
      expect(
        regionCurrency(
          timeZone: 'Africa/Cairo',
          locales: const <Locale>[Locale('en', 'US')],
        ),
        isNull,
      );
      expect(
        regionCurrency(
          timeZone: 'Asia/Kuwait',
          locales: const <Locale>[Locale('ar', 'KW')],
        ),
        isNull,
      );
      expect(
        regionCurrency(timeZone: 'Asia/Muscat'),
        isNull,
        reason: 'Oman keeps Dubai’s clock, not its dirham',
      );
    });
  });

  group('without a zone, the phone’s languages', () {
    test('the first one that names a country decides', () {
      expect(
        regionCurrency(locales: const <Locale>[Locale('ar', 'YE')]),
        AppCurrency.yer,
      );
      expect(
        regionCurrency(
          locales: const <Locale>[Locale('ar'), Locale('en', 'GB')],
        ),
        AppCurrency.gbp,
      );
      expect(
        regionCurrency(
          locales: const <Locale>[Locale('fr', 'FR'), Locale('ar', 'SA')],
        ),
        AppCurrency.eur,
      );
      expect(
        regionCurrency(
          locales: const <Locale>[Locale('ar', 'EG'), Locale('en', 'US')],
        ),
        isNull,
        reason: 'the first country named decides, even with no currency here',
      );
    });

    test('a zone that is no place is no zone', () {
      for (final String zone in <String>['UTC', 'Etc/GMT-3', 'GMT', '']) {
        expect(
          regionCurrency(
            timeZone: zone,
            locales: const <Locale>[Locale('ar', 'AE')],
          ),
          AppCurrency.aed,
          reason: zone,
        );
      }
    });

    test('a region that is not a country is passed over', () {
      expect(
        regionCurrency(
          locales: const <Locale>[Locale('es', '419'), Locale('en', 'US')],
        ),
        AppCurrency.usd,
      );
    });

    test('nothing to go on is no suggestion', () {
      expect(regionCurrency(), isNull);
      expect(
        regionCurrency(locales: const <Locale>[Locale('ar'), Locale('en')]),
        isNull,
      );
    });
  });

  group('the order a picker offers', () {
    test('the suggestion first, and the rest as usual', () {
      expect(currenciesWithFirst(AppCurrency.yer), <AppCurrency>[
        AppCurrency.yer,
        AppCurrency.inr,
        AppCurrency.usd,
        AppCurrency.sar,
        AppCurrency.aed,
        AppCurrency.eur,
        AppCurrency.gbp,
      ]);
    });

    test('no suggestion, or the first already, is the usual order', () {
      expect(currenciesWithFirst(null), AppCurrency.values);
      expect(currenciesWithFirst(AppCurrency.inr), AppCurrency.values);
    });
  });

  test('a country code is read in either case', () {
    expect(currencyOfCountry('ye'), AppCurrency.yer);
    expect(currencyOfCountry('YE'), AppCurrency.yer);
    expect(currencyOfCountry('EG'), isNull);
    expect(currencyOfCountry(null), isNull);
  });
}
