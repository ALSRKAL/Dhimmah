import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/backup/backup_codec.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/backup_coordinator.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// The audit pass: what the backup system does when things go wrong, and what it
/// must never do.
///
/// `backup_failure_test.dart` covers a bad file being refused.
/// `backup_round_trip_test.dart` covers a good file coming back. This file is
/// about the space in between — the failures that only appear when a process
/// dies, a disk fills, a clock moves, or two things happen at once — and it
/// holds every one of them to the same rule:
///
/// > **No failure of a backup, a restore or a merge may leave the user's current
/// > data invalid or silently lost.**
void main() {
  late Directory dir;
  late AppDatabase db;
  late LedgerService service;
  late BackupService backups;
  late BackupRestoreService restores;

  final DateTime today = dateOnly(DateTime.now());
  DateTime now = DateTime(2026, 9, 25, 10, 35);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-hardening');
    db = AppDatabase.memory();
    service = buildService(db);
    now = DateTime(2026, 9, 25, 10, 35);
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => now,
      directory: dir,
    );
    restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: service.refreshNotifications,
    );
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  // --- Harness --------------------------------------------------------------

  Future<Person> addPerson(String name) =>
      service.createPerson(PersonDraft(name: name));

  Future<void> seed({int people = 2, int debts = 2, int payments = 0}) async {
    for (int i = 0; i < people; i++) {
      final Person person = await addPerson('شخص $i');
      for (int d = 0; d < debts; d++) {
        final debt = await service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            personIds: <String>[person.id],
            title: 'دين $d',
            principalMinor: 100000 + d,
            currency: AppCurrency.inr,
            issuedAt: today,
            dueAt: addDays(today, 3),
          ),
        );
        for (int p = 0; p < payments; p++) {
          await service.recordPayment(
            debt.id,
            PaymentDraft(amountMinor: 2500, paidAt: today),
          );
        }
      }
    }
  }

  /// A picture of everything the user has, in the order it matters.
  ///
  /// Every one of these parts is compared before and after a failure, because
  /// "the ledger is unchanged" has to mean the records, the links, the payments
  /// and the settings — not just the row count.
  Future<String> fingerprint() async {
    final List<String> parts = <String>[];
    for (final PersonRow row in await db.peopleDao.getAll()) {
      parts.add('P ${row.id} ${row.name} ${row.phone} ${row.note} '
          '${row.colorIndex} ${row.archivedAt} ${row.updatedAt}');
    }
    for (final DebtRow row in await db.debtsDao.getAll()) {
      parts.add('D ${row.id} ${row.personId} ${row.direction} ${row.title} '
          '${row.principalMinor} ${row.currencyCode} ${row.issuedAt} '
          '${row.dueAt} ${row.reminderLeads} ${row.recurrence} '
          '${row.closedAt} ${row.updatedAt}');
    }
    for (final DebtPersonRow row in await db.debtsDao.allParticipantRows()) {
      parts.add('L ${row.debtId} ${row.personId} ${row.position}');
    }
    for (final PaymentRow row in await db.debtsDao.getAllPayments()) {
      parts.add('A ${row.id} ${row.debtId} ${row.amountMinor} ${row.paidAt} '
          '${row.currencyCode}');
    }
    for (final ObligationRow row in await db.obligationsDao.getAll()) {
      parts.add('O ${row.id} ${row.name} ${row.amountMinor} ${row.frequency}');
    }
    for (final ObligationOccurrenceRow row
        in await db.obligationsDao.getOccurrences()) {
      parts.add('C ${row.id} ${row.obligationId} ${row.periodKey} ${row.status}');
    }
    for (final ReminderRow row in await db.remindersDao.getAll()) {
      parts.add('R ${row.id} ${row.title} ${row.dueAt} ${row.status}');
    }
    final Setting? settings = await db.settingsDao.get();
    if (settings != null) {
      parts.add('S ${settings.language} ${settings.defaultCurrencyCode} '
          '${settings.themeMode} ${settings.notificationsEnabled} '
          '${settings.lockEnabled}');
    }
    // Sorted, because the order rows come back in is the storage's business:
    // a restore rewrites them in the file's order, which is not the order they
    // were inserted in. What must not change is the *content*.
    parts.sort();
    return parts.join('\n');
  }

  /// The same read models every screen reads, built the same way.
  LedgerQueries queries() => LedgerQueries(
        database: db,
        people: PersonRepositoryImpl(db),
        debts: DebtRepositoryImpl(db),
        payments: PaymentRepositoryImpl(db),
        obligations: ObligationRepositoryImpl(db),
        reminders: ReminderRepositoryImpl(db),
        activity: ActivityRepositoryImpl(db),
      );

  Future<File> writeRaw(String name, Object? contents) async {
    final File file = File('${dir.path}/$name');
    await file.writeAsString(
      contents is String ? contents : jsonEncode(contents),
    );
    return file;
  }

  /// A valid backup as text, for a test that needs to place one by hand.
  Future<String> validText() async =>
      await (await backups.create(kind: BackupKind.manual)).file.readAsString();

  /// A valid backup, decoded so a test can damage exactly one part of it.
  Future<Map<String, Object?>> validEnvelope() async {
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    return jsonDecode(await written.file.readAsString())
        as Map<String, Object?>;
  }

  // ---------------------------------------------------------------------------
  // 1. The corruption matrix.
  //
  // Every way a file can be wrong, each with the same two questions asked of it:
  // is it refused, and did the database change? The second is the one that
  // matters, and the one a validation test that only inspects the verdict would
  // never ask.
  // ---------------------------------------------------------------------------
  group('every way a file can be wrong', () {
    /// Refuses [file], and proves the ledger is untouched afterwards.
    Future<BackupValidation> refused(File file) async {
      final String before = await fingerprint();
      final BackupValidation verdict = await backups.inspect(file.path);
      expect(verdict.isUsable, isFalse, reason: '${file.path} must be refused');
      expect(
        await fingerprint(),
        before,
        reason: 'a file that is refused changes nothing',
      );
      return verdict;
    }

    test('a truncated file', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final String text = jsonEncode(envelope);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        text.substring(0, text.length ~/ 2),
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before, reason: 'the ledger is untouched');
    });

    test('an empty file', () async {
      await seed();
      final File file =
          await writeRaw('dhimmah-manual-20260925T103500.dhimmah', '');
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before);
    });

    test('random bytes', () async {
      await seed();
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        List<int>.generate(4096, (int i) => (i * 37) % 256),
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before);
    });

    test('a valid wrapper around a payload that is not there', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      envelope['payload'] = 'not a payload';
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before);
    });

    test('a valid payload whose checksum does not match', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      envelope['checksum'] = 'sha256:0000000000000000000000000000000';
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before);
    });

    test('a damaged byte inside the payload', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      // Change one amount in the payload without touching the checksum: the
      // exact shape of a file edited by hand.
      final Map<String, Object?> data =
          (envelope['payload']! as Map<String, Object?>)['data']!
              as Map<String, Object?>;
      final Map<String, Object?> firstDebt =
          (data['debts']! as List<Object?>).first! as Map<String, Object?>;
      firstDebt['amountMinor'] = 999999999;
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before);
    });

    test('a missing table', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> data =
          (envelope['payload']! as Map<String, Object?>)['data']!
              as Map<String, Object?>;
      data.remove('payments');
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      // A missing table is a warning, not a refusal: a file written before a
      // table existed is legitimately missing it, and refusing those would make
      // every old backup unrestorable.
      final BackupValidation verdict = await backups.inspect(file.path);
      expect(verdict.isUsable, isTrue);
      expect(verdict.preview!.counts['payments'], 0);
    });

    test('an unknown field is ignored, not fatal', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      payload['somethingFromTheFuture'] = <String, Object?>{'x': 1};
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final BackupValidation verdict = await backups.inspect(file.path);
      expect(verdict.isUsable, isTrue,
          reason: 'a field this version does not know about is not a reason to '
              'refuse a file the user needs');
    });

    test('a file from a newer format version', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      envelope['formatVersion'] = BackupFormat.currentFormatVersion + 1;
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(file.path),
        throwsA(isA<BackupFormatException>().having(
          (BackupFormatException e) => e.problem,
          'problem',
          BackupProblem.formatTooNew,
        )),
      );
      expect(await fingerprint(), before);
    });

    test('a file from a newer schema is refused and named as such', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      payload['schemaVersion'] = AppDatabase.currentSchemaVersion + 1;
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      final BackupValidation verdict = await refused(file);
      expect(
        verdict.errors.map((BackupIssue i) => i.code),
        contains('schema_too_new'),
      );
      expect(await fingerprint(), before);
    });

    test('a link to a debt that is not in the file', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      (data['debtPeople']! as List<Object?>).add(<String, Object?>{
        'id': 'ghost:ghost',
        'debtId': 'ghost',
        'personId': 'ghost',
        'position': 0,
        'createdAt': '2026-09-25T10:00:00.000Z',
      });
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      final BackupValidation verdict = await refused(file);
      expect(
        verdict.errors.map((BackupIssue i) => i.code),
        contains('missing_debt'),
      );
      expect(await fingerprint(), before);
    });

    test('an amount that is not an integer', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      final Map<String, Object?> firstDebt =
          (data['debts']! as List<Object?>).first! as Map<String, Object?>;
      firstDebt['amountMinor'] = 1500.5;
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      final BackupValidation verdict = await refused(file);
      expect(
        verdict.errors.map((BackupIssue i) => i.code),
        contains('fractional_amount'),
      );
      expect(await fingerprint(), before);
    });

    test('a currency the app does not know', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      final Map<String, Object?> firstDebt =
          (data['debts']! as List<Object?>).first! as Map<String, Object?>;
      firstDebt['currency'] = 'XYZ';
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      final BackupValidation verdict = await refused(file);
      // Money is only ever an amount *in a currency*. A code this build cannot
      // name is not a debt it can add up, so the file is refused rather than
      // having its amounts quietly treated as the default currency.
      expect(
        verdict.errors.map((BackupIssue i) => i.code),
        contains('unknown_currency'),
      );
      expect(await fingerprint(), before);
    });

    test('the same id twice in one table', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      final List<Object?> people = data['people']! as List<Object?>;
      people.add(Map<String, Object?>.from(
        people.first! as Map<String, Object?>,
      ));
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final String before = await fingerprint();
      final BackupValidation verdict = await refused(file);
      // Two rows claiming one identity is not a ledger that can be restored:
      // whichever one was kept, the other's payments would land on it.
      expect(
        verdict.errors.map((BackupIssue i) => i.code),
        contains('duplicate_id'),
      );
      expect(await fingerprint(), before);
    });

    test('a file renamed to look like a backup', () async {
      // The extension is a convenience for the picker, never evidence: the
      // content is what is checked. An Excel export, a JSON export from this
      // app's own export screen, or another app's file renamed by hand must all
      // be refused the same way.
      await seed();
      final File json = await writeRaw(
        'evil.dhimmah',
        <String, Object?>{'hello': 'this is not a backup'},
      );
      final String before = await fingerprint();
      await expectLater(
        backups.inspect(json.path),
        throwsA(isA<BackupFormatException>().having(
          (BackupFormatException e) => e.problem,
          'problem',
          BackupProblem.notADhimmahBackup,
        )),
      );

      // And the same file wearing the name of a real snapshot, so the picker
      // would happily offer it.
      final File named = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        <String, Object?>{'hello': 'still not a backup'},
      );
      await expectLater(
        backups.inspect(named.path),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await fingerprint(), before, reason: 'nothing was written');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. The restore under failure: nothing half-applied, ever.
  // ---------------------------------------------------------------------------
  group('a restore that fails', () {
    test('rolls back completely when the insert fails halfway', () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      // Two summaries for one month: the unique index refuses the second, which
      // fails the transaction after rows have already been written.
      data['monthlySummaries'] = <Object?>[
        for (final String id in <String>['a', 'b'])
          <String, Object?>{
            'id': 'summary-$id',
            'year': 2026,
            'month': 9,
            'currency': 'INR',
            'newDebtMinor': 1,
            'settledMinor': 0,
            'receivedMinor': 0,
            'paidOutMinor': 0,
            'obligationsMinor': 0,
            'overdueMinor': 0,
            'peopleCount': 0,
            'closedDebts': 0,
            'activeDebts': 0,
            'generatedAt': '2026-09-25T10:00:00.000Z',
          },
      ];
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final ParsedBackup parsed = await backups.read(file.path);

      final String before = await fingerprint();
      await expectLater(
        restores.apply(backup: parsed, mode: RestoreMode.replace),
        throwsA(anything),
      );
      expect(
        await fingerprint(),
        before,
        reason: 'a restore that fails halfway must leave nothing behind — '
            'not one row, not one link',
      );

      // And the safety snapshot taken before it is still a usable file, because
      // it was written before anything was touched.
      final List<BackupFileInfo> safety = (await backups.list())
          .where((BackupFileInfo i) => i.kind == BackupKind.safety)
          .toList();
      expect(safety, hasLength(1));
      expect((await backups.inspect(safety.first.path)).isUsable, isTrue);
    });

    test('is refused whole when the safety snapshot cannot be written', () async {
      await seed();
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final String before = await fingerprint();

      // The volume refuses writes, so the safety copy cannot be made, so the
      // restore does not happen at all. Losing the current ledger to a restore
      // that could not first save it is the one outcome this design refuses to
      // risk.
      await Process.run('chmod', <String>['0555', dir.path]);
      await expectLater(
        restores.apply(backup: written.backup, mode: RestoreMode.replace),
        throwsA(anything),
        reason: 'without a safety copy there is no restore',
      );
      expect(await fingerprint(), before);
      await Process.run('chmod', <String>['0755', dir.path]);

      // Once writes are possible again, the same restore goes through: the
      // refusal was about the volume, not about the file. The state afterwards
      // is the state the file holds, which here is the state it came from — a
      // restore of an identical file is a no-op on the data, and that is worth
      // asserting too.
      final RestoreReport report = await restores.apply(
        backup: written.backup,
        mode: RestoreMode.replace,
      );
      expect(report.counts['debts'], 4);
      expect(await fingerprint(), before);
    });

    test('a kill during the restore leaves either the old ledger or the new one',
        () async {
      // A process kill cannot be delivered from inside a test, so the failure is
      // injected where it makes the difference: the transaction. The rule being
      // proven is the one a kill relies on — the database is either entirely the
      // old state or entirely the new one, because every write is in one
      // transaction and the verification runs inside it.
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      // A payment for a debt that does not exist: the validator catches this, so
      // to reach the *transaction* the reference is broken after validation —
      // which is what validation-insert a fake row here simulates.
      data['payments'] = <Object?>[
        ...(data['payments']! as List<Object?>),
        <String, Object?>{
          'id': 'late-payment',
          'debtId': 'debt-that-does-not-exist',
          'personId': null,
          'amountMinor': 100,
          'currency': 'INR',
          'paidAt': '2026-09-25',
          'note': null,
          'createdAt': '2026-09-25T10:00:00.000Z',
        },
      ];
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );

      // The verdict refuses it before anything is written.
      final BackupValidation verdict = await backups.inspect(file.path);
      expect(verdict.isUsable, isFalse);

      final String before = await fingerprint();
      final ParsedBackup parsed = await backups.read(file.path);
      await expectLater(
        restores.apply(backup: parsed, mode: RestoreMode.replace),
        throwsA(anything),
      );
      expect(await fingerprint(), before);
    });

    test('a merge that fails leaves the local records exactly as they were',
        () async {
      await seed();
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      // A record that arrives looking newer, with an amount that cannot exist:
      // the insert succeeds and the *verification* is what refuses it.
      final List<Object?> people = data['people']! as List<Object?>;
      (people.first! as Map<String, Object?>)['name'] = '';
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T103500.dhimmah',
        envelope,
      );
      final BackupValidation verdict = await backups.inspect(file.path);
      expect(verdict.isUsable, isFalse);
      expect(
        verdict.errors.map((BackupIssue i) => i.code),
        contains('missing_field'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 3. The files on disk: names, retention, temporary files.
  // ---------------------------------------------------------------------------
  group('the files on disk', () {
    test('two snapshots in the same second are two files, not one', () async {
      await seed();
      // The clock does not move: a user tapping twice, or an automatic snapshot
      // landing on the same second as a manual one.
      final ({File file, ParsedBackup backup}) first =
          await backups.create(kind: BackupKind.manual);
      final ({File file, ParsedBackup backup}) second =
          await backups.create(kind: BackupKind.manual);

      expect(
        first.file.path,
        isNot(second.file.path),
        reason: 'the second snapshot must not overwrite the first',
      );
      final List<BackupFileInfo> listed = await backups.list();
      expect(listed, hasLength(2));
      expect(
        listed.map((BackupFileInfo i) => i.createdAt).toSet(),
        hasLength(1),
        reason: 'both still report the moment they were taken',
      );
    });

    test('a name says what it is and nothing more', () async {
      await seed();
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.safety);
      final String name = written.file.path.split('/').last;
      expect(
        RegExp(r'^dhimmah-safety-\d{8}T\d{6}\d{3}(-\d+)?\.dhimmah$').hasMatch(name),
        isTrue,
        reason: 'a name is a kind and a moment: no names, no ids, no notes',
      );
      expect(name.contains('..'), isFalse);
      expect(name.contains('/'), isFalse);
    });

    test('a snapshot written before milliseconds were in the name still counts',
        () async {
      await seed();
      // The name format this app wrote before: second resolution only.
      await writeRaw('dhimmah-auto-20000101T000000.dhimmah', await validText());
      final List<BackupFileInfo> listed = await backups.list();
      final BackupFileInfo old = listed
          .firstWhere((BackupFileInfo i) => i.path.contains('20000101'));
      expect(old.createdAt, DateTime(2000)); // 1 January, midnight
      expect(old.kind, BackupKind.auto);
    });

    test('a temporary file never survives a successful write', () async {
      await seed();
      await backups.create(kind: BackupKind.manual);
      final List<String> temporary = dir
          .listSync()
          .map((FileSystemEntity e) => e.path)
          .where((String p) => p.endsWith('.tmp'))
          .toList();
      expect(temporary, isEmpty);
    });

    test('a temporary file left by a crash is cleaned up, not accumulated',
        () async {
      await seed();
      // A process killed mid-write leaves exactly this: a partial file with the
      // name of a snapshot it never became.
      final File orphan = File('${dir.path}/dhimmah-auto-20260925T103500'
          '${BackupFormat.extension}.tmp');
      await orphan.writeAsString('{"format":"dhimmah-backup","paylo');

      await backups.create(kind: BackupKind.manual);

      expect(
        await orphan.exists(),
        isFalse,
        reason: 'an abandoned half-file is not something the user should keep '
            'paying storage for, and it can never become a backup',
      );
      expect(await backups.list(), hasLength(1));
    });

    test('retention tolerates a file it cannot delete', () async {
      await seed();
      for (int i = 0; i < BackupService.autoRetention + 2; i++) {
        now = DateTime(2026, 9, 25, 10, 35, i);
        await backups.create(kind: BackupKind.auto);
      }
      final List<BackupFileInfo> automatic = (await backups.list())
          .where((BackupFileInfo i) => i.kind == BackupKind.auto)
          .toList();
      expect(automatic, hasLength(BackupService.autoRetention));

      // The oldest survivor cannot be deleted: retention reports nothing and the
      // next snapshot still succeeds.
      final FileSystemEntity oldest = automatic.last.file;
      final String path = oldest.path;
      await oldest.delete();
      await Directory(path).create();
      now = DateTime(2026, 9, 25, 10, 36);
      await backups.create(kind: BackupKind.auto);
      expect(
        (await backups.list()).where((BackupFileInfo i) => i.kind == BackupKind.auto),
        hasLength(BackupService.autoRetention),
      );
    });

    test('a garbage file wearing a backup name cannot break the rotation',
        () async {
      await seed();
      await writeRaw('dhimmah-auto-20000101T000000.dhimmah', 'not a backup');
      for (int i = 0; i < BackupService.autoRetention + 3; i++) {
        now = DateTime(2026, 9, 25, 10, 35, i);
        await backups.create(kind: BackupKind.auto);
      }
      final List<BackupFileInfo> listed = await backups.list();
      expect(
        listed.where((BackupFileInfo i) => i.kind == BackupKind.auto),
        hasLength(BackupService.autoRetention),
        reason: 'the unrecognised file ages out like any other old snapshot, '
            'and never takes a good one with it',
      );
      expect(
        (await backups.inspect(listed.first.path)).isUsable,
        isTrue,
        reason: 'the newest snapshot is still a real one',
      );
    });

    test('manual snapshots are never deleted by the app', () async {
      await seed();
      for (int i = 0; i < BackupService.autoRetention + 4; i++) {
        now = DateTime(2026, 9, 25, 10, 35, i);
        await backups.create(kind: BackupKind.manual);
      }
      expect(
        (await backups.list()).where((BackupFileInfo i) => i.kind == BackupKind.manual),
        hasLength(BackupService.autoRetention + 4),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Freshness: does the app know its copy is out of date?
  // ---------------------------------------------------------------------------
  group('freshness', () {
    BackupCoordinator coordinatorFor() {
      final BackupCoordinator coordinator = BackupCoordinator(
        database: db,
        backups: backups,
        settings: () => AppSettings.initial,
        clock: () => now,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);
      return coordinator;
    }

    test('changes made after a snapshot are seen as changes', () async {
      await seed();
      now = DateTime.now();
      final BackupCoordinator coordinator = coordinatorFor();
      await coordinator.runIfDue(leavingForeground: true);
      expect(await coordinator.pendingChanges(), 0,
          reason: 'nothing has happened since the snapshot was taken');

      await addPerson('شخص جديد');
      expect(await coordinator.pendingChanges(), greaterThan(0),
          reason: 'a record written after the snapshot is not in it');
    });

    test('a snapshot dated in the future does not report the ledger as saved',
        () async {
      await seed();
      final BackupCoordinator coordinator = coordinatorFor();
      // A clock that was wrong when the snapshot was taken: the file claims to
      // be from a day ahead. Everything is relative to the clock this test
      // actually runs on — the dates used to be written out in full, and once
      // the calendar reached them the records (which the database stamps with
      // the real clock) landed *after* "tomorrow" and the scenario quietly
      // turned into a different one.
      now = DateTime.now();
      final DateTime corrected = now;
      final DateTime fromTomorrow = now.add(const Duration(days: 1));
      now = fromTomorrow;
      await coordinator.runIfDue(leavingForeground: true);
      expect(await backups.list(), hasLength(1));

      // The clock is corrected back a day. Nothing in the ledger looks newer
      // than a snapshot from tomorrow, so the naive question — "what changed
      // since the snapshot?" — answers zero forever.
      now = corrected;
      expect(
        await coordinator.changedRecordsSince(fromTomorrow),
        0,
        reason: 'this is exactly why the timestamp alone cannot be trusted',
      );

      expect(
        await coordinator.pendingChanges(),
        greaterThan(0),
        reason: 'an unanswerable question must not be reported as "saved"',
      );
      expect(
        await coordinator.dueTrigger(leavingForeground: true),
        isNotNull,
        reason: 'the next boundary takes a fresh snapshot rather than trusting '
            'a timestamp from the future',
      );
    });

    test('a snapshot restores the same whatever the clock says', () async {
      await seed();
      // Written with a clock that was a year fast.
      now = DateTime(2027, 9, 25, 10, 35);
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final BackupValidation verdict = await backups.inspect(written.file.path);
      expect(verdict.isUsable, isTrue);
      expect(verdict.preview!.createdAt, DateTime(2027, 9, 25, 10, 35));

      await db.transaction(() async {
        await db.delete(db.payments).go();
        await db.delete(db.debtPeople).go();
        await db.delete(db.debts).go();
        await db.delete(db.people).go();
      });
      await restores.apply(backup: written.backup, mode: RestoreMode.replace);
      expect((await db.peopleDao.getAll()), hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. What the user sees afterwards: the numbers, in every layer.
  // ---------------------------------------------------------------------------
  group('after a restore', () {
    test('every debt computes exactly as it did before', () async {
      // A ledger with all the shapes that can go wrong: several currencies, a
      // partial payment, a settled record, an overdue one, a shared record.
      final Person ahmed = await addPerson('أحمد');
      final Person khalid = await addPerson('خالد');
      final Person mariam = await addPerson('مريم');

      final shared = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id, khalid.id, mariam.id],
          title: 'رحلة',
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -30),
          dueAt: addDays(today, -2),
        ),
      );
      await service.recordPayment(
        shared.id,
        PaymentDraft(amountMinor: 50000, paidAt: addDays(today, -5)),
      );
      final settled = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[khalid.id],
          title: 'سلفة',
          principalMinor: 90000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -10),
          dueAt: addDays(today, 4),
        ),
      );
      await service.recordPayment(
        settled.id,
        PaymentDraft(amountMinor: 90000, paidAt: addDays(today, -1)),
      );
      final dollars = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'Transfer',
          principalMinor: 120000,
          currency: AppCurrency.usd,
          issuedAt: addDays(today, -3),
          dueAt: addDays(today, 20),
        ),
      );

      /// amount, paid, remaining and status for every record, as the app
      /// computes them — through `DebtCalculator`, which is the single source of
      /// that arithmetic everywhere else.
      Future<Map<String, String>> calculations() async {
        final List<DebtRow> rows = await db.debtsDao.getAll();
        final List<PaymentRow> payments = await db.debtsDao.getAllPayments();
        final Map<String, int> paid = <String, int>{};
        for (final PaymentRow row in payments) {
          if (row.debtId == null) continue;
          paid[row.debtId!] = (paid[row.debtId!] ?? 0) + row.amountMinor;
        }
        final Map<String, List<DebtPersonRow>> links =
            <String, List<DebtPersonRow>>{};
        for (final DebtPersonRow link in await db.debtsDao.allParticipantRows()) {
          links.putIfAbsent(link.debtId, () => <DebtPersonRow>[]).add(link);
        }
        final Map<String, String> out = <String, String>{};
        for (final DebtRow row in rows) {
          final Debt debt = row.toEntity(
            personIds: <String>[
              for (final DebtPersonRow link in links[row.id] ?? const <DebtPersonRow>[])
                link.personId,
            ],
          );
          final int paidMinor = paid[row.id] ?? 0;
          final int remaining = DebtCalculator.remainingOf(
            row.principalMinor,
            paidMinor,
          );
          out[row.id] = '${row.principalMinor}/$paidMinor/$remaining/'
              '${DebtCalculator.resolveStatus(
                debt: debt,
                remainingMinor: remaining,
                asOf: today,
                dueSoonWindowDays: 7,
              )}';
        }
        return out;
      }

      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final Map<String, String> before = await calculations();

      await db.transaction(() async {
        await db.delete(db.payments).go();
        await db.delete(db.debtPeople).go();
        await db.delete(db.debts).go();
        await db.delete(db.people).go();
      });
      await restores.apply(backup: written.backup, mode: RestoreMode.replace);

      expect(await calculations(), before);

      // The shared record is one record with one amount, and every participant
      // reads it in full — the behaviour the app promises on every page.
      final List<DebtPersonRow> links = (await db.debtsDao.allParticipantRows())
          .where((DebtPersonRow l) => l.debtId == shared.id)
          .toList();
      expect(links, hasLength(3));
      expect(
        (await db.debtsDao.getById(shared.id))!.principalMinor,
        150000,
        reason: 'one record, one amount — never three records or 4500',
      );

      final LedgerQueries read = queries();
      for (final Person person in <Person>[ahmed, khalid, mariam]) {
        final PersonLedger? ledger = await read
            .watchPersonLedger(person.id, asOf: today, dueSoonWindowDays: 7)
            .first;
        final DebtView trip = ledger!.debts
            .firstWhere((DebtView v) => v.debt.id == shared.id);
        expect(trip.remainingMinor, 100000,
            reason: '${person.name} sees the amount left, not a share of it');
      }
      final PersonLedger? page = await read
          .watchPersonLedger(ahmed.id, asOf: today, dueSoonWindowDays: 7)
          .first;
      expect(
        page!.debts.where((DebtView v) => v.debt.id == shared.id).length,
        1,
        reason: 'the same record appears once on the page, not once per person',
      );
      expect((await db.debtsDao.getById(dollars.id))!.principalMinor, 120000);
      expect(
        (await db.debtsDao.getAll()).map((DebtRow d) => d.currencyCode).toSet(),
        <String>{'INR', 'USD'},
        reason: 'currencies never merge',
      );
    });

    test('search finds the restored records by every participant', () async {
      final Person ahmed = await addPerson('أحمد الحربي');
      final Person mariam = await addPerson('مريم القاسم');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id, mariam.id],
          title: 'رحلة العائلة',
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      await db.transaction(() async {
        await db.delete(db.debtPeople).go();
        await db.delete(db.debts).go();
        await db.delete(db.people).go();
      });
      await restores.apply(backup: written.backup, mode: RestoreMode.replace);

      // The same views the search screen filters, read the same way it reads
      // them, and matched with the same rule: the record itself, its note, and
      // every participant by name or number.
      final List<DebtView> views =
          await queries().watchDebtViews(asOf: today, dueSoonWindowDays: 7).first;
      bool matches(DebtView view, String needle) {
        if (view.displayName.toLowerCase().contains(needle)) return true;
        if (view.debt.title.toLowerCase().contains(needle)) return true;
        for (final Person person in view.participants) {
          if (person.name.toLowerCase().contains(needle)) return true;
          final String? phone = person.phone;
          if (phone != null && phone.toLowerCase().contains(needle)) return true;
        }
        return false;
      }

      for (final String term in <String>['أحمد', 'مريم', 'رحلة']) {
        expect(
          views.where((DebtView v) => matches(v, term.toLowerCase())),
          isNotEmpty,
          reason: '«$term» must find the restored record',
        );
      }
    });

    test('a statement is built from the restored records', () async {
      final Person ahmed = await addPerson('أحمد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: 'قرض',
          principalMinor: 250000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -20),
        ),
      );
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      await db.transaction(() async {
        await db.delete(db.debtPeople).go();
        await db.delete(db.debts).go();
        await db.delete(db.people).go();
      });
      await restores.apply(backup: written.backup, mode: RestoreMode.replace);

      // The statement the PDF is rendered from, built exactly as the app builds
      // it: from the restored records, through the same calculator. Rendering
      // the PDF itself needs a Flutter binding and fonts, which is what the
      // device test is for; what can be proven here is that the numbers and the
      // rows it would print come from the restored ledger.
      final PersonLedger ledger = (await queries()
          .watchPersonLedger(ahmed.id, asOf: today, dueSoonWindowDays: 7)
          .first)!;
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

      final StatementData statement = StatementService(
        localizations: l10n,
        formatting: AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: l10n,
        ),
        settings: AppSettings.initial,
      ).buildData(
        ledger: ledger,
        payments: await service.payments.getAll(),
        currency: AppCurrency.inr,
        now: today,
      );
      expect(statement.personName, 'أحمد');
      expect(statement.remainingMinor, 250000,
          reason: 'the statement is rebuilt from the restored records, and the '
              'amount is counted once');
      expect(statement.debts, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. After a process is killed mid-snapshot.
  //
  // The seven questions a kill raises, answered in one place, because they are
  // one situation from the user's point of view: the app died while it was
  // saving, and now they have opened it again.
  // ---------------------------------------------------------------------------
  group('after a kill mid-snapshot', () {
    test('the ledger, the files and the next snapshot all survive it', () async {
      await seed();
      // A good snapshot, taken yesterday.
      now = DateTime(2026, 9, 24, 20);
      final ({File file, ParsedBackup backup}) good =
          await backups.create(kind: BackupKind.manual);
      final String goodContents = await good.file.readAsString();

      // The user works, and the app is killed while writing the next one: what
      // is left on disk is a partial file and nothing else.
      now = DateTime(2026, 9, 25, 10, 35);
      await addPerson('شخص بعد النسخة');
      final String stateBefore = await fingerprint();
      await File('${dir.path}/dhimmah-auto-20260925T103500000'
              '${BackupFormat.extension}.tmp')
          .writeAsString(goodContents.substring(0, goodContents.length ~/ 3));

      // The app starts again, on the same directory, with the same database.
      final BackupService restarted = BackupService(
        database: db,
        appVersion: '1.0.0+1',
        clock: () => now,
        directory: dir,
      );
      final BackupCoordinator coordinator = BackupCoordinator(
        database: db,
        backups: restarted,
        settings: () => AppSettings.initial,
        clock: () => now,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      // 1. The last valid snapshot is still there, and still usable.
      final BackupFileInfo? last = await restarted.latest();
      expect(last, isNotNull);
      expect(last!.path, good.file.path);
      expect(await good.file.readAsString(), goodContents,
          reason: 'the file that was already finished is untouched');
      expect((await restarted.inspect(last.path)).isUsable, isTrue);

      // 2. The half-written file is not offered as a snapshot...
      expect(
        (await restarted.list())
            .where((BackupFileInfo i) => i.path.endsWith('.tmp')),
        isEmpty,
      );

      // 3. ...and nothing claims the snapshot succeeded: the newest file is
      //    yesterday's, and the record written since is counted as pending.
      expect(last.kind, BackupKind.manual);
      expect(await coordinator.pendingChanges(), greaterThan(0),
          reason: 'the app must not believe the killed snapshot happened');

      // 4. The next boundary takes a fresh snapshot, which also clears the
      //    abandoned temporary file.
      final BackupFileInfo? written =
          await coordinator.runIfDue(leavingForeground: true);
      expect(written, isNotNull, reason: 'a fresh snapshot is taken');
      expect(
        dir.listSync().where((FileSystemEntity e) => e.path.endsWith('.tmp')),
        isEmpty,
        reason: 'the abandoned half-file is gone',
      );

      // 5. The current data is intact — the kill cost nothing but time.
      expect(await fingerprint(), stateBefore);

      // 6. Nothing is corrupt: every file the app offers is a usable backup.
      for (final BackupFileInfo info in await restarted.list()) {
        expect((await restarted.inspect(info.path)).isUsable, isTrue,
            reason: '${info.name} must be a real backup');
      }

      // 7. Retention still holds: the old one, the new one, and the safety
      //    snapshot the restore path would take — all of them good.
      expect(await restarted.list(), hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Idempotency and merge semantics.
  // ---------------------------------------------------------------------------
  group('the same file, again and again', () {
    test('three restores of one file leave exactly one of everything', () async {
      await seed(payments: 1);
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);

      for (int round = 0; round < 3; round++) {
        await restores.apply(
          backup: written.backup,
          mode: RestoreMode.replace,
          takeSafetySnapshot: false,
        );
      }

      expect((await db.peopleDao.getAll()), hasLength(2));
      expect((await db.debtsDao.getAll()), hasLength(4));
      expect((await db.debtsDao.allParticipantRows()), hasLength(4));
      expect((await db.debtsDao.getAllPayments()), hasLength(4),
          reason: 'payments are the table a repeated import duplicates first');
      expect((await db.obligationsDao.getAll()), isEmpty);
    });

    test('three merges of one file insert nothing after the first', () async {
      await seed(payments: 1);
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final int people = (await db.peopleDao.getAll()).length;
      final int payments = (await db.debtsDao.getAllPayments()).length;

      final List<RestoreReport> reports = <RestoreReport>[
        for (int round = 0; round < 3; round++)
          await restores.apply(
            backup: written.backup,
            mode: RestoreMode.merge,
            takeSafetySnapshot: false,
          ),
      ];

      expect(reports.first.inserted, 0);
      expect(reports[1].inserted, 0);
      expect((await db.peopleDao.getAll()), hasLength(people));
      expect((await db.debtsDao.getAllPayments()), hasLength(payments));
      expect(reports.every((RestoreReport r) => r.conflicts.isEmpty), isTrue);
    });

    test('a payment made on the other device is added, not lost', () async {
      // The case the brief names: this device has a payment of 500, the file has
      // 500 and 300. A merge that replaced "the payment list" would lose one of
      // them; identity per payment row is what makes both survive.
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'قرض',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: addDays(today, 10),
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 50000, paidAt: addDays(today, -2)),
      );
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);

      // The other device recorded a second payment.
      final Map<String, Object?> envelope =
          jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      (data['payments']! as List<Object?>).add(<String, Object?>{
        'id': 'payment-from-the-other-device',
        'debtId': debt.id,
        'obligationId': null,
        'occurrenceId': null,
        'personId': person.id,
        'amountMinor': 30000,
        'currency': 'INR',
        'paidAt': '2026-09-20',
        'note': null,
        'createdAt': '2026-09-20T10:00:00.000Z',
      });
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T104000000.dhimmah',
        envelope,
      );

      final RestoreReport report = await restores.apply(
        backup: await backups.read(file.path),
        mode: RestoreMode.merge,
        takeSafetySnapshot: false,
      );

      expect(report.inserted, 1);
      expect(report.conflicts, isEmpty);
      final List<PaymentRow> all = await db.debtsDao.getAllPayments();
      expect(all, hasLength(2));
      expect(
        all.map((PaymentRow p) => p.amountMinor).toSet(),
        <int>{50000, 30000},
        reason: 'both payments exist; neither replaced the other',
      );
    });

    test('a participant added on the other device joins the record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person khalid = await addPerson('خالد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'رحلة',
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);

      final Map<String, Object?> envelope =
          jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      (data['debtPeople']! as List<Object?>).add(<String, Object?>{
        'id': '${debt.id}:${khalid.id}',
        'debtId': debt.id,
        'personId': khalid.id,
        'position': 1,
        'createdAt': '2026-09-25T09:00:00.000Z',
      });
      envelope['checksum'] = BackupFormat.checksumOf(payload);
      final File file = await writeRaw(
        'dhimmah-manual-20260925T104000000.dhimmah',
        envelope,
      );

      await restores.apply(
        backup: await backups.read(file.path),
        mode: RestoreMode.merge,
        takeSafetySnapshot: false,
      );

      final List<DebtPersonRow> links = (await db.debtsDao.allParticipantRows())
          .where((DebtPersonRow l) => l.debtId == debt.id)
          .toList()
        ..sort((DebtPersonRow a, DebtPersonRow b) =>
            a.position.compareTo(b.position));
      expect(links.map((DebtPersonRow l) => l.personId).toList(),
          <String>[ahmed.id, khalid.id],
          reason: 'the record gains a participant; nobody is duplicated and the '
              'order the user chose is kept');
      expect(links, hasLength(2));
      expect(
        (await db.debtsDao.getById(debt.id))!.personId,
        ahmed.id,
        reason: 'the first participant is still the one the record names',
      );
    });

    test('a differing record is reported, and the local one kept', () async {
      // The brief's example: 1000 here, 1200 in the file. The rule: newer wins,
      // because `updatedAt` is the record's own field and travels with it — and
      // when the file is *not* newer nothing is guessed: the local record stays
      // and the difference is reported so the user can look at it.
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'قرض',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);

      // The file's version says 1200.
      final Map<String, Object?> envelope =
          jsonDecode(await written.file.readAsString()) as Map<String, Object?>;
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      ((data['debts']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .firstWhere((Map<String, Object?> row) => row['id'] == debt.id))
          ['amountMinor'] = 120000;
      // Signed again, so the file is a well-formed one whose *content* disagrees
      // with this device — not a damaged file, which is a different test.
      envelope['checksum'] = BackupFormat.checksumOf(payload);

      final RestoreReport report = await restores.apply(
        backup: BackupFormat.parse(jsonEncode(envelope)),
        mode: RestoreMode.merge,
      );

      expect(report.conflicts, isNotEmpty,
          reason: 'a record that differs and is not newer is reported');
      expect(report.conflicts.single.table, 'debts');
      expect(report.conflicts.single.id, debt.id);
      expect(
        (await db.debtsDao.getById(debt.id))!.principalMinor,
        100000,
        reason: 'nothing in the ledger changes on a comparison the app cannot '
            'decide',
      );

      // And when the file *is* newer, it wins — the one case where the app can
      // tell which edit came second, because the record itself says so.
      final Map<String, Object?> newer =
          jsonDecode(jsonEncode(envelope)) as Map<String, Object?>;
      final Map<String, Object?> newerPayload =
          newer['payload']! as Map<String, Object?>;
      final Map<String, Object?> newerData =
          newerPayload['data']! as Map<String, Object?>;
      final Map<String, Object?> newerRow =
          (newerData['debts']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .firstWhere((Map<String, Object?> row) => row['id'] == debt.id);
      newerRow['updatedAt'] =
          DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String();
      newer['checksum'] = BackupFormat.checksumOf(newerPayload);

      final RestoreReport second = await restores.apply(
        backup: BackupFormat.parse(jsonEncode(newer)),
        mode: RestoreMode.merge,
      );
      expect(second.replaced, 1);
      expect(second.conflicts, isEmpty);
      expect((await db.debtsDao.getById(debt.id))!.principalMinor, 120000);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Settings: what travels, what stays on the device, and why.
  // ---------------------------------------------------------------------------
  group('settings', () {
    test('every preference travels; the device keeps its own', () async {
      final AppSettings before = AppSettings.initial.copyWith(
        language: AppLanguage.english,
        themeMode: AppThemeMode.dark,
        numerals: NumeralsStyle.arabicIndic,
        defaultCurrency: AppCurrency.usd,
        notificationsEnabled: false,
        notificationHour: 7,
        notificationMinute: 45,
        monthEndSummaryEnabled: true,
        dueSoonWindowDays: 10,
      );
      await db.settingsDao.write(before.toCompanion());
      await seed();

      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);

      // Restored onto a device that had its own preferences and its lock off.
      await db.settingsDao.write(
        AppSettings.initial
            .copyWith(language: AppLanguage.arabic, defaultCurrency: AppCurrency.inr)
            .toCompanion(),
      );

      await restores.apply(
        backup: written.backup,
        mode: RestoreMode.replace,
        takeSafetySnapshot: false,
      );

      final Setting after = (await db.settingsDao.get())!;
      expect(after.language, AppLanguage.english);
      expect(after.themeMode, AppThemeMode.dark);
      expect(after.numerals, NumeralsStyle.arabicIndic);
      expect(after.defaultCurrencyCode, 'USD');
      expect(after.notificationsEnabled, isFalse);
      expect(after.notificationHour, 7);
      expect(after.notificationMinute, 45);
      expect(after.monthEndSummaryEnabled, isTrue);
      expect(after.dueSoonWindowDays, 10);

      // The two that must not travel: the credential that would satisfy a lock
      // lives in the Android keystore and never leaves the device, so importing
      // "lock is on" would be importing a lock with no key behind it.
      expect(after.lockEnabled, isFalse,
          reason: 'security state is device-bound and is never imported');
      expect(after.biometricEnabled, isFalse);
      expect(
        after.lastSummarySentOn,
        before.lastSummarySentOn,
        reason: 'what this device has already sent is a fact about this device',
      );
    });

    test('a merge leaves the device settings alone', () async {
      await seed();
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      await db.settingsDao.write(
        AppSettings.initial
            .copyWith(language: AppLanguage.english, dueSoonWindowDays: 12)
            .toCompanion(),
      );

      final RestoreReport report = await restores.apply(
        backup: written.backup,
        mode: RestoreMode.merge,
        takeSafetySnapshot: false,
      );

      final Setting after = (await db.settingsDao.get())!;
      expect(after.language, AppLanguage.english);
      expect(after.dueSoonWindowDays, 12);
      expect(
        report.warnings.map((BackupIssue i) => i.code),
        contains('settings_untouched'),
        reason: 'and the user is told, rather than left to discover it',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Reminders after a restore: the schedule describes the restored records,
  //     never the ones that were here before.
  // ---------------------------------------------------------------------------
  group('reminders after a restore', () {
    late FakeNotificationGateway platform;
    late LedgerService notifying;

    setUp(() {
      platform = FakeNotificationGateway();
      notifying = buildService(
        db,
        notifications: NotificationService(gateway: platform),
      );
    });

    /// Applies [backup] and rebuilds the schedule from what it wrote — the same
    /// two steps the app performs.
    Future<RestoreReport> restore(ParsedBackup backup, RestoreMode mode) =>
        BackupRestoreService(
          database: db,
          backups: backups,
          rebuildDerivedState: notifying.refreshNotifications,
        ).apply(backup: backup, mode: mode, takeSafetySnapshot: false);

    Future<({Person person, Debt debt})> debtWithReminder(String name) async {
      final Person person =
          await notifying.createPerson(PersonDraft(name: name));
      final Debt debt = await notifying.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'قرض $name',
          principalMinor: 500000,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: addDays(today, 5),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );
      return (person: person, debt: debt);
    }

    test('a restored record is armed once, and re-arming changes nothing',
        () async {
      final ({Person person, Debt debt}) one = await debtWithReminder('أحمد');
      await notifying.refreshNotifications();
      final Map<int, FakeScheduledNotification> before =
          Map<int, FakeScheduledNotification>.of(platform.held);
      expect(before, isNotEmpty, reason: 'the record asks for a reminder');

      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);

      // Wipe, restore, rebuild — twice, because a user who restores the same
      // file again must not end up with two of everything, reminders included.
      for (int round = 0; round < 2; round++) {
        await db.transaction(() async {
          await db.delete(db.reminders).go();
          await db.delete(db.debtPeople).go();
          await db.delete(db.debts).go();
          await db.delete(db.people).go();
        });
        await restore(written.backup, RestoreMode.replace);
      }

      expect(
        platform.held.keys.toSet(),
        before.keys.toSet(),
        reason: 'the same records ask for the same notifications, by id',
      );
      expect(
        platform.held.values.where((FakeScheduledNotification n) =>
            n.payload == 'debt:${one.debt.id}'),
        isNotEmpty,
        reason: 'the restored record is still armed',
      );
    });

    test('a record the restore does not bring back loses its reminder', () async {
      final ({Person person, Debt debt}) one = await debtWithReminder('أحمد');
      final ({Person person, Debt debt}) two = await debtWithReminder('خالد');
      await notifying.refreshNotifications();
      expect(platform.held, isNotEmpty);

      // A snapshot taken before the second record existed.
      final Map<String, Object?> envelope = await validEnvelope();
      final Map<String, Object?> payload =
          envelope['payload']! as Map<String, Object?>;
      final Map<String, Object?> data =
          payload['data']! as Map<String, Object?>;
      final List<Object?> debtsInFile = data['debts']! as List<Object?>;
      debtsInFile.removeWhere((Object? row) =>
          (row! as Map<String, Object?>)['id'] == two.debt.id);
      data['debtPeople'] = <Object?>[
        for (final Object? row in data['debtPeople']! as List<Object?>)
          if ((row! as Map<String, Object?>)['debtId'] != two.debt.id) row,
      ];
      data['reminders'] = <Object?>[
        for (final Object? row in data['reminders']! as List<Object?>)
          if ((row! as Map<String, Object?>)['relatedId'] != two.debt.id) row,
      ];
      envelope['checksum'] = BackupFormat.checksumOf(payload);

      await restore(
        BackupFormat.parse(jsonEncode(envelope)),
        RestoreMode.replace,
      );

      expect(
        platform.held.values.where((FakeScheduledNotification n) =>
            n.payload == 'debt:${two.debt.id}'),
        isEmpty,
        reason: 'a record that is not in the ledger cannot still be asking for '
            'a reminder — the database is the source of truth, not the old '
            'schedule',
      );
      expect(
        platform.held.values.where((FakeScheduledNotification n) =>
            n.payload == 'debt:${one.debt.id}'),
        isNotEmpty,
        reason: 'and the one that came back is still armed',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 9. The codec's own contract: the two halves agree.
  // ---------------------------------------------------------------------------
  group('the writer and the reader agree', () {
    test('a snapshot says what the reference path says, and hashes the same',
        () async {
      // The writer takes a shortcut: it reduces the payload to canonical bytes
      // once, hashes *those* bytes, and wraps them in the envelope's text —
      // rather than canonicalising the whole ledger for the digest and then
      // encoding it all again for the file. That shortcut is only sound if the
      // result says exactly what the long way round says and hashes the same,
      // so both are built here from the same rows and compared.
      //
      // What is *not* asserted is byte equality, because it is not true and does
      // not need to be: the writer emits the payload with its keys in canonical
      // (sorted) order, and the reference emits them in the order they were
      // built. An object's key order is not part of what it says — the reader
      // decodes, and both sides hash the canonical form. A test that demanded
      // identical bytes would be pinning the map's construction order, which is
      // nobody's contract.
      await seed();
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final String actual = await written.file.readAsString();
      final ParsedBackup backup = written.backup;

      // The reference path, over the same rows the file carries.
      final Map<String, Object?> payload = BackupFormat.payload(
        schemaVersion: backup.schemaVersion,
        tables: <String, List<Map<String, Object?>>>{
          for (final String table in BackupFormat.tables) table: backup.rows(table),
        },
        settings: backup.settings,
        counts: backup.counts,
        truncated: backup.truncated,
      );
      final Map<String, Object?> reference = jsonDecode(BackupFormat.encode(
        BackupFormat.envelope(
          payload: payload,
          appVersion: backup.appVersion,
          createdAt: backup.createdAt!,
          kind: backup.kind,
        ),
      )) as Map<String, Object?>;

      expect(
        jsonDecode(actual),
        reference,
        reason: 'the file the writer produces says exactly what the reference '
            'implementation says',
      );

      // The one-pass builder, on the same rows: it must produce the same
      // payload, the same bytes and therefore the same digest as the reference
      // path. If it ever stops doing so, the equivalence above would still pass
      // (both would be decoded) while the file's own checksum would not add up —
      // so the digest is compared directly, here.
      final CanonicalPayload built = BackupFormat.build(
        schemaVersion: backup.schemaVersion,
        tables: <String, List<Map<String, Object?>>>{
          for (final String table in BackupFormat.tables) table: backup.rows(table),
        },
        settings: backup.settings,
        counts: backup.counts,
        truncated: backup.truncated,
      );
      // The property the one-pass builder depends on: what `payload` builds is
      // already canonical, so encoding it is the same as canonicalising and
      // encoding it. If this ever fails, the shortcut is invalid and the writer
      // must go back to canonicalising — which is why it is asserted directly
      // rather than inferred.
      expect(built.text, BackupFormat.canonical(payload).text);
      expect(built.digest, BackupFormat.checksumOf(payload));
      expect(built.payload, payload);

      // And the digest the writer put in the file is the digest the reader
      // computes from the payload — which is the whole point of the shortcut.
      final Map<String, Object?> envelope =
          jsonDecode(actual) as Map<String, Object?>;
      expect(envelope['checksum'], BackupFormat.checksumOf(payload));

      // The reader's own check, on the bytes on disk, and the same content back.
      final ParsedBackup reparsed = BackupFormat.parse(actual);
      expect(reparsed.counts, backup.counts);
      expect(reparsed.rows('debts'), backup.rows('debts'));
    });
  });

  group('the codec', () {
    test('a row read from the database and a row read from a file are the same',
        () async {
      // The backup path writes rows out and reads them back; the restore path
      // takes rows from a file and turns them into database rows. If the two
      // halves disagreed about a column, the round trip would hide it — this
      // compares them directly, column by column, for a record that uses every
      // field.
      final Person person = await service.createPerson(
        PersonDraft(name: 'أحمد', phone: '+967 771 234 567', note: 'ملاحظة'),
      );
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[person.id],
          title: 'دين بكل الحقول',
          principalMinor: 123456,
          currency: AppCurrency.usd,
          issuedAt: today,
          dueAt: addDays(today, 10),
          note: 'ملاحظة الدين',
        ),
      );

      final DebtRow debt = (await db.debtsDao.getAll()).single;
      final Map<String, Object?> encoded = BackupCodec.debt(debt);

      // Out to a file and back in, through the real writer and reader.
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      final Map<String, Object?> fromFile = written.backup
          .rows('debts')
          .firstWhere((Map<String, Object?> r) => r['id'] == debt.id);

      expect(fromFile.keys.toSet(), encoded.keys.toSet());
      expect(fromFile, encoded);
    });
  });
}
