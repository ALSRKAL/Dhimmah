/// The two languages Dhimmah ships with.
///
/// This is the language the interface is *in*, and it is never stored: it is
/// resolved from the user's [LanguagePreference] and the phone's own list of
/// languages, so a phone that changes language takes the app with it.
enum AppLanguage {
  arabic('ar'),
  english('en');

  const AppLanguage(this.code);

  /// ISO 639-1 code, also used as the Flutter [Locale] language code.
  final String code;

  bool get isArabic => this == AppLanguage.arabic;

  /// Script direction implied by the language.
  bool get isRtl => this == AppLanguage.arabic;

  /// The other one. There are two, so a switch between them is a toggle.
  AppLanguage get other => isArabic ? AppLanguage.english : AppLanguage.arabic;

  /// What a phone in neither language opens in.
  ///
  /// English rather than Arabic: a phone set to Hindi, Urdu or French belongs to
  /// someone who is far more likely to read English than Arabic, and the app is
  /// complete in both. Arabic-first means an Arabic phone opens in Arabic — not
  /// that everyone else has to read it.
  static const AppLanguage fallback = AppLanguage.english;

  /// The language a locale tag names, or null when Dhimmah does not ship it.
  ///
  /// Only the language subtag counts, so `ar`, `ar-YE` and `ar_EG` are all
  /// Arabic and `en-IN` is English. Anything else is an honest "not ours".
  static AppLanguage? tryParse(String? tag) {
    if (tag == null) return null;
    final String subtag =
        tag.trim().toLowerCase().split(RegExp('[-_]')).first;
    for (final AppLanguage language in AppLanguage.values) {
      if (language.code == subtag) return language;
    }
    return null;
  }

  /// The language to open in on a phone that prefers [languageCodes], most
  /// preferred first.
  ///
  /// The first language on the phone's list that Dhimmah ships wins, which is
  /// the rule the phone's own settings describe: someone who reads French first
  /// and Arabic second gets Arabic, not the [fallback].
  static AppLanguage fromDevice(Iterable<String> languageCodes) {
    for (final String code in languageCodes) {
      final AppLanguage? language = tryParse(code);
      if (language != null) return language;
    }
    return fallback;
  }
}

/// What the user asked for: follow the phone, or one language whatever the
/// phone says.
///
/// Stored, unlike [AppLanguage]. Keeping the choice apart from its result is what
/// lets the app follow a phone whose language changes while it is open, and
/// still remember a user who picked a language on purpose. A new install
/// follows the phone.
enum LanguagePreference {
  system,
  arabic,
  english;

  /// The language this preference names, or null when the phone decides.
  AppLanguage? get language => switch (this) {
        LanguagePreference.system => null,
        LanguagePreference.arabic => AppLanguage.arabic,
        LanguagePreference.english => AppLanguage.english,
      };

  bool get followsDevice => this == LanguagePreference.system;

  /// The language the interface is in on a phone whose language is [device].
  AppLanguage resolve(AppLanguage device) => language ?? device;

  /// The preference that pins [language].
  static LanguagePreference of(AppLanguage language) => switch (language) {
        AppLanguage.arabic => LanguagePreference.arabic,
        AppLanguage.english => LanguagePreference.english,
      };
}

/// Whether amounts are rendered with Western or Arabic-Indic digits.
///
/// Latin digits stay the default because they are unambiguous at a glance on a
/// phone, but Arabic-Indic is offered for readers who prefer it.
enum NumeralsStyle {
  latin('latn'),
  arabicIndic('arab');

  const NumeralsStyle(this.icuNumbering);

  /// ICU numbering-system keyword value.
  final String icuNumbering;

  static NumeralsStyle fromName(String? name) {
    for (final NumeralsStyle style in NumeralsStyle.values) {
      if (style.name == name) return style;
    }
    return NumeralsStyle.latin;
  }
}

/// Theme selection, including following the operating system.
enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromName(String? name) {
    for (final AppThemeMode mode in AppThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return AppThemeMode.system;
  }
}

/// Which day the month-end summary notification is sent on.
enum MonthEndDay {
  day25(25),
  day26(26),
  day27(27),
  day28(28),
  day29(29),
  day30(30),
  day31(31),

  /// Clamp to the real last day of whatever month it is — 28, 29, 30 or 31.
  lastDay(0);

  const MonthEndDay(this.dayOfMonth);

  /// `0` marks "the last day of the month" rather than a fixed day.
  final int dayOfMonth;

  bool get isLastDay => this == MonthEndDay.lastDay;

  static MonthEndDay fromDay(int day) {
    for (final MonthEndDay value in MonthEndDay.values) {
      if (value.dayOfMonth == day) return value;
    }
    return MonthEndDay.lastDay;
  }
}
