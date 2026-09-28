import '../../core/money/currency.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/recurrence.dart';
import 'amount_rules.dart';
import 'backup_format.dart';

/// One thing wrong with a backup file.
class BackupIssue {
  const BackupIssue({
    required this.code,
    required this.detail,
    this.table,
    this.id,
  });

  /// A stable machine-readable name, so a test can assert the exact rule that
  /// fired rather than matching a sentence.
  final String code;
  final String detail;
  final String? table;
  final String? id;

  @override
  String toString() =>
      '${table ?? '-'}${id == null ? '' : '/$id'}: $code — $detail';
}

/// The verdict on a backup file.
///
/// An error means the file cannot be restored at all: a broken reference, an
/// amount that is not money, a row that is not a row. A warning means something
/// was noticed and dealt with — a truncated activity log, an unknown settings
/// key — and the user is told rather than kept in the dark.
class BackupValidation {
  const BackupValidation({
    required this.errors,
    required this.warnings,
    required this.preview,
  });

  static const BackupValidation unusable = BackupValidation(
    errors: <BackupIssue>[],
    warnings: <BackupIssue>[],
    preview: null,
  );

  final List<BackupIssue> errors;
  final List<BackupIssue> warnings;
  final BackupPreview? preview;

  bool get isUsable => errors.isEmpty && preview != null;

  String get firstError => errors.isEmpty ? '' : errors.first.detail;
}

/// What the preview screen shows before anything is written.
class BackupPreview {
  const BackupPreview({
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
    required this.counts,
    required this.currencies,
    required this.sharedRecords,
    required this.oldestRecordAt,
    required this.newestChangeAt,
    required this.warnings,
  });

  final DateTime? createdAt;
  final String appVersion;
  final int schemaVersion;

  /// Rows per table, as the file actually carries them.
  final Map<String, int> counts;

  /// Every currency present in the file. A backup can hold several, and they are
  /// never added together.
  final List<AppCurrency> currencies;

  /// Records linked to more than one person — the shape that must survive a
  /// round trip without being multiplied.
  final int sharedRecords;

  final DateTime? oldestRecordAt;
  final DateTime? newestChangeAt;

  /// Counts of rows the writer shortened, for the preview to state.
  final Map<String, Object?> warnings;

  int get people => counts['people'] ?? 0;
  int get debts => counts['debts'] ?? 0;
  int get payments => counts['payments'] ?? 0;
  int get obligations => counts['obligations'] ?? 0;
  int get reminders => counts['reminders'] ?? 0;
  int get links => counts['debtPeople'] ?? 0;
  int get totalRecords =>
      people + debts + payments + obligations + reminders + links;
}

/// Checks a parsed backup before a single row of it is trusted.
///
/// The rules here are the ones the app already lives by, asked of a file instead
/// of a form: money is an integer number of minor units and is positive
/// ([AmountRules]), a currency is one the app knows (never a silent fallback), a
/// relation points at a row that exists, and a debt's one-value `personId` agrees
/// with its participant list. A file that fails any of them is refused whole.
abstract final class BackupValidator {
  const BackupValidator._();

  /// Validates [backup] against the app's rules.
  ///
  /// [currentSchemaVersion] is the schema this build writes. A file written by a
  /// newer one is refused rather than half-read: its rows may mean things this
  /// code does not know, and a restore that guessed would be the one operation
  /// that must never guess.
  static BackupValidation validate(
    ParsedBackup backup, {
    int currentSchemaVersion = 0,
  }) {
    final List<BackupIssue> errors = <BackupIssue>[];
    final List<BackupIssue> warnings = <BackupIssue>[];

    if (currentSchemaVersion > 0 &&
        backup.schemaVersion > currentSchemaVersion) {
      // Nothing else is checked: the shape of the data is unknown, and every
      // later rule would be guessing at it.
      return BackupValidation(
        errors: <BackupIssue>[
          BackupIssue(
            code: 'schema_too_new',
            detail: 'النسخة الاحتياطية من إصدار أحدث من التطبيق '
                '(schema ${backup.schemaVersion} مقابل $currentSchemaVersion)',
          ),
        ],
        warnings: warnings,
        preview: null,
      );
    }

    final Map<String, Map<String, Map<String, Object?>>> byTable =
        <String, Map<String, Map<String, Object?>>>{};
    for (final String table in BackupFormat.tables) {
      final Map<String, Map<String, Object?>> rows =
          <String, Map<String, Object?>>{};
      for (final Map<String, Object?> row in backup.rows(table)) {
        final String? id = _id(row);
        if (id == null) {
          errors.add(BackupIssue(
            code: 'row_without_id',
            detail: 'صف بلا معرّف في $table',
            table: table,
          ));
          continue;
        }
        if (rows.containsKey(id)) {
          errors.add(BackupIssue(
            code: 'duplicate_id',
            detail: 'المعرّف $id مكرّر',
            table: table,
            id: id,
          ));
          continue;
        }
        rows[id] = row;
      }
      byTable[table] = rows;
    }

    if (backup.countsMismatch) {
      warnings.add(BackupIssue(
        code: 'counts_mismatch',
        detail: 'عدد السجلات المعلن لا يطابق ما في الملف',
      ));
    }
    if (!backup.hasChecksum) {
      warnings.add(const BackupIssue(
        code: 'no_checksum',
        detail: 'الملف قديم ولا يحتوي على بصمة تحقق',
      ));
    }

    final Map<String, Map<String, Object?>> people = byTable['people']!;
    final Map<String, Map<String, Object?>> debts = byTable['debts']!;
    final Map<String, Map<String, Object?>> links = byTable['debtPeople']!;
    final Map<String, Map<String, Object?>> payments = byTable['payments']!;
    final Map<String, Map<String, Object?>> obligations =
        byTable['obligations']!;
    final Map<String, Map<String, Object?>> occurrences =
        byTable['obligationOccurrences']!;
    final Map<String, Map<String, Object?>> reminders = byTable['reminders']!;

    final Set<AppCurrency> currencies = <AppCurrency>{};
    final List<String> personlessDebts = <String>[];
    // The records a participant link exists for, collected once. Asking the link
    // table for each record in turn — which is what this used to do — scans the
    // whole table per row: invisible in a small ledger, quadratic in a large one.
    final Set<String> linkedDebtIds = <String>{};
    for (final Map<String, Object?> link in links.values) {
      final String? debtId = _text(link['debtId']);
      if (debtId != null) linkedDebtIds.add(debtId);
    }

    // --- People -------------------------------------------------------------
    for (final MapEntry<String, Map<String, Object?>> entry in people.entries) {
      final Map<String, Object?> row = entry.value;
      _requiredText(row, 'name', errors, 'people', entry.key);
      _instant(row, 'createdAt', errors, 'people', entry.key);
      _instant(row, 'updatedAt', errors, 'people', entry.key);
      _instant(row, 'archivedAt', errors, 'people', entry.key, optional: true);
    }

    // --- Debts --------------------------------------------------------------
    for (final MapEntry<String, Map<String, Object?>> entry in debts.entries) {
      final Map<String, Object?> row = entry.value;
      final String id = entry.key;

      final int? amount = _minorUnits(row, 'amountMinor', errors, 'debts', id);
      if (amount != null && !AmountRules.isValid(amount)) {
        errors.add(BackupIssue(
          code: 'invalid_amount',
          detail: 'المبلغ $amount ليس مبلغًا صحيحًا',
          table: 'debts',
          id: id,
        ));
      }
      final AppCurrency? currency =
          _currency(row, currencies, errors, 'debts', id);
      _enumValue(row, 'direction', DebtDirection.values, errors, 'debts', id);
      _enumValue(row, 'recurrence', RecurrenceFrequency.values, errors, 'debts',
          id);
      _leads(row, errors, 'debts', id);
      _dateOnly(row, 'issuedAt', errors, 'debts', id);
      _dateOnly(row, 'dueAt', errors, 'debts', id, optional: true);
      _instant(row, 'createdAt', errors, 'debts', id);
      _instant(row, 'updatedAt', errors, 'debts', id);
      _instant(row, 'closedAt', errors, 'debts', id, optional: true);
      _instant(row, 'archivedAt', errors, 'debts', id, optional: true);

      final String? owner = _text(row['personId']);
      if (owner != null && !people.containsKey(owner)) {
        errors.add(BackupIssue(
          code: 'missing_person',
          detail: 'الدين يشير إلى شخص غير موجود: $owner',
          table: 'debts',
          id: id,
        ));
      }
      if (owner == null && !linkedDebtIds.contains(id)) {
        personlessDebts.add(id);
      }
      if (currency != null) currencies.add(currency);
    }
    if (personlessDebts.isNotEmpty) {
      // Records written before participants were required. They are restorable —
      // the app shows them and refuses to save them without a person — so this
      // is stated, not refused.
      warnings.add(BackupIssue(
        code: 'record_without_person',
        detail: '${personlessDebts.length} دين بلا شخص (سجلات قديمة)',
      ));
    }

    // --- Participant links --------------------------------------------------
    for (final MapEntry<String, Map<String, Object?>> entry in links.entries) {
      final Map<String, Object?> row = entry.value;
      final String debtId = _text(row['debtId']) ?? '';
      final String personId = _text(row['personId']) ?? '';
      if (!debts.containsKey(debtId)) {
        errors.add(BackupIssue(
          code: 'missing_debt',
          detail: 'ارتباط يشير إلى دين غير موجود: $debtId',
          table: 'debtPeople',
          id: entry.key,
        ));
      }
      if (!people.containsKey(personId)) {
        errors.add(BackupIssue(
          code: 'missing_person',
          detail: 'ارتباط يشير إلى شخص غير موجود: $personId',
          table: 'debtPeople',
          id: entry.key,
        ));
      }
      _instant(row, 'createdAt', errors, 'debtPeople', entry.key);
    }
    _checkMirror(debts, links, errors);

    // --- Payments -----------------------------------------------------------
    for (final MapEntry<String, Map<String, Object?>> entry
        in payments.entries) {
      final Map<String, Object?> row = entry.value;
      final String id = entry.key;
      final int? amount = _minorUnits(row, 'amountMinor', errors, 'payments', id);
      if (amount != null && !AmountRules.isValid(amount)) {
        errors.add(BackupIssue(
          code: 'invalid_amount',
          detail: 'الدفعة $amount ليست مبلغًا صحيحًا',
          table: 'payments',
          id: id,
        ));
      }
      final AppCurrency? currency =
          _currency(row, currencies, errors, 'payments', id);
      if (currency != null) currencies.add(currency);
      _dateOnly(row, 'paidAt', errors, 'payments', id);
      _instant(row, 'createdAt', errors, 'payments', id);

      final String? debtId = _text(row['debtId']);
      final String? obligationId = _text(row['obligationId']);
      final String? occurrenceId = _text(row['occurrenceId']);
      if (debtId == null && obligationId == null) {
        errors.add(BackupIssue(
          code: 'orphan_payment',
          detail: 'دفعة بلا دين ولا التزام',
          table: 'payments',
          id: id,
        ));
      }
      if (debtId != null && !debts.containsKey(debtId)) {
        errors.add(BackupIssue(
          code: 'missing_debt',
          detail: 'دفعة تشير إلى دين غير موجود: $debtId',
          table: 'payments',
          id: id,
        ));
      }
      if (obligationId != null && !obligations.containsKey(obligationId)) {
        errors.add(BackupIssue(
          code: 'missing_obligation',
          detail: 'دفعة تشير إلى التزام غير موجود: $obligationId',
          table: 'payments',
          id: id,
        ));
      }
      if (occurrenceId != null && !occurrences.containsKey(occurrenceId)) {
        errors.add(BackupIssue(
          code: 'missing_occurrence',
          detail: 'دفعة تشير إلى فترة غير موجودة: $occurrenceId',
          table: 'payments',
          id: id,
        ));
      }
    }

    // --- Obligations and their periods --------------------------------------
    for (final MapEntry<String, Map<String, Object?>> entry
        in obligations.entries) {
      final Map<String, Object?> row = entry.value;
      final String id = entry.key;
      _requiredText(row, 'name', errors, 'obligations', id);
      final int? amount =
          _minorUnits(row, 'amountMinor', errors, 'obligations', id);
      if (amount != null && !AmountRules.isValid(amount)) {
        errors.add(BackupIssue(
          code: 'invalid_amount',
          detail: 'الالتزام $amount ليس مبلغًا صحيحًا',
          table: 'obligations',
          id: id,
        ));
      }
      final AppCurrency? currency =
          _currency(row, currencies, errors, 'obligations', id);
      if (currency != null) currencies.add(currency);
      _enumValue(row, 'category', ObligationCategory.values, errors,
          'obligations', id);
      _enumValue(row, 'frequency', RecurrenceFrequency.values, errors,
          'obligations', id);
      _leads(row, errors, 'obligations', id);
      _dateOnly(row, 'startAt', errors, 'obligations', id);
      _dateOnly(row, 'nextDueAt', errors, 'obligations', id);
      _dateOnly(row, 'endAt', errors, 'obligations', id, optional: true);
      _instant(row, 'createdAt', errors, 'obligations', id);
      _instant(row, 'updatedAt', errors, 'obligations', id);
      _instant(row, 'archivedAt', errors, 'obligations', id, optional: true);
    }

    final Set<String> periodKeys = <String>{};
    for (final MapEntry<String, Map<String, Object?>> entry
        in occurrences.entries) {
      final Map<String, Object?> row = entry.value;
      final String id = entry.key;
      final String obligationId = _text(row['obligationId']) ?? '';
      if (!obligations.containsKey(obligationId)) {
        errors.add(BackupIssue(
          code: 'missing_obligation',
          detail: 'فترة تشير إلى التزام غير موجود: $obligationId',
          table: 'obligationOccurrences',
          id: id,
        ));
      }
      final String? periodKey = _text(row['periodKey']);
      if (periodKey == null) {
        errors.add(BackupIssue(
          code: 'missing_field',
          detail: 'فترة بلا مفتاح',
          table: 'obligationOccurrences',
          id: id,
        ));
      } else if (!periodKeys.add('$obligationId/$periodKey')) {
        errors.add(BackupIssue(
          code: 'duplicate_period',
          detail: 'فترة مكرّرة: $periodKey',
          table: 'obligationOccurrences',
          id: id,
        ));
      }
      final int? amount =
          _minorUnits(row, 'amountMinor', errors, 'obligationOccurrences', id);
      if (amount != null && !AmountRules.isValid(amount)) {
        errors.add(BackupIssue(
          code: 'invalid_amount',
          detail: 'مبلغ الفترة $amount غير صحيح',
          table: 'obligationOccurrences',
          id: id,
        ));
      }
      // A period has no currency column of its own: it is paid in the currency
      // of the commitment it belongs to, which is validated above.
      _enumValue(row, 'status', ObligationStatus.values, errors,
          'obligationOccurrences', id);
      _dateOnly(row, 'dueAt', errors, 'obligationOccurrences', id);
    }

    // --- Reminders ----------------------------------------------------------
    for (final MapEntry<String, Map<String, Object?>> entry
        in reminders.entries) {
      final Map<String, Object?> row = entry.value;
      final String id = entry.key;
      _requiredText(row, 'title', errors, 'reminders', id);
      _dateOnly(row, 'dueAt', errors, 'reminders', id);
      _enumValue(row, 'status', ReminderStatus.values, errors, 'reminders', id);
      final RelatedEntityType? related = _enumValue<RelatedEntityType>(
        row,
        'relatedType',
        RelatedEntityType.values,
        errors,
        'reminders',
        id,
      );
      final String? relatedId = _text(row['relatedId']);
      if (relatedId != null) {
        if (related == RelatedEntityType.debt && !debts.containsKey(relatedId)) {
          errors.add(BackupIssue(
            code: 'missing_debt',
            detail: 'تذكير يشير إلى دين غير موجود: $relatedId',
            table: 'reminders',
            id: id,
          ));
        }
        if (related == RelatedEntityType.obligation &&
            !obligations.containsKey(relatedId)) {
          errors.add(BackupIssue(
            code: 'missing_obligation',
            detail: 'تذكير يشير إلى التزام غير موجود: $relatedId',
            table: 'reminders',
            id: id,
          ));
        }
      }
    }

    // --- Settings -----------------------------------------------------------
    final List<BackupIssue> settingWarnings =
        _settings(backup.settings, warnings);
    warnings.addAll(settingWarnings);

    if (errors.isNotEmpty) {
      return BackupValidation(
        errors: errors,
        warnings: warnings,
        preview: null,
      );
    }

    return BackupValidation(
      errors: errors,
      warnings: warnings,
      preview: _preview(backup, byTable, currencies),
    );
  }

  /// The one-value `person_id` must agree with the participant list.
  ///
  /// It is what payments, notifications and the person-deletion rule read, so a
  /// file where the two disagree would restore a record that behaves one way in
  /// one screen and another way in the next.
  static void _checkMirror(
    Map<String, Map<String, Object?>> debts,
    Map<String, Map<String, Object?>> links,
    List<BackupIssue> errors,
  ) {
    final Map<String, List<Map<String, Object?>>> byDebt =
        <String, List<Map<String, Object?>>>{};
    for (final Map<String, Object?> link in links.values) {
      final String? debtId = _text(link['debtId']);
      if (debtId == null) continue;
      byDebt.putIfAbsent(debtId, () => <Map<String, Object?>>[]).add(link);
    }
    for (final MapEntry<String, List<Map<String, Object?>>> entry
        in byDebt.entries) {
      final List<Map<String, Object?>> ordered =
          List<Map<String, Object?>>.of(entry.value)
            ..sort((Map<String, Object?> a, Map<String, Object?> b) =>
                _int(a['position']).compareTo(_int(b['position'])));
      final Map<String, Object?>? debt = debts[entry.key];
      if (debt == null) continue;
      if (_text(debt['personId']) != _text(ordered.first['personId'])) {
        errors.add(BackupIssue(
          code: 'mirror_mismatch',
          detail: 'الدين ${entry.key}: الشخص الأساسي لا يطابق أول ارتباط',
          table: 'debts',
          id: entry.key,
        ));
      }
    }
  }

  static BackupPreview _preview(
    ParsedBackup backup,
    Map<String, Map<String, Map<String, Object?>>> byTable,
    Set<AppCurrency> currencies,
  ) {
    DateTime? oldest;
    DateTime? newest;
    for (final Map<String, Map<String, Object?>> table in byTable.values) {
      for (final Map<String, Object?> row in table.values) {
        final DateTime? created = _instantOrNull(row['createdAt']) ??
            _dateOnlyOrNull(row['issuedAt']) ??
            _dateOnlyOrNull(row['paidAt']);
        final DateTime? changed = _instantOrNull(row['updatedAt']) ?? created;
        if (created != null &&
            (oldest == null || created.isBefore(oldest))) {
          oldest = created;
        }
        if (changed != null && (newest == null || changed.isAfter(newest))) {
          newest = changed;
        }
      }
    }

    int shared = 0;
    final Map<String, int> perDebt = <String, int>{};
    for (final Map<String, Object?> link in byTable['debtPeople']!.values) {
      final String? debtId = _text(link['debtId']);
      if (debtId != null) perDebt[debtId] = (perDebt[debtId] ?? 0) + 1;
    }
    for (final int count in perDebt.values) {
      if (count > 1) shared++;
    }

    final List<AppCurrency> ordered = currencies.toList()
      ..sort((AppCurrency a, AppCurrency b) => a.code.compareTo(b.code));

    return BackupPreview(
      createdAt: backup.createdAt,
      appVersion: backup.appVersion,
      schemaVersion: backup.schemaVersion,
      counts: backup.actualCounts,
      currencies: ordered,
      sharedRecords: shared,
      oldestRecordAt: oldest,
      newestChangeAt: newest,
      warnings: backup.truncated,
    );
  }

  static List<BackupIssue> _settings(
    Map<String, Object?> settings,
    List<BackupIssue> warnings,
  ) {
    final List<BackupIssue> out = <BackupIssue>[];
    if (settings.isEmpty) {
      out.add(const BackupIssue(
        code: 'no_settings',
        detail: 'الملف بلا إعدادات؛ ستُترك إعدادات الجهاز كما هي',
      ));
      return out;
    }
    // Settings are preferences, not records: an unreadable one is skipped and
    // reported, because refusing a whole ledger over a theme name would be the
    // wrong trade.
    for (final MapEntry<String, Object?> entry in settings.entries) {
      if (entry.key == 'id') continue;
      if (entry.value == null) continue;
      final Object value = entry.value!;
      if (value is! String && value is! int && value is! bool) {
        out.add(BackupIssue(
          code: 'unreadable_setting',
          detail: 'إعداد غير مقروء: ${entry.key}',
        ));
      }
    }
    return out;
  }

  // --- Field readers --------------------------------------------------------

  static String? _id(Map<String, Object?> row) {
    final String? id = _text(row['id']);
    return (id == null || id.isEmpty) ? null : id;
  }

  static String? _text(Object? value) {
    if (value is String) return value;
    if (value == null) return null;
    return null;
  }

  static int _int(Object? value) => value is int ? value : 0;

  static void _requiredText(
    Map<String, Object?> row,
    String key,
    List<BackupIssue> errors,
    String table,
    String id,
  ) {
    final String? value = _text(row[key]);
    if (value == null || value.trim().isEmpty) {
      errors.add(BackupIssue(
        code: 'missing_field',
        detail: 'حقل مطلوب مفقود: $key',
        table: table,
        id: id,
      ));
    }
  }

  /// Money must be an integer count of minor units.
  ///
  /// A `double` here — from a hand-edited file or another tool — is refused
  /// rather than rounded: `1500.50` becoming `1500.499999` is exactly the
  /// corruption this rule exists to prevent.
  static int? _minorUnits(
    Map<String, Object?> row,
    String key,
    List<BackupIssue> errors,
    String table,
    String id,
  ) {
    final Object? value = row[key];
    if (value is int) return value;
    errors.add(BackupIssue(
      code: value is double ? 'fractional_amount' : 'missing_field',
      detail: value is double
          ? 'المبلغ $value كسر عشري؛ يجب أن يكون عددًا صحيحًا من الوحدات الصغرى'
          : 'المبلغ مفقود',
      table: table,
      id: id,
    ));
    return null;
  }

  static AppCurrency? _currency(
    Map<String, Object?> row,
    Set<AppCurrency> seen,
    List<BackupIssue> errors,
    String table,
    String id,
  ) {
    final String? code = _text(row['currency']);
    if (code == null) {
      errors.add(BackupIssue(
        code: 'missing_field',
        detail: 'العملة مفقودة',
        table: table,
        id: id,
      ));
      return null;
    }
    for (final AppCurrency currency in AppCurrency.values) {
      if (currency.code == code) {
        seen.add(currency);
        return currency;
      }
    }
    errors.add(BackupIssue(
      code: 'unknown_currency',
      detail: 'عملة غير معروفة: $code',
      table: table,
      id: id,
    ));
    return null;
  }

  static T? _enumValue<T extends Enum>(
    Map<String, Object?> row,
    String key,
    List<T> values,
    List<BackupIssue> errors,
    String table,
    String id,
  ) {
    final String? name = _text(row[key]);
    for (final T value in values) {
      if (value.name == name) return value;
    }
    errors.add(BackupIssue(
      code: 'unknown_value',
      detail: '$key = $name غير معروف',
      table: table,
      id: id,
    ));
    return null;
  }

  static void _leads(
    Map<String, Object?> row,
    List<BackupIssue> errors,
    String table,
    String id,
  ) {
    final Object? value = row['reminderLeads'];
    if (value == null) return;
    if (value is! List) {
      errors.add(BackupIssue(
        code: 'unreadable_field',
        detail: 'مهل التذكير ليست قائمة',
        table: table,
        id: id,
      ));
      return;
    }
    for (final Object? lead in value) {
      if (lead is! int || ReminderLead.fromDays(lead).isNone) {
        errors.add(BackupIssue(
          code: 'unknown_lead',
          detail: 'مهلة تذكير غير معروفة: $lead',
          table: table,
          id: id,
        ));
      }
    }
  }

  static void _dateOnly(
    Map<String, Object?> row,
    String key,
    List<BackupIssue> errors,
    String table,
    String id, {
    bool optional = false,
  }) {
    final Object? value = row[key];
    if (value == null) {
      if (!optional) {
        errors.add(BackupIssue(
          code: 'missing_field',
          detail: 'حقل مطلوب مفقود: $key',
          table: table,
          id: id,
        ));
      }
      return;
    }
    if (_dateOnlyOrNull(value) == null) {
      errors.add(BackupIssue(
        code: 'unreadable_date',
        detail: '$key = $value ليس تاريخًا صحيحًا',
        table: table,
        id: id,
      ));
    }
  }

  static void _instant(
    Map<String, Object?> row,
    String key,
    List<BackupIssue> errors,
    String table,
    String id, {
    bool optional = false,
  }) {
    final Object? value = row[key];
    if (value == null) {
      if (!optional) {
        errors.add(BackupIssue(
          code: 'missing_field',
          detail: 'حقل مطلوب مفقود: $key',
          table: table,
          id: id,
        ));
      }
      return;
    }
    if (_instantOrNull(value) == null) {
      errors.add(BackupIssue(
        code: 'unreadable_date',
        detail: '$key = $value ليس وقتًا صحيحًا',
        table: table,
        id: id,
      ));
    }
  }

  static DateTime? _dateOnlyOrNull(Object? value) {
    if (value is! String) return null;
    final RegExpMatch? match =
        RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final int year = int.parse(match.group(1)!);
    final int month = int.parse(match.group(2)!);
    final int day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  /// An instant read out of a backup file, in the phone's own time.
  ///
  /// The file stores instants as UTC (`…Z`) and the app parses the envelope's
  /// own `createdAt` with `.toLocal()`, so the two must be read the same way or
  /// the same moment appears as two different days. Found by reading the phone:
  /// a copy written at 00:45 local was offered as `نسخة احتياطية من 28 سبتمبر`
  /// and, four lines below it, `آخر تغيير في النسخة: 27 سبتمبر` — because the
  /// rows' timestamps were still in UTC (19:15 the previous evening) while the
  /// envelope's had been converted. Anyone told their newest change was the day
  /// before the copy they are holding has been told something untrue.
  static DateTime? _instantOrNull(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
