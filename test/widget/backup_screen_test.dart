import 'dart:convert';
import 'dart:io';


import 'package:dhimmah/app/backup_providers.dart';
import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/widgets/async_value_view.dart';
import 'package:dhimmah/core/widgets/settings_tile.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/features/settings/backup_screen.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';
import '../support/fake_backup_location.dart';
import '../support/fake_file_gateway.dart';
import '../support/fake_notification_gateway.dart';

/// The backup screen, driven the way the app drives it.
///
/// The service tests prove what a snapshot contains and what a restore does to
/// the ledger. What they cannot see is whether the screen tells the truth about
/// it: whether the history follows the files, whether a deletion that fails
/// leaves the row alone *and says so*, and whether an emptied history becomes an
/// empty state without the user closing and reopening anything. Those are
/// behaviours of the screen, so they are tested through the screen.
///
/// The screen is reached through its real route rather than by pumping the
/// widget on its own, so the providers, the service and the directory are the
/// ones a running app builds.
void main() {
  late AppDatabase db;
  late Directory dir;

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    db = AppDatabase.memory();
    dir = await Directory.systemTemp.createTemp('dhimmah-backup-screen');
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) {
      // A test that made the directory read-only to force a real failure has to
      // hand the permission back before the directory can be removed.
      await _chmod(dir.path, 'u+rwx');
      await dir.delete(recursive: true);
    }
  });

  Future<void> chmodReadOnly(String path) => _chmod(path, 'a-w');

  /// Real work, on the real event loop.
  ///
  /// A test body runs inside a fake clock, where a `dart:io` future — writing a
  /// file, renaming it, deleting it — never completes, because nothing is
  /// driving the event loop it is waiting on. Anything that touches the file
  /// system has to go through here or the test hangs rather than fails.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
    final T? value = await tester.runAsync(body);
    return value as T;
  }

  /// Lets the real futures — file reads, database reads — actually run while
  /// frames keep being produced.
  ///
  /// A test body runs inside a fake clock, so real work only advances during
  /// `runAsync`, and its result only reaches the widgets on a later `pump`.
  /// Both halves are needed, in that order, which is why they are one call.
  ///
  /// The trailing frames matter as much as the rest: real work finishes inside
  /// `runAsync`, so a sheet that only appears once its list has been read starts
  /// sliding in on the *last* round — and an animation is driven by the frame
  /// clock, not by the real one. Without them the press is sent to a rectangle
  /// the sheet has not reached yet, and the tap silently misses.
  Future<void> settle(WidgetTester tester, {int rounds = 6}) async {
    for (int i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pumps until [done] holds, or fails saying what it waited for.
  ///
  /// The screen shows what the providers hold, so a test that needs a *value*
  /// waits on the provider rather than on a frame count. A fixed number of pumps
  /// is a guess about how long a directory read takes, and a test that passes
  /// only on a fast machine is worse than one that never passes.
  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() done,
    String what, {
    int rounds = 80,
  }) async {
    for (int i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (done()) return;
    }
    // A timeout with no picture of the screen is a guess. The texts are the
    // cheapest honest answer to "what was on stage instead?".
    // ignore: avoid_print
    print('--- waiting for "$what"; the screen showed: '
        '${tester
            .widgetList<Text>(find.byType(Text))
            .map((Text t) => t.data)
            .where((String? t) => t != null && t.trim().isNotEmpty)
            .toList()}');
    fail('timed out waiting for $what');
  }

  /// A ledger with something in it, so the screen has local data to talk about.
  Future<void> seedLedgerData() async {
    final Person person = await buildService(
      db,
      notifications: NotificationService(gateway: FakeNotificationGateway()),
    ).createPerson(const PersonDraft(name: 'أحمد محمد'));
    expect(person.id, isNotEmpty);
  }

  /// Snapshots written by the service itself, dated apart so the listing has a
  /// deterministic newest-first order rather than one decided by the file system.
  Future<List<BackupFileInfo>> seedBackups(
    WidgetTester tester,
    int count,
  ) async {
    final BackupService service = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    );
    return real(tester, () async {
      final DateTime base = DateTime.now();
      for (int i = 0; i < count; i++) {
        await service.create(
          kind: BackupKind.manual,
          now: base.subtract(Duration(days: i)),
        );
      }
      return service.list();
    });
  }

  /// Opens the backup screen through its real route and waits until its status
  /// has actually been read, so the rows exist to be pressed.
  ///
  /// [folder] is the repository the screen sees. A test that hands one in
  /// controls what the folder holds, which is how the folder's states are
  /// reached without a phone.
  Future<ProviderContainer> openBackupScreen(
    WidgetTester tester, {
    FakeFileGateway? gateway,
    FakeBackupLocationRepository? folder,
  }) async {
    // A phone-width viewport, tall enough for the whole screen to be built: the
    // settings rows live in a lazy list, and a row that is never laid out is a
    // row no finder can see.
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 3.2;
    addTearDown(tester.view.reset);

    final FakeBackupLocationRepository folders =
        folder ?? FakeBackupLocationRepository();
    final ProviderContainer container = await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial,
      notificationPermission: NotificationPermission.granted,
      fileGateway: gateway ?? FakeFileGateway(),
      backupDirectory: dir,
      backupFolders: folders,
    );
    await settle(tester);
    // The router has to be looked up from *inside* the routed content: the app
    // widget is what builds the router, so its own element sits above it.
    final BuildContext inside = tester.element(find.byType(Scaffold).first);
    GoRouter.of(inside).go(AppRoutes.backup);
    // The route needs frames to arrive; the screen is on stage as soon as it
    // does, whether or not its first read has finished.
    await settle(tester);
    expect(
      find.byType(BackupScreen),
      findsOneWidget,
      reason: 'the screen under test has to be the one that is on stage',
    );

    await settleUntil(
      tester,
      () => container.read(backupStatusProvider).hasValue,
      'the backup status to be read',
    );
    await settleUntil(
      tester,
      () => container.read(backupLocationHealthProvider).hasValue,
      'the backup folder to be read',
    );
    await settle(tester);
    return container;
  }

  /// The listing the screen is showing, read from the same place the screen
  /// reads it — the authority the visible rows have to agree with.
  Future<List<BackupFileInfo>> authoritative(
    WidgetTester tester,
    ProviderContainer container,
  ) =>
      real(tester, () => container.read(backupServiceProvider).list());

  /// Scrolls a settings row into view before tapping it: the history row sits
  /// below the fold on a phone-shaped viewport.
  Future<void> tapRow(WidgetTester tester, String label) async {
    final Finder row = find.text(label);
    if (row.evaluate().isEmpty) {
      // ignore: avoid_print
      print('--- no "$label". Texts on screen: '
          '${tester.widgetList<Text>(find.byType(Text)).map((Text t) => t.data).toList()}');
      // ignore: avoid_print
      print('--- spinner=${find.byType(CircularProgressIndicator).evaluate().length} '
          'skeleton=${find.byType(SkeletonBox).evaluate().length} '
          'list=${find.byType(ListView).evaluate().length} '
          'tile=${find.byType(SettingsTile).evaluate().length} '
          'scrollable=${find.byType(Scrollable).evaluate().length}');
    }
    expect(row, findsWidgets, reason: 'no row labelled "$label" on the screen');
    await tester.ensureVisible(row.first);
    await settle(tester);
    await tester.tap(row.first);
    await settle(tester);
  }

  Finder deleteButtons() => find.byTooltip(l10n.backupDeleteAction);

  /// A real, acceptable backup, for filling the folder with.
  List<int> realBackupBytes() => FakeBackupLocationRepository().realBackup();

  List<String> filesOnDisk() => dir
      .listSync()
      .whereType<File>()
      .map((File f) => f.uri.pathSegments.last)
      .where((String name) => name.endsWith('.dhimmah'))
      .toList()
    ..sort();

  testWidgets('the history lists the files that are on disk', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final List<BackupFileInfo> written = await seedBackups(tester, 2);
    expect(written, hasLength(2));

    final ProviderContainer container = await openBackupScreen(tester);
    await tapRow(tester, l10n.backupPreviousAction);

    expect(
      find.text(l10n.backupPreviousTitle),
      findsWidgets,
      reason: 'the sheet is open',
    );
    expect(
      deleteButtons(),
      findsNWidgets(2),
      reason: 'one row per snapshot on disk, newest first',
    );
    expect(
      await authoritative(tester, container),
      hasLength(2),
      reason: 'and the authority agrees with what is shown',
    );
  });

  testWidgets('deleting a snapshot leaves the row gone while the sheet stays open', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    await seedBackups(tester, 3);

    final ProviderContainer container = await openBackupScreen(tester);
    await tapRow(tester, l10n.backupPreviousAction);
    expect(deleteButtons(), findsNWidgets(3));

    final List<String> before = filesOnDisk();
    expect(before, hasLength(3));

    await tester.tap(deleteButtons().first);
    // The wait *is* the assertion: the row has to go while the sheet is open, so
    // the test waits for exactly that and fails if it never happens.
    await settleUntil(
      tester,
      () => deleteButtons().evaluate().length == 2,
      'the open sheet to drop the deleted row',
    );

    // The sheet is still the one that was open: its own close action is there,
    // and no sheet was reopened for the assertion to hold.
    expect(
      find.text(l10n.actionClose),
      findsOneWidget,
      reason: 'the sheet must not have been closed and reopened',
    );

    final List<String> after = filesOnDisk();
    expect(after, hasLength(2), reason: 'and the file really was deleted');
    expect(
      before.toSet().difference(after.toSet()),
      hasLength(1),
      reason: 'exactly one file left the disk',
    );
    expect(
      deleteButtons(),
      findsNWidgets(after.length),
      reason: 'the visible rows and the authoritative listing agree',
    );
    expect(
      await authoritative(tester, container),
      hasLength(2),
      reason: 'and the deletion reached the source of truth, not just the sheet',
    );
  });

  testWidgets('emptying the history shows the empty state in the open sheet', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    await seedBackups(tester, 2);

    await openBackupScreen(tester);
    await tapRow(tester, l10n.backupPreviousAction);

    for (int i = 0; i < 2; i++) {
      await tester.tap(deleteButtons().first);
      await settleUntil(
        tester,
        () => deleteButtons().evaluate().length == 1 - i,
        'the open sheet to drop row ${i + 1}',
      );
    }

    expect(filesOnDisk(), isEmpty);
    expect(find.text(l10n.backupPreviousEmpty), findsOneWidget);
    expect(deleteButtons(), findsNothing);
    expect(
      find.text(l10n.actionClose),
      findsOneWidget,
      reason: 'the empty state is shown in the same open sheet',
    );
  });

  testWidgets('a snapshot that has already gone is not an error', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final List<BackupFileInfo> written = await seedBackups(tester, 2);

    await openBackupScreen(tester);
    await tapRow(tester, l10n.backupPreviousAction);
    expect(deleteButtons(), findsNWidgets(2));

    // The file leaves behind the app's back — a cleaner, another device, a
    // restore of the folder — while the sheet still lists it.
    await real(tester, () => File(written.first.path).delete());
    expect(filesOnDisk(), hasLength(1));

    await tester.tap(deleteButtons().first);
    await settleUntil(
      tester,
      () => deleteButtons().evaluate().length == 1,
      'the row for the already-absent file to leave the open sheet',
    );

    expect(
      find.text(l10n.backupDeleteFailed),
      findsNothing,
      reason: 'a file that is already absent is not a failure',
    );
  });

  testWidgets('a deletion that fails keeps the row and names the failure', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    await seedBackups(tester, 2);

    await openBackupScreen(tester);
    await tapRow(tester, l10n.backupPreviousAction);
    expect(deleteButtons(), findsNWidgets(2));

    // A real refusal from the operating system, not a stubbed one: without write
    // permission on the directory the file cannot be removed, which is the same
    // thing that happens when the storage is read-only or the file is held open.
    await real(tester, () => chmodReadOnly(dir.path));
    addTearDown(() => _chmod(dir.path, 'u+rwx'));

    await tester.tap(deleteButtons().first);
    await settleUntil(
      tester,
      () => find.text(l10n.backupDeleteFailed).evaluate().isNotEmpty,
      'the failure to be named',
    );

    expect(
      deleteButtons(),
      findsNWidgets(2),
      reason: 'a deletion that failed must leave the row where it was',
    );
    expect(filesOnDisk(), hasLength(2), reason: 'nothing was removed');
  });

  testWidgets('sharing a copy adds a row to the history', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeFileGateway gateway = FakeFileGateway();
    final ProviderContainer container =
        await openBackupScreen(tester, gateway: gateway);

    expect(filesOnDisk(), isEmpty);
    await tapRow(tester, l10n.backupShareTile);

    // The offer to the share sheet comes after the file is written, so the wait
    // is on the offer itself rather than on the file.
    await settleUntil(
      tester,
      () => gateway.shared.isNotEmpty,
      'the new snapshot to be offered to the share sheet',
    );
    expect(
      gateway.shared,
      hasLength(1),
      reason: 'the copy is offered to the system share sheet exactly once',
    );
    expect(filesOnDisk(), hasLength(1));

    final List<BackupFileInfo> listed = await authoritative(tester, container);
    expect(listed, hasLength(1), reason: 'and the authority knows about it');

    // The history row is disabled until the screen has been told about the new
    // snapshot, so the wait is on the screen's own state, not on the file.
    await settleUntil(
      tester,
      () => container.read(backupStatusProvider).value?.snapshots == 1,
      'the screen to account for the new snapshot',
    );
    await tapRow(tester, l10n.backupPreviousAction);
    expect(deleteButtons(), findsNWidgets(1));
  });

  testWidgets('the history row counts copies, not days', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    await seedBackups(tester, 2);
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used();
    folders.addFile('in-the-folder.dhimmah', folders.realBackup());
    final ProviderContainer container =
        await openBackupScreen(tester, folder: folders);

    await settleUntil(
      tester,
      () => container.read(backupStatusProvider).value?.snapshots == 2,
      'the screen to account for the two snapshots inside the app',
    );
    await settleUntil(
      tester,
      () => container.read(backupLocationHealthProvider).value?.validBackups == 1,
      'the folder to report the copy it holds',
    );
    await settle(tester);

    expect(
      find.text(l10n.backupCopiesCount(3)),
      findsOneWidget,
      reason: 'two copies inside the app plus one in the folder is three',
    );
    expect(
      find.text(l10n.dateDayCount(3)),
      findsNothing,
      reason: 'the row used the day-count plural, so three stored copies were '
          'labelled "3 أيام" — three days — on the row that leads to them',
    );
  });

  testWidgets('saving an external copy confirms only after the file is verified', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used();
    final ProviderContainer container =
        await openBackupScreen(tester, folder: folders);

    await tapRow(tester, l10n.backupNowAction);
    // The confirmation is the *last* step: it waits for the write and for the
    // read-back check, and it is the only place the app says a file was saved.
    await settleUntil(
      tester,
      () => find.text(l10n.backupExternalSaved).evaluate().isNotEmpty,
      'the verified save to be confirmed',
    );

    expect(folders.files, hasLength(1), reason: 'one document, in the folder');
    // And the confirmation names the file as the folder holds it.
    expect(
      find.textContaining(folders.files.keys.single),
      findsOneWidget,
      reason: 'the name shown is the one the folder reports',
    );
    expect(filesOnDisk(), hasLength(1), reason: 'and the internal snapshot exists');
    await settleUntil(
      tester,
      () => container.read(backupStatusProvider).value?.snapshots == 1,
      'the history to account for the snapshot',
    );
  });

  testWidgets('a save that cannot be verified reports the failure', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    // The folder keeps what it was given but hands back something else of the
    // same length, so the read-back cannot vouch for the file — the case where
    // saying "saved" would be a lie about a file nobody checked.
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used()..corruptReads = true;
    await openBackupScreen(tester, folder: folders);

    await tapRow(tester, l10n.backupNowAction);
    await settleUntil(
      tester,
      () => find.text(l10n.backupExternalFailedReadBack).evaluate().isNotEmpty,
      'the failure to be named',
    );

    expect(
      find.text(l10n.backupExternalSaved),
      findsNothing,
      reason: 'a file that could not be verified is never called saved',
    );
  });

  testWidgets('sharing a copy goes to the share sheet, not to a chooser', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeFileGateway gateway = FakeFileGateway();
    await openBackupScreen(tester, gateway: gateway);

    await tapRow(tester, l10n.backupShareTile);
    // The snapshot is written first, so the wait is on the offer itself.
    await settleUntil(
      tester,
      () => gateway.shared.isNotEmpty,
      'the copy to be offered to the share sheet',
    );
    await settle(tester);

    expect(gateway.shared, hasLength(1), reason: 'offered exactly once');
    expect(gateway.savePrompts, 0, reason: 'sharing never asks for a file');
    expect(find.text(l10n.backupExternalSaved), findsNothing);
    expect(
      find.text(l10n.backupExternalFailedWrite),
      findsNothing,
      reason: 'a share is not a save, and says neither',
    );
  });

  testWidgets('with no folder chosen, the screen offers the setup', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    await openBackupScreen(tester);

    expect(
      find.text(l10n.backupFolderSetupTitle),
      findsOneWidget,
      reason: 'the first-run state, offered as a place to set up',
    );
    expect(find.text(l10n.backupFolderChoose), findsOneWidget);
  });

  testWidgets('a chosen folder shows its state and its count', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used()
      ..addFile('dhimmah-manual-a.dhimmah', realBackupBytes())
      ..addFile('dhimmah-manual-b.dhimmah', realBackupBytes());
    await openBackupScreen(tester, folder: folders);

    expect(find.text(l10n.backupFolderTitle), findsOneWidget);
    expect(find.text(l10n.backupFolderAvailable), findsOneWidget);
    expect(find.text(l10n.backupFolderBackupsCount(2)), findsOneWidget);
    expect(find.text(l10n.backupFolderChange), findsOneWidget);
    expect(find.text(l10n.backupFolderCheck), findsOneWidget);
  });

  testWidgets('a folder holding files that are not backups says so', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used()
      ..addFile('dhimmah-manual-real.dhimmah', realBackupBytes())
      ..addFile('dhimmah-manual-broken.dhimmah', utf8.encode('{"no":true}'));
    await openBackupScreen(tester, folder: folders);

    expect(find.text(l10n.backupFolderInvalidNote(1)), findsOneWidget);
  });

  testWidgets('a revoked folder is not shown as available', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used()
      ..persisted = false;
    await openBackupScreen(tester, folder: folders);

    expect(find.text(l10n.backupFolderAvailable), findsNothing);
    // The app's own sentence, not the platform's. This row used to prefer
    // `health.detail`, which on the phone was the provider's exception text —
    // "Failed to determine if primary:Documents/Dhimmah Backups is child of
    // primary:Documents: java.io.FileNotFoundException…" — printed in English
    // under an Arabic heading, saying nothing about what to do next.
    expect(find.text(l10n.backupFolderLostAccess), findsOneWidget);
    expect(
      find.text(l10n.backupFolderReauthorize),
      findsOneWidget,
      reason: 'the way back is offered, not just the bad news',
    );
  });

  testWidgets('a reinstall with copies in the folder offers the restore', (
    WidgetTester tester,
  ) async {
    // Nothing in the ledger and nothing inside the app, but the user's folder
    // holds copies — the state a reinstall lands in, and the one path a
    // reinstall has to walk. The screen read "a copy can be restored" and
    // offered nothing to press, because the card that carries the action was
    // shown by asking whether the *app* had a snapshot of its own. Found on the
    // phone, on the recovery path itself.
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used()
      ..addFile('dhimmah-manual-external.dhimmah', realBackupBytes());
    await openBackupScreen(tester, folder: folders);

    expect(find.text(l10n.backupProtectionRecoverable), findsOneWidget);
    expect(find.text(l10n.backupFoundTitle), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, l10n.backupRestoreAction),
      findsOneWidget,
      reason: 'a state that says something can be put back has to carry the way '
          'to put it back',
    );
  });

  testWidgets('the history shows the folder and the app separately', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used()
      ..addFile('dhimmah-manual-external.dhimmah', realBackupBytes());
    // One internal snapshot, written before the screen opens, so the history
    // row is enabled from the first frame. Real work, so it goes through
    // `real`: the reader yields between pages, and a yield is a timer that the
    // fake clock only fires when frames are pumped.
    await real(
      tester,
      () => BackupService(
        database: db,
        appVersion: '1.0.0+1',
        clock: DateTime.now,
        directory: dir,
      ).create(kind: BackupKind.manual),
    );
    final ProviderContainer container = await openBackupScreen(tester, folder: folders);

    await tapRow(tester, l10n.backupPreviousAction);
    await settleUntil(
      tester,
      () => find.text(l10n.backupHistoryFolder).evaluate().isNotEmpty,
      'the folder section to appear',
    );

    expect(find.text(l10n.backupHistoryFolder), findsOneWidget);
    expect(find.text(l10n.backupHistoryInternal), findsOneWidget);
    expect(
      find.text('dhimmah-manual-external.dhimmah'),
      findsOneWidget,
      reason: 'the folder\'s copy is listed by its own name',
    );
    expect(
      container.read(backupLocationRepositoryProvider),
      same(folders),
      reason: 'the screen reads the folder the test controls',
    );
  });

  testWidgets('deleting a copy from the folder updates the open sheet', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    final FakeBackupLocationRepository folders = FakeBackupLocationRepository.used()
      ..addFile('dhimmah-manual-only.dhimmah', realBackupBytes());
    await openBackupScreen(tester, folder: folders);

    await tapRow(tester, l10n.backupPreviousAction);
    await settleUntil(
      tester,
      () => find.byTooltip(l10n.backupDeleteAction).evaluate().isNotEmpty,
      'the folder\'s row to appear',
    );

    await tester.tap(find.byTooltip(l10n.backupDeleteAction).first);
    await settleUntil(
      tester,
      () => find.byTooltip(l10n.backupDeleteAction).evaluate().isEmpty,
      'the row to leave the open sheet',
    );

    // While the sheet is still open, it says the folder has nothing left.
    expect(
      find.text(l10n.backupPreviousEmpty),
      findsOneWidget,
      reason: 'the folder is empty, and the sheet says so without being closed '
          'and reopened — which is the whole point of the test',
    );
    expect(folders.files, isEmpty, reason: 'and the file really left the folder');

    // And the screen behind agrees, once it is back in view. The list had to be
    // scrolled to reach the history row, and a card that has scrolled out of a
    // lazy list is not built at all — so it is scrolled back and *then*
    // asserted, rather than treated as missing because it is off-screen.
    await tester.tap(find.text(l10n.actionClose).last);
    await settle(tester);
    for (int i = 0; i < 4 && find.text(l10n.backupFolderEmpty).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 600));
      await settle(tester);
    }
    expect(
      find.text(l10n.backupFolderEmpty),
      findsOneWidget,
      reason: 'the folder card on the screen behind reflects the folder it is '
          'describing, not what it held when the screen was first read',
    );
  });

  testWidgets('a copy inside the app restores with one press — no file picker', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    // A snapshot of the current ledger, then a second person added *after* it:
    // the restore must take the ledger back to one person.
    await seedBackups(tester, 1);
    final ProviderContainer container = await openBackupScreen(tester);
    await buildService(db).createPerson(const PersonDraft(name: 'سارة بعد النسخة'));
    await settleUntil(
      tester,
      () => container.read(backupStatusProvider).value != null,
      'the screen to settle',
    );

    await tapRow(tester, l10n.backupPreviousAction);
    await settleUntil(
      tester,
      () => find.byTooltip(l10n.backupRestoreAction).evaluate().isNotEmpty,
      'the history rows to offer restore',
    );

    await tester.tap(find.byTooltip(l10n.backupRestoreAction).first);
    // The preview is the gate: replace or merge, with the counts, before
    // anything changes.
    await settleUntil(
      tester,
      () => find.text(l10n.backupModeReplace).evaluate().isNotEmpty,
      'the restore preview to appear',
    );
    expect(
      find.text(l10n.backupModeMerge),
      findsOneWidget,
      reason: 'the two modes stay distinct',
    );

    // The preview is taller than the screen: its modes and its confirm button
    // live below the fold, inside the sheet's own scroll view. Scrolling to the
    // *button* (not to a text inside it) is what makes the tap land.
    final Finder confirm = find.ancestor(
      of: find.text(l10n.backupRestoreConfirm),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(confirm);
    await settle(tester);
    await tester.ensureVisible(confirm);
    await settle(tester);
    await tester.tap(confirm, warnIfMissed: false);
    await settleUntil(
      tester,
      () => find.text(l10n.backupRestoreDone).evaluate().isNotEmpty,
      'the restore to finish',
    );

    // And the ledger went back: the person added after the snapshot is gone.
    final int people = (await db.peopleDao.getAll()).length;
    expect(people, 1, reason: 'the snapshot held one person');
  });

  testWidgets('a file that is not a backup is refused, and the ledger is untouched', (
    WidgetTester tester,
  ) async {
    await seedLedgerData();
    // A real file with the right name and the wrong contents: the extension is
    // never the authority.
    final File impostor = File('${dir.path}/renamed.dhimmah');
    await real(tester, () => impostor.writeAsString('{"not":"a backup"}'));

    await openBackupScreen(tester, gateway: FakeFileGateway(pick: impostor.path));
    final int debtsBefore = (await db.debtsDao.getAll()).length;

    await tapRow(tester, l10n.backupRestoreAction);
    await settleUntil(
      tester,
      () => find.text(l10n.backupRestoreNotOurs).evaluate().isNotEmpty,
      'the refusal to be shown',
    );

    expect(
      find.text(l10n.backupRestoreNotOurs),
      findsOneWidget,
      reason: 'the reason is named in the user\'s words, not as a code',
    );
    expect(
      (await db.debtsDao.getAll()).length,
      debtsBefore,
      reason: 'a refused file must not have touched the ledger',
    );
  });
}

/// `chmod` is not in `dart:io`, and the permissions *are* the point of two of
/// these tests, so they are set with the one tool that sets them.
Future<void> _chmod(String path, String mode) async {
  final ProcessResult result = await Process.run('chmod', <String>[mode, path]);
  if (result.exitCode != 0) {
    throw StateError('chmod $mode $path failed: ${result.stderr}');
  }
}
