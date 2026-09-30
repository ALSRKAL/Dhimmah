import 'dart:io';

import 'package:dhimmah/data/backup/backup_codec.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the language preference lives, and what reads it back.
///
/// Two readers matter besides the app itself: the file after a restart, and a
/// backup — including one written by a build from before the preference
/// existed, and one read by a build that has never heard of `system`.
void main() {
  group('the file keeps it', () {
    late Directory dir;
    late String path;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('dhimmah-language');
      path = '${dir.path}/dhimmah.sqlite';
    });
    tearDown(() async => dir.delete(recursive: true));

    Future<T> run<T>(Future<T> Function(SettingsRepositoryImpl s) body) async {
      final AppDatabase db = AppDatabase(NativeDatabase(File(path)));
      try {
        return await body(SettingsRepositoryImpl(db));
      } finally {
        await db.close();
      }
    }

    test(
      'a new install follows the phone, and still does after a restart',
      () async {
        expect(
          await run(
            (SettingsRepositoryImpl s) async =>
                (await s.get()).languagePreference,
          ),
          LanguagePreference.system,
        );
        expect(
          await run(
            (SettingsRepositoryImpl s) async =>
                (await s.get()).languagePreference,
          ),
          LanguagePreference.system,
        );
      },
    );

    test(
      'a chosen language survives a restart, and so does un-choosing it',
      () async {
        await run(
          (SettingsRepositoryImpl s) => s.update(
            (AppSettings c) =>
                c.copyWith(languagePreference: LanguagePreference.english),
          ),
        );
        expect(
          await run(
            (SettingsRepositoryImpl s) async =>
                (await s.get()).languagePreference,
          ),
          LanguagePreference.english,
        );

        await run(
          (SettingsRepositoryImpl s) => s.update(
            (AppSettings c) =>
                c.copyWith(languagePreference: LanguagePreference.system),
          ),
        );
        expect(
          await run(
            (SettingsRepositoryImpl s) async =>
                (await s.get()).languagePreference,
          ),
          LanguagePreference.system,
        );
      },
    );
  });

  group('a backup carries it', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.memory());
    tearDown(() async => db.close());

    test('under the key older files already use', () async {
      final Setting row = (await db.settingsDao.get())!;
      final Map<String, Object?> written = BackupCodec.settings(row);
      expect(written['language'], 'system');
      expect(
        written.containsKey('languagePreference'),
        isFalse,
        reason: 'an older build looks for `language` and nothing else',
      );
    });

    const int before = BackupCodec.languagePreferenceSchema - 1;
    const int since = BackupCodec.languagePreferenceSchema;

    test('a file from this version reads back exactly what it says', () {
      for (final LanguagePreference stored in LanguagePreference.values) {
        final AppSettings restored = BackupCodec.applySettings(
          <String, Object?>{'language': stored.name},
          AppSettings.initial,
          schemaVersion: since,
        );
        expect(restored.languagePreference, stored, reason: stored.name);
      }
    });

    test('an older file’s Arabic was the seed, and does not pin Arabic', () {
      // Every install before version 5 was given Arabic, chosen or not — the
      // same reason the database migration hands it back to the phone.
      for (final LanguagePreference device in LanguagePreference.values) {
        final AppSettings restored = BackupCodec.applySettings(
          const <String, Object?>{'language': 'arabic'},
          AppSettings.initial.copyWith(languagePreference: device),
          schemaVersion: before,
        );
        expect(restored.languagePreference, device, reason: device.name);
      }
    });

    test('an older file’s English was a choice, and is kept', () {
      final AppSettings restored = BackupCodec.applySettings(
        const <String, Object?>{'language': 'english'},
        AppSettings.initial,
        schemaVersion: before,
      );
      expect(restored.languagePreference, LanguagePreference.english);
    });

    test('a value this build does not know keeps the device’s own', () {
      final AppSettings current = AppSettings.initial
          .copyWith(languagePreference: LanguagePreference.english);
      for (final Object? unknown in <Object?>['french', 42, null]) {
        expect(
          BackupCodec.applySettings(
            <String, Object?>{'language': unknown},
            current,
            schemaVersion: since,
          ).languagePreference,
          LanguagePreference.english,
          reason: '$unknown',
        );
      }
      expect(
        BackupCodec.applySettings(
          const <String, Object?>{},
          current,
          schemaVersion: since,
        ).languagePreference,
        LanguagePreference.english,
      );
    });
  });
}
