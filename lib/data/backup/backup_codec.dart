import 'package:drift/drift.dart' show Value;

import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/preference_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../database/app_database.dart';

/// Rows to JSON and back, one table at a time.
///
/// Written by hand rather than reflected from the schema, for two reasons: the
/// file has to be readable (dates as `yyyy-MM-dd`, money as integer minor units,
/// enums by name) and the mapping has to be *explicit* about every column, so a
/// column added later is a visible omission rather than a silent one.
/// `test/data/backup_round_trip_test.dart` compares every column of every table
/// after a round trip, which is what turns "explicit" into "complete".
abstract final class BackupCodec {
  const BackupCodec._();

  // --- Encode ---------------------------------------------------------------

  static Map<String, Object?> person(PersonRow row) => <String, Object?>{
        'id': row.id,
        'name': row.name,
        'phone': row.phone,
        'note': row.note,
        'colorIndex': row.colorIndex,
        'archivedAt': _instant(row.archivedAt),
        'createdAt': _instant(row.createdAt),
        'updatedAt': _instant(row.updatedAt),
      };

  static Map<String, Object?> debt(DebtRow row) => <String, Object?>{
        'id': row.id,
        'personId': row.personId,
        'direction': row.direction.name,
        'title': row.title,
        'amountMinor': row.principalMinor,
        'currency': row.currencyCode,
        'issuedAt': toIsoDate(row.issuedAt),
        'dueAt': row.dueAt == null ? null : toIsoDate(row.dueAt!),
        'note': row.note,
        'reminderLeads': _leads(row.reminderLeads),
        'recurrence': row.recurrence.name,
        'recurrenceInterval': row.recurrenceInterval,
        'recurrenceEndAt':
            row.recurrenceEndAt == null ? null : toIsoDate(row.recurrenceEndAt!),
        'closedAt': _instant(row.closedAt),
        'archivedAt': _instant(row.archivedAt),
        'createdAt': _instant(row.createdAt),
        'updatedAt': _instant(row.updatedAt),
      };

  /// One link. `position` is kept because it is the order the user chose, and
  /// the first link is the person a single-valued field reads.
  static Map<String, Object?> link(DebtPersonRow row) => <String, Object?>{
        'id': '${row.debtId}:${row.personId}',
        'debtId': row.debtId,
        'personId': row.personId,
        'position': row.position,
        'createdAt': _instant(row.createdAt),
      };

  static Map<String, Object?> payment(PaymentRow row) => <String, Object?>{
        'id': row.id,
        'debtId': row.debtId,
        'obligationId': row.obligationId,
        'occurrenceId': row.occurrenceId,
        'personId': row.personId,
        'amountMinor': row.amountMinor,
        'currency': row.currencyCode,
        'paidAt': toIsoDate(row.paidAt),
        'note': row.note,
        'createdAt': _instant(row.createdAt),
      };

  static Map<String, Object?> obligation(ObligationRow row) =>
      <String, Object?>{
        'id': row.id,
        'name': row.name,
        'category': row.category.name,
        'amountMinor': row.amountMinor,
        'currency': row.currencyCode,
        'frequency': row.frequency.name,
        'intervalCount': row.intervalCount,
        'dayOfMonth': row.dayOfMonth,
        'startAt': toIsoDate(row.startAt),
        'nextDueAt': toIsoDate(row.nextDueAt),
        'endAt': row.endAt == null ? null : toIsoDate(row.endAt!),
        'note': row.note,
        'reminderLeads': _leads(row.reminderLeads),
        'archivedAt': _instant(row.archivedAt),
        'createdAt': _instant(row.createdAt),
        'updatedAt': _instant(row.updatedAt),
      };

  static Map<String, Object?> occurrence(ObligationOccurrenceRow row) =>
      <String, Object?>{
        'id': row.id,
        'obligationId': row.obligationId,
        'periodKey': row.periodKey,
        'dueAt': toIsoDate(row.dueAt),
        'amountMinor': row.amountMinor,
        'status': row.status.name,
        'paidAt': row.paidAt == null ? null : toIsoDate(row.paidAt!),
        'paymentId': row.paymentId,
        'createdAt': _instant(row.createdAt),
        'updatedAt': _instant(row.updatedAt),
      };

  static Map<String, Object?> reminder(ReminderRow row) => <String, Object?>{
        'id': row.id,
        'title': row.title,
        'note': row.note,
        'dueAt': toIsoDate(row.dueAt),
        'status': row.status.name,
        'relatedType': row.relatedType.name,
        'relatedId': row.relatedId,
        'notificationId': row.notificationId,
        'completedAt': _instant(row.completedAt),
        'createdAt': _instant(row.createdAt),
        'updatedAt': _instant(row.updatedAt),
      };

  static Map<String, Object?> summary(MonthlySummaryRow row) => <String, Object?>{
        'id': row.id,
        'year': row.year,
        'month': row.month,
        'currency': row.currencyCode,
        'newDebtMinor': row.newDebtMinor,
        'settledMinor': row.settledMinor,
        'receivedMinor': row.receivedMinor,
        'paidOutMinor': row.paidOutMinor,
        'obligationsMinor': row.obligationsMinor,
        'overdueMinor': row.overdueMinor,
        'peopleCount': row.peopleCount,
        'closedDebts': row.closedDebts,
        'activeDebts': row.activeDebts,
        'generatedAt': _instant(row.generatedAt),
      };

  static Map<String, Object?> activity(ActivityEntryRow row) => <String, Object?>{
        'id': row.id,
        'type': row.type.name,
        'entityType': row.entityType.name,
        'entityId': row.entityId,
        'title': row.title,
        'amountMinor': row.amountMinor,
        'currency': row.currencyCode,
        'detail': row.detail,
        'occurredAt': _instant(row.occurredAt),
      };

  /// Settings, minus what belongs to the device rather than to the user.
  ///
  /// Two fields are deliberately not carried:
  ///
  /// * the lock switches — the PIN digest lives in the Android keystore, which
  ///   never travels, so a restored "lock is on" would be a setting with no
  ///   credential behind it;
  /// * `lastSummarySentOn`, which is a record of what *this* device has already
  ///   sent, not a preference.
  static Map<String, Object?> settings(Setting row) => <String, Object?>{
        'language': row.language.name,
        'themeMode': row.themeMode.name,
        'numerals': row.numerals.name,
        'defaultCurrency': row.defaultCurrencyCode,
        'notificationsEnabled': row.notificationsEnabled,
        'notificationHour': row.notificationHour,
        'notificationMinute': row.notificationMinute,
        'defaultReminderLeads': _leads(row.defaultReminderLeads),
        'monthEndSummaryEnabled': row.monthEndSummaryEnabled,
        'monthEndDay': row.monthEndDay.name,
        'monthEndHour': row.monthEndHour,
        'monthEndMinute': row.monthEndMinute,
        'dueSoonWindowDays': row.dueSoonWindowDays,
        'onboardingCompleted': row.onboardingCompleted,
      };

  // --- Decode ---------------------------------------------------------------

  static PeopleCompanion personRow(Map<String, Object?> row) =>
      PeopleCompanion.insert(
        id: _text(row['id'])!,
        name: _text(row['name'])!,
        phone: Value<String?>(_text(row['phone'])),
        note: Value<String?>(_text(row['note'])),
        colorIndex: Value<int>(_int(row['colorIndex']) ?? 0),
        archivedAt: Value<DateTime?>(_dateTime(row['archivedAt'])),
        createdAt: _dateTime(row['createdAt'])!,
        updatedAt: _dateTime(row['updatedAt'])!,
      );

  static DebtsCompanion debtRow(Map<String, Object?> row) => DebtsCompanion.insert(
        id: _text(row['id'])!,
        personId: Value<String?>(_text(row['personId'])),
        direction: DebtDirection.values.byName(_text(row['direction'])!),
        title: Value<String>(_text(row['title']) ?? ''),
        principalMinor: _int(row['amountMinor'])!,
        currencyCode: _text(row['currency'])!,
        issuedAt: _dateOnly(row['issuedAt'])!,
        dueAt: Value<DateTime?>(_dateOnly(row['dueAt'])),
        note: Value<String?>(_text(row['note'])),
        reminderLeads: Value<List<ReminderLead>>(_leadList(row['reminderLeads'])),
        recurrence: RecurrenceFrequency.values.byName(_text(row['recurrence'])!),
        recurrenceInterval: Value<int>(_int(row['recurrenceInterval']) ?? 0),
        recurrenceEndAt: Value<DateTime?>(_dateOnly(row['recurrenceEndAt'])),
        closedAt: Value<DateTime?>(_dateTime(row['closedAt'])),
        archivedAt: Value<DateTime?>(_dateTime(row['archivedAt'])),
        createdAt: _dateTime(row['createdAt'])!,
        updatedAt: _dateTime(row['updatedAt'])!,
      );

  static DebtPeopleCompanion linkRow(Map<String, Object?> row) =>
      DebtPeopleCompanion.insert(
        debtId: _text(row['debtId'])!,
        personId: _text(row['personId'])!,
        position: Value<int>(_int(row['position']) ?? 0),
        createdAt: _dateTime(row['createdAt'])!,
      );

  static PaymentsCompanion paymentRow(Map<String, Object?> row) =>
      PaymentsCompanion.insert(
        id: _text(row['id'])!,
        debtId: Value<String?>(_text(row['debtId'])),
        obligationId: Value<String?>(_text(row['obligationId'])),
        occurrenceId: Value<String?>(_text(row['occurrenceId'])),
        personId: Value<String?>(_text(row['personId'])),
        amountMinor: _int(row['amountMinor'])!,
        currencyCode: _text(row['currency'])!,
        paidAt: _dateOnly(row['paidAt'])!,
        note: Value<String?>(_text(row['note'])),
        createdAt: _dateTime(row['createdAt'])!,
      );

  static ObligationsCompanion obligationRow(Map<String, Object?> row) =>
      ObligationsCompanion.insert(
        id: _text(row['id'])!,
        name: _text(row['name'])!,
        category: ObligationCategory.values.byName(_text(row['category'])!),
        amountMinor: _int(row['amountMinor'])!,
        currencyCode: _text(row['currency'])!,
        frequency: RecurrenceFrequency.values.byName(_text(row['frequency'])!),
        intervalCount: Value<int>(_int(row['intervalCount']) ?? 1),
        dayOfMonth: Value<int?>(_int(row['dayOfMonth'])),
        startAt: _dateOnly(row['startAt'])!,
        nextDueAt: _dateOnly(row['nextDueAt'])!,
        endAt: Value<DateTime?>(_dateOnly(row['endAt'])),
        note: Value<String?>(_text(row['note'])),
        reminderLeads: Value<List<ReminderLead>>(_leadList(row['reminderLeads'])),
        archivedAt: Value<DateTime?>(_dateTime(row['archivedAt'])),
        createdAt: _dateTime(row['createdAt'])!,
        updatedAt: _dateTime(row['updatedAt'])!,
      );

  static ObligationOccurrencesCompanion occurrenceRow(Map<String, Object?> row) =>
      ObligationOccurrencesCompanion.insert(
        id: _text(row['id'])!,
        obligationId: _text(row['obligationId'])!,
        periodKey: _text(row['periodKey'])!,
        dueAt: _dateOnly(row['dueAt'])!,
        amountMinor: _int(row['amountMinor'])!,
        status: ObligationStatus.values.byName(_text(row['status'])!),
        paidAt: Value<DateTime?>(_dateOnly(row['paidAt'])),
        paymentId: Value<String?>(_text(row['paymentId'])),
        createdAt: _dateTime(row['createdAt'])!,
        updatedAt: _dateTime(row['updatedAt'])!,
      );

  static RemindersCompanion reminderRow(Map<String, Object?> row) =>
      RemindersCompanion.insert(
        id: _text(row['id'])!,
        title: _text(row['title'])!,
        note: Value<String?>(_text(row['note'])),
        dueAt: _dateOnly(row['dueAt'])!,
        relatedType:
            RelatedEntityType.values.byName(_text(row['relatedType']) ?? 'none'),
        relatedId: Value<String?>(_text(row['relatedId'])),
        status: ReminderStatus.values.byName(_text(row['status'])!),
        notificationId: Value<int?>(_int(row['notificationId'])),
        completedAt: Value<DateTime?>(_dateTime(row['completedAt'])),
        createdAt: _dateTime(row['createdAt'])!,
        updatedAt: _dateTime(row['updatedAt'])!,
      );

  static MonthlySummariesCompanion summaryRow(Map<String, Object?> row) =>
      MonthlySummariesCompanion.insert(
        id: _text(row['id'])!,
        year: _int(row['year'])!,
        month: _int(row['month'])!,
        currencyCode: _text(row['currency'])!,
        newDebtMinor: Value<int>(_int(row['newDebtMinor']) ?? 0),
        settledMinor: Value<int>(_int(row['settledMinor']) ?? 0),
        receivedMinor: Value<int>(_int(row['receivedMinor']) ?? 0),
        paidOutMinor: Value<int>(_int(row['paidOutMinor']) ?? 0),
        obligationsMinor: Value<int>(_int(row['obligationsMinor']) ?? 0),
        overdueMinor: Value<int>(_int(row['overdueMinor']) ?? 0),
        peopleCount: Value<int>(_int(row['peopleCount']) ?? 0),
        closedDebts: Value<int>(_int(row['closedDebts']) ?? 0),
        activeDebts: Value<int>(_int(row['activeDebts']) ?? 0),
        generatedAt: _dateTime(row['generatedAt'])!,
      );

  static ActivityEntriesCompanion activityRow(Map<String, Object?> row) =>
      ActivityEntriesCompanion.insert(
        id: _text(row['id'])!,
        type: ActivityType.values.byName(_text(row['type'])!),
        entityType: RelatedEntityType.values.byName(_text(row['entityType'])!),
        entityId: Value<String?>(_text(row['entityId'])),
        title: Value<String>(_text(row['title']) ?? ''),
        amountMinor: Value<int?>(_int(row['amountMinor'])),
        currencyCode: Value<String?>(_text(row['currency'])),
        detail: Value<String?>(_text(row['detail'])),
        occurredAt: _dateTime(row['occurredAt'])!,
      );

  /// The settings a backup carries, applied on top of the device's own.
  ///
  /// Every field that is missing or unreadable keeps the value the device
  /// already had, so a file written by an older app cannot silently reset a
  /// preference it never knew about.
  static AppSettings applySettings(
    Map<String, Object?> row,
    AppSettings current,
  ) {
    return current.copyWith(
      language: _enumByName(AppLanguage.values, row['language']) ??
          current.language,
      themeMode:
          _enumByName(AppThemeMode.values, row['themeMode']) ?? current.themeMode,
      numerals: _enumByName(NumeralsStyle.values, row['numerals']) ??
          current.numerals,
      defaultCurrency: _currency(row['defaultCurrency']) ?? current.defaultCurrency,
      notificationsEnabled:
          _bool(row['notificationsEnabled']) ?? current.notificationsEnabled,
      notificationHour: _int(row['notificationHour']) ?? current.notificationHour,
      notificationMinute:
          _int(row['notificationMinute']) ?? current.notificationMinute,
      defaultReminderLeads: row['defaultReminderLeads'] is List
          ? _leadList(row['defaultReminderLeads'])
          : current.defaultReminderLeads,
      monthEndSummaryEnabled:
          _bool(row['monthEndSummaryEnabled']) ?? current.monthEndSummaryEnabled,
      monthEndDay: _enumByName(MonthEndDay.values, row['monthEndDay']) ??
          current.monthEndDay,
      monthEndHour: _int(row['monthEndHour']) ?? current.monthEndHour,
      monthEndMinute: _int(row['monthEndMinute']) ?? current.monthEndMinute,
      dueSoonWindowDays:
          _int(row['dueSoonWindowDays']) ?? current.dueSoonWindowDays,
      onboardingCompleted: true,
    );
  }

  // --- Primitives -----------------------------------------------------------

  static String? _instant(DateTime? value) => value?.toUtc().toIso8601String();

  static DateTime? _dateTime(Object? value) {
    if (value is! String) return null;
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }

  static DateTime? _dateOnly(Object? value) {
    if (value is! String || value.length < 10) return null;
    return tryParseIsoDate(value.substring(0, 10));
  }

  static List<int> _leads(List<ReminderLead> leads) => <int>[
        for (final ReminderLead lead in ReminderLead.sorted(leads))
          lead.daysBefore,
      ];

  static List<ReminderLead> _leadList(Object? value) {
    if (value is! List) return const <ReminderLead>[];
    return ReminderLead.sorted(<ReminderLead>[
      for (final Object? lead in value)
        if (lead is int) ReminderLead.fromDays(lead),
    ]);
  }

  static String? _text(Object? value) => value is String ? value : null;

  static int? _int(Object? value) => value is int ? value : null;

  static bool? _bool(Object? value) => value is bool ? value : null;

  static T? _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) return null;
    for (final T value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static AppCurrency? _currency(Object? code) {
    if (code is! String) return null;
    for (final AppCurrency currency in AppCurrency.values) {
      if (currency.code == code) return currency;
    }
    return null;
  }
}
