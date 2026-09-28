import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

/// A value object that lies about being equal is a bug factory.
///
/// `AppSettings` is compared in three places that all decide whether to do work:
/// Riverpod decides whether a dependent provider must recompute, Flutter decides
/// whether a widget subtree must rebuild, and the settings provider decides
/// whether anything changed at all. A field left out of `==` is therefore not a
/// cosmetic omission — it is a field the app cannot react to.
///
/// That is exactly what happened: `backupAutoEnabled` was absent from `==`, so
/// turning automatic saving off wrote the database, streamed the new row back,
/// and changed nothing on screen until the app was restarted.
///
/// This walks every field, so the next one added is caught here rather than on a
/// phone.
void main() {
  /// `AppSettings.initial`, and the same object with exactly one field changed.
  ///
  /// [changed] is called with a `copyWith` that differs in one field; the test
  /// asserts the result is not equal to the original.
  final Map<String, AppSettings Function(AppSettings)> oneFieldChanged =
      <String, AppSettings Function(AppSettings)>{
    'language': (AppSettings s) =>
        s.copyWith(language: AppLanguage.english),
    'themeMode': (AppSettings s) => s.copyWith(themeMode: AppThemeMode.dark),
    'numerals': (AppSettings s) =>
        s.copyWith(numerals: NumeralsStyle.arabicIndic),
    'defaultCurrency': (AppSettings s) =>
        s.copyWith(defaultCurrency: AppCurrency.usd),
    'notificationsEnabled': (AppSettings s) =>
        s.copyWith(notificationsEnabled: !s.notificationsEnabled),
    'notificationHour': (AppSettings s) => s.copyWith(notificationHour: 7),
    'notificationMinute': (AppSettings s) => s.copyWith(notificationMinute: 30),
    'defaultReminderLeads': (AppSettings s) => s.copyWith(
          defaultReminderLeads: <ReminderLead>[ReminderLead.oneWeekBefore],
        ),
    'monthEndSummaryEnabled': (AppSettings s) =>
        s.copyWith(monthEndSummaryEnabled: !s.monthEndSummaryEnabled),
    'monthEndDay': (AppSettings s) =>
        s.copyWith(monthEndDay: MonthEndDay.day25),
    'monthEndHour': (AppSettings s) => s.copyWith(monthEndHour: 6),
    'monthEndMinute': (AppSettings s) => s.copyWith(monthEndMinute: 15),
    'dueSoonWindowDays': (AppSettings s) => s.copyWith(dueSoonWindowDays: 3),
    'lockEnabled': (AppSettings s) => s.copyWith(lockEnabled: true),
    'biometricEnabled': (AppSettings s) => s.copyWith(biometricEnabled: true),
    'onboardingCompleted': (AppSettings s) =>
        s.copyWith(onboardingCompleted: true),
    'backupAutoEnabled': (AppSettings s) =>
        s.copyWith(backupAutoEnabled: !s.backupAutoEnabled),
    'lastSummarySentOn': (AppSettings s) =>
        s.copyWith(lastSummarySentOn: DateTime(2026, 9, 27)),
    'lastExportedAt': (AppSettings s) =>
        s.copyWith(lastExportedAt: DateTime(2026, 9, 27)),
  };

  group('every field is visible to equality', () {
    for (final MapEntry<String, AppSettings Function(AppSettings)> entry
        in oneFieldChanged.entries) {
      test('changing ${entry.key} makes the settings unequal', () {
        final AppSettings changed = entry.value(AppSettings.initial);
        expect(
          changed,
          isNot(AppSettings.initial),
          reason: '`${entry.key}` is missing from AppSettings.==, so nothing '
              'that compares settings — a provider, a widget, a change check — '
              'can see it change',
        );
        expect(
          changed.hashCode,
          isNot(AppSettings.initial.hashCode),
          reason: '`${entry.key}` is missing from AppSettings.hashCode, so two '
              'different settings can land in the same bucket and compare equal '
              'to a container',
        );
      });
    }
  });

  group('and says nothing changed when nothing did', () {
    test('a copy with the same values is equal', () {
      expect(AppSettings.initial.copyWith(), AppSettings.initial);
      expect(
        AppSettings.initial.copyWith().hashCode,
        AppSettings.initial.hashCode,
      );
    });

    test('the reminder leads compare by value, not by identity', () {
      // Two reads of the same row produce two different lists. Comparing them by
      // identity would make every emission look like a change; ignoring the
      // field — which is what the old `==` effectively did — makes a real change
      // invisible.
      final AppSettings first = AppSettings.initial.copyWith(
        defaultReminderLeads: <ReminderLead>[
          ReminderLead.oneDayBefore,
          ReminderLead.oneWeekBefore,
        ],
      );
      final AppSettings second = AppSettings.initial.copyWith(
        defaultReminderLeads: <ReminderLead>[
          ReminderLead.oneDayBefore,
          ReminderLead.oneWeekBefore,
        ],
      );
      expect(identical(first.defaultReminderLeads, second.defaultReminderLeads),
          isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);

      final AppSettings reordered = AppSettings.initial.copyWith(
        defaultReminderLeads: <ReminderLead>[
          ReminderLead.oneWeekBefore,
          ReminderLead.oneDayBefore,
        ],
      );
      expect(
        reordered,
        isNot(first),
        reason: 'the order is the one the user set, and it is what the record '
            'form pre-selects',
      );
      expect(reordered, isNot(AppSettings.initial));
    });

    test('a different number of leads is a different setting', () {
      final AppSettings one = AppSettings.initial.copyWith(
        defaultReminderLeads: <ReminderLead>[ReminderLead.oneDayBefore],
      );
      final AppSettings two = AppSettings.initial.copyWith(
        defaultReminderLeads: <ReminderLead>[
          ReminderLead.oneDayBefore,
          ReminderLead.onDueDate,
        ],
      );
      expect(one, isNot(two));
    });
  });
}
