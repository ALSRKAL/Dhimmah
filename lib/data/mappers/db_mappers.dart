import 'package:drift/drift.dart';

import '../../core/money/currency.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/monthly_summary.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/preference_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../database/app_database.dart';

/// Translation between database rows and domain entities.
///
/// Keeping this in one place means the persistence shape can change without
/// touching a single widget or service, and it gives every currency code a
/// single, checked conversion point.
extension PersonRowMapper on PersonRow {
  Person toEntity() => Person(
        id: id,
        name: name,
        phone: phone,
        note: note,
        colorIndex: colorIndex,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      );
}

extension PersonMapper on Person {
  PeopleCompanion toCompanion() => PeopleCompanion(
        id: Value<String>(id),
        name: Value<String>(name),
        phone: Value<String?>(phone),
        note: Value<String?>(note),
        colorIndex: Value<int>(colorIndex),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
        archivedAt: Value<DateTime?>(archivedAt),
      );

  PersonRow toRow() => PersonRow(
        id: id,
        name: name,
        phone: phone,
        note: note,
        colorIndex: colorIndex,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      );
}

extension DebtRowMapper on DebtRow {
  /// Builds the record with the people it is with.
  ///
  /// [personIds] is required rather than optional so a read path that forgets to
  /// load the links is a compile error: a debt built without them would look like
  /// a record that names nobody, and would then be saved that way.
  Debt toEntity({required List<String> personIds}) => Debt(
        id: id,
        personIds: personIds,
        direction: direction,
        title: title,
        principalMinor: principalMinor,
        currency: AppCurrency.parse(currencyCode),
        issuedAt: issuedAt,
        dueAt: dueAt,
        note: note,
        reminderLeads: reminderLeads,
        recurrence: recurrence,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndAt: recurrenceEndAt,
        closedAt: closedAt,
        archivedAt: archivedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension DebtMapper on Debt {
  DebtsCompanion toCompanion() => DebtsCompanion(
        id: Value<String>(id),
        personId: Value<String?>(personId),
        direction: Value<DebtDirection>(direction),
        title: Value<String>(title),
        principalMinor: Value<int>(principalMinor),
        currencyCode: Value<String>(currency.code),
        issuedAt: Value<DateTime>(issuedAt),
        dueAt: Value<DateTime?>(dueAt),
        note: Value<String?>(note),
        reminderLeads: Value<List<ReminderLead>>(reminderLeads),
        recurrence: Value<RecurrenceFrequency>(recurrence),
        recurrenceInterval: Value<int>(recurrenceInterval),
        recurrenceEndAt: Value<DateTime?>(recurrenceEndAt),
        closedAt: Value<DateTime?>(closedAt),
        archivedAt: Value<DateTime?>(archivedAt),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
      );

  DebtRow toRow() => DebtRow(
        id: id,
        personId: personId,
        direction: direction,
        title: title,
        principalMinor: principalMinor,
        currencyCode: currency.code,
        issuedAt: issuedAt,
        dueAt: dueAt,
        note: note,
        reminderLeads: reminderLeads,
        recurrence: recurrence,
        recurrenceInterval: recurrenceInterval,
        recurrenceEndAt: recurrenceEndAt,
        closedAt: closedAt,
        archivedAt: archivedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension PaymentRowMapper on PaymentRow {
  Payment toEntity() => Payment(
        id: id,
        debtId: debtId,
        obligationId: obligationId,
        occurrenceId: occurrenceId,
        personId: personId,
        amountMinor: amountMinor,
        currency: AppCurrency.parse(currencyCode),
        paidAt: paidAt,
        note: note,
        createdAt: createdAt,
      );
}

extension PaymentMapper on Payment {
  PaymentsCompanion toCompanion() => PaymentsCompanion(
        id: Value<String>(id),
        debtId: Value<String?>(debtId),
        obligationId: Value<String?>(obligationId),
        occurrenceId: Value<String?>(occurrenceId),
        personId: Value<String?>(personId),
        amountMinor: Value<int>(amountMinor),
        currencyCode: Value<String>(currency.code),
        paidAt: Value<DateTime>(paidAt),
        note: Value<String?>(note),
        createdAt: Value<DateTime>(createdAt),
      );

  PaymentRow toRow() => PaymentRow(
        id: id,
        debtId: debtId,
        obligationId: obligationId,
        occurrenceId: occurrenceId,
        personId: personId,
        amountMinor: amountMinor,
        currencyCode: currency.code,
        paidAt: paidAt,
        note: note,
        createdAt: createdAt,
      );
}

extension ObligationRowMapper on ObligationRow {
  Obligation toEntity() => Obligation(
        id: id,
        name: name,
        category: category,
        amountMinor: amountMinor,
        currency: AppCurrency.parse(currencyCode),
        frequency: frequency,
        intervalCount: intervalCount,
        dayOfMonth: dayOfMonth,
        startAt: startAt,
        nextDueAt: nextDueAt,
        endAt: endAt,
        note: note,
        reminderLeads: reminderLeads,
        archivedAt: archivedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ObligationMapper on Obligation {
  ObligationsCompanion toCompanion() => ObligationsCompanion(
        id: Value<String>(id),
        name: Value<String>(name),
        category: Value<ObligationCategory>(category),
        amountMinor: Value<int>(amountMinor),
        currencyCode: Value<String>(currency.code),
        frequency: Value<RecurrenceFrequency>(frequency),
        intervalCount: Value<int>(intervalCount),
        dayOfMonth: Value<int?>(dayOfMonth),
        startAt: Value<DateTime>(startAt),
        nextDueAt: Value<DateTime>(nextDueAt),
        endAt: Value<DateTime?>(endAt),
        note: Value<String?>(note),
        reminderLeads: Value<List<ReminderLead>>(reminderLeads),
        archivedAt: Value<DateTime?>(archivedAt),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
      );

  ObligationRow toRow() => ObligationRow(
        id: id,
        name: name,
        category: category,
        amountMinor: amountMinor,
        currencyCode: currency.code,
        frequency: frequency,
        intervalCount: intervalCount,
        dayOfMonth: dayOfMonth,
        startAt: startAt,
        nextDueAt: nextDueAt,
        endAt: endAt,
        note: note,
        reminderLeads: reminderLeads,
        archivedAt: archivedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ObligationOccurrenceRowMapper on ObligationOccurrenceRow {
  ObligationOccurrence toEntity() => ObligationOccurrence(
        id: id,
        obligationId: obligationId,
        periodKey: periodKey,
        dueAt: dueAt,
        amountMinor: amountMinor,
        status: status,
        paidAt: paidAt,
        paymentId: paymentId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ObligationOccurrenceMapper on ObligationOccurrence {
  ObligationOccurrencesCompanion toCompanion() => ObligationOccurrencesCompanion(
        id: Value<String>(id),
        obligationId: Value<String>(obligationId),
        periodKey: Value<String>(periodKey),
        dueAt: Value<DateTime>(dueAt),
        amountMinor: Value<int>(amountMinor),
        status: Value<ObligationStatus>(status),
        paidAt: Value<DateTime?>(paidAt),
        paymentId: Value<String?>(paymentId),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
      );

  ObligationOccurrenceRow toRow() => ObligationOccurrenceRow(
        id: id,
        obligationId: obligationId,
        periodKey: periodKey,
        dueAt: dueAt,
        amountMinor: amountMinor,
        status: status,
        paidAt: paidAt,
        paymentId: paymentId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ReminderRowMapper on ReminderRow {
  Reminder toEntity() => Reminder(
        id: id,
        title: title,
        note: note,
        dueAt: dueAt,
        relatedType: relatedType,
        relatedId: relatedId,
        status: status,
        notificationId: notificationId,
        completedAt: completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ReminderMapper on Reminder {
  RemindersCompanion toCompanion() => RemindersCompanion(
        id: Value<String>(id),
        title: Value<String>(title),
        note: Value<String?>(note),
        dueAt: Value<DateTime>(dueAt),
        relatedType: Value<RelatedEntityType>(relatedType),
        relatedId: Value<String?>(relatedId),
        status: Value<ReminderStatus>(status),
        notificationId: Value<int?>(notificationId),
        completedAt: Value<DateTime?>(completedAt),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
      );

  ReminderRow toRow() => ReminderRow(
        id: id,
        title: title,
        note: note,
        dueAt: dueAt,
        relatedType: relatedType,
        relatedId: relatedId,
        status: status,
        notificationId: notificationId,
        completedAt: completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

extension ActivityEntryRowMapper on ActivityEntryRow {
  ActivityEntry toEntity() => ActivityEntry(
        id: id,
        type: type,
        entityType: entityType,
        entityId: entityId,
        title: title,
        amountMinor: amountMinor,
        currency: currencyCode == null ? null : AppCurrency.parse(currencyCode),
        detail: detail,
        occurredAt: occurredAt,
      );
}

extension ActivityEntryMapper on ActivityEntry {
  ActivityEntriesCompanion toCompanion() => ActivityEntriesCompanion(
        id: Value<String>(id),
        type: Value<ActivityType>(type),
        entityType: Value<RelatedEntityType>(entityType),
        entityId: Value<String?>(entityId),
        title: Value<String>(title),
        amountMinor: Value<int?>(amountMinor),
        currencyCode: Value<String?>(currency?.code),
        detail: Value<String?>(detail),
        occurredAt: Value<DateTime>(occurredAt),
      );

  ActivityEntryRow toRow() => ActivityEntryRow(
        id: id,
        type: type,
        entityType: entityType,
        entityId: entityId,
        title: title,
        amountMinor: amountMinor,
        currencyCode: currency?.code,
        detail: detail,
        occurredAt: occurredAt,
      );
}

extension MonthlySummaryRowMapper on MonthlySummaryRow {
  MonthlySummary toEntity() => MonthlySummary(
        year: year,
        month: month,
        currency: AppCurrency.parse(currencyCode),
        newDebtMinor: newDebtMinor,
        settledMinor: settledMinor,
        receivedMinor: receivedMinor,
        paidOutMinor: paidOutMinor,
        obligationsMinor: obligationsMinor,
        overdueMinor: overdueMinor,
        peopleCount: peopleCount,
        closedDebts: closedDebts,
        activeDebts: activeDebts,
        generatedAt: generatedAt,
      );
}

extension SettingRowMapper on Setting {
  AppSettings toEntity() => AppSettings(
        languagePreference: languagePreference,
        themeMode: themeMode,
        numerals: numerals,
        defaultCurrency: AppCurrency.parse(defaultCurrencyCode),
        notificationsEnabled: notificationsEnabled,
        notificationHour: notificationHour,
        notificationMinute: notificationMinute,
        defaultReminderLeads: defaultReminderLeads,
        monthEndSummaryEnabled: monthEndSummaryEnabled,
        monthEndDay: monthEndDay,
        monthEndHour: monthEndHour,
        monthEndMinute: monthEndMinute,
        dueSoonWindowDays: dueSoonWindowDays,
        lockEnabled: lockEnabled,
        biometricEnabled: biometricEnabled,
        onboardingCompleted: onboardingCompleted,
        backupAutoEnabled: backupAutoEnabled,
        lastSummarySentOn: lastSummarySentOn,
        lastExportedAt: lastExportedAt,
      );
}

extension AppSettingsMapper on AppSettings {
  SettingsCompanion toCompanion() => SettingsCompanion(
        id: const Value<int>(Settings.singletonId),
        languagePreference: Value<LanguagePreference>(languagePreference),
        themeMode: Value<AppThemeMode>(themeMode),
        numerals: Value<NumeralsStyle>(numerals),
        defaultCurrencyCode: Value<String>(defaultCurrency.code),
        notificationsEnabled: Value<bool>(notificationsEnabled),
        notificationHour: Value<int>(notificationHour),
        notificationMinute: Value<int>(notificationMinute),
        defaultReminderLeads: Value<List<ReminderLead>>(defaultReminderLeads),
        monthEndSummaryEnabled: Value<bool>(monthEndSummaryEnabled),
        monthEndDay: Value<MonthEndDay>(monthEndDay),
        monthEndHour: Value<int>(monthEndHour),
        monthEndMinute: Value<int>(monthEndMinute),
        dueSoonWindowDays: Value<int>(dueSoonWindowDays),
        lockEnabled: Value<bool>(lockEnabled),
        biometricEnabled: Value<bool>(biometricEnabled),
        onboardingCompleted: Value<bool>(onboardingCompleted),
        backupAutoEnabled: Value<bool>(backupAutoEnabled),
        lastSummarySentOn: Value<DateTime?>(lastSummarySentOn),
        lastExportedAt: Value<DateTime?>(lastExportedAt),
      );
}
