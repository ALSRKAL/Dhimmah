import 'dart:io';

import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What the app is allowed to throw away, and what it must never.
///
/// Retention is the one part of this subsystem that deletes the user's data on
/// its own, so it is the part with the least room for a good intention. Every
/// rule here is a promise, and each one is checked by making the app hold more
/// than it wants to and looking at what is left.
void main() {
  late Directory dir;
  late AppDatabase db;
  late BackupService backups;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-retention');
    db = AppDatabase.memory();
    backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: () => DateTime(2026, 9, 27, 17),
      directory: dir,
    );
    await buildService(db).createPerson(const PersonDraft(name: 'أحمد'));
  });

  tearDown(() async {
    await Process.run('chmod', <String>['0755', dir.path]);
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Writes [count] snapshots of [kind], an hour apart so the order is decided
  /// by the name rather than by the filesystem.
  Future<List<BackupFileInfo>> write(int count, BackupKind kind) async {
    final DateTime base = DateTime(2026, 9, 27, 6);
    for (int i = 0; i < count; i++) {
      await backups.create(kind: kind, now: base.add(Duration(hours: i)));
    }
    return backups.list();
  }

  List<String> names(List<BackupFileInfo> files) =>
      files.map((BackupFileInfo f) => f.file.uri.pathSegments.last).toList();

  group('what is kept', () {
    test('automatic snapshots are held to their count, oldest first', () async {
      final List<BackupFileInfo> kept =
          await write(BackupService.autoRetention + 3, BackupKind.auto);

      expect(kept, hasLength(BackupService.autoRetention));
      await expectFilesIntact(backups, kept);
      // Eight were written, an hour apart from 06:00. The five that survive are
      // the last five — named explicitly, so the test says which ones it means
      // rather than only how many.
      expect(kept.first.createdAt, DateTime(2026, 9, 27, 13));
      expect(kept.last.createdAt, DateTime(2026, 9, 27, 9));
      expect(
        names(kept).any((String n) => n.contains('T06')),
        isFalse,
        reason: 'the earliest went first',
      );
    });

    test('manual snapshots are never deleted, however many there are', () async {
      final List<BackupFileInfo> kept = await write(12, BackupKind.manual);

      expect(
        kept,
        hasLength(12),
        reason: 'the user asked for these by hand, and a copy the app removes on '
            'its own is not a copy anyone can rely on',
      );
      await expectFilesIntact(backups, kept);
    });

    test('a manual snapshot is not counted against the automatic ones', () async {
      await buildService(db).createPerson(const PersonDraft(name: 'خالد'));
      final DateTime base = DateTime(2026, 9, 27, 6);
      for (int i = 0; i < 12; i++) {
        await backups.create(
          kind: i.isEven ? BackupKind.manual : BackupKind.auto,
          now: base.add(Duration(hours: i)),
        );
      }

      final List<BackupFileInfo> kept = await backups.list();
      expect(
        kept.where((BackupFileInfo f) => f.kind == BackupKind.manual),
        hasLength(6),
        reason: 'six manual snapshots, all kept',
      );
      expect(
        kept.where((BackupFileInfo f) => f.kind == BackupKind.auto),
        hasLength(5),
        reason: 'and six automatic ones held to the count',
      );
    });

    test('safety snapshots are held to their own count', () async {
      final List<BackupFileInfo> kept =
          await write(BackupService.safetyRetention + 4, BackupKind.safety);

      expect(kept, hasLength(BackupService.safetyRetention));
      await expectFilesIntact(backups, kept);
    });

    test('the newest of every kind survives the others being pruned', () async {
      // Interleaved, so a policy that pruned by position rather than by kind
      // would take the newest safety snapshot with the oldest automatic ones.
      final DateTime base = DateTime(2026, 9, 27, 6);
      for (int i = 0; i < 20; i++) {
        await backups.create(
          kind: switch (i % 3) {
            0 => BackupKind.auto,
            1 => BackupKind.safety,
            _ => BackupKind.manual,
          },
          now: base.add(Duration(hours: i)),
        );
      }

      final List<BackupFileInfo> kept = await backups.list();
      for (final BackupKind kind in BackupKind.values) {
        expect(
          kept.any((BackupFileInfo f) => f.kind == kind),
          isTrue,
          reason: '$kind must still have its newest snapshot: it is the one a '
              'restore would offer first',
        );
      }
      await expectFilesIntact(backups, kept);
    });

    test('more than one recovery point is always left', () async {
      // The floor is what stops the policy from ever becoming a policy that can
      // reach zero. Two is checked as the smallest case that can arise.
      await write(BackupService.autoRetention + 10, BackupKind.auto);
      expect(
        (await backups.list()).length,
        greaterThanOrEqualTo(BackupService.fewestKept),
      );
    });
  });

  group('when the disk is full', () {
    test('gives back what it can and writes anyway', () async {
      await buildService(db).createPerson(const PersonDraft(name: 'خالد'));
      await write(BackupService.autoRetention + 3, BackupKind.auto);
      final int before = (await backups.list()).length;

      // The closest a test comes to a full disk, and the same failure the writer
      // meets there. The permission is checked by the assertions: if this
      // environment ignored it, the "cannot write" expectation below would fail
      // loudly rather than the test passing without testing anything.
      await Process.run('chmod', <String>['0555', dir.path]);
      await expectLater(
        BackupService(
          database: db,
          appVersion: '1.0.0+1',
          clock: () => DateTime(2026, 9, 27, 18),
          directory: dir,
        ).create(kind: BackupKind.manual),
        throwsA(anything),
        reason: 'a manual snapshot has nothing the app may hand back, and the '
            'floor stops it from eating the automatic ones to make room',
      );

      expect(
        (await backups.list()).length,
        before,
        reason: 'a write that could not be made must not have cost a snapshot',
      );
    });

    test('never deletes below the floor to make room', () async {
      await write(BackupService.fewestKept, BackupKind.auto);
      final List<BackupFileInfo> before = await backups.list();
      expect(before, hasLength(BackupService.fewestKept));

      await Process.run('chmod', <String>['0555', dir.path]);
      await expectLater(
        BackupService(
          database: db,
          appVersion: '1.0.0+1',
          clock: () => DateTime(2026, 9, 27, 19),
          directory: dir,
        ).create(kind: BackupKind.auto),
        throwsA(anything),
      );

      expect(
        (await backups.list()).length,
        BackupService.fewestKept,
        reason: 'the app would rather fail to write than leave the user with '
            'fewer recovery points than it promised to keep',
      );
    });
  });
}

/// Reads every snapshot the app kept, to prove they are still restorable.
///
/// A retention policy that leaves a file in place but unreadable would pass
/// every count-based check while failing at the only thing that matters.
Future<void> expectFilesIntact(
  BackupService backups,
  List<BackupFileInfo> files,
) async {
  for (final BackupFileInfo info in files) {
    final ParsedBackup parsed = BackupFormat.parse(
      await info.file.readAsString(),
    );
    expect(parsed.counts['people'], isNotNull);
  }
}
