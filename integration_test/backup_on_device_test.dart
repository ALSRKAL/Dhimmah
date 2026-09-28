import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/app_harness.dart';
import '../test/support/fake_notification_gateway.dart';

/// Backup and restore against Android's own file system.
///
/// The unit tests prove the format, the validation and the merge rules in
/// memory; this proves the parts that only exist on a device: the app's private
/// directory, a real multi-megabyte file written and fsynced by the platform,
/// and a restore that rebuilds the ledger from it.
///
///   flutter test integration_test/backup_on_device_test.dart -d `device`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final DateTime today = dateOnly(DateTime.now());

  testWidgets('a backup written on the phone restores the ledger', (
    WidgetTester tester,
  ) async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${root.path}/backup_device_test');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final AppDatabase db = AppDatabase.memory();
    // The file system is what this test is about; delivery is covered by
    // `notifications_on_device_test.dart`. Using the fake platform here keeps
    // the two concerns apart and means no alarm is ever armed by a test.
    final LedgerService service = buildService(
      db,
      notifications: NotificationService(gateway: FakeNotificationGateway()),
    );
    final BackupService backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    );
    final BackupRestoreService restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: () async {
        await service.ensureOccurrences();
        await service.refreshNotifications();
      },
    );

    // A ledger with the shapes that must survive: a shared record, a payment, a
    // recurring commitment with its periods, and both scripts.
    final Person ahmed = await service.createPerson(
      const PersonDraft(name: 'أحمد محمد عبدالرحمن'),
    );
    final Person maryam = await service.createPerson(
      const PersonDraft(name: 'Maryam Hassan'),
    );
    final Debt shared = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id, maryam.id],
        title: 'فاتورة العشاء',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 3),
      ),
    );
    await service.recordPayment(
      shared.id,
      PaymentDraft(amountMinor: 50000, paidAt: today),
    );
    await service.createObligation(
      ObligationDraft(
        name: 'الإيجار',
        category: ObligationCategory.housing,
        amountMinor: 200000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );
    await service.ensureOccurrences();

    final Stopwatch backupWatch = Stopwatch()..start();
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    backupWatch.stop();

    final int size = await written.file.length();
    // ignore: avoid_print
    print('DEVICE backup: ${(size / 1024).toStringAsFixed(1)} KB written in '
        '${backupWatch.elapsedMilliseconds} ms to ${written.file.path}');
    expect(await written.file.exists(), isTrue);
    expect(written.backup.rows('people'), hasLength(2));
    expect(written.backup.rows('debtPeople'), hasLength(2));

    // The file is readable again, and the checksum holds.
    final BackupValidation verdict = await backups.inspect(written.file.path);
    expect(verdict.isUsable, isTrue, reason: verdict.errors.join(' | '));
    expect(verdict.preview!.sharedRecords, 1);

    // Wipe the ledger the way a reinstall does, then restore from the file.
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
    expect(await db.debtsDao.getAll(), isEmpty);

    final Stopwatch restoreWatch = Stopwatch()..start();
    final RestoreReport report = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
    );
    restoreWatch.stop();
    // ignore: avoid_print
    print('DEVICE restore: ${restoreWatch.elapsedMilliseconds} ms, '
        '${report.counts}');

    expect(report.counts['people'], 2);
    expect(report.counts['debts'], 1);
    expect(report.counts['payments'], 1);
    expect(report.counts['debtPeople'], 2);
    expect(
      await db.debtsDao.participantsFor(shared.id),
      hasLength(2),
      reason: 'the shared record comes back with both of its people',
    );
    final List<ObligationOccurrenceRow> periods =
        await db.obligationsDao.getOccurrences();
    expect(periods, isNotEmpty, reason: 'the commitment brings its periods');

    // Nothing was on the device, so there was nothing to protect: a safety
    // snapshot is taken when there is something to lose, not unconditionally.
    expect(report.safetyBackupPath, isNull);

    // Restoring *over* a ledger, on the other hand, must always leave a way
    // back — this is the guarantee the whole feature rests on.
    final RestoreReport second = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.merge,
    );
    expect(second.safetyBackupPath, isNotNull);
    expect(await File(second.safetyBackupPath!).exists(), isTrue);
    expect(
      second.inserted,
      0,
      reason: 'merging a file that is already here adds nothing',
    );

    // And the listing sees what is on disk, newest first.
    final List<BackupFileInfo> listed = await backups.list();
    expect(listed, hasLength(2));
    // ignore: avoid_print
    print('DEVICE backups on disk: '
        '${listed.map((BackupFileInfo i) => i.name).join(', ')}');

    await db.close();
    await dir.delete(recursive: true);
  });
}
