import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/enums/preference_enums.dart';
import '../../l10n/generated/app_localizations.dart';
import '../money/currency.dart';
import '../money/money.dart';
import '../utils/dates.dart';
import 'money_formatter.dart';

/// Formats dates and relative times for display.
///
/// The app leans on two shapes: an absolute date for records ("22 Sep 2026") and
/// a relative phrase for anything with a deadline ("in 3 days", "5 days late").
/// Relative phrases come from the ARB files so their plural rules are correct in
/// both languages, including Arabic's dual and plural forms.
class DateFormatter {
  DateFormatter({required this.language, required this.localizations});

  final AppLanguage language;
  final AppLocalizations localizations;

  String get _locale => language.code;

  /// `22 Sep 2026`
  String medium(DateTime date) => DateFormat.yMMMd(_locale).format(date);

  /// `22 September 2026`
  String long(DateTime date) => DateFormat.yMMMMd(_locale).format(date);

  /// `September 2026` — used for report and summary headings.
  String monthYear(DateTime date) => DateFormat.yMMMM(_locale).format(date);

  /// `Sep 2026` — compact month heading for chips and pickers.
  String shortMonthYear(DateTime date) => DateFormat.yM(_locale).format(date);

  /// `22/09/2026`
  String numeric(DateTime date) => DateFormat.yMd(_locale).format(date);

  /// `8:00 PM`
  String time(BuildContext context, int hour, int minute) {
    final TimeOfDay value = TimeOfDay(hour: hour, minute: minute);
    return value.format(context);
  }

  /// The phrase shown next to anything with a due date.
  ///
  /// Lateness is always stated as lateness, however long ago the deadline was: a
  /// date two months in the past tells the reader less than "متأخر 60 يومًا"
  /// does. Dates in the future switch to an absolute form after a week, because
  /// "in 23 days" is harder to act on than "15 Oct 2026".
  String relativeDue(DateTime dueAt, DateTime asOf) {
    final int days = daysBetween(asOf, dueAt);
    if (days == 0) return localizations.dateToday;
    if (days == 1) return localizations.dateTomorrow;
    if (days == -1) return localizations.dateYesterday;
    if (days < 0) return localizations.dateOverdueBy(-days);
    if (days <= 7) return localizations.dateInDays(days);
    return localizations.dateDueOn(medium(dueAt));
  }

  /// A label for something that needs attention: always how soon, plus when.
  ///
  /// [relativeDue] falls back to an absolute date once something is more than a
  /// fortnight out, which is right for a list of reminders but wrong here — the
  /// caller appends the date itself, so the fallback would print it twice. This
  /// always leads with how long there is, however long that is.
  String attentionLabel(DateTime dueAt, DateTime asOf) {
    final int days = daysBetween(asOf, dueAt);
    if (days == 0) return localizations.dateToday;
    if (days == 1) return localizations.dateTomorrow;
    if (days == -1) return localizations.dateYesterday;
    if (days < 0) return localizations.dateOverdueBy(-days);
    return localizations.dateInDays(days);
  }

  /// How late something is, or an empty string when it is not late.
  String overdueBy(DateTime dueAt, DateTime asOf) {
    final int days = daysBetween(asOf, dueAt);
    if (days >= 0) return '';
    return localizations.dateOverdueBy(-days);
  }

  /// A grouping label for the date-picker header.
  String range(DateTime from, DateTime to) =>
      '${medium(from)} – ${medium(to)}';

  /// Month key used by reports, e.g. `2026-09`.
  String monthKeyOf(DateTime date) => monthKey(date);
}

/// Bundles the formatters a screen needs, built from the user's settings.
///
/// One object is passed down so a screen can never format two amounts with
/// different locale rules.
class AppFormatting {
  AppFormatting({
    required this.language,
    required this.numerals,
    required this.defaultCurrency,
    required this.localizations,
  })  : money = MoneyFormatter(
          numerals: numerals,
          defaultCurrency: defaultCurrency,
        ),
        _dates = DateFormatter(language: language, localizations: localizations);

  final AppLanguage language;
  final NumeralsStyle numerals;
  final AppCurrency defaultCurrency;
  final AppLocalizations localizations;

  final MoneyFormatter money;
  final DateFormatter _dates;

  DateFormatter get dates => _dates;

  /// A currency amount, with the code added when the symbol would be ambiguous.
  ///
  /// [isolate] is false for documents; see [MoneyFormatter.format].
  String amount(
    Money value, {
    bool compact = false,
    bool showCode = false,
    bool isolate = true,
  }) =>
      money.format(
        value,
        compact: compact,
        showCode: showCode,
        isolate: isolate,
      );

  /// An amount for a printed document: plain text, no bidi controls.
  String documentAmount(Money value, {bool showCode = false}) =>
      money.format(value, showCode: showCode, isolate: false);

  /// A plain count, honouring the numeral style.
  String count(int value) => money.integer(value);

  String percent(double fraction) => money.percent(fraction);

  String relativeDue(DateTime dueAt, DateTime asOf) =>
      _dates.relativeDue(dueAt, asOf);

  String date(DateTime value) => _dates.medium(value);

  static AppFormatting of({
    required AppLanguage language,
    required NumeralsStyle numerals,
    required AppCurrency defaultCurrency,
    required AppLocalizations localizations,
  }) =>
      AppFormatting(
        language: language,
        numerals: numerals,
        defaultCurrency: defaultCurrency,
        localizations: localizations,
      );
}

/// `context.format.amount(money)` — formatting resolved from the active locale.
extension FormattingContext on BuildContext {
  AppFormatting get formatting => AppFormattingScope.of(this);
}

/// Provides [AppFormatting] to the widget tree.
class AppFormattingScope extends InheritedWidget {
  const AppFormattingScope({
    required this.formatting,
    required super.child,
    super.key,
  });

  final AppFormatting formatting;

  static AppFormatting of(BuildContext context) {
    final AppFormattingScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppFormattingScope>();
    assert(scope != null, 'AppFormattingScope is missing above this widget');
    return scope!.formatting;
  }

  @override
  bool updateShouldNotify(AppFormattingScope oldWidget) =>
      oldWidget.formatting.language != formatting.language ||
      oldWidget.formatting.numerals != formatting.numerals ||
      oldWidget.formatting.defaultCurrency != formatting.defaultCurrency;
}
