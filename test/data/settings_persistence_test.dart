import 'dart:io';

import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The setting has to be in the file, not in the session.
///
/// A restart is the one test that cannot be faked with a second provider
/// container: it has to be the same database file, closed and opened again. So
/// this uses a real file in a temporary directory and does exactly that — which
/// is also what makes it worth having, because "it worked until I closed the
/// app" is the failure a store that only *looks* persistent produces.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-settings');
    path = '${dir.path}/dhimmah.sqlite';
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// One "run" of the app: open the file, do the work, close it.
  Future<void> run(Future<void> Function(SettingsRepositoryImpl settings) body) async {
    final AppDatabase db = AppDatabase(NativeDatabase(File(path)));
    try {
      await body(SettingsRepositoryImpl(db));
    } finally {
      await db.close();
    }
  }

  Future<AppSettings> readAfterRestart() async {
    late AppSettings settings;
    await run((SettingsRepositoryImpl s) async => settings = await s.get());
    return settings;
  }

  test('off is still off after a restart', () async {
    await run((SettingsRepositoryImpl s) async {
      expect(
        (await s.update((AppSettings c) => c.copyWith(backupAutoEnabled: false)))
            .backupAutoEnabled,
        isFalse,
      );
    });

    expect(
      (await readAfterRestart()).backupAutoEnabled,
      isFalse,
      reason: 'the user turned it off; it must not come back on by itself when '
          'the app is opened again',
    );
  });

  test('on is still on after a restart', () async {
    await run((SettingsRepositoryImpl s) async {
      await s.update((AppSettings c) => c.copyWith(backupAutoEnabled: false));
      await s.update((AppSettings c) => c.copyWith(backupAutoEnabled: true));
    });

    expect((await readAfterRestart()).backupAutoEnabled, isTrue);
  });

  test('off, on, off — the file keeps the last word', () async {
    await run((SettingsRepositoryImpl s) async {
      await s.update((AppSettings c) => c.copyWith(backupAutoEnabled: false));
      await s.update((AppSettings c) => c.copyWith(backupAutoEnabled: true));
      await s.update((AppSettings c) => c.copyWith(backupAutoEnabled: false));
    });

    expect((await readAfterRestart()).backupAutoEnabled, isFalse);
  });

  test('a first run that never touches the switch keeps the default', () async {
    await run((SettingsRepositoryImpl s) async {
      // Nothing written: this is a brand-new install.
      expect((await s.get()).backupAutoEnabled, isTrue);
    });

    expect(
      (await readAfterRestart()).backupAutoEnabled,
      isTrue,
      reason: 'automatic saving is on out of the box, and an install that has '
          'never chosen otherwise must not read back as off',
    );
  });

  test('the setting travels with the rest of them, not on its own', () async {
    // A value object whose equality ignores a field is how this went wrong in
    // the first place; the file is the other half of that, and it is checked the
    // same way — every field read back is the field written.
    await run((SettingsRepositoryImpl s) async {
      await s.update((AppSettings c) => c.copyWith(
            backupAutoEnabled: false,
            notificationsEnabled: false,
            dueSoonWindowDays: 3,
          ));
    });

    final AppSettings settings = await readAfterRestart();
    expect(settings.backupAutoEnabled, isFalse);
    expect(settings.notificationsEnabled, isFalse);
    expect(settings.dueSoonWindowDays, 3);
  });
}
