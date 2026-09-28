import 'dart:ui' show FrameTiming;

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/app_harness.dart';

/// The multi-person record, driven on a real device.
///
/// `test/widget/multi_person_pages_test.dart` proves the behaviour against the
/// real widgets but a fake pipeline; this proves the same thing on Android's own
/// renderer and its own SQLite, and reports the frames each person's page cost
/// while it does it.
///
///   flutter test integration_test/multi_person_on_device_test.dart -d `device`
///
/// It is deliberately small — three people and two records — so it can run on a
/// phone that is short of memory, where the 500-person frame measurement cannot.
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String first = 'محمد أحمد عبدالرحمن';
  const String second = 'خالد العلي';
  const String third = 'مريم الحسن';
  const String sharedTitle = 'فاتورة العشاء';
  const String ownTitle = 'سلفة';

  testWidgets('each person reads one record as their own', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.memory();
    addTearDown(() async => db.close());

    // Reminders off before anything is written.
    //
    // The timezone database and the notification plugin are prepared by the
    // app's own start-up, and this test seeds its ledger *before* the first
    // pump, so on a device every write would try to schedule against a plugin
    // that is not ready yet. (The widget tests never meet this: scheduling is
    // skipped entirely when the platform cannot show notifications.) Turning
    // reminders off is a real configuration, and nothing in this test is about
    // them.
    await SettingsRepositoryImpl(db).update(
      (AppSettings settings) => settings.copyWith(
        notificationsEnabled: false,
        monthEndSummaryEnabled: false,
      ),
    );

    final LedgerService service = buildService(db);
    final DateTime today = dateOnly(DateTime.now());

    final Person ahmed = await service.createPerson(const PersonDraft(name: first));
    final Person khalid = await service.createPerson(const PersonDraft(name: second));
    final Person maryam = await service.createPerson(const PersonDraft(name: third));

    // 1,500 owed to three people at once: one record, three links.
    final Debt dinner = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id, khalid.id, maryam.id],
        title: sharedTitle,
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: ownTitle,
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: today,
      ),
    );

    await pumpDhimmah(tester, db: db);
    await tester.pumpAndSettle();

    // The frames each page cost, from the engine's own numbers.
    final Map<String, List<int>> build = <String, List<int>>{};
    void collect(List<FrameTiming> timings) {
      for (final FrameTiming timing in timings) {
        build
            .putIfAbsent(_openLabel, () => <int>[])
            .add(timing.buildDuration.inMicroseconds);
      }
    }

    binding.addTimingsCallback(collect);
    addTearDown(() => binding.removeTimingsCallback(collect));

    Future<void> openPerson(String name) async {
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .popUntil((Route<dynamic> route) => route.isFirst);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الأشخاص').last);
      await tester.pumpAndSettle();
      _openLabel = name;
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    for (final String name in <String>[first, second, third]) {
      await openPerson(name);

      // The record is one of this person's debts, with its own amount.
      expect(
        find.text(sharedTitle),
        findsOneWidget,
        reason: '$name should see the record',
      );
      expect(find.textContaining('1,500'), findsWidgets);

      // Nobody else on the record is named, and nothing calls it shared.
      for (final String other in <String>[first, second, third]) {
        if (other == name) continue;
        expect(
          find.textContaining(other),
          findsNothing,
          reason: '$name’s page must not name $other',
        );
      }
      expect(find.textContaining('مشترك'), findsNothing);

      // ignore: avoid_print
      print('DEVICE $name: record shown, nobody else named');
    }

    // One payment on the one record: every page shows the same 1,000 left.
    await service.recordPayment(
      dinner.id,
      PaymentDraft(amountMinor: 50000, paidAt: today),
    );
    await tester.pumpAndSettle();

    for (final String name in <String>[first, second, third]) {
      await openPerson(name);
      expect(
        find.textContaining('1,000'),
        findsWidgets,
        reason: '$name sees the same record fall by the same payment',
      );
    }

    expect(await db.debtsDao.getAll(), hasLength(2));
    expect(await db.debtsDao.participantsFor(dinner.id), hasLength(3));

    for (final MapEntry<String, List<int>> entry in build.entries) {
      // ignore: avoid_print
      print('DEVICE frames for ${entry.key}: '
          'frames=${entry.value.length} '
          'p50=${_p(entry.value, 0.50)} p90=${_p(entry.value, 0.90)} '
          'worst=${_p(entry.value, 1.0)}');
    }
  });
}

/// The label the frame callback is currently attributing frames to.
String _openLabel = 'start';

String _p(List<int> micros, double fraction) {
  if (micros.isEmpty) return '-';
  final List<int> sorted = List<int>.of(micros)..sort();
  final int index = ((sorted.length - 1) * fraction).round();
  return '${(sorted[index] / 1000).toStringAsFixed(1)}ms';
}
