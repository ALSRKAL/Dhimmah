import 'package:drift/drift.dart';

/// Secondary indexes.
///
/// The schema shipped with only primary-key autoindexes, so every foreign-key
/// lookup scanned the whole table: reading one person's five debts took 265 ms
/// at 2,500 debts, and the person page's payment lookup — one query *per debt* —
/// scanned the payments table each time. Measured, and the reason the person
/// page cost 287 ms to show five rows.

import '../../domain/enums/activity_enums.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/preference_enums.dart';
import '../../domain/enums/recurrence.dart';
import 'converters.dart';

@DataClassName('PersonRow')
class People extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get createdAt =>
      integer().map(const TimestampConverter())();
  IntColumn get updatedAt =>
      integer().map(const TimestampConverter())();
  IntColumn get archivedAt =>
      integer().nullable().map(const NullableTimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('DebtRow')
@TableIndex(name: 'idx_debts_person', columns: <Symbol>{#personId})
@TableIndex(name: 'idx_debts_due', columns: <Symbol>{#dueAt})
@TableIndex(name: 'idx_debts_archived', columns: <Symbol>{#archivedAt})
class Debts extends Table {
  TextColumn get id => text()();

  /// The person the user named first, kept as one value.
  ///
  /// [DebtPeople] is the authority on who a debt is with, and this column is a
  /// projection of it: the participant at position 0, or NULL for a record that
  /// names nobody. It survives because it is what payments, notifications, the
  /// statement and the activity feed have always read, and because its foreign
  /// key is what unlinks a debt when the person behind it is deleted. It is
  /// written in exactly one place — the same write that stores the links — and
  /// `debts_dao` refuses to let the two disagree.
  TextColumn get personId => text().nullable().references(People, #id, onDelete: KeyAction.setNull)();
  TextColumn get direction => textEnum<DebtDirection>()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get principalMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get issuedAt =>
      text().map(const DateOnlyConverter())();
  TextColumn get dueAt =>
      text().nullable().map(const NullableDateOnlyConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get reminderLeads =>
      text().withDefault(const Constant('')).map(const ReminderLeadsConverter())();
  TextColumn get recurrence => textEnum<RecurrenceFrequency>()();
  IntColumn get recurrenceInterval => integer().withDefault(const Constant(0))();
  TextColumn get recurrenceEndAt =>
      text().nullable().map(const NullableDateOnlyConverter())();
  IntColumn get closedAt =>
      integer().nullable().map(const NullableTimestampConverter())();
  IntColumn get archivedAt =>
      integer().nullable().map(const NullableTimestampConverter())();
  IntColumn get createdAt =>
      integer().map(const TimestampConverter())();
  IntColumn get updatedAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Who a debt is with.
///
/// One record can be shared by several people — a dinner bill, a group
/// purchase — and the link is a table rather than a column of ids or of JSON
/// for the reasons a relation always wins: the database enforces uniqueness, a
/// person's page is an indexed lookup instead of a scan over encoded text, and
/// deleting a person removes exactly their links through the foreign key.
///
/// [position] keeps the user's own order (the order they picked the people in),
/// which is what makes "the first participant" a stable, meaningful value: it is
/// the one mirrored into `debts.person_id` for the single-participant case.
@DataClassName('DebtPersonRow')
@TableIndex(name: 'idx_debt_people_person', columns: <Symbol>{#personId})
class DebtPeople extends Table {
  TextColumn get debtId =>
      text().references(Debts, #id, onDelete: KeyAction.cascade)();
  TextColumn get personId =>
      text().references(People, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().map(const TimestampConverter())();

  /// The pair is the key, so the same person cannot be linked twice — the rule
  /// is enforced by the database and not only by the screen that collects it.
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{debtId, personId};
}

@DataClassName('PaymentRow')
@TableIndex(name: 'idx_payments_debt', columns: <Symbol>{#debtId})
@TableIndex(name: 'idx_payments_person', columns: <Symbol>{#personId})
@TableIndex(name: 'idx_payments_paid_at', columns: <Symbol>{#paidAt})
@TableIndex(name: 'idx_payments_occurrence', columns: <Symbol>{#occurrenceId})
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text().nullable().references(Debts, #id, onDelete: KeyAction.setNull)();
  TextColumn get obligationId => text().nullable()();
  TextColumn get occurrenceId => text().nullable()();
  TextColumn get personId => text().nullable().references(People, #id, onDelete: KeyAction.setNull)();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get paidAt =>
      text().map(const DateOnlyConverter())();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ObligationRow')
@TableIndex(name: 'idx_obligations_next_due', columns: <Symbol>{#nextDueAt})
@TableIndex(name: 'idx_obligations_archived', columns: <Symbol>{#archivedAt})
class Obligations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get category => textEnum<ObligationCategory>()();
  IntColumn get amountMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get frequency => textEnum<RecurrenceFrequency>()();
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  IntColumn get dayOfMonth => integer().nullable()();
  TextColumn get startAt =>
      text().map(const DateOnlyConverter())();
  TextColumn get nextDueAt =>
      text().map(const DateOnlyConverter())();
  TextColumn get endAt =>
      text().nullable().map(const NullableDateOnlyConverter())();
  TextColumn get note => text().nullable()();
  TextColumn get reminderLeads =>
      text().withDefault(const Constant('')).map(const ReminderLeadsConverter())();
  IntColumn get archivedAt =>
      integer().nullable().map(const NullableTimestampConverter())();
  IntColumn get createdAt =>
      integer().map(const TimestampConverter())();
  IntColumn get updatedAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ObligationOccurrenceRow')
@TableIndex(name: 'idx_occurrences_obligation', columns: <Symbol>{#obligationId})
@TableIndex(name: 'idx_occurrences_due', columns: <Symbol>{#dueAt})
@TableIndex(name: 'idx_occurrences_status', columns: <Symbol>{#status})
class ObligationOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get obligationId =>
      text().references(Obligations, #id, onDelete: KeyAction.cascade)();
  TextColumn get periodKey => text()();
  TextColumn get dueAt =>
      text().map(const DateOnlyConverter())();
  IntColumn get amountMinor => integer()();
  TextColumn get status => textEnum<ObligationStatus>()();
  TextColumn get paidAt =>
      text().nullable().map(const NullableDateOnlyConverter())();
  TextColumn get paymentId => text().nullable()();
  IntColumn get createdAt =>
      integer().map(const TimestampConverter())();
  IntColumn get updatedAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
        'UNIQUE (obligation_id, period_key)',
      ];
}

@DataClassName('ReminderRow')
@TableIndex(name: 'idx_reminders_due', columns: <Symbol>{#dueAt})
@TableIndex(name: 'idx_reminders_status', columns: <Symbol>{#status})
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get note => text().nullable()();
  TextColumn get dueAt =>
      text().map(const DateOnlyConverter())();
  TextColumn get relatedType => textEnum<RelatedEntityType>()();
  TextColumn get relatedId => text().nullable()();
  TextColumn get status => textEnum<ReminderStatus>()();
  /// Vestigial. The app does not store the platform's notification id: the
  /// records are the source of truth and the pending set is the platform's own
  /// record of what it is holding, compared on every reconciliation. The column
  /// is never written, and dropping it would cost a migration for nothing.
  IntColumn get notificationId => integer().nullable()();
  IntColumn get completedAt =>
      integer().nullable().map(const NullableTimestampConverter())();
  IntColumn get createdAt =>
      integer().map(const TimestampConverter())();
  IntColumn get updatedAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('ActivityEntryRow')
@TableIndex(name: 'idx_activity_entity', columns: <Symbol>{#entityType, #entityId})
@TableIndex(name: 'idx_activity_occurred', columns: <Symbol>{#occurredAt})
class ActivityEntries extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<ActivityType>()();
  TextColumn get entityType => textEnum<RelatedEntityType>()();
  TextColumn get entityId => text().nullable()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get amountMinor => integer().nullable()();
  TextColumn get currencyCode => text().nullable()();
  TextColumn get detail => text().nullable()();
  IntColumn get occurredAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('MonthlySummaryRow')
class MonthlySummaries extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get newDebtMinor => integer().withDefault(const Constant(0))();
  IntColumn get settledMinor => integer().withDefault(const Constant(0))();
  IntColumn get receivedMinor => integer().withDefault(const Constant(0))();
  IntColumn get paidOutMinor => integer().withDefault(const Constant(0))();
  IntColumn get obligationsMinor => integer().withDefault(const Constant(0))();
  IntColumn get overdueMinor => integer().withDefault(const Constant(0))();
  IntColumn get peopleCount => integer().withDefault(const Constant(0))();
  IntColumn get closedDebts => integer().withDefault(const Constant(0))();
  IntColumn get activeDebts => integer().withDefault(const Constant(0))();
  IntColumn get generatedAt =>
      integer().map(const TimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
        'UNIQUE (year, month, currency_code)',
      ];
}

/// User preferences. Exactly one row, pinned to [singletonId].
class Settings extends Table {
  IntColumn get id => integer()();

  /// `system`, `arabic` or `english`: a [LanguagePreference], not a language.
  ///
  /// The column keeps its name. Every row written before version 5 holds
  /// `arabic` or `english`, which are already valid preferences, so the values
  /// carry over untouched and only the new one, `system`, is added.
  TextColumn get languagePreference =>
      textEnum<LanguagePreference>().named('language')();
  TextColumn get themeMode => textEnum<AppThemeMode>()();
  TextColumn get numerals => textEnum<NumeralsStyle>()();
  TextColumn get defaultCurrencyCode => text().withLength(min: 3, max: 3)();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(true))();
  IntColumn get notificationHour => integer().withDefault(const Constant(20))();
  IntColumn get notificationMinute => integer().withDefault(const Constant(0))();
  TextColumn get defaultReminderLeads =>
      text().withDefault(const Constant('1')).map(const ReminderLeadsConverter())();
  BoolColumn get monthEndSummaryEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get monthEndDay => textEnum<MonthEndDay>()();
  IntColumn get monthEndHour => integer().withDefault(const Constant(20))();
  IntColumn get monthEndMinute => integer().withDefault(const Constant(0))();
  IntColumn get dueSoonWindowDays => integer().withDefault(const Constant(7))();
  BoolColumn get lockEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get biometricEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  /// Whether the app keeps its own snapshots up to date.
  ///
  /// On by default: the point of a safety net is that it is already there the
  /// first time it is needed. Turning it off leaves the manual buttons working.
  BoolColumn get backupAutoEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get lastSummarySentOn =>
      text().nullable().map(const NullableDateOnlyConverter())();
  IntColumn get lastExportedAt =>
      integer().nullable().map(const NullableTimestampConverter())();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  /// The only row this table will ever hold.
  static const int singletonId = 1;
}
