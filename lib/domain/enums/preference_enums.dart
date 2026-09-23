/// The two languages Dhimmah ships with. Arabic is the default.
enum AppLanguage {
  arabic('ar'),
  english('en');

  const AppLanguage(this.code);

  /// ISO 639-1 code, also used as the Flutter [Locale] language code.
  final String code;

  bool get isArabic => this == AppLanguage.arabic;

  /// Script direction implied by the language.
  bool get isRtl => this == AppLanguage.arabic;

  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.arabic;
    final String needle = code.trim().toLowerCase();
    for (final AppLanguage language in AppLanguage.values) {
      if (language.code == needle) return language;
    }
    if (needle.startsWith('ar')) return AppLanguage.arabic;
    if (needle.startsWith('en')) return AppLanguage.english;
    return AppLanguage.arabic;
  }

  /// A short label the settings screen can show without localisation, used only
  /// as a fallback; the localised name comes from the ARB files.
  String get nativeName => this == AppLanguage.arabic ? 'العربية' : 'English';
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
