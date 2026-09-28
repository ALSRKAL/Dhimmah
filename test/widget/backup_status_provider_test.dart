import 'dart:io';

import 'package:dhimmah/app/backup_providers.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Regression guard for the defect the widget coverage found.
///
/// The status provider's body used to register two of its dependencies with
/// `ref.watch` *after* an await. A dependency that settled while the body was
/// running restarted the body, and the future the first caller was holding was
/// abandoned — a status card that never leaves its spinner, for anyone who reads
/// it as a future rather than watching it from a widget. This is that read, and
/// it has to complete.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the first read of the backup status completes, with nothing else read',
      () async {
    final AppDatabase db = AppDatabase.memory();
    final Directory dir =
        await Directory.systemTemp.createTemp('dhimmah-status-probe');
    await buildService(db).createPerson(const PersonDraft(name: 'أحمد'));
    await BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    ).create(kind: BackupKind.manual);

    final ProviderContainer container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        backupDirectoryProvider.overrideWithValue(dir),
      ],
    );

    final BackupStatus status = await container
        .read(backupStatusProvider.future)
        .timeout(const Duration(seconds: 20));

    expect(status.snapshots, 1);
    expect(status.hasLocalData, isTrue);

    container.dispose();
    await db.close();
    await dir.delete(recursive: true);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
