import 'dart:ui' show Locale;

import 'currency.dart';

/// The currency of the place a phone is in, from what the phone already says
/// about itself — no location permission, and nothing leaves the device.
///
/// The time zone comes first. It is set by the network and moves with the
/// phone, so it names the country the person is in: an Indian phone left in
/// English still reports `Asia/Kolkata`, a Yemeni one in Arabic set to Saudi
/// Arabia's region still reports `Asia/Aden`. When the zone names a place,
/// that place decides — and if its currency is not one Dhimmah records in,
/// there is no suggestion rather than a guess from somewhere else.
///
/// The region of the phone's languages is the fallback, for a phone that gives
/// no zone or a zone that is no place (`UTC`): the first language that names a
/// country decides, in the order the person ranked them.
///
/// Null when neither says anything Dhimmah can use. The caller then offers the
/// currencies in their usual order and suggests nothing.
AppCurrency? regionCurrency({
  String? timeZone,
  List<Locale> locales = const <Locale>[],
}) {
  final String? zone = timeZone?.trim();
  if (zone != null && _namesAPlace(zone)) {
    return currencyOfCountry(_zoneCountries[zone]);
  }
  for (final Locale locale in locales) {
    final String? country = locale.countryCode?.toUpperCase();
    if (country == null || !_isCountryCode(country)) continue;
    return currencyOfCountry(country);
  }
  return null;
}

/// The currency a country uses, among the ones Dhimmah records in, from its
/// ISO 3166 alpha-2 code.
AppCurrency? currencyOfCountry(String? country) {
  if (country == null) return null;
  return _countryCurrencies[country.toUpperCase()];
}

/// Every currency, [first] at the top and the rest in their usual order.
///
/// Used by every currency picker, so the suggested currency is in the same
/// place everywhere it is offered.
List<AppCurrency> currenciesWithFirst(AppCurrency? first) {
  if (first == null) return AppCurrency.values;
  return <AppCurrency>[
    first,
    for (final AppCurrency currency in AppCurrency.values)
      if (currency != first) currency,
  ];
}

/// A zone for a place — `Area/City` — rather than an offset (`Etc/GMT+3`) or a
/// plain `UTC`.
bool _namesAPlace(String zone) => zone.contains('/') && !zone.startsWith('Etc/');

final RegExp _alpha2 = RegExp(r'^[A-Z]{2}$');

/// Two letters: a country, not a region such as `419` for Latin America.
bool _isCountryCode(String code) => _alpha2.hasMatch(code);

/// The countries that use one of Dhimmah's currencies.
const Map<String, AppCurrency> _countryCurrencies = <String, AppCurrency>{
  'IN': AppCurrency.inr,
  'YE': AppCurrency.yer,
  'SA': AppCurrency.sar,
  'AE': AppCurrency.aed,
  // The United Kingdom and the Crown Dependencies, whose local notes are
  // sterling: ISO 4217 gives them no code of their own. Gibraltar, the
  // Falklands and St Helena have pounds of their own, and are left out.
  'GB': AppCurrency.gbp,
  'IM': AppCurrency.gbp,
  'JE': AppCurrency.gbp,
  'GG': AppCurrency.gbp,
  // The United States, its territories, and the countries that use the dollar
  // as their own.
  'US': AppCurrency.usd,
  'PR': AppCurrency.usd,
  'VI': AppCurrency.usd,
  'GU': AppCurrency.usd,
  'MP': AppCurrency.usd,
  'AS': AppCurrency.usd,
  'UM': AppCurrency.usd,
  'EC': AppCurrency.usd,
  'SV': AppCurrency.usd,
  'PA': AppCurrency.usd,
  'TL': AppCurrency.usd,
  'PW': AppCurrency.usd,
  'MH': AppCurrency.usd,
  'FM': AppCurrency.usd,
  'VG': AppCurrency.usd,
  'TC': AppCurrency.usd,
  'BQ': AppCurrency.usd,
  // The euro area — 21 members since Bulgaria joined on 1 January 2026 — and
  // the places that use the euro as their currency.
  'AT': AppCurrency.eur,
  'BE': AppCurrency.eur,
  'BG': AppCurrency.eur,
  'HR': AppCurrency.eur,
  'CY': AppCurrency.eur,
  'EE': AppCurrency.eur,
  'FI': AppCurrency.eur,
  'FR': AppCurrency.eur,
  'DE': AppCurrency.eur,
  'GR': AppCurrency.eur,
  'IE': AppCurrency.eur,
  'IT': AppCurrency.eur,
  'LV': AppCurrency.eur,
  'LT': AppCurrency.eur,
  'LU': AppCurrency.eur,
  'MT': AppCurrency.eur,
  'NL': AppCurrency.eur,
  'PT': AppCurrency.eur,
  'SK': AppCurrency.eur,
  'SI': AppCurrency.eur,
  'ES': AppCurrency.eur,
  'AD': AppCurrency.eur,
  'MC': AppCurrency.eur,
  'SM': AppCurrency.eur,
  'VA': AppCurrency.eur,
  'ME': AppCurrency.eur,
  'XK': AppCurrency.eur,
  'AX': AppCurrency.eur,
  'GF': AppCurrency.eur,
  'GP': AppCurrency.eur,
  'MQ': AppCurrency.eur,
  'RE': AppCurrency.eur,
  'YT': AppCurrency.eur,
  'PM': AppCurrency.eur,
  'BL': AppCurrency.eur,
  'MF': AppCurrency.eur,
};

/// The time zones of those countries, as a phone reports them, old names
/// included. A zone of any other place is deliberately absent: it names a
/// country whose currency Dhimmah does not have, and the answer for it is no
/// suggestion.
const Map<String, String> _zoneCountries = <String, String>{
  'Asia/Kolkata': 'IN',
  'Asia/Calcutta': 'IN',
  'Asia/Aden': 'YE',
  'Asia/Riyadh': 'SA',
  'Asia/Dubai': 'AE',
  'Europe/London': 'GB',
  'Europe/Belfast': 'GB',
  'Europe/Isle_of_Man': 'IM',
  'Europe/Jersey': 'JE',
  'Europe/Guernsey': 'GG',
  // The United States.
  'America/New_York': 'US',
  'America/Detroit': 'US',
  'America/Kentucky/Louisville': 'US',
  'America/Kentucky/Monticello': 'US',
  'America/Louisville': 'US',
  'America/Indiana/Indianapolis': 'US',
  'America/Indiana/Vincennes': 'US',
  'America/Indiana/Winamac': 'US',
  'America/Indiana/Marengo': 'US',
  'America/Indiana/Petersburg': 'US',
  'America/Indiana/Vevay': 'US',
  'America/Indiana/Tell_City': 'US',
  'America/Indiana/Knox': 'US',
  'America/Indianapolis': 'US',
  'America/Fort_Wayne': 'US',
  'America/Knox_IN': 'US',
  'America/Chicago': 'US',
  'America/Menominee': 'US',
  'America/North_Dakota/Center': 'US',
  'America/North_Dakota/New_Salem': 'US',
  'America/North_Dakota/Beulah': 'US',
  'America/Denver': 'US',
  'America/Boise': 'US',
  'America/Shiprock': 'US',
  'America/Phoenix': 'US',
  'America/Los_Angeles': 'US',
  'America/Anchorage': 'US',
  'America/Juneau': 'US',
  'America/Sitka': 'US',
  'America/Metlakatla': 'US',
  'America/Yakutat': 'US',
  'America/Nome': 'US',
  'America/Adak': 'US',
  'America/Atka': 'US',
  'Pacific/Honolulu': 'US',
  'US/Eastern': 'US',
  'US/Central': 'US',
  'US/Mountain': 'US',
  'US/Pacific': 'US',
  'US/Alaska': 'US',
  'US/Hawaii': 'US',
  'US/Arizona': 'US',
  'US/Michigan': 'US',
  'US/Aleutian': 'US',
  'US/East-Indiana': 'US',
  'US/Indiana-Starke': 'US',
  // Its territories, and the countries that use the dollar.
  'America/Puerto_Rico': 'PR',
  'America/St_Thomas': 'VI',
  'America/Virgin': 'VI',
  'Pacific/Guam': 'GU',
  'Pacific/Saipan': 'MP',
  'Pacific/Pago_Pago': 'AS',
  'Pacific/Samoa': 'AS',
  'US/Samoa': 'AS',
  'Pacific/Midway': 'UM',
  'Pacific/Wake': 'UM',
  'America/Guayaquil': 'EC',
  'Pacific/Galapagos': 'EC',
  'America/El_Salvador': 'SV',
  'America/Panama': 'PA',
  'Asia/Dili': 'TL',
  'Pacific/Palau': 'PW',
  'Pacific/Majuro': 'MH',
  'Pacific/Kwajalein': 'MH',
  'Pacific/Chuuk': 'FM',
  'Pacific/Truk': 'FM',
  'Pacific/Pohnpei': 'FM',
  'Pacific/Ponape': 'FM',
  'Pacific/Kosrae': 'FM',
  'America/Tortola': 'VG',
  'America/Grand_Turk': 'TC',
  'America/Kralendijk': 'BQ',
  // The euro area, and the places that use the euro.
  'Europe/Vienna': 'AT',
  'Europe/Brussels': 'BE',
  'Europe/Sofia': 'BG',
  'Europe/Zagreb': 'HR',
  // Not Asia/Famagusta: the database files it under Cyprus, but it is the
  // north's zone, and the north pays in Turkish lira.
  'Asia/Nicosia': 'CY',
  'Europe/Nicosia': 'CY',
  'Europe/Tallinn': 'EE',
  'Europe/Helsinki': 'FI',
  'Europe/Mariehamn': 'AX',
  'Europe/Paris': 'FR',
  // Not Europe/Busingen: German, but inside Swiss customs and paid in francs.
  'Europe/Berlin': 'DE',
  'Europe/Athens': 'GR',
  'Europe/Dublin': 'IE',
  'Europe/Rome': 'IT',
  'Europe/Riga': 'LV',
  'Europe/Vilnius': 'LT',
  'Europe/Luxembourg': 'LU',
  'Europe/Malta': 'MT',
  'Europe/Amsterdam': 'NL',
  'Europe/Lisbon': 'PT',
  'Atlantic/Madeira': 'PT',
  'Atlantic/Azores': 'PT',
  'Europe/Bratislava': 'SK',
  'Europe/Ljubljana': 'SI',
  'Europe/Madrid': 'ES',
  'Africa/Ceuta': 'ES',
  'Atlantic/Canary': 'ES',
  'Europe/Andorra': 'AD',
  'Europe/Monaco': 'MC',
  'Europe/San_Marino': 'SM',
  'Europe/Vatican': 'VA',
  'Europe/Podgorica': 'ME',
  'America/Cayenne': 'GF',
  'America/Guadeloupe': 'GP',
  'America/Martinique': 'MQ',
  'Indian/Reunion': 'RE',
  'Indian/Mayotte': 'YT',
  'America/Miquelon': 'PM',
  'America/St_Barthelemy': 'BL',
  'America/Marigot': 'MF',
};
