import 'dart:io';
import 'dart:ui' show FrameTiming;
import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:drift/drift.dart' as drift show Value;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Frame timings from a real render pipeline.
///
/// Widget tests cannot produce these: `flutter test` drives a fake clock and
/// never rasterises. This runs on a device or emulator, seeds a ledger, drives
/// the screens a person drives, and reports what the engine actually spent per
/// frame.
///
///   flutter test integration_test/frame_measure_test.dart -d `device`
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Runs [body] while the engine reports its own frame timings.
  ///
  /// `FrameTiming` is what the engine measured: `buildDuration` is the UI
  /// thread's frame, `rasterDuration` the GPU thread's. Both are needed — a
  /// screen can have a cheap build and an expensive raster, and only one of
  /// those is fixed by changing Dart.
  Future<void> measured(String label, Future<void> Function() body) async {
    final List<FrameTiming> timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    binding.addTimingsCallback(collect);
    final Stopwatch wall = Stopwatch()..start();
    await body();
    wall.stop();
    // Let the engine flush the last batch before reading.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    binding.removeTimingsCallback(collect);

    final List<Duration> build =
        <Duration>[for (final FrameTiming t in timings) t.buildDuration];
    final List<Duration> raster =
        <Duration>[for (final FrameTiming t in timings) t.rasterDuration];
    // ignore: avoid_print
    print('FRAMES $label | wall=${wall.elapsedMilliseconds}ms '
        'frames=${build.length} '
        'build p50=${_p(build, 0.50)} p90=${_p(build, 0.90)} '
        'p99=${_p(build, 0.99)} worst=${_p(build, 1.0)} '
        '| raster p50=${_p(raster, 0.50)} p90=${_p(raster, 0.90)} '
        'worst=${_p(raster, 1.0)} '
        '| over16ms=${_over(build, 16.7)} over33ms=${_over(build, 33.0)}');
  }

  testWidgets('measure frames at scale', (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    final DateTime today = dateOnly(DateTime.now());
    const int people = 500;
    const int debtsPerPerson = 5;
    const int paymentsPerDebt = 4;

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
            personId: drift.Value<String>('p$p'),
            direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
            title: drift.Value<String>('قرض رقم $d للشخص $p'),
            principalMinor: 100000 + d * 1000,
            currencyCode: AppCurrency.inr.code,
            issuedAt: addDays(today, -100 - d),
            dueAt: drift.Value<DateTime>(addDays(today, d - 2)),
            recurrence: RecurrenceFrequency.none,
            createdAt: today,
            updatedAt: today,
          ),
    ];
    await db.batch((Batch b) => b.insertAll(db.debts, debts));
    await db.batch((Batch b) => b.insertAll(db.payments, <PaymentsCompanion>[
          for (final DebtsCompanion d in debts)
            for (int k = 0; k < paymentsPerDebt; k++)
              PaymentsCompanion.insert(
                id: 'pay${d.id.value}_$k',
                debtId: drift.Value<String>(d.id.value),
                personId: d.personId,
                amountMinor: 5000,
                currencyCode: AppCurrency.inr.code,
                paidAt: addDays(today, -20 + k),
                createdAt: today,
              ),
        ]));

    // Resident set size from the device's own /proc. Not a heap breakdown — the
    // Dart VM's heap needs the observatory — but it is the number that says
    // whether the app is holding on to something.
    int rss() {
      final String text = File('/proc/self/status').readAsStringSync();
      final RegExpMatch? m = RegExp(r'VmRSS:\s+(\d+) kB').firstMatch(text);
      return m == null ? -1 : int.parse(m.group(1)!);
    }

    final int rssAtStart = rss();
    // ignore: avoid_print
    print('MEMORY at start (ledger seeded, nothing rendered): $rssAtStart kB');

    final ProviderContainer container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await measured('startup', () async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const DhimmahApp(onboardingCompleted: true),
        ),
      );
      await tester.pumpAndSettle();
    });

    // Let the streams deliver before measuring scroll frames.
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    await measured('dashboard scroll', () async {
      final Finder list = find.byType(Scrollable).first;
      for (int i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -400), 2000);
        await tester.pumpAndSettle(const Duration(milliseconds: 60));
      }
    });

    await measured('open ledger', () async {
      await tester.tap(find.text('السجل').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 60));
    });

    await measured('ledger scroll (2500 rows)', () async {
      final Finder list = find.byType(Scrollable).first;
      for (int i = 0; i < 12; i++) {
        await tester.fling(list, const Offset(0, -500), 3000);
        await tester.pumpAndSettle(const Duration(milliseconds: 40));
      }
    });

    await measured('open people', () async {
      await tester.tap(find.text('الأشخاص').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 60));
    });

    await measured('people scroll (500 rows)', () async {
      final Finder list = find.byType(Scrollable).first;
      for (int i = 0; i < 8; i++) {
        await tester.fling(list, const Offset(0, -500), 3000);
        await tester.pumpAndSettle(const Duration(milliseconds: 40));
      }
    });

    await measured('open obligations', () async {
      await tester.tap(find.text('التزامات').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 60));
    });

    // ignore: avoid_print
    print('MEMORY after everything: ${rss()} kB');

    // How much the session's working set grew from beginning to end. A leak in
    // a screen that is opened and closed shows up here as growth that does not
    // come back.
    // ignore: avoid_print
    print('MEMORY growth over the session: '
        '${rssAtStart}kB -> ${rss()}kB (+${rss() - rssAtStart}kB)');

    await db.close();
  });
}

int _over(List<Duration> values, double ms) =>
    values.where((Duration d) => d.inMicroseconds > ms * 1000).length;

String _p(List<Duration> values, double fraction) {
  if (values.isEmpty) return '-';
  final List<int> sorted = <int>[
    for (final Duration d in values) d.inMicroseconds,
  ]..sort();
  final int index = ((sorted.length - 1) * fraction).round();
  return '${(sorted[index] / 1000).toStringAsFixed(1)}ms';
}
