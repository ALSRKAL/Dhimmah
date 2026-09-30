import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/backup/backup_codec.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// A backup that comes back saying exactly what it left with.
///
/// The bar for this file is the one the whole feature stands on: after
/// **backup → restore into an empty database**, every table must hold the same
/// rows, field for field, relationship for relationship, minor unit for minor
/// unit. Anything less is a file that looks like a backup and is not one.
void main() {
  late Directory dir;
  late AppDatabase db;
  late FakeNotificationGateway platform;
  late LedgerService service;
  late BackupService backups;
  late BackupRestoreService restores;

  final DateTime today = dateOnly(DateTime.now());
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-backup-test');
    db = AppDatabase.memory();
    platform = FakeNotificationGateway();
    service = buildService(
      db,
      notifications: NotificationService(gateway: platform),
    );
    await service.notifications.initialize(localizations: l10n);
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => DateTime(2026, 9, 25, 10, 35),
      directory: dir,
    );
    restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: () async {
        await service.ensureOccurrences();
        await service.refreshNotifications();
      },
    );
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Map<String, Object?> sortedRow(Map<String, Object?> row) {
    final List<String> keys = row.keys.toList()..sort();
    return <String, Object?>{for (final String key in keys) key: row[key]};
  }

  /// Every row of every table, as the codec writes them, keyed by id.
  ///
  /// This is the comparison basis for a round trip: it is the *whole* database,
  /// not the entity-level view a screen sees, so a column the codec forgot shows
  /// up as a difference rather than as silence.
  Future<Map<String, Map<String, String>>> state() async {
    final Map<String, List<Map<String, Object?>>> tables =
        <String, List<Map<String, Object?>>>{
      'people': (await db.peopleDao.getAll()).map(BackupCodec.person).toList(),
      'debts': (await db.debtsDao.getAll()).map(BackupCodec.debt).toList(),
      'debtPeople':
          (await db.debtsDao.allParticipantRows()).map(BackupCodec.link).toList(),
      'payments':
          (await db.debtsDao.getAllPayments()).map(BackupCodec.payment).toList(),
      'obligations':
          (await db.obligationsDao.getAll()).map(BackupCodec.obligation).toList(),
      'obligationOccurrences': (await db.obligationsDao.getOccurrences())
          .map(BackupCodec.occurrence)
          .toList(),
      'reminders':
          (await db.remindersDao.getAll()).map(BackupCodec.reminder).toList(),
      'monthlySummaries': (await db.activityDao.getAllSummaries())
          .map(BackupCodec.summary)
          .toList(),
      'activity':
          (await db.activityDao.getAll()).map(BackupCodec.activity).toList(),
    };

    return <String, Map<String, String>>{
      for (final MapEntry<String, List<Map<String, Object?>>> entry
          in tables.entries)
        entry.key: <String, String>{
          for (final Map<String, Object?> row in entry.value)
            '${row['id'] ?? '${row['debtId']}:${row['personId']}'}':
                jsonEncode(sortedRow(row)),
        },
    };
  }

  /// Empties the ledger without touching the settings row, so a restore is
  /// proven to rebuild the data rather than to have found it already there.
  Future<void> wipe() async {
    await db.transaction(() async {
      await db.delete(db.activityEntries).go();
      await db.delete(db.monthlySummaries).go();
      await db.delete(db.reminders).go();
      await db.delete(db.obligations).go();
      await db.delete(db.payments).go();
      await db.delete(db.debtPeople).go();
      await db.delete(db.debts).go();
      await db.delete(db.people).go();
    });
  }

  // --- The datasets ---------------------------------------------------------

  /// A: one person, one debt, one payment.
  Future<void> datasetA() async {
    final Person ahmed = await service.createPerson(
      const PersonDraft(name: 'أحمد'),
    );
    final debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض',
        principalMinor: 150050,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -10),
        dueAt: addDays(today, 5),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );
    await service.recordPayment(
      debt.id,
      PaymentDraft(amountMinor: 50000, paidAt: today, note: 'دفعة أولى'),
    );
  }

  /// B and C: several people, one of them shared, one currency each.
  Future<void> datasetBC() async {
    final Person ahmed = await service.createPerson(
      const PersonDraft(name: 'أحمد', phone: '+967 771 234 567'),
    );
    final Person khalid = await service.createPerson(
      const PersonDraft(name: 'خالد العلي', note: 'جار'),
    );
    final Person maryam = await service.createPerson(
      const PersonDraft(name: 'Maryam Hassan'),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id, khalid.id, maryam.id],
        title: 'فاتورة العشاء',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 3),
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[khalid.id],
        title: 'سلفة',
        principalMinor: 200000,
        currency: AppCurrency.usd,
        issuedAt: today,
      ),
    );
  }

  /// D: a recurring commitment with its periods, one of them paid.
  Future<void> datasetD() async {
    await service.createObligation(
      ObligationDraft(
        name: 'الإيجار',
        category: ObligationCategory.housing,
        amountMinor: 200000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        reminderLeads: const <ReminderLead>[ReminderLead.threeDaysBefore],
        note: 'شهريًا',
      ),
    );
    await service.ensureOccurrences();
    final List<ObligationOccurrence> periods =
        await service.obligations.allOccurrences();
    final List<Obligation> all = await service.obligations.getAll();
    for (final ObligationOccurrence period in periods.take(1)) {
      await service.markObligationPaid(
        ObligationInstance(obligation: all.first, occurrence: period),
      );
    }
  }

  /// The whole shape in one ledger: every table, both scripts, two currencies,
  /// a shared record, a recurring commitment, a standalone reminder.
  Future<void> datasetEverything() async {
    await datasetA();
    await datasetBC();
    await datasetD();
    await service.createReminder(
      ReminderDraft(title: 'اتصل بالمحاسب', dueAt: addDays(today, 2)),
    );
  }

  // --- Tests ----------------------------------------------------------------

  test('every table survives backup → wipe → restore, field for field',
      () async {
    await datasetEverything();
    final Map<String, Map<String, String>> before = await state();

    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    await wipe();
    expect(
      (await state()).values.fold<int>(0, (int a, Map<String, String> b) => a + b.length),
      0,
      reason: 'the ledger is empty, so a restore has to rebuild it',
    );

    final BackupValidationResult validation = await _inspect(backups, written.file);
    expect(validation.isUsable, isTrue, reason: validation.errors.join('\n'));

    final RestoreReport report = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );

    expect(report.counts['people'], before['people']!.length);
    expect(await state(), before, reason: 'the same rows, field for field');
  });

  test('money comes back as the same integer minor units', () async {
    await service.createPerson(const PersonDraft(name: 'أحمد'));
    final Person person = (await service.people.getAll()).single;
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'كسر',
        principalMinor: 150050,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );

    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final String raw = await written.file.readAsString();
    expect(
      raw.contains('150050'),
      isTrue,
      reason: 'minor units are written as integers, never as 1500.50',
    );
    expect(
      RegExp(r'"amountMinor": \d+\.\d').hasMatch(raw),
      isFalse,
      reason: 'no amount is ever a decimal in the file',
    );

    await wipe();
    await restores.apply(backup: written.backup, mode: RestoreMode.replace);
    final DebtRow debt = (await db.debtsDao.getAll()).single;
    expect(debt.principalMinor, 150050);
  });

  test('a shared record keeps one amount and all three people, in order',
      () async {
    await datasetBC();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    await wipe();
    await restores.apply(backup: written.backup, mode: RestoreMode.replace);

    final List<DebtRow> debts = await db.debtsDao.getAll();
    expect(debts, hasLength(2), reason: 'two records, not one per person');
    final DebtRow shared = debts.firstWhere(
      (DebtRow row) => row.title == 'فاتورة العشاء',
    );
    expect(shared.principalMinor, 150000);
    expect(
      await db.debtsDao.participantsFor(shared.id),
      hasLength(3),
      reason: 'the links come back with the record',
    );
    expect(
      shared.personId,
      (await db.debtsDao.participantsFor(shared.id)).first,
      reason: 'the one-value column still agrees with the first link',
    );
  });

  test('restoring the same file twice changes nothing the second time',
      () async {
    await datasetEverything();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    await wipe();

    final RestoreReport first = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );
    final Map<String, Map<String, String>> afterFirst = await state();

    final RestoreReport second = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );

    expect(second.inserted, first.inserted);
    expect(await state(), afterFirst, reason: 'a replace of the same file');
  });

  test('merging the same file again inserts nothing', () async {
    await datasetEverything();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    final RestoreReport first = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.merge,
    );
    final Map<String, Map<String, String>> afterFirst = await state();

    final RestoreReport second = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.merge,
    );

    expect(
      second.inserted,
      0,
      reason: 'every row is already there, so an import is idempotent',
    );
    expect(second.replaced, 0);
    expect(second.skipped, first.inserted + first.skipped);
    expect(await state(), afterFirst);
  });

  test('merging into a ledger that already has data adds only what is new',
      () async {
    // Phone A: Ahmed and a debt.
    final Person ahmed = await service.createPerson(
      const PersonDraft(name: 'أحمد'),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
    final ({File file, ParsedBackup backup}) fromA =
        await backups.create(kind: BackupKind.manual);

    // Phone B: the same person and debt, plus one more.
    final Person maryam = await service.createPerson(
      const PersonDraft(name: 'مريم'),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[maryam.id],
        title: 'سلفة',
        principalMinor: 70000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );

    final RestoreReport report = await restores.apply(
      backup: fromA.backup,
      mode: RestoreMode.merge,
    );

    expect(report.inserted, 0, reason: 'both sides already had these rows');
    expect(report.conflicts, isEmpty);
    expect(await db.peopleDao.getAll(), hasLength(2), reason: 'no duplicate');
    expect(await db.debtsDao.getAll(), hasLength(2));
  });

  test('an older version of a record is reported, never applied', () async {
    final Person ahmed = await service.createPerson(
      const PersonDraft(name: 'أحمد'),
    );
    final debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
    final ({File file, ParsedBackup backup}) old =
        await backups.create(kind: BackupKind.manual);

    // The ledger moves on: the amount is corrected, which makes the record
    // newer than the copy in the file.
    await service.updateDebt(
      debt.id,
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض',
        principalMinor: 250000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );

    final RestoreReport report = await restores.apply(
      backup: old.backup,
      mode: RestoreMode.merge,
    );

    expect(
      report.conflicts.map((BackupIssue i) => i.id),
      contains(debt.id),
      reason: 'the file is older, so the edit here is kept and reported',
    );
    expect((await db.debtsDao.getAll()).single.principalMinor, 250000);
  });

  test('a backup taken before the restore is left behind for going back',
      () async {
    await datasetA();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    await wipe();
    await datasetBC();

    final RestoreReport report = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );

    expect(report.safetyBackupPath, isNotNull);
    final List<BackupFileInfo> all = await backups.list();
    final BackupFileInfo safety = all.firstWhere(
      (BackupFileInfo info) => info.kind == BackupKind.safety,
    );
    // And it really holds the state that was replaced.
    final ParsedBackup safetyBackup = await backups.read(safety.path);
    expect(safetyBackup.rows('people'), hasLength(3));
  });

  test('settings travel, but the lock does not', () async {
    await datasetA();
    await db.settingsDao.write(
      (AppSettings.initial.copyWith(
        languagePreference: LanguagePreference.english,
        themeMode: AppThemeMode.dark,
        defaultCurrency: AppCurrency.usd,
        dueSoonWindowDays: 14,
        lockEnabled: true,
        notificationHour: 7,
      )).toCompanion(),
    );
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    await db.settingsDao.write(
      (AppSettings.initial).toCompanion(),
    );
    final RestoreReport report = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );
    expect(report.counts['people'], 1);

    final AppSettings now = (await db.settingsDao.get())!.toEntity();
    expect(now.languagePreference, LanguagePreference.english);
    expect(now.themeMode, AppThemeMode.dark);
    expect(now.defaultCurrency, AppCurrency.usd);
    expect(now.dueSoonWindowDays, 14);
    expect(now.notificationHour, 7);
    expect(
      now.lockEnabled,
      isFalse,
      reason: 'the PIN that would satisfy a lock lives in the keystore and '
          'never travels, so the flag must not come back on its own',
    );
  });

  test('obligations come back with their periods and their recurrence',
      () async {
    await datasetD();
    final Map<String, Map<String, String>> before = await state();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    await wipe();
    await restores.apply(backup: written.backup, mode: RestoreMode.replace);

    final Map<String, Map<String, String>> after = await state();
    expect(after['obligations'], before['obligations']);
    expect(after['obligationOccurrences'], before['obligationOccurrences']);
    final ObligationRow obligation = (await db.obligationsDao.getAll()).single;
    expect(obligation.frequency, RecurrenceFrequency.monthly);
    expect(obligation.reminderLeads, <ReminderLead>[ReminderLead.threeDaysBefore]);
  });

  test('notifications are rebuilt from the restored records', () async {
    await datasetA();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    await wipe();
    platform.loseEverythingOnReboot();

    await restores.apply(backup: written.backup, mode: RestoreMode.replace);

    expect(
      // The month-end summary is armed in the last days of every month, and it
      // is the ledger's, not a record's.
      platform.armedPayloads.where((String p) => !p.startsWith('report:')),
      hasLength(1),
      reason: 'one record with a reminder, so one payload — the old schedule '
          'is never consulted',
    );
  });

  test('a file from the previous version does not pin the seeded Arabic',
      () async {
    await datasetA();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);

    // The file exactly as the previous version wrote it: schema 4, and the
    // Arabic every install of that version was seeded with.
    final Map<String, Object?> envelope =
        jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
    final Map<String, Object?> payload =
        envelope['payload']! as Map<String, Object?>;
    payload['schemaVersion'] = BackupCodec.languagePreferenceSchema - 1;
    ((payload['data']! as Map<String, Object?>)['settings']!
        as Map<String, Object?>)['language'] = 'arabic';
    envelope['checksum'] = BackupFormat.checksumOf(payload);
    final File old = File('${dir.path}/previous-version.dhimmah');
    await old.writeAsString(jsonEncode(envelope));

    await db.settingsDao.write(AppSettings.initial.toCompanion());
    await restores.apply(
      backup: await backups.read(old.path),
      mode: RestoreMode.replace,
      takeSafetySnapshot: false,
    );

    expect(
      (await db.settingsDao.get())!.languagePreference,
      LanguagePreference.system,
      reason: 'the app still follows the phone after restoring a file the '
          'previous version wrote',
    );
    expect((await db.peopleDao.getAll()), isNotEmpty, reason: 'and the records came back');
  });

  test('a file from a newer schema is refused, not guessed at', () async {
    await datasetA();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final Map<String, Object?> envelope =
        jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
    final Map<String, Object?> payload =
        envelope['payload']! as Map<String, Object?>;
    payload['schemaVersion'] = 99;
    envelope['checksum'] = BackupFormat.checksumOf(payload);
    final File tampered = File('${dir.path}/future.dhimmah');
    await tampered.writeAsString(jsonEncode(envelope));

    final BackupValidation verdict = await backups.inspect(tampered.path);
    expect(verdict.isUsable, isFalse);
    expect(
      verdict.errors.first.code,
      'schema_too_new',
      reason: 'a file from a newer app is refused, never half-read',
    );
  });
}

/// Validates a file, surfacing the errors in the failure message.
Future<BackupValidationResult> _inspect(BackupService backups, File file) async {
  final result = await backups.inspect(file.path);
  return BackupValidationResult(
    isUsable: result.isUsable,
    errors: <String>[for (final BackupIssue issue in result.errors) '${issue.code}: ${issue.detail}'],
  );
}

/// A small carrier so the test's assertion reads clearly.
class BackupValidationResult {
  const BackupValidationResult({required this.isUsable, required this.errors});

  final bool isUsable;
  final List<String> errors;
}
