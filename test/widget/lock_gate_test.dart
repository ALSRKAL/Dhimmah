import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The lock gate's three decisions, each driven by a keystore the test writes.
///
/// Until the harness could hand the gate a [FakePinService], no test could make
/// a PIN exist, not exist, or fail to read — the real [PinService] talks to a
/// platform plugin, so every widget test silently exercised only the throw
/// path. The gate is the one security control in the app; these tests hold it
/// to the two rules written at its call site: a lock with no key must never
/// engage, and a keystore that cannot be read is never a way past the lock.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async => db.close());

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  testWidgets('a lock with no key never engages, and corrects the flag',
      (WidgetTester tester) async {
    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(lockEnabled: true),
      pinService: FakePinService(),
    );

    // The ledger opens. A PIN pad raised over a keystore with no digest can
    // never be satisfied by any input — the one way to escape it is
    // uninstalling, which takes the records it was guarding.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(l10n.lockTitle), findsNothing);

    // And the flag that claimed protection stops lying about itself, so the
    // next launch does not have to walk the same correction again.
    bool stored = true;
    for (int i = 0; i < 20 && stored; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      stored = (await db.settingsDao.get())!.lockEnabled;
    }
    expect(stored, isFalse,
        reason: 'lock_enabled must be corrected once no digest exists');
  });

  testWidgets('a lock with a key covers the ledger and is satisfiable',
      (WidgetTester tester) async {
    final FakePinService keystore = FakePinService();
    await keystore.setPin('1234');
    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(lockEnabled: true),
      pinService: keystore,
    );

    // Covered before anything is typed.
    expect(find.text(l10n.lockTitle), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // And the key opens it. This is the half of the contract the gate's own
    // comment worries about: the ledger arriving on a new phone with the flag
    // set and no digest must not be the state these tests make here.
    for (final String digit in <String>['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(l10n.lockTitle), findsNothing);
  });

  testWidgets('a keystore that cannot be read fails closed, not crashed',
      (WidgetTester tester) async {
    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(lockEnabled: true),
      pinService: FakePinService(readError: Exception('keystore unavailable')),
    );

    // The gate caught the platform failure instead of throwing from
    // initState, and kept the lock up: "could not tell" must not be a way
    // past it.
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.lockTitle), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    // And it changed nothing on disk — the flag is left exactly as the user
    // set it, unlike the empty-keystore case which is allowed to correct it.
    await tester.pump(const Duration(milliseconds: 200));
    final Setting? stored = await db.settingsDao.get();
    expect(stored!.lockEnabled, isTrue);
  });
}
