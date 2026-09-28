import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/store_demo_seed.dart';

/// Not a product test: a probe used while preparing the store captures, to
/// prove that seeding in English really stores English.
void main() {
  test('the seed stores the language it was asked for', () async {
    final AppDatabase db = AppDatabase.memory();
    // ignore: avoid_print
    print('AppSettings.initial.language = ${AppSettings.initial.language}');
    await seedStoreDemoData(db, language: AppLanguage.english);
    final AppSettings settings = await SettingsRepositoryImpl(db).get();
    // ignore: avoid_print
    print('after english seed: language=${settings.language} '
        'theme=${settings.themeMode} onboarding=${settings.onboardingCompleted}');
    expect(settings.language, AppLanguage.english);
    await db.close();
  });
}
