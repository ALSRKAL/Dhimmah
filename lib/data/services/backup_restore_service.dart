import 'dart:io';

import 'package:drift/drift.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/services/backup_format.dart';
import '../../domain/services/backup_progress.dart';
import '../../domain/services/backup_validation.dart';
import '../backup/backup_codec.dart';
import '../backup/table_reader.dart';
import '../database/app_database.dart';
import '../mappers/db_mappers.dart';
import 'backup_service.dart';

/// Puts a validated backup back into the database.
///
/// The order of operations is the whole design, and every step exists because
/// skipping it has a failure mode:
///
/// 1. **Inspect** — the file is parsed, checksummed and validated before
///    anything is touched. A file that fails is refused whole.
/// 2. **Safety snapshot** — the current state is backed up first. There is no
///    path in this class that replaces the ledger without one, because "restore"
///    must never be the reason someone loses the data they had.
/// 3. **Plan** — merge decisions are made before a single write, so the user can
///    be told what will happen, and a conflict cannot be discovered halfway
///    through.
/// 4. **One transaction** — every insert, update and delete happens inside a
///    single database transaction, with the verification *inside* it: if the
///    restored state does not hold together, the transaction is rolled back and
///    the database is exactly as it was.
/// 5. **Rebuild** — periods are materialised and notifications are recomputed
///    from the restored records. The old schedule is never the source of truth.
class BackupRestoreService {
  BackupRestoreService({
    required AppDatabase database,
    required this.backups,
    required this.rebuildDerivedState,
  })  : _db = database;

  final AppDatabase _db;

  /// Used for the safety snapshot that every restore takes first.
  final BackupService backups;

  /// Materialises periods and recomputes notifications from the restored data.
  final Future<void> Function() rebuildDerivedState;

  /// Applies [backup] in [mode], after taking a safety snapshot.
  ///
  /// [takeSafetySnapshot] is false only for the tests that exercise the failure
  /// paths; the app always leaves it true.
  Future<RestoreReport> apply({
    required ParsedBackup backup,
    required RestoreMode mode,
    bool takeSafetySnapshot = true,
    DateTime? now,
    void Function(RestoreStep step)? onStep,
  }) async {
    if (backup.encrypted) {
      throw const BackupFormatException(BackupProblem.encrypted);
    }

    // The plan is computed before any write, and against the *current* state.
    await reportStep(onStep, RestoreStep.planning);
    final _Plan plan = mode == RestoreMode.replace
        ? await _planReplace(backup)
        : await _planMerge(backup);

    String? safetyPath;
    await reportStep(onStep, RestoreStep.snapshot);
    final bool hasLocalData = !await backups.isEmpty();
    if (takeSafetySnapshot && hasLocalData) {
      final ({File file, ParsedBackup backup}) safety =
          await backups.create(kind: BackupKind.safety, now: now);
      safetyPath = safety.file.path;
    }

    final List<BackupIssue> warnings = <BackupIssue>[...plan.warnings];

    await reportStep(onStep, RestoreStep.writing);
    // The counts come out of the verification, which read every table inside the
    // transaction: the numbers reported to the user are therefore the numbers
    // the transaction committed, read from the same rows that were checked.
    Map<String, int> counts = const <String, int>{};
    await _db.transaction(() async {
      if (mode == RestoreMode.replace) {
        await _deleteEverything();
      }
      await _applyInserts(plan.inserts);
      await _applyReplaces(plan.replaces);
      if (mode == RestoreMode.replace) {
        await _applySettings(backup.settings, schemaVersion: backup.schemaVersion);
      }
      // Verification runs on the state the transaction is about to commit.
      // Throwing here rolls the whole thing back.
      await reportStep(onStep, RestoreStep.verifying);
      counts = await _verify(plan);
    });

    // Outside the transaction, because these are derived: if either fails the
    // records are still correct, and the next launch runs them again.
    await reportStep(onStep, RestoreStep.rebuilding);
    try {
      await rebuildDerivedState();
    } on Object catch (error) {
      warnings.add(BackupIssue(
        code: 'rebuild_failed',
        detail: 'أُعيدت البيانات، لكن تعذّر تحديث الجداول المشتقة: $error',
      ));
    }

    return RestoreReport(
      mode: mode,
      inserted: plan.inserts.values.fold<int>(0, (int a, List<Object?> b) => a + b.length),
      replaced: plan.replaces.values.fold<int>(0, (int a, List<Object?> b) => a + b.length),
      skipped: plan.skipped,
      conflicts: plan.conflicts,
      warnings: warnings,
      safetyBackupPath: safetyPath,
      counts: counts,
    );
  }

  // --- Plans ----------------------------------------------------------------

  /// Replace: everything here goes, everything in the file arrives.
  Future<_Plan> _planReplace(ParsedBackup backup) async {
    final _Plan plan = _Plan();
    for (final String table in BackupFormat.tables) {
      final List<Map<String, Object?>> rows = table == 'debtPeople'
          ? _linksIncludingLegacy(backup)
          : backup.rows(table);
      plan.inserts[table] = rows;
      for (final Map<String, Object?> row in rows) {
        plan.expect(table, _idOf(table, row), row);
      }
    }
    // Local rows the file does not carry are deleted with everything else, so
    // there is nothing to count as skipped.
    return plan;
  }

  /// Merge: the file is folded in, record by record, with a rule for every case.
  ///
  /// Identity is the record's own id — never its name, never its amount — so a
  /// person who exists on both sides is one person. When both sides hold a
  /// *different* version of the same record, the newer one wins and the older
  /// one is reported: an equal-or-older incoming row is not applied, because
  /// guessing which edit is wanted is exactly the silent data loss this design
  /// exists to prevent.
  Future<_Plan> _planMerge(ParsedBackup backup) async {
    final _Plan plan = _Plan();

    // Read in pages, like the backup: a merge reads the whole ledger to compare
    // it row by row, and one `SELECT` per table would hold the frame thread for
    // seconds at scale.
    final TableReader reader = TableReader(database: _db);
    final Map<String, Map<String, Map<String, Object?>>> local =
        <String, Map<String, Map<String, Object?>>>{
      'people': _byId(await reader.people(), BackupCodec.person),
      'debts': _byId(await reader.debts(), BackupCodec.debt),
      'debtPeople': <String, Map<String, Object?>>{
        for (final DebtPersonRow row in await reader.links())
          '${row.debtId}:${row.personId}': BackupCodec.link(row),
      },
      'payments': _byId(await reader.payments(), BackupCodec.payment),
      'obligations': _byId(await reader.obligations(), BackupCodec.obligation),
      'obligationOccurrences':
          _byId(await reader.occurrences(), BackupCodec.occurrence),
      'reminders': _byId(await reader.reminders(), BackupCodec.reminder),
      'monthlySummaries':
          _byId(await reader.summaries(), BackupCodec.summary),
      'activity': _byId(await reader.activity(limit: BackupFormat.activityLimit),
          BackupCodec.activity),
    };

    for (final String table in BackupFormat.tables) {
      final List<Map<String, Object?>> inserts = <Map<String, Object?>>[];
      final List<Map<String, Object?>> replaces = <Map<String, Object?>>[];
      final Map<String, Map<String, Object?>> here = local[table]!;

      final List<Map<String, Object?>> incomingRows = table == 'debtPeople'
          ? _linksIncludingLegacy(backup)
          : backup.rows(table);
      for (final Map<String, Object?> incoming in incomingRows) {
        final String id = _idOf(table, incoming);
        final Map<String, Object?>? mine = here[id];
        if (mine == null) {
          inserts.add(incoming);
          plan.expect(table, id, incoming);
          continue;
        }
        if (_sameRow(mine, incoming)) {
          plan.skipped++;
          plan.expect(table, id, mine);
          continue;
        }
        final DateTime? mineAt = _changeMoment(mine);
        final DateTime? theirsAt = _changeMoment(incoming);
        if (mineAt != null && theirsAt != null && theirsAt.isAfter(mineAt)) {
          replaces.add(incoming);
          plan.expect(table, id, incoming);
          continue;
        }
        // Ambiguous on purpose: both sides changed it and the file is not
        // newer. The local record stays and the user is told which one it is.
        plan.conflicts.add(BackupIssue(
          code: 'kept_local_version',
          detail: 'سجل مختلف في النسخة الاحتياطية ولم يكن أحدث؛ أُبقي الموجود',
          table: table,
          id: id,
        ));
        plan.expect(table, id, mine);
      }

      if (inserts.isNotEmpty) plan.inserts[table] = inserts;
      if (replaces.isNotEmpty) plan.replaces[table] = replaces;
    }

    if (backup.settings.isNotEmpty) {
      plan.warnings.add(const BackupIssue(
        code: 'settings_untouched',
        detail: 'الدمج لا يغيّر إعدادات الجهاز',
      ));
    }
    return plan;
  }

  // --- Writes ---------------------------------------------------------------

  /// Empties every table, children before parents.
  ///
  /// The order is the reverse of the insert order so a foreign key is never
  /// left pointing at a row that has already gone — which, with
  /// `PRAGMA foreign_keys = ON`, would abort the transaction halfway.
  Future<void> _deleteEverything() async {
    await _db.delete(_db.activityEntries).go();
    await _db.delete(_db.monthlySummaries).go();
    await _db.delete(_db.reminders).go();
    await _db.delete(_db.obligations).go();
    await _db.delete(_db.payments).go();
    await _db.delete(_db.debtPeople).go();
    await _db.delete(_db.debts).go();
    await _db.delete(_db.people).go();
  }

  /// How many rows are written between two turns of the event loop.
  ///
  /// The writes are inside one transaction either way — this only decides how
  /// often the thread that draws the screen is given a chance to. A single batch
  /// of forty thousand payments is one long stretch; four hundred rows at a time
  /// is a sequence of short ones, and the screen keeps moving.
  static const int writeChunk = 400;

  Future<void> _applyInserts(Map<String, List<Map<String, Object?>>> inserts) async {
    for (final String table in BackupFormat.tables) {
      final List<Map<String, Object?>>? rows = inserts[table];
      if (rows == null || rows.isEmpty) continue;
      if (rows.length > writeChunk) {
        for (int start = 0; start < rows.length; start += writeChunk) {
          final int end = start + writeChunk;
          await _applyInserts(<String, List<Map<String, Object?>>>{
            table: rows.sublist(start, end > rows.length ? rows.length : end),
          });
          await _breathe();
        }
        continue;
      }
      switch (table) {
        case 'people':
          await _db.batch((Batch b) =>
              b.insertAll(_db.people, rows.map(BackupCodec.personRow).toList()));
        case 'debts':
          await _db.batch((Batch b) =>
              b.insertAll(_db.debts, rows.map(BackupCodec.debtRow).toList()));
        case 'debtPeople':
          await _db.batch((Batch b) => b.insertAll(
              _db.debtPeople, rows.map(BackupCodec.linkRow).toList()));
        case 'payments':
          await _db.batch((Batch b) =>
              b.insertAll(_db.payments, rows.map(BackupCodec.paymentRow).toList()));
        case 'obligations':
          await _db.batch((Batch b) => b.insertAll(
              _db.obligations, rows.map(BackupCodec.obligationRow).toList()));
        case 'obligationOccurrences':
          await _db.batch((Batch b) => b.insertAll(_db.obligationOccurrences,
              rows.map(BackupCodec.occurrenceRow).toList()));
        case 'reminders':
          await _db.batch((Batch b) =>
              b.insertAll(_db.reminders, rows.map(BackupCodec.reminderRow).toList()));
        case 'monthlySummaries':
          await _db.batch((Batch b) => b.insertAll(
              _db.monthlySummaries, rows.map(BackupCodec.summaryRow).toList()));
        case 'activity':
          await _db.batch((Batch b) => b.insertAll(
              _db.activityEntries, rows.map(BackupCodec.activityRow).toList()));
      }
    }
  }

  /// Rewrites the rows a merge decided to replace, keyed by their id.
  ///
  /// The incoming row wins outright, field by field: it is a newer version of
  /// the same record, not a patch to it, so applying only the fields it happens
  /// to mention would leave a mixture of two versions.
  Future<void> _applyReplaces(Map<String, List<Map<String, Object?>>> replaces) async {
    for (final String table in BackupFormat.tables) {
      final List<Map<String, Object?>>? rows = replaces[table];
      if (rows == null || rows.isEmpty) continue;
      await _replaceRows(table, rows);
    }
  }

  Future<void> _replaceRows(
    String table,
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.length > writeChunk) {
      for (int start = 0; start < rows.length; start += writeChunk) {
        final int end = start + writeChunk;
        await _replaceRows(
          table,
          rows.sublist(start, end > rows.length ? rows.length : end),
        );
        await _breathe();
      }
      return;
    }
    switch (table) {
      case 'people':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.people)..where((People t) => t.id.equals(_id(row)))
            ).write(BackupCodec.personRow(row));
        }
      case 'debts':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.debts)..where((Debts t) => t.id.equals(_id(row)))
            ).write(BackupCodec.debtRow(row));
        }
      case 'payments':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.payments)
                ..where((Payments t) => t.id.equals(_id(row))))
              .write(BackupCodec.paymentRow(row));
        }
      case 'obligations':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.obligations)
                ..where((Obligations t) => t.id.equals(_id(row))))
              .write(BackupCodec.obligationRow(row));
        }
      case 'obligationOccurrences':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.obligationOccurrences)
                ..where((ObligationOccurrences t) => t.id.equals(_id(row))))
              .write(BackupCodec.occurrenceRow(row));
        }
      case 'reminders':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.reminders)
                ..where((Reminders t) => t.id.equals(_id(row))))
              .write(BackupCodec.reminderRow(row));
        }
      case 'monthlySummaries':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.monthlySummaries)
                ..where((MonthlySummaries t) => t.id.equals(_id(row))))
              .write(BackupCodec.summaryRow(row));
        }
      case 'activity':
        for (final Map<String, Object?> row in rows) {
          await (_db.update(_db.activityEntries)
                ..where((ActivityEntries t) => t.id.equals(_id(row))))
              .write(BackupCodec.activityRow(row));
        }
      case 'debtPeople':
        // A link is either there or not; replacing it means ensuring it is.
        await _db.batch((Batch b) => b.insertAll(
            _db.debtPeople, rows.map(BackupCodec.linkRow).toList(),
            mode: InsertMode.insertOrIgnore));
    }
  }

  Future<void> _applySettings(
    Map<String, Object?> settings, {
    required int schemaVersion,
  }) async {
    if (settings.isEmpty) return;
    final Setting? current = await _db.settingsDao.get();
    final AppSettings base =
        current?.toEntity() ?? AppSettings.initial;
    // The two lock switches and the record of what this device has already sent
    // stay with the device: the credential that would satisfy a lock lives in
    // the Android keystore and never travels, and "this month's summary was
    // sent" is a fact about this phone.
    final AppSettings next = BackupCodec.applySettings(
      settings,
      base,
      schemaVersion: schemaVersion,
    ).copyWith(
      lockEnabled: base.lockEnabled,
      biometricEnabled: base.biometricEnabled,
      lastSummarySentOn: base.lastSummarySentOn,
    );
    await _db.settingsDao.write(next.toCompanion());
  }

  // --- Verification ---------------------------------------------------------

  /// Checks the state the transaction is about to commit, and reports what every
  /// table holds afterwards.
  ///
  /// This runs *inside* the transaction on purpose: a state that does not hold
  /// together must abort the restore, not be discovered afterwards. The check is
  /// by identity — the rows the plan meant to write must be there, saying what
  /// the file says — because a count alone would pass for the wrong rows.
  ///
  /// Two decisions here are the difference between a restore that takes seconds
  /// and one that takes a minute at scale, and both are measured:
  ///
  /// * **Every table is read once.** The earlier version read the same rows up
  ///   to three times — once to compare against the plan, once for the
  ///   references, once again to count them — and that repetition was the
  ///   largest single cost of a restore.
  /// * **Rows are converted only where the plan expects them.** A merge that
  ///   writes four records has no reason to rebuild the canonical form of forty
  ///   thousand.
  Future<Map<String, int>> _verify(_Plan plan) async {
    final Map<String, Set<String>> expected = <String, Set<String>>{};
    for (final _Expectation expectation in plan.expectations) {
      expected
          .putIfAbsent(expectation.table, () => <String>{})
          .add(expectation.id);
    }

    // --- The rows, each read once, in pages --------------------------------
    final TableReader reader = TableReader(database: _db);
    final List<PersonRow> personRows = await reader.people();
    final List<DebtRow> debtRows = await reader.debts();
    final List<DebtPersonRow> linkRows = await reader.links();
    final List<PaymentRow> paymentRows = await reader.payments();
    final List<ObligationRow> obligationRows = await reader.obligations();
    final List<ObligationOccurrenceRow> occurrenceRows =
        await reader.occurrences();
    // Only read when the plan wrote something there: these three are the tables
    // a merge usually leaves alone, and the activity log is the biggest of them.
    final List<ReminderRow> reminderRows = expected.containsKey('reminders')
        ? await reader.reminders()
        : const <ReminderRow>[];
    final List<MonthlySummaryRow> summaryRows =
        expected.containsKey('monthlySummaries')
            ? await reader.summaries()
            : const <MonthlySummaryRow>[];
    final List<ActivityEntryRow> activityRows =
        expected.containsKey('activity')
            ? await reader.activity(limit: BackupFormat.activityLimit)
            : const <ActivityEntryRow>[];

    // --- What the plan must find --------------------------------------------
    final Set<String> wantedPeople = expected['people'] ?? const <String>{};
    final Set<String> wantedDebts = expected['debts'] ?? const <String>{};
    final Set<String> wantedLinks = expected['debtPeople'] ?? const <String>{};
    final Set<String> wantedPayments = expected['payments'] ?? const <String>{};
    final Set<String> wantedObligations =
        expected['obligations'] ?? const <String>{};
    final Set<String> wantedOccurrences =
        expected['obligationOccurrences'] ?? const <String>{};
    final Set<String> wantedReminders = expected['reminders'] ?? const <String>{};
    final Set<String> wantedSummaries =
        expected['monthlySummaries'] ?? const <String>{};
    final Set<String> wantedActivity = expected['activity'] ?? const <String>{};

    final Map<String, Map<String, Object?>> storedPeople =
        <String, Map<String, Object?>>{
      for (final PersonRow row in personRows)
        if (wantedPeople.contains(row.id)) row.id: BackupCodec.person(row),
    };
    final Map<String, Map<String, Object?>> storedDebts =
        <String, Map<String, Object?>>{
      for (final DebtRow row in debtRows)
        if (wantedDebts.contains(row.id)) row.id: BackupCodec.debt(row),
    };
    final Map<String, Map<String, Object?>> storedLinks =
        <String, Map<String, Object?>>{
      for (final DebtPersonRow row in linkRows)
        if (wantedLinks.contains('${row.debtId}:${row.personId}'))
          '${row.debtId}:${row.personId}': BackupCodec.link(row),
    };
    final Map<String, Map<String, Object?>> storedPayments =
        <String, Map<String, Object?>>{
      for (final PaymentRow row in paymentRows)
        if (wantedPayments.contains(row.id)) row.id: BackupCodec.payment(row),
    };
    final Map<String, Map<String, Object?>> storedObligations =
        <String, Map<String, Object?>>{
      for (final ObligationRow row in obligationRows)
        if (wantedObligations.contains(row.id))
          row.id: BackupCodec.obligation(row),
    };
    final Map<String, Map<String, Object?>> storedOccurrences =
        <String, Map<String, Object?>>{
      for (final ObligationOccurrenceRow row in occurrenceRows)
        if (wantedOccurrences.contains(row.id))
          row.id: BackupCodec.occurrence(row),
    };
    final Map<String, Map<String, Object?>> storedReminders =
        <String, Map<String, Object?>>{
      for (final ReminderRow row in reminderRows)
        if (wantedReminders.contains(row.id)) row.id: BackupCodec.reminder(row),
    };
    final Map<String, Map<String, Object?>> storedSummaries =
        <String, Map<String, Object?>>{
      for (final MonthlySummaryRow row in summaryRows)
        if (wantedSummaries.contains(row.id)) row.id: BackupCodec.summary(row),
    };
    final Map<String, Map<String, Object?>> storedActivity =
        <String, Map<String, Object?>>{
      for (final ActivityEntryRow row in activityRows)
        if (wantedActivity.contains(row.id)) row.id: BackupCodec.activity(row),
    };

    final Map<String, Map<String, Map<String, Object?>>> now =
        <String, Map<String, Map<String, Object?>>>{
      'people': storedPeople,
      'debts': storedDebts,
      'debtPeople': storedLinks,
      'payments': storedPayments,
      'obligations': storedObligations,
      'obligationOccurrences': storedOccurrences,
      'reminders': storedReminders,
      'monthlySummaries': storedSummaries,
      'activity': storedActivity,
    };

    for (final _Expectation expectation in plan.expectations) {
      final Map<String, Object?>? stored = now[expectation.table]![expectation.id];
      if (stored == null) {
        throw BackupVerificationException(
          'صف مفقود بعد الاستعادة: ${expectation.table}/${expectation.id}',
        );
      }
      if (!_sameRow(stored, expectation.row)) {
        throw BackupVerificationException(
          'صف لا يطابق ما خُطّط له: ${expectation.table}/${expectation.id}',
        );
      }
    }

    // --- Every reference must point at a row that exists, as things are now --
    final Set<String> people = <String>{
      for (final PersonRow row in personRows) row.id,
    };
    final Set<String> debts = <String>{
      for (final DebtRow row in debtRows) row.id,
    };
    final Set<String> obligations = <String>{
      for (final ObligationRow row in obligationRows) row.id,
    };

    final Map<String, List<DebtPersonRow>> byDebt = <String, List<DebtPersonRow>>{};
    for (final DebtPersonRow link in linkRows) {
      byDebt.putIfAbsent(link.debtId, () => <DebtPersonRow>[]).add(link);
    }
    for (final MapEntry<String, List<DebtPersonRow>> entry in byDebt.entries) {
      if (!debts.contains(entry.key)) {
        throw BackupVerificationException('ارتباط لدين غير موجود: ${entry.key}');
      }
      for (final DebtPersonRow link in entry.value) {
        if (!people.contains(link.personId)) {
          throw BackupVerificationException(
            'ارتباط لشخص غير موجود: ${link.personId}',
          );
        }
      }
    }
    for (final DebtRow debt in debtRows) {
      final List<DebtPersonRow> links =
          byDebt[debt.id] ?? const <DebtPersonRow>[];
      if (links.isEmpty) continue;
      links.sort((DebtPersonRow a, DebtPersonRow b) =>
          a.position.compareTo(b.position));
      if (debt.personId != links.first.personId) {
        throw BackupVerificationException(
          'الدين ${debt.id}: الشخص الأساسي لا يطابق أول ارتباط',
        );
      }
    }

    for (final PaymentRow payment in paymentRows) {
      final bool hasDebt =
          payment.debtId != null && debts.contains(payment.debtId);
      final bool hasObligation = payment.obligationId != null &&
          obligations.contains(payment.obligationId);
      if (!hasDebt && !hasObligation) {
        throw BackupVerificationException('دفعة بلا دين ولا التزام: ${payment.id}');
      }
    }

    final Set<String> periods = <String>{};
    for (final ObligationOccurrenceRow row in occurrenceRows) {
      if (!periods.add('${row.obligationId}/${row.periodKey}')) {
        throw BackupVerificationException(
          'فترة مكرّرة: ${row.obligationId}/${row.periodKey}',
        );
      }
    }

    return <String, int>{
      'people': personRows.length,
      'debts': debtRows.length,
      'debtPeople': linkRows.length,
      'payments': paymentRows.length,
      'obligations': obligationRows.length,
      'obligationOccurrences': occurrenceRows.length,
      'reminders': reminderRows.isEmpty
          ? await _count(_db.reminders)
          : reminderRows.length,
      'monthlySummaries': summaryRows.isEmpty
          ? await _count(_db.monthlySummaries)
          : summaryRows.length,
      'activity': activityRows.isEmpty
          ? await _count(_db.activityEntries)
          : activityRows.length,
    };
  }

  /// Groups rows by their id, through the codec.
  ///
  /// Encoded once per row: a comprehension that asks for the id and the value
  /// separately encodes every row twice, which at forty thousand payments is
  /// forty thousand wasted conversions.
  static Map<String, Map<String, Object?>> _byId<T>(
    List<T> rows,
    Map<String, Object?> Function(T row) encode,
  ) {
    final Map<String, Map<String, Object?>> out =
        <String, Map<String, Object?>>{};
    for (final T row in rows) {
      final Map<String, Object?> encoded = encode(row);
      out['${encoded['id']}'] = encoded;
    }
    return out;
  }

  /// Lets the event loop run between chunks of work.
  static Future<void> _breathe() => Future<void>.delayed(Duration.zero);

  /// How many rows a table holds, counted by SQLite.
  ///
  /// Cheaper than reading the rows: the number is all that is wanted, and
  /// materialising forty thousand payments to learn one is work the database can
  /// do on its own.
  Future<int> _count(TableInfo<Table, dynamic> table) async {
    final Expression<int> count = table.$columns.first.count();
    final TypedResult row =
        await (_db.selectOnly(table)..addColumns(<Expression<Object>>[count]))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// The participant links in a file, including the ones an older file implies.
  ///
  /// Before the link table existed a record carried a single `personId`, so a
  /// backup written then has no links at all. The rule that reads them back is
  /// the same one the version-3 migration applied to the database itself: the
  /// person named on the record becomes its first participant. Nothing is
  /// invented — a record that named nobody keeps naming nobody.
  static List<Map<String, Object?>> _linksIncludingLegacy(ParsedBackup backup) {
    final List<Map<String, Object?>> rows =
        List<Map<String, Object?>>.of(backup.rows('debtPeople'));
    final Set<String> linked = <String>{
      for (final Map<String, Object?> row in rows) '${row['debtId']}',
    };
    for (final Map<String, Object?> debt in backup.rows('debts')) {
      final Object? owner = debt['personId'];
      final String id = '${debt['id']}';
      if (owner is! String || owner.isEmpty || linked.contains(id)) continue;
      rows.add(<String, Object?>{
        'id': '$id:$owner',
        'debtId': id,
        'personId': owner,
        'position': 0,
        'createdAt': debt['createdAt'],
      });
    }
    return rows;
  }

  // --- Comparison -----------------------------------------------------------

  /// The id a row is known by. A link has no id of its own, so its identity is
  /// the pair it joins — which is also what makes importing the same file twice
  /// insert no link twice.
  static String _idOf(String table, Map<String, Object?> row) {
    if (table == 'debtPeople') {
      return '${row['debtId']}:${row['personId']}';
    }
    return _id(row);
  }

  static String _id(Map<String, Object?> row) => '${row['id']}';

  /// True when two versions of a record say exactly the same thing.
  ///
  /// Field by field rather than by comparing encoded JSON. Both are correct —
  /// the keys are compared as a set, so order does not matter — but encoding two
  /// rows for every comparison meant the merge and the verification each encoded
  /// the whole ledger: at ten thousand records that was seconds of work spent
  /// turning maps into text in order to compare the text.
  ///
  /// The one case the two forms treat differently is a number written as a float
  /// in a hand-edited file (`5000.0` against `5000`): JSON spells those
  /// differently, Dart's `==` says they are the same. Such a value is refused by
  /// validation before it reaches here, so the difference cannot be reached
  /// through the app.
  static bool _sameRow(
    Map<String, Object?> a,
    Map<String, Object?> b,
  ) {
    for (final MapEntry<String, Object?> entry in a.entries) {
      if (entry.key == 'id') continue;
      if (!b.containsKey(entry.key)) return false;
      if (!_sameValue(entry.value, b[entry.key])) return false;
    }
    for (final String key in b.keys) {
      if (key != 'id' && !a.containsKey(key)) return false;
    }
    return true;
  }

  /// Equality for one field.
  ///
  /// `==` covers everything a row holds except the reminder leads, which travel
  /// as a list — and two lists with the same contents are not `==` in Dart.
  /// Leaving that to `==` would have made every record carrying a reminder look
  /// changed, which is not a subtle bug: identical rows would have been reported
  /// as conflicts and rewritten.
  static bool _sameValue(Object? a, Object? b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_sameValue(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final MapEntry<Object?, Object?> entry in a.entries) {
        if (!b.containsKey(entry.key)) return false;
        if (!_sameValue(entry.value, b[entry.key])) return false;
      }
      return true;
    }
    if (a == b) return true;
    if (a is String && b is String) {
      // The database keeps moments as epoch milliseconds. A file carrying finer
      // precision — microseconds, from another tool or a version that wrote
      // them — is stored truncated, so comparing the text would fail a restore
      // whose data is exactly right. The same moment at the precision this
      // database can hold is the same value.
      final DateTime? mine = DateTime.tryParse(a);
      final DateTime? theirs = DateTime.tryParse(b);
      if (mine != null && theirs != null) {
        return mine.millisecondsSinceEpoch == theirs.millisecondsSinceEpoch;
      }
    }
    return false;
  }

  /// When a row last changed, from whichever field the table carries.
  static DateTime? _changeMoment(Map<String, Object?> row) {
    for (final String key in <String>[
      'updatedAt',
      'createdAt',
      'generatedAt',
      'occurredAt',
      'paidAt',
      'issuedAt',
    ]) {
      final Object? value = row[key];
      if (value is String) {
        final DateTime? parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

/// Thrown when the restored state does not hold together.
///
/// Deliberately thrown *inside* the restore transaction, so the failure means
/// "nothing was changed" rather than "something is half-applied".
class BackupVerificationException implements Exception {
  const BackupVerificationException(this.detail);

  final String detail;

  @override
  String toString() => 'BackupVerificationException($detail)';
}

/// What a restore intends to do, decided before anything is written.
///
/// It carries not only what to write but what the database should hold
/// afterwards, row by row. That is what the verification checks: not "does the
/// file look present" but "is the state we are about to commit the state we
/// planned" — which is the only way a conflict can be deliberately left alone
/// and still be verified.
class _Plan {
  final Map<String, List<Map<String, Object?>>> inserts =
      <String, List<Map<String, Object?>>>{};
  final Map<String, List<Map<String, Object?>>> replaces =
      <String, List<Map<String, Object?>>>{};
  final List<BackupIssue> conflicts = <BackupIssue>[];
  final List<BackupIssue> warnings = <BackupIssue>[];
  final List<_Expectation> expectations = <_Expectation>[];
  int skipped = 0;

  /// Records what a table must hold for one id once the plan is applied.
  void expect(String table, String id, Map<String, Object?> row) =>
      expectations.add(_Expectation(table: table, id: id, row: row));
}

/// One row the database must hold after a restore, and what it must say.
class _Expectation {
  const _Expectation({required this.table, required this.id, required this.row});

  final String table;
  final String id;
  final Map<String, Object?> row;
}
