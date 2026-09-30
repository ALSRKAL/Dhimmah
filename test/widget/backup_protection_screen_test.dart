import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:dhimmah/app/backup_providers.dart';
import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/widgets/settings_tile.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../support/app_harness.dart';
import '../support/fake_backup_location.dart';
import '../support/fake_file_gateway.dart';
import '../support/fake_notification_gateway.dart';

/// What the screen says about protection, in each state it can be in.
///
/// The engine that decides the state is tested on its own, exhaustively and
/// without a widget tree. What those tests cannot show is that the screen *says*
/// it — that the one sentence a user reads is the sentence their situation
/// deserves, and that the states where the app is coping do not look like the
/// states where it is not.
void main() {
  late AppDatabase db;
  late Directory dir;

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    db = AppDatabase.memory();
    dir = await Directory.systemTemp.createTemp('dhimmah-protection-screen');
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

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

  Future<void> settleUntil(
    WidgetTester tester,
    bool Function() done,
    String what,
  ) async {
    for (int i = 0; i < 80; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (done()) return;
    }
    // ignore: avoid_print
    print('--- waiting for "$what"; the screen showed: '
        '${tester.widgetList<Text>(find.byType(Text)).map((Text t) => t.data).toList()}');
    fail('timed out waiting for $what');
  }

  Future<ProviderContainer> openScreen(
    WidgetTester tester,
    FakeBackupLocationRepository folders, {
    AppSettings? settings,
  }) async {
    // Tall and wide enough that the whole screen is built: the protection card
    // is the first thing on it, and a widget that was never laid out is a widget
    // no finder can see.
    tester.view.physicalSize = const Size(1200, 5200);
    tester.view.devicePixelRatio = 3.2;
    addTearDown(tester.view.reset);

    final ProviderContainer container = await pumpDhimmah(
      tester,
      db: db,
      settings: settings ?? AppSettings.initial,
      notificationPermission: NotificationPermission.granted,
      fileGateway: FakeFileGateway(),
      backupDirectory: dir,
      backupFolders: folders,
    );
    await settle(tester);
    final BuildContext inside = tester.element(find.byType(Scaffold).first);
    GoRouter.of(inside).go(AppRoutes.backup);
    await settle(tester);
    await settleUntil(
      tester,
      () => container.read(backupProtectionProvider).hasValue,
      'the protection state to be worked out',
    );
    await settle(tester);
    return container;
  }

  List<String> snapshotsOnDisk() => <String>[
        for (final FileSystemEntity entity in dir.listSync())
          if (entity.path.endsWith('.dhimmah')) entity.path,
      ];

  Future<void> seedLedger() async {
    final Person person = await buildService(
      db,
      notifications: NotificationService(gateway: FakeNotificationGateway()),
    ).createPerson(const PersonDraft(name: 'أحمد محمد'));
    expect(person.id, isNotEmpty);
  }

  Future<void> seedSnapshot(WidgetTester tester) async {
    await tester.runAsync(() async {
      await BackupService(
        database: db,
        appVersion: '1.0.0+1',
        clock: DateTime.now,
        directory: dir,
      ).create(kind: BackupKind.auto);
    });
  }

  /// The headline, asserted and then returned so a test can also state what it
  /// must *not* say.
  void expectHeadline(String expected) {
    expect(
      find.text(expected),
      findsOneWidget,
      reason: 'the card at the top of the screen is the answer to "are my data '
          'protected?", and this is the answer for this situation',
    );
  }

  testWidgets('a healthy ledger says it is protected', (WidgetTester tester) async {
    await seedLedger();
    await seedSnapshot(tester);
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());

    await openScreen(tester, folders);

    expectHeadline(l10n.backupProtectionProtected);
    expect(
      find.text(l10n.backupProtectionPending),
      findsNothing,
      reason: 'nothing is waiting, so the card must not suggest otherwise',
    );
  });

  testWidgets('a ledger with no copy anywhere says so', (
    WidgetTester tester,
  ) async {
    await seedLedger();
    await openScreen(tester, FakeBackupLocationRepository.used());

    expectHeadline(l10n.backupProtectionNever);
    expect(
      find.text(l10n.backupProtectionDataSafe),
      findsNothing,
      reason: 'this one is not a failed attempt: there has never been a copy, '
          'and saying "your data is safe" here would be the wrong reassurance',
    );
  });

  testWidgets('copies that live only inside the app are not called protection',
      (WidgetTester tester) async {
    await seedLedger();
    await seedSnapshot(tester);
    // No folder chosen: the snapshots exist, and uninstalling the app would take
    // them with it.
    await openScreen(tester, FakeBackupLocationRepository());

    expectHeadline(l10n.backupProtectionNoLocation);
  });

  testWidgets('a working install with automatic saving off does not claim protection',
      (WidgetTester tester) async {
    // Found on a real device after an upgrade: a restore carries the settings
    // with it, so an install can arrive with automatic saving switched off and
    // no memory of choosing it. The screen said "your data is protected" while
    // nothing was watching.
    await seedLedger();
    await seedSnapshot(tester);
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());

    tester.view.physicalSize = const Size(1200, 5200);
    tester.view.devicePixelRatio = 3.2;
    addTearDown(tester.view.reset);
    final ProviderContainer container = await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(backupAutoEnabled: false),
      notificationPermission: NotificationPermission.granted,
      fileGateway: FakeFileGateway(),
      backupDirectory: dir,
      backupFolders: folders,
    );
    await settle(tester);
    final BuildContext inside = tester.element(find.byType(Scaffold).first);
    GoRouter.of(inside).go(AppRoutes.backup);
    await settle(tester);
    await settleUntil(
      tester,
      () => container.read(backupProtectionProvider).hasValue,
      'the protection state to be worked out',
    );
    await settle(tester);

    expectHeadline(l10n.backupProtectionAutoOff);
    expect(
      find.text(l10n.backupProtectionProtected),
      findsNothing,
      reason: 'nothing is being added to their copies, and telling them they are '
          'protected would be true about the past and false about the future',
    );
  });

  testWidgets('changes that are waiting are said without alarm', (
    WidgetTester tester,
  ) async {
    await seedLedger();
    await seedSnapshot(tester);
    // Written *after* the snapshot, so it is not in it.
    await buildService(db).createPerson(const PersonDraft(name: 'خالد'));
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());

    await openScreen(tester, folders);

    expectHeadline(l10n.backupProtectionPending);
    expect(
      find.text(l10n.backupProtectionDataSafe),
      findsNothing,
      reason: 'waiting changes are the app\'s job; the card must not read as a '
          'failure, or the state a working app is in most of the time becomes '
          'the state that trains the user to ignore it',
    );
  });

  testWidgets('a folder whose permission was taken back needs attention', (
    WidgetTester tester,
  ) async {
    await seedLedger();
    await seedSnapshot(tester);
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());
    folders.persisted = false;

    await openScreen(tester, folders);

    expectHeadline(l10n.backupProtectionAttention);
    expect(
      find.text(l10n.backupProtectionDataSafe),
      findsTrueValue,
      reason: 'the first thing the user fears when a backup breaks is that they '
          'have lost something, and the card answers that before anything else',
    );
  });

  testWidgets('a device with no ledger and copies to restore says recoverable',
      (WidgetTester tester) async {
    // Nothing seeded: this is the reinstall.
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());

    await openScreen(tester, folders);

    expectHeadline(l10n.backupProtectionRecoverable);
    expect(
      find.text(l10n.backupProtectionNeverWorked),
      findsNothing,
      reason: 'there is a copy, so "no copy has been saved yet" would be false',
    );
  });

  testWidgets('the details are behind a control, and say more when opened', (
    WidgetTester tester,
  ) async {
    await seedLedger();
    await seedSnapshot(tester);
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());

    await openScreen(tester, folders);

    expect(
      find.text(l10n.backupDetailLastCopy),
      findsNothing,
      reason: 'the short answer is the card; the numbers are one tap away',
    );

    await tester.tap(find.text(l10n.backupProtectionDetails));
    await settle(tester);

    // The five facts the details exist to show, each in words rather than codes.
    for (final String label in <String>[
      l10n.backupDetailAutomatic,
      l10n.backupDetailLastCopy,
      l10n.backupDetailRestorable,
      l10n.backupDetailFolder,
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
    expect(find.text(l10n.backupProtectionHideDetails), findsOneWidget);
    expect(
      find.text(l10n.backupAutoStateOn),
      findsNWidgets(2),
      reason: 'twice, and both are wanted: the control says its own position, '
          'and the details row says it as a value beside its label rather than '
          'as a sentence repeating it',
    );
  });

  testWidgets('what the app promises is on the screen, in plain words', (
    WidgetTester tester,
  ) async {
    await seedLedger();
    await seedSnapshot(tester);
    await openScreen(tester, FakeBackupLocationRepository.used());

    await tester.scrollUntilVisible(
      find.text(l10n.backupProtectionHowTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.backupProtectionHowTitle), findsOneWidget);
    expect(find.text(l10n.backupProtectionHowBody), findsOneWidget);
  });

  testWidgets('the actions are still there, below the answer', (
    WidgetTester tester,
  ) async {
    // The screen was rebuilt around protection; every control that was proven on
    // a real device has to still exist.
    await seedLedger();
    await seedSnapshot(tester);
    await openScreen(tester, FakeBackupLocationRepository.used());

    for (final String label in <String>[
      l10n.backupNowAction,
      l10n.backupShareTile,
      l10n.backupRestoreAction,
      l10n.backupPreviousAction,
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(label), findsWidgets, reason: '$label is missing');
    }
    expect(find.byType(SettingsTile), findsWidgets);
  });

  testWidgets('the switch and the screen move together, both ways', (
    WidgetTester tester,
  ) async {
    // The defect this pins, found on the phone: turning automatic saving off
    // stored `backup_auto_enabled = 0` and changed nothing on screen — the
    // switch stayed on and the header still said the data was protected, until
    // the app was restarted. The cause was not in this screen: `AppSettings.==`
    // left the field out, so a settings value that differed only in that field
    // compared equal to the old one and Riverpod had nothing to tell anyone.
    await seedLedger();
    await seedSnapshot(tester);
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());
    final ProviderContainer container = await openScreen(tester, folders);

    expectHeadline(l10n.backupProtectionProtected);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);

    // ON -> OFF, through the control a person uses.
    await tester.tap(find.byType(Switch).first);
    await settleUntil(
      tester,
      () => find.text(l10n.backupProtectionAutoOff).evaluate().isNotEmpty,
      'the screen to say automatic saving is off',
    );
    expect(
      tester.widget<Switch>(find.byType(Switch).first).value,
      isFalse,
      reason: 'the switch must show what the app stored, or the user is told '
          'their change did not happen',
    );
    expect(
      find.text(l10n.backupProtectionProtected),
      findsNothing,
      reason: 'and nothing may claim protection while nothing is being taken',
    );
    expect(
      container.read(backupStatusProvider).value!.autoEnabled,
      isFalse,
      reason: 'the stored value is the one source of truth, and it agrees',
    );

    // OFF -> ON again, and the screen has to come back with it.
    await tester.tap(find.byType(Switch).first);
    await settleUntil(
      tester,
      () => find.text(l10n.backupProtectionProtected).evaluate().isNotEmpty,
      'the screen to say the data is protected again',
    );
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
    expect(
      container.read(backupStatusProvider).value!.autoEnabled,
      isTrue,
    );
  });

  testWidgets('a change waiting is not called protection once saving is off', (
    WidgetTester tester,
  ) async {
    // The state the user is most likely to be in when they turn it off: work
    // they have just done that is not in a file yet.
    await seedLedger();
    await seedSnapshot(tester);
    await buildService(db).createPerson(const PersonDraft(name: 'خالد'));
    final FakeBackupLocationRepository folders =
        FakeBackupLocationRepository.used();
    folders.addFile('copy.dhimmah', folders.realBackup());
    final ProviderContainer container = await openScreen(tester, folders);

    await settleUntil(
      tester,
      () =>
          container.read(backupStatusProvider).value?.changedRecords != 0,
      'the change to be counted',
    );
    expectHeadline(l10n.backupProtectionPending);

    await tester.tap(find.byType(Switch).first);
    await settleUntil(
      tester,
      () => find.text(l10n.backupProtectionAutoOff).evaluate().isNotEmpty,
      'the screen to say automatic saving is off',
    );
    expect(
      container.read(backupStatusProvider).value!.changedRecords,
      greaterThan(0),
      reason: 'the work is still not in a file',
    );
    expect(
      find.text(l10n.backupProtectionProtected),
      findsNothing,
      reason: 'off, with work waiting, is the furthest thing from protected',
    );
  });

  group('the screen says what it is doing, in each state', () {
    testWidgets('the automatic control states its own position', (
      WidgetTester tester,
    ) async {
      await seedLedger();
      await seedSnapshot(tester);
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      folders.addFile('copy.dhimmah', folders.realBackup());
      await openScreen(tester, folders);

      // A switch alone makes the user read the answer off a piece of furniture.
      expect(find.text(l10n.backupAutoStateOn), findsOneWidget);
      expect(find.text(l10n.backupAutoOffBody), findsNothing);
      expect(
        find.text(l10n.backupAutoOnBody),
        findsOneWidget,
        reason: 'and the sentence under it is the one for this position',
      );
    });

    testWidgets('and when it is off, it says what that means', (
      WidgetTester tester,
    ) async {
      await seedLedger();
      await seedSnapshot(tester);
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      folders.addFile('copy.dhimmah', folders.realBackup());
      await openScreen(
        tester,
        folders,
        settings: AppSettings.initial.copyWith(backupAutoEnabled: false),
      );

      expect(find.text(l10n.backupAutoStateOff), findsOneWidget);
      expect(find.text(l10n.backupAutoOffBody), findsOneWidget);
      expect(
        find.text(l10n.backupAutoOnBody),
        findsNothing,
        reason: 'the sentence for "on" must not be the one shown when it is off',
      );
    });

    testWidgets('the header offers one action, not a toolbar', (
      WidgetTester tester,
    ) async {
      // Nothing has ever been saved and there is somewhere to save it to: one
      // filled action, and the secondary list below it stays secondary.
      await seedLedger();
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      await openScreen(tester, folders);

      expectHeadline(l10n.backupProtectionNever);
      final Finder header = find.ancestor(
        of: find.text(l10n.backupProtectionNever),
        matching: find.byType(FilledButton),
      );
      expect(
        header,
        findsNothing,
        reason: 'the button sits beside the headline, not inside it',
      );
      expect(find.widgetWithText(FilledButton, l10n.backupNowAction),
          findsOneWidget);
    });

    testWidgets('and offers none when there is nothing to do', (
      WidgetTester tester,
    ) async {
      await seedLedger();
      await seedSnapshot(tester);
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      folders.addFile('copy.dhimmah', folders.realBackup());
      await openScreen(tester, folders);

      expectHeadline(l10n.backupProtectionProtected);
      expect(
        find.widgetWithText(FilledButton, l10n.backupNowAction),
        findsNothing,
        reason: 'the point of this state is that there is nothing to do',
      );
    });
  });

  group('the history reads like a history', () {
    testWidgets('the newest copy is marked and every copy says it was checked',
        (WidgetTester tester) async {
      await seedLedger();
      await seedSnapshot(tester);
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      folders.addFile('dhimmah-manual-older.dhimmah', folders.realBackup());
      folders.addFile('dhimmah-manual-newer.dhimmah', folders.realBackup());
      await openScreen(tester, folders);

      await tester.tap(find.text(l10n.backupPreviousAction).first);
      await settleUntil(
        tester,
        () => find.text(l10n.backupHistoryLatest).evaluate().isNotEmpty,
        'the history sheet to mark its newest copy',
      );

      expect(
        find.text(l10n.backupHistoryLatest),
        findsOneWidget,
        reason: 'exactly one copy is the newest, and comparing timestamps to '
            'find it is work the app can do instead',
      );
      expect(
        find.textContaining(l10n.backupHistoryVerified),
        findsWidgets,
        reason: 'and what was checked says so',
      );
    });
  });

  group('the same screen in English', () {
    testWidgets('renders every long sentence without overflowing', (
      WidgetTester tester,
    ) async {
      // The English body sentences are longer than the Arabic ones, and an
      // overflow in a widget test is thrown rather than logged — so rendering
      // this screen and reaching the end of it is the check.
      await seedLedger();
      await seedSnapshot(tester);
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      folders.addFile('copy.dhimmah', folders.realBackup());
      await openScreen(
        tester,
        folders,
        settings: AppSettings.initial.copyWith(languagePreference: LanguagePreference.english),
      );

      final AppLocalizations english = lookupAppLocalizations(const Locale('en'));
      expect(find.text(english.backupProtectionProtected), findsOneWidget);
      expect(find.text(english.backupAutoOnBody), findsOneWidget);
      expect(find.text(english.backupProtectionDetails), findsOneWidget);
    });
  });

  group('what a screen reader hears', () {
    testWidgets('the automatic switch reports its own state', (
      WidgetTester tester,
    ) async {
      // Disposed in the body rather than by addTearDown: the framework checks
      // for a live handle before tear-downs run, and reports one as a leak.
      final SemanticsHandle handle = tester.ensureSemantics();
      await seedLedger();
      await seedSnapshot(tester);
      final FakeBackupLocationRepository folders =
          FakeBackupLocationRepository.used();
      folders.addFile('copy.dhimmah', folders.realBackup());
      await openScreen(tester, folders);

      final SemanticsData data =
          tester.getSemantics(find.byType(Switch).first).getSemanticsData();
      expect(
        data.flagsCollection.isToggled,
        Tristate.isTrue,
        reason: 'and its value has to reach the screen reader, not just the eye',
      );
      expect(
        data.label,
        contains(l10n.backupAutoStateOn),
        reason: 'the state is also said in words, which is what carries the '
            'meaning when the switch itself is not the thing being read',
      );
      handle.dispose();
    });
  });

  group('a copy before something irreversible', () {
    testWidgets('is taken when the newest copy is old', (
      WidgetTester tester,
    ) async {
      await seedLedger();
      final ProviderContainer container =
          await openScreen(tester, FakeBackupLocationRepository.used());
      expect(
        snapshotsOnDisk(),
        isEmpty,
        reason: 'nothing has been saved yet, which is the state that needs one',
      );

      // Real work on the real event loop: a test body runs inside a fake clock,
      // where the file write behind this never completes.
      final BackupFileInfo? made = await tester.runAsync<BackupFileInfo?>(
        () => container.read(backupControllerProvider).safetyBeforeDestructive(),
      );

      expect(made, isNotNull);
      expect(made!.kind, BackupKind.safety);
      expect(snapshotsOnDisk(), hasLength(1));
    });

    testWidgets('is skipped when a copy was just taken', (
      WidgetTester tester,
    ) async {
      await seedLedger();
      await seedSnapshot(tester);
      final ProviderContainer container =
          await openScreen(tester, FakeBackupLocationRepository.used());

      final BackupFileInfo? made = await tester.runAsync<BackupFileInfo?>(
        () => container.read(backupControllerProvider).safetyBeforeDestructive(),
      );

      expect(
        made,
        isNull,
        reason: 'ten deletions in a row must make one copy rather than ten: the '
            'point is that there is something recent to go back to, and a copy '
            'from a minute ago answers that as well as one made now',
      );
      expect(snapshotsOnDisk(), hasLength(1));
    });

    testWidgets('is skipped when there is nothing to protect', (
      WidgetTester tester,
    ) async {
      // No ledger at all: clearing it, or deleting a person from it, is not an
      // act that can lose anything.
      final ProviderContainer container =
          await openScreen(tester, FakeBackupLocationRepository.used());

      expect(
        await tester.runAsync<BackupFileInfo?>(
          () =>
              container.read(backupControllerProvider).safetyBeforeDestructive(),
        ),
        isNull,
      );
      expect(snapshotsOnDisk(), isEmpty);
    });
  });
}

/// `findsOneWidget` spelled so the intent reads at the call site.
final Matcher findsTrueValue = findsOneWidget;
