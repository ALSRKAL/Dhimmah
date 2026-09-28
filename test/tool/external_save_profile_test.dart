import 'dart:io';

import 'package:dhimmah/core/files/backup_location.dart';
import 'package:dhimmah/core/files/backup_location_repository.dart';
import 'package:dhimmah/core/files/file_gateway.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/external_backup_service.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// What saving an external copy costs, and what the read-back adds.
///
/// Print only, on purpose: the numbers are the evidence, and a threshold in a
/// test that seeds thousands of rows measures the machine more than the app.
///
///   flutter test test/tool/external_save_profile_test.dart --dart-define=people=500 --dart-define=debts=5
const int peopleCount = int.fromEnvironment('people', defaultValue: 500);
const int debtsPerPerson = int.fromEnvironment('debts', defaultValue: 5);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the price of an external save, and of verifying it',
    timeout: const Timeout(Duration(minutes: 20)),
    () async {
      final Directory dir = await Directory.systemTemp.createTemp('dhimmah-save-profile');
      final Directory outside = await Directory.systemTemp.createTemp('dhimmah-save-target');
      final AppDatabase db = AppDatabase.memory();
      final DateTime today = dateOnly(DateTime.now());

      await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
            for (int i = 0; i < peopleCount; i++)
              PeopleCompanion.insert(
                id: 'p$i',
                name: 'شخص رقم $i',
                createdAt: today,
                updatedAt: today,
              ),
          ]));
      final List<DebtsCompanion> debts = <DebtsCompanion>[
        for (int p = 0; p < peopleCount; p++)
          for (int d = 0; d < debtsPerPerson; d++)
            DebtsCompanion.insert(
              id: 'd${p}_$d',
              personId: Value<String>('p$p'),
              direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
              title: Value<String>('قرض $d للشخص $p'),
              principalMinor: 100000 + d * 1000,
              currencyCode: AppCurrency.usd.code,
              issuedAt: addDays(today, -100 - d),
              dueAt: Value<DateTime>(addDays(today, d)),
              recurrence: RecurrenceFrequency.none,
              createdAt: today,
              updatedAt: today,
            ),
      ];
      await db.batch((Batch b) => b.insertAll(db.debts, debts));

      final BackupService backups = BackupService(
        database: db,
        appVersion: '1.0.0+1',
        clock: DateTime.now,
        directory: dir,
      );
      final ExternalBackupService external = ExternalBackupService(
        backups: backups,
        folders: _ProfileFolderRepository(directory: outside),
        files: _TempFileGateway(outside),
      );

      // The internal snapshot on its own, for the baseline.
      final Stopwatch internal = Stopwatch()..start();
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      internal.stop();
      final int bytes = await written.file.length();

      // And the whole external save: build, write out, read back, compare.
      final Stopwatch save = Stopwatch()..start();
      final ExternalSaveReport report = await external.save();
      save.stop();

      // A restore of that same file, for scale.
      final Stopwatch read = Stopwatch()..start();
      final bool usable = (await backups.inspect(written.file.path)).isUsable;
      read.stop();
      await db.transaction(() async {
        await db.delete(db.debts).go();
        await db.delete(db.people).go();
      });
      final Stopwatch restore = Stopwatch()..start();
      final RestoreReport restored = await BackupRestoreService(
        database: db,
        backups: backups,
        rebuildDerivedState: () async {},
      ).apply(backup: written.backup, mode: RestoreMode.replace);
      restore.stop();

      // ignore: avoid_print
      print('''
=== EXTERNAL SAVE PROFILE — $peopleCount people / ${debts.length} debts ===
   file size                     : ${(bytes / 1024 / 1024).toStringAsFixed(2)} MB
   internal snapshot (write)     : ${internal.elapsedMilliseconds} ms
   external save (write+verify)  : ${save.elapsedMilliseconds} ms  -> ${report.outcome.name}
   verification overhead         : ${save.elapsedMilliseconds - internal.elapsedMilliseconds} ms
   inspect (validate + read)     : ${read.elapsedMilliseconds} ms (usable: $usable)
   restore (replace)             : ${restore.elapsedMilliseconds} ms
   verified bytes                : ${report.bytes}
   restored counts               : ${restored.counts}''');

      expect(report.outcome, ExternalSaveOutcome.saved);

      await db.close();
      await dir.delete(recursive: true);
      await outside.delete(recursive: true);
    },
  );
}

/// The user's backup folder, as a plain directory on disk.
///
/// The device writes through the ContentResolver, which a host test cannot do;
/// what this measures is the work the app does around the write — the copy out,
/// the read back, the byte comparison and the second parse — which is the same
/// work whatever the destination turns out to be.
class _ProfileFolderRepository implements BackupLocationRepository {
  _ProfileFolderRepository({required this.directory});

  final Directory directory;

  BackupLocation? _location;

  static const String _name = 'Dhimmah Backups';

  @override
  Future<BackupLocation?> getConfiguredLocation() async =>
      _location ??= BackupLocation(
        identifier: 'file://${directory.path}/$_name',
        displayName: _name,
        platform: BackupPlatform.android,
        verifiedAt: DateTime.now(),
      );

  Directory get _folder => Directory('${directory.path}/$_name');

  @override
  Future<ChosenFolder?> chooseLocation() async => null;

  @override
  Future<BackupLocationHealth> check({bool deep = false}) async =>
      const BackupLocationHealth(
        status: BackupLocationStatus.available,
        checkedAt: null,
      );

  @override
  Future<List<ExternalBackupFile>> listBackups() async => <ExternalBackupFile>[
        for (final FileSystemEntity entity in _folder.listSync())
          if (entity is File &&
              entity.path.endsWith('.dhimmah'))
            ExternalBackupFile(
              identifier: entity.path,
              displayName: entity.uri.pathSegments.last,
              sizeBytes: await entity.length(),
              modifiedAt: (await entity.stat()).modified,
            ),
      ];

  @override
  Future<ExternalBackupFile> createBackupFile({
    required String suggestedName,
    required List<int> bytes,
  }) async {
    await _folder.create(recursive: true);
    final File file = File('${_folder.path}/$suggestedName');
    await file.writeAsBytes(bytes, flush: true);
    return ExternalBackupFile(
      identifier: file.path,
      displayName: suggestedName,
      sizeBytes: bytes.length,
      modifiedAt: DateTime.now(),
    );
  }

  @override
  Future<List<int>> readBackup(ExternalBackupFile file) =>
      File(file.identifier).readAsBytes();

  @override
  Future<void> deleteBackup(ExternalBackupFile file) async =>
      File(file.identifier).delete();

  @override
  Future<String?> initialLocation() async => (await getConfiguredLocation())?.identifier;

  @override
  Future<void> clearLocation() async => _location = null;
}

/// A document in a directory outside the app's own, reached as a plain file.
///
/// The device writes through the ContentResolver, which a host test cannot do;
/// what this measures is the work the app does around the write — the copy out,
/// the read back, the byte comparison and the second parse — which is the same
/// work whatever the destination turns out to be.
class _TempFileGateway implements FileGateway {
  _TempFileGateway(this.directory);

  final Directory directory;

  @override
  Future<String?> pickBackupFile({String? initialDirectory}) async => null;

  @override
  Future<SaveTarget?> createSaveTarget({required String suggestedName}) async =>
      _TempFileTarget('${directory.path}/$suggestedName');

  @override
  Future<void> shareFile(String path, {String? subject}) async {}
}

class _TempFileTarget implements SaveTarget {
  _TempFileTarget(this.path);

  final String path;

  @override
  String get displayName => path.split('/').last;

  @override
  String get identifier => path;

  @override
  Future<int> write(List<int> bytes) async {
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return bytes.length;
  }

  @override
  Future<List<int>> read() => File(path).readAsBytes();

  @override
  Future<int?> size() async => File(path).length();
}
