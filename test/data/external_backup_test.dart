import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/files/backup_folder_channel.dart';
import 'package:dhimmah/core/files/backup_location.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/external_backup_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_backup_location.dart';
import '../support/fake_file_gateway.dart';
import '../support/fake_notification_gateway.dart';

/// Saving a backup into the user's own folder, and living with that folder.
///
/// The point of these tests is the one thing a chooser cannot tell you: whether
/// a file was actually written, and whether it is the file that was meant. Every
/// case below is a way a save could look fine and not be, and the contract is
/// that none of them reports success.
///
/// The folder side carries equal weight, because the folder is where the user's
/// copies live: it is chosen once, remembered, reconciled from what is actually
/// in it, and a file there is only called a backup after its content has been
/// read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;
  late BackupService backups;
  late FakeBackupLocationRepository folders;
  late ExternalBackupService service;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-external');
    db = AppDatabase.memory();
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    );
    folders = FakeBackupLocationRepository();
    service = ExternalBackupService(
      backups: backups,
      folders: folders,
      files: FakeFileGateway(),
    );
    final Person person = await buildService(
      db,
      notifications: NotificationService(gateway: FakeNotificationGateway()),
    ).createPerson(const PersonDraft(name: 'أحمد محمد'));
    await buildService(db).createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'قرض',
        principalMinor: 150000,
        currency: AppCurrency.usd,
        issuedAt: dateOnly(DateTime.now()),
        dueAt: addDays(dateOnly(DateTime.now()), 5),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('saving into the folder', () {
    test('a verified document is saved, and the report says what it holds',
        () async {
      await folders.chooseLocation();

      final ExternalSaveReport report = await service.save();

      expect(report.outcome, ExternalSaveOutcome.saved);
      expect(report.displayName, startsWith('dhimmah-manual-'));
      expect(report.displayName, endsWith('.dhimmah'));
      expect(report.bytes, greaterThan(0));
      expect(folders.files, hasLength(1), reason: 'one document, in the folder');
      // And what it holds really is a backup, per the format's own reader.
      final ParsedBackup parsed =
          BackupFormat.parse(utf8.decode(folders.files.values.single));
      expect(parsed.rows('people'), hasLength(1));
      expect(report.preview!.counts['debts'], 1);
    });

    test('the name offered to the folder carries no user data and cannot escape',
        () async {
      await folders.chooseLocation();
      await service.save();

      expect(folders.lastSuggestedName, startsWith('dhimmah-manual-'));
      expect(folders.lastSuggestedName, isNot(contains('أحمد')));
      expect(folders.lastSuggestedName, isNot(contains('/')));
      expect(folders.lastSuggestedName, isNot(contains('..')));
    });

    test('with no folder chosen, the answer is the setup state, not an error',
        () async {
      final ExternalSaveReport report = await service.save();

      expect(report.outcome, ExternalSaveOutcome.needsFolder);
      expect(folders.files, isEmpty, reason: 'nothing was written anywhere');
      expect(report.isSaved, isFalse);
    });

    test('a folder that refuses the write is a failure, not a save', () async {
      await folders.chooseLocation();
      folders.failWith = FolderFailure.io;

      final ExternalSaveReport report = await service.save();

      expect(report.outcome, ExternalSaveOutcome.failed);
      expect(report.problem, ExternalSaveProblem.write);
      expect(folders.files, isEmpty);
    });

    test('a read-only folder is a failure, and says so', () async {
      await folders.chooseLocation();
      folders.writable = false;

      final ExternalSaveReport report = await service.save();

      expect(report.outcome, ExternalSaveOutcome.failed);
      expect(report.problem, ExternalSaveProblem.write);
    });

    test('the snapshot behind an external save is a real internal backup too',
        () async {
      await folders.chooseLocation();
      await service.save();

      final List<BackupFileInfo> listed = await backups.list();
      expect(listed, hasLength(1));
      expect((await backups.inspect(listed.single.path)).isUsable, isTrue);
    });
  });

  group('the folder itself', () {
    test('choosing once is remembered, and restore starts there', () async {
      final ChosenFolder? chosen = await folders.chooseLocation();
      expect(chosen, isNotNull);
      expect(chosen!.location.displayName, BackupFolderChannel.folderName);
      expect(await folders.getConfiguredLocation(), isNotNull);
      expect(await folders.initialLocation(), isNotNull);
    });

    test('a revoked grant is named, not discovered at save time', () async {
      await folders.chooseLocation();
      folders.persisted = false;

      final BackupLocationHealth health = await folders.check();

      expect(health.status, BackupLocationStatus.permissionRevoked);
    });

    test('a folder that has gone away is unavailable, and says why', () async {
      await folders.chooseLocation();
      folders.failWith = FolderFailure.io;

      final BackupLocationHealth health = await folders.check();

      expect(health.status, BackupLocationStatus.unavailable);
      expect(health.detail, isNotNull);
    });

    test('a folder that lists but will not accept writes is read-only', () async {
      await folders.chooseLocation();
      folders.writable = false;

      final BackupLocationHealth health = await folders.check(deep: true);

      expect(health.status, BackupLocationStatus.readOnly);
    });

    test('a folder that was never chosen is not configured', () async {
      final BackupLocationHealth health = await folders.check();
      expect(health.status, BackupLocationStatus.notConfigured);
    });

    test('files added outside the app are counted, and named for what they are',
        () async {
      await folders.chooseLocation();
      folders.addFile('dhimmah-manual-real.dhimmah', folders.realBackup());
      folders.addFile('dhimmah-manual-broken.dhimmah', utf8.encode('{"no":true}'));
      folders.addFile('holiday-photo.jpg', <int>[1, 2, 3]);

      final BackupLocationHealth health = await folders.check();

      expect(health.validBackups, 1);
      expect(health.invalidFiles, 1);
      expect(health.otherFiles, 1);

      final List<ExternalBackupFile> listed = await folders.listBackups();
      expect(listed, hasLength(3));
      expect(
        listed
            .firstWhere((ExternalBackupFile f) => f.displayName == 'holiday-photo.jpg')
            .validity,
        ExternalFileValidity.unrelated,
        reason: 'an unrelated file is left alone and never offered',
      );
      expect(
        listed
            .firstWhere(
              (ExternalBackupFile f) => f.displayName == 'dhimmah-manual-broken.dhimmah',
            )
            .validity,
        ExternalFileValidity.invalid,
        reason: 'named like a backup, and not one',
      );
    });

    test('a file the user deleted by hand is gone from the next listing',
        () async {
      await folders.chooseLocation();
      await service.save();
      expect(await folders.listBackups(), hasLength(1));

      // The user removes it in their file manager: the folder no longer holds
      // it, and that is all the reconciliation has to do.
      folders.files.clear();

      expect(await folders.listBackups(), isEmpty);
    });

    test('a valid backup is recognised by its content, not its name', () async {
      await folders.chooseLocation();
      folders.addFile('something-else.dhimmah', folders.realBackup());
      folders.addFile('dhimmah-manual-not-one.dhimmah', utf8.encode('{"no":1}'));

      final List<ExternalBackupFile> listed = await folders.listBackups();

      expect(
        listed
            .firstWhere((ExternalBackupFile f) => f.displayName == 'something-else.dhimmah')
            .isValid,
        isTrue,
        reason: 'a real backup with an odd name is still a backup',
      );
      expect(
        listed
            .firstWhere(
              (ExternalBackupFile f) => f.displayName == 'dhimmah-manual-not-one.dhimmah',
            )
            .isValid,
        isFalse,
      );
    });

    test('deleting a backup removes the file, and a second delete is quiet',
        () async {
      await folders.chooseLocation();
      await service.save();
      final List<ExternalBackupFile> listed = await folders.listBackups();

      await folders.deleteBackup(listed.single);
      expect(folders.files, isEmpty);

      // And again, for a file that is already gone: no error, no crash.
      await folders.deleteBackup(listed.single);
      expect(folders.deletedNames, hasLength(1),
          reason: 'an absent file was not deleted twice');
    });

    test('forgetting the folder clears it, and the next save asks for one',
        () async {
      await folders.chooseLocation();
      await service.save();

      await folders.clearLocation();
      expect(await folders.getConfiguredLocation(), isNull);

      final ExternalSaveReport report = await service.save();
      expect(report.outcome, ExternalSaveOutcome.needsFolder);
    });
  });
}
