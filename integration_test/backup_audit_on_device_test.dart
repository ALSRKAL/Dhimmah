import 'dart:io';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:dhimmah/app/backup_providers.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/services/backup_coordinator.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_validation.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/fake_file_gateway.dart';
import '../test/support/fake_notification_gateway.dart';

/// The final audit, on the phone.
///
/// Three questions only a device can answer:
///
/// 1. **Is the screen still alive while a large ledger is saved and restored?**
///    Frame timings from the real engine, including the gaps — which is what a
///    blocked UI thread actually looks like from the outside.
/// 2. **What is the state after a snapshot is killed?** The seven things a
///    half-written snapshot must not have broken.
/// 3. **Can a file that left the app come back?** A snapshot is carried out of
///    the sandbox, the app is uninstalled and installed again, and the ledger is
///    rebuilt from that file.
///
///   flutter test integration_test/backup_audit_on_device_test.dart -d `device` --dart-define=phase=all

const String phase = String.fromEnvironment('phase', defaultValue: 'all');

/// The name of the exported copy inside the app's own directory.
///
/// A copy that leaves the app does so through the share sheet, and comes back
/// through the picker; neither is available to a test. So the copy is taken from
/// here with `adb` and put back here after the reinstall — the file is byte for
/// byte the one the app wrote, and everything that reads it is the app's own
/// code. What the app guarantees is that the file is complete and
/// self-describing, which is what makes it usable after a reinstall.
const String exportName = 'audit-export.dhimmah';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The engine renders continuously, so the frame timings collected below are
  /// the application's own. `tester.pump()` advances `flutter_test`'s fake clock
  /// and the backup and restore do real file and database I/O, which completes
  /// on the real event loop — pumping frames while that I/O is pending is a race
  /// that stalled the restore step of this file once, with no Dart error, and
  /// sent this investigation looking for a product defect that was not there.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;


  final DateTime today = dateOnly(DateTime.now());

  /// Where the app really keeps its snapshots.
  Future<Directory> backupsDirectory() async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${root.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Reports what the engine did while [body] ran.
  ///
  /// The number that answers "can the user use the screen?" is not the average
  /// frame time — it is the longest *gap* between frames. A frame that never
  /// started is a frame nobody saw, and no amount of cheap frames afterwards
  /// gives that time back.
  Future<void> measured(
    WidgetTester tester,
    String label,
    Future<void> Function() body,
  ) async {
    final List<FrameTiming> timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    binding.addTimingsCallback(collect);

    // Frames are *asked for* while the work runs, because in an integration test
    // a frame only happens when the test pumps for one. Without this the harness
    // would be measuring itself: an app that renders nothing and a frame thread
    // that is blocked look identical from the outside, and only one of them is a
    // problem. A pump that cannot build its frame shows up here as a gap between
    // two vsyncs.
    final Stopwatch wall = Stopwatch()..start();
    await body();
    wall.stop();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    binding.removeTimingsCallback(collect);

    final List<int> starts = <int>[
      for (final FrameTiming t in timings) t.timestampInMicroseconds(FramePhase.vsyncStart),
    ];
    final List<int> gaps = <int>[
      for (int i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
    ];
    final List<Duration> build = <Duration>[
      for (final FrameTiming t in timings) t.buildDuration,
    ];
    int worstGap = 0;
    int blocked = 0;
    for (final int gap in gaps) {
      if (gap > worstGap) worstGap = gap;
      // Anything longer than a frame's budget is time the user waited with a
      // frozen screen.
      if (gap > 34000) blocked += gap ~/ 1000 - 17;
    }
    // ignore: avoid_print
    print('DEVICE $label | wall=${wall.elapsedMilliseconds}ms '
        'frames=${starts.length} '
        'worst frame build=${_p(build, 1.0)}ms build p90=${_p(build, 0.90)}ms '
        '| frames over 16.7ms=${build.where((Duration d) => d.inMicroseconds > 16700).length} '
        '| worst gap=${(worstGap / 1000).round()}ms '
        '| blocked≈${blocked}ms');
  }

  testWidgets('the app survives a large ledger being saved and restored',
      (WidgetTester tester) async {
    final Directory dir = await backupsDirectory();
    final AppDatabase db = AppDatabase.memory();
    await _seedLargeLedger(db, today, people: 500, debtsPerPerson: 5);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupDirectoryProvider.overrideWithValue(dir),
        fileGatewayProvider.overrideWithValue(FakeFileGateway()),
        notificationServiceProvider.overrideWithValue(
          NotificationService(gateway: FakeNotificationGateway()),
        ),
      ],
    );
    addTearDown(container.dispose);

    // A spinner, so the engine has a reason to draw a frame every vsync while
    // the work runs. That is what makes the frame timings mean something: with
    // nothing animating, a blocked UI thread and an idle one look the same.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
    );
    await tester.pump();

    // The work the backup action does before it hands anything to the platform:
    // generating and writing the snapshot at the largest size the app is
    // expected to meet — 500 people, 2,500 records, 10,000 payments. The chooser
    // is not exercised here, because a harness cannot tap a system dialog; this
    // measures the engine, and the flow that presses the button is a separate,
    // guarded run.
    BackupFileInfo? written;
    await measured(tester, 'backup 500/2500/10000', () async {
      final BackupService service = container.read(backupServiceProvider);
      final ({File file, ParsedBackup backup}) snapshot =
          await service.create(kind: BackupKind.manual);
      written = BackupFileInfo(
        path: snapshot.file.path,
        kind: BackupKind.manual,
        createdAt: DateTime.now(),
        sizeBytes: await snapshot.file.length(),
      );
    });
    expect(written, isNotNull);

    final File file = File(written!.path);
    // ignore: avoid_print
    print('DEVICE file: ${(await file.length() / 1024 / 1024).toStringAsFixed(2)} MB '
        'at ${file.path}');

    // A copy the user could keep. The app can only write inside its own
    // directory — it asks for no storage permission — so this is where the copy
    // lives until `adb` carries it out of the sandbox.
    final Directory root = await getApplicationDocumentsDirectory();
    final File exported = await file.copy('${root.path}/$exportName');
    // ignore: avoid_print
    print('DEVICE exported: ${exported.path} '
        '(${((await exported.length()) / 1024 / 1024).toStringAsFixed(2)} MB)');

    // Now the restore, from a wiped ledger, through the same service the screen
    // uses. This is the operation the user waits on with a progress label.
    // ignore: avoid_print
    print('DEVICE RESTORE_STEP: wipe start');
    await db.transaction(() async {
      await db.delete(db.activityEntries).go();
      await db.delete(db.monthlySummaries).go();
      await db.delete(db.reminders).go();
      await db.delete(db.obligationOccurrences).go();
      await db.delete(db.obligations).go();
      await db.delete(db.payments).go();
      await db.delete(db.debtPeople).go();
      await db.delete(db.debts).go();
      await db.delete(db.people).go();
    });
    // ignore: avoid_print
    print('DEVICE RESTORE_STEP: wipe done');
    final ParsedBackup parsed = await container.read(backupServiceProvider).read(file.path);
    // ignore: avoid_print
    print('DEVICE RESTORE_STEP: read done (${parsed.counts})');

    // The restore is awaited directly, with no frame pumping around it. This is
    // the same call the other two tests in this file make — and the same call
    // that restored this exact file, on this phone, in the import test — so if
    // it completes here and the pumped variant does not, the difference is the
    // harness, not the application. The pumped measurement is what the frame
    // numbers need, and it can only be trusted once this one is green.
    // ignore: avoid_print
    print('DEVICE RESTORE_STEP: apply start');
    final Stopwatch restoreWatch = Stopwatch()..start();
    final RestoreReport report = await container
        .read(backupRestoreServiceProvider)
        .apply(backup: parsed, mode: RestoreMode.replace);
    restoreWatch.stop();
    // ignore: avoid_print
    print('DEVICE RESTORE_STEP: apply done in ${restoreWatch.elapsedMilliseconds} ms '
        '(${report.counts})');

    expect((await db.peopleDao.getAll()), hasLength(500));
    expect((await db.debtsDao.getAll()), hasLength(2500));
    // ignore: avoid_print
    print('DEVICE restored: ${(await db.debtsDao.getAllPayments()).length} payments');

    // The in-memory database is deliberately not closed: the provider graph
    // holds streams open and drift's `close` waits for its listeners. The
    // process ends immediately after this and takes the memory with it.
  }, timeout: const Timeout(Duration(minutes: 15)));

  testWidgets('restore completes ten times in a row on the device', (
    WidgetTester tester,
  ) async {
    // The matrix the closure needs: the same file, the same dataset, restored
    // ten times in one process, each one after wiping the ledger. Recorded
    // rather than assumed, and no timeout is allowed to turn a stall into a
    // pass — a cycle that does not finish is printed as a failure.
    final Directory dir = await backupsDirectory();
    final AppDatabase db = AppDatabase.memory();
    await _seedLargeLedger(db, today, people: 500, debtsPerPerson: 5);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupDirectoryProvider.overrideWithValue(dir),
        fileGatewayProvider.overrideWithValue(FakeFileGateway()),
        notificationServiceProvider.overrideWithValue(
          NotificationService(gateway: FakeNotificationGateway()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final BackupService backups = container.read(backupServiceProvider);
    final BackupRestoreService restores =
        container.read(backupRestoreServiceProvider);
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final ParsedBackup parsed = await backups.read(written.file.path);

    int passed = 0;
    final List<String> runs = <String>[];
    for (int run = 1; run <= 10; run++) {
      await tester.runAsync(() async {
        await db.transaction(() async {
          await db.delete(db.activityEntries).go();
          await db.delete(db.monthlySummaries).go();
          await db.delete(db.reminders).go();
          await db.delete(db.obligationOccurrences).go();
          await db.delete(db.obligations).go();
          await db.delete(db.payments).go();
          await db.delete(db.debtPeople).go();
          await db.delete(db.debts).go();
          await db.delete(db.people).go();
        });
      });
      final Stopwatch watch = Stopwatch()..start();
      final RestoreReport report =
          await restores.apply(backup: parsed, mode: RestoreMode.replace);
      watch.stop();
      final bool ok = report.counts['people'] == 500 &&
          report.counts['debts'] == 2500 &&
          report.counts['payments'] == 10000;
      if (ok) passed++;
      runs.add('run $run: ${ok ? 'PASS' : 'FAIL'} '
          '${watch.elapsedMilliseconds} ms ${report.counts}');
    }

    for (final String line in runs) {
      // ignore: avoid_print
      print('DEVICE RESTORE_X10 $line');
    }
    // ignore: avoid_print
    print('DEVICE RESTORE_X10 TOTAL: $passed/10 completed deterministically');
    expect(passed, 10, reason: 'every restore must complete with the full data');
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('six backup and restore cycles, with the memory after each', (
    WidgetTester tester,
  ) async {
    // The leak question, on the device: does memory climb across repeated
    // backup/restore cycles, or does it come back? Peak alone cannot answer it,
    // so the figure is recorded after every cycle, before and after.
    final Directory dir = await backupsDirectory();
    final AppDatabase db = AppDatabase.memory();
    await _seedLargeLedger(db, today, people: 500, debtsPerPerson: 5);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupDirectoryProvider.overrideWithValue(dir),
        fileGatewayProvider.overrideWithValue(FakeFileGateway()),
        notificationServiceProvider.overrideWithValue(
          NotificationService(gateway: FakeNotificationGateway()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final BackupService backups = container.read(backupServiceProvider);
    final BackupRestoreService restores =
        container.read(backupRestoreServiceProvider);

    // ignore: avoid_print
    print('DEVICE MEM baseline: ${_rss()}');
    final List<String> rows = <String>[];
    for (int cycle = 1; cycle <= 6; cycle++) {
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.auto);
      final ParsedBackup parsed = await backups.read(written.file.path);
      await tester.runAsync(() async {
        await db.transaction(() async {
          await db.delete(db.activityEntries).go();
          await db.delete(db.monthlySummaries).go();
          await db.delete(db.reminders).go();
          await db.delete(db.obligationOccurrences).go();
          await db.delete(db.obligations).go();
          await db.delete(db.payments).go();
          await db.delete(db.debtPeople).go();
          await db.delete(db.debts).go();
          await db.delete(db.people).go();
        });
      });
      final RestoreReport report =
          await restores.apply(backup: parsed, mode: RestoreMode.replace);
      final String memory = _rss();
      rows.add('cycle $cycle: rss=$memory '
          'restored=${report.counts['people']}/${report.counts['debts']}/'
          '${report.counts['payments']}');
      // ignore: avoid_print
      print('DEVICE MEM ${rows.last}');
    }
    // ignore: avoid_print
    print('DEVICE MEM done — 6 cycles, no restart between them');
    expect((await db.debtsDao.getAll()), hasLength(2500));
  }, timeout: const Timeout(Duration(minutes: 20)));

  testWidgets('the state a killed snapshot leaves behind is recoverable',
      (WidgetTester tester) async {
    // The app's own directory, so this is the real thing: the same path the app
    // writes to on a real run.
    final Directory dir = await backupsDirectory();
    final AppDatabase db = AppDatabase.memory();
    // Written *now*, not at midnight: freshness is about write times, and a
    // ledger seeded at midnight would look older than any snapshot taken today.
    await _seedLargeLedger(db, today, people: 20, debtsPerPerson: 2);

    await db.settingsDao.write(AppSettings.initial.toCompanion());
    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupDirectoryProvider.overrideWithValue(dir),
        fileGatewayProvider.overrideWithValue(FakeFileGateway()),
        // The file system is what this test is about. The delivery plugin is
        // covered by `notifications_on_device_test.dart`; leaving the real one
        // in place here would arm alarms from a test and, on a device where the
        // plugin has not been initialised by `main`, hang the rebuild.
        notificationServiceProvider.overrideWithValue(
          NotificationService(gateway: FakeNotificationGateway()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final BackupService backups = container.read(backupServiceProvider);
    final BackupCoordinator coordinator =
        container.read(backupCoordinatorProvider);

    // A snapshot that finished, and then work the user did: enough of it that
    // the policy considers it worth saving at the next boundary — which is what
    // "the app was being used when it died" looks like from here.
    final ({File file, ParsedBackup backup}) good =
        await backups.create(kind: BackupKind.manual);
    final String goodContents = await good.file.readAsString();
    final DateTime after = DateTime.now();
    // A real install always has its settings row — it is written on first launch.
  // The providers that read it wait for it, so a ledger without one is not a
  // state any screen is designed to meet.
  await db.settingsDao.write(AppSettings.initial.toCompanion());
  await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
          for (int i = 0; i < BackupCoordinator.mutationThreshold; i++)
            PeopleCompanion.insert(
              id: 'after-the-snapshot-$i',
              name: 'شخص بعد النسخة $i',
              createdAt: after,
              updatedAt: after,
            ),
        ]));

    // The kill: a write that never finished, which is what the process leaves
    // behind when it dies between the first byte and the rename.
    final File partial = File(
      '${dir.path}/dhimmah-auto-${DateTime.now().millisecondsSinceEpoch}'
      '${BackupFormat.extension}.tmp',
    );
    await partial.writeAsString(goodContents.substring(0, goodContents.length ~/ 3));

    final List<BackupFileInfo> all = await backups.list();
    // ignore: avoid_print
    print('DEVICE after a killed write: files=${all.map((BackupFileInfo i) => i.name).join(', ')} '
        'temporaries on disk='
        '${dir.listSync().where((FileSystemEntity e) => e.path.endsWith('.tmp')).length}');

    // ignore: avoid_print
    print('DEVICE step 1: inspecting ${all.length} file(s)');
    // 1. The snapshot that finished is intact, and every file the app offers is
    //    a usable backup: the half-written one is not offered at all, because a
    //    file only receives a snapshot's name once it is complete.
    expect(await good.file.readAsString(), goodContents);
    expect(all, isNotEmpty);
    for (final BackupFileInfo info in all) {
      expect((await backups.inspect(info.path)).isUsable, isTrue,
          reason: '${info.name} must be restorable');
    }

    // ignore: avoid_print
    print('DEVICE step 2: ledger is untouched');
    // 2. The ledger itself is untouched by the kill.
    expect((await db.debtsDao.getAll()), hasLength(40));
    expect(
      (await db.peopleDao.getAll()),
      hasLength(20 + BackupCoordinator.mutationThreshold),
    );

    // 3. The app does not believe the killed write happened: the newest file is
    //    the one that finished, and the work done since counts as pending.
    expect(all.first.kind, BackupKind.manual);
    expect(all.first.path, good.file.path);
    // ignore: avoid_print
    print('DEVICE step 3: pending = ${await coordinator.pendingChanges()}');
    expect(await coordinator.pendingChanges(), greaterThan(0),
        reason: 'the killed snapshot must not be counted as saved');

    // 4. The next boundary takes a fresh snapshot...
    // ignore: avoid_print
    print('DEVICE step 4: taking a fresh snapshot');
    final BackupFileInfo? fresh =
        await coordinator.runIfDue(leavingForeground: true);
    // ignore: avoid_print
    print('DEVICE step 4 done: ${fresh?.name}');
    expect(fresh, isNotNull, reason: 'a fresh snapshot is taken');

    // 5. ...which clears the abandoned half-file, so nothing accumulates.
    expect(
      dir.listSync().where((FileSystemEntity e) => e.path.endsWith('.tmp')),
      isEmpty,
      reason: 'an abandoned temporary file is removed, not accumulated',
    );

    // 6. And the file written after the kill is itself restorable.
    expect((await backups.inspect(fresh!.path)).isUsable, isTrue);
    expect(
      (await backups.read(fresh.path)).rows('people'),
      hasLength(20 + BackupCoordinator.mutationThreshold),
      reason: 'the snapshot taken after the kill has the work in it',
    );

    // 7. Retention still holds: the snapshot taken before the kill is still
    //    there alongside the new one, and the ledger can still be restored from
    //    what is on disk. (The exact number of files depends on what earlier
    //    runs left on this device, which is the point of asserting the
    //    properties rather than a count.)
    expect(
      (await backups.list()).where((BackupFileInfo i) => i.path == good.file.path),
      hasLength(1),
      reason: 'the snapshot that finished survived the kill',
    );
    await db.transaction(() async {
      await db.delete(db.debtPeople).go();
      await db.delete(db.debts).go();
      await db.delete(db.people).go();
    });
    // ignore: avoid_print
    print('DEVICE step 7: restoring from the snapshot taken after the kill');
    await container.read(backupRestoreServiceProvider).apply(
          backup: await backups.read(fresh.path),
          mode: RestoreMode.replace,
        );
    // ignore: avoid_print
    print('DEVICE step 7 done');
    expect((await db.debtsDao.getAll()), hasLength(40));

    // Not closed, for the reason given in the first test: the provider graph
    // holds live streams and `close` waits for them. Stopping the coordinator is
    // what matters, and that happens when the container is disposed.
    await coordinator.dispose();
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('a backup that left the app can be restored after a reinstall',
      (WidgetTester tester) async {
    // Nothing of this ledger is on the device: this is the state after the app
    // was deleted and installed again, with the user's own file on disk.
    final Directory root = await getApplicationDocumentsDirectory();
    final String exportedPath = '${root.path}/$exportName';
    expect(
      await File(exportedPath).exists(),
      isTrue,
      reason: 'the exported copy must be in place — the reinstall script puts '
          'it back before this phase runs',
    );

    final AppDatabase db = AppDatabase.memory();
    final Directory dir = await backupsDirectory();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupDirectoryProvider.overrideWithValue(dir),
        fileGatewayProvider.overrideWithValue(
          FakeFileGateway(pick: exportedPath),
        ),
        notificationServiceProvider.overrideWithValue(
          NotificationService(gateway: FakeNotificationGateway()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final BackupService backups = container.read(backupServiceProvider);
    expect(await db.peopleDao.getAll(), isEmpty, reason: 'a fresh install');

    // The verdict the restore screen shows before anything is written.
    final ({ParsedBackup backup, BackupValidation validation}) opened =
        await backups.open(exportedPath);
    expect(opened.validation.isUsable, isTrue,
        reason: opened.validation.errors.join(' | '));
    // ignore: avoid_print
    print('DEVICE imported from outside the app: '
        '${opened.validation.preview!.counts}');

    final RestoreReport report = await container
        .read(backupRestoreServiceProvider)
        .apply(backup: opened.backup, mode: RestoreMode.replace);
    // ignore: avoid_print
    print('DEVICE imported counts: ${report.counts}');

    expect(report.counts['people'], 500);
    expect(report.counts['debts'], 2500);
    expect(report.counts['payments'], 10000);
    expect(
      report.safetyBackupPath,
      isNull,
      reason: 'nothing was on the device to protect',
    );

    // The records are usable: the search reads them, the ledger counts them.
    final int total = (await db.debtsDao.getAll())
        .fold<int>(0, (int sum, DebtRow row) => sum + row.principalMinor);
    expect(total, greaterThan(0));
    // ignore: avoid_print
    print('DEVICE after import: ${report.counts['people']} people, '
        '${report.counts['debts']} records, total minor units $total');
  }, timeout: const Timeout(Duration(minutes: 15)));
}

/// This process's resident memory, from the kernel. Null when the platform does
/// not let an app read its own status — which is recorded as unavailable rather
/// than guessed at.
String _rss() {
  try {
    final String status = File('/proc/self/status').readAsStringSync();
    for (final String line in status.split('\n')) {
      if (line.startsWith('VmRSS:')) {
        final int kb = int.parse(line.split(RegExp(r'\s+'))[1]);
        return '${(kb / 1024).toStringAsFixed(0)} MB';
      }
    }
    return 'VmRSS absent';
  } on Object catch (error) {
    return 'unavailable ($error)';
  }
}

double _p(List<Duration> values, double percentile) {
  if (values.isEmpty) return 0;
  final List<int> micros = <int>[for (final Duration d in values) d.inMicroseconds]..sort();
  final int index = ((micros.length - 1) * percentile).round();
  return micros[index] / 1000;
}

Future<void> _seedLargeLedger(
  AppDatabase db,
  DateTime today, {
  required int people,
  required int debtsPerPerson,
}) async {
  // A real install always has its settings row — it is written on first launch.
  // The providers that read it wait for it, so a ledger without one is not a
  // state any screen is designed to meet.
  await db.settingsDao.write(AppSettings.initial.toCompanion());
  await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
        for (int i = 0; i < people; i++)
          PeopleCompanion.insert(
            id: 'p$i',
            name: 'شخص رقم $i',
            createdAt: today,
            updatedAt: today,
          ),
      ]));
  final List<DebtsCompanion> debts = <DebtsCompanion>[
    for (int p = 0; p < people; p++)
      for (int d = 0; d < debtsPerPerson; d++)
        DebtsCompanion.insert(
          id: 'd${p}_$d',
          personId: Value<String>('p$p'),
          direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
          title: Value<String>('قرض $d للشخص $p'),
          principalMinor: 100000 + d * 1000,
          currencyCode: AppCurrency.inr.code,
          issuedAt: addDays(today, -100 - d),
          dueAt: Value<DateTime>(addDays(today, d)),
          recurrence: RecurrenceFrequency.none,
          createdAt: today,
          updatedAt: today,
        ),
  ];
  await db.batch((Batch b) => b.insertAll(db.debts, debts));
  await db.batch((Batch b) => b.insertAll(db.debtPeople, <DebtPeopleCompanion>[
        for (final DebtsCompanion d in debts)
          DebtPeopleCompanion.insert(
            debtId: d.id.value,
            personId: d.personId.value!,
            createdAt: today,
          ),
      ]));
  await db.batch((Batch b) => b.insertAll(db.payments, <PaymentsCompanion>[
        for (final DebtsCompanion d in debts)
          for (int k = 0; k < 4; k++)
            PaymentsCompanion.insert(
              id: 'pay${d.id.value}_$k',
              debtId: Value<String>(d.id.value),
              personId: d.personId,
              amountMinor: 5000,
              currencyCode: AppCurrency.inr.code,
              paidAt: addDays(today, -20 + k),
              createdAt: today,
            ),
      ]));
}
