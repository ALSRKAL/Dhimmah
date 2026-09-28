import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/backup/backup_codec.dart';
import 'package:dhimmah/data/backup/table_reader.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/domain/services/backup_progress.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the time actually goes in a backup and a restore.
///
/// The earlier profile measured three totals — create, inspect, restore — and a
/// total cannot be optimised: it does not say whether the cost is in SQLite, in
/// JSON, in the checksum or in the file. This one splits each operation at the
/// seams the services already report for the progress indicator, so every figure
/// below is a real phase of the real code path.
///
/// Print only, on purpose. The numbers are the evidence; a threshold pinned to a
/// machine would be a different, weaker claim.
///
///   flutter test test/tool/backup_phase_profile_test.dart
///   flutter test test/tool/backup_phase_profile_test.dart --dart-define=people=1000 --dart-define=debts=10
const int peopleCount = int.fromEnvironment('people', defaultValue: 500);
const int debtsPerPerson = int.fromEnvironment('debts', defaultValue: 5);

/// A stopwatch that splits its elapsed time at named marks.
///
/// A phase's duration is the time between the mark that starts it and the next
/// mark, which is why the phase that is running is closed by the mark that
/// follows rather than by a mark of its own.
class _Timeline {
  final Stopwatch _watch = Stopwatch()..start();
  final Map<String, int> millis = <String, int>{};
  int _last = 0;
  String? _current;

  void mark(String step) {
    final int now = _watch.elapsedMilliseconds;
    if (_current != null) {
      millis[_current!] = (millis[_current!] ?? 0) + (now - _last);
    }
    _current = step;
    _last = now;
  }

  void finish() {
    final int now = _watch.elapsedMilliseconds;
    if (_current != null) {
      millis[_current!] = (millis[_current!] ?? 0) + (now - _last);
    }
    _current = null;
    _last = now;
  }

  int get total {
    finish();
    int sum = 0;
    for (final int value in millis.values) {
      sum += value;
    }
    return sum;
  }

  void report(String title, {String indent = '   '}) {
    final int sum = total;
    final List<MapEntry<String, int>> rows = millis.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    final StringBuffer out = StringBuffer()
      ..writeln('$indent$title — $sum ms');
    for (final MapEntry<String, int> row in rows) {
      final String share =
          sum == 0 ? '  -' : '${(row.value * 100 / sum).round().toString().padLeft(3)}%';
      out.writeln('$indent   ${row.key.padRight(14)} ${row.value.toString().padLeft(7)} ms  $share');
    }
    // ignore: avoid_print
    print(out.toString().trimRight());
  }
}

/// Peak and current resident memory of this process, from the kernel.
///
/// Host figures, not device figures: they say how much the Dart heap grows while
/// a snapshot is built, which is the question "does the file exist four times in
/// memory at once?" — a question no timing answers.
String memoryLine() {
  try {
    final String status = File('/proc/self/status').readAsStringSync();
    String read(String key) {
      for (final String line in status.split('\n')) {
        if (line.startsWith(key)) return line.split(RegExp(r'\s+'))[1];
      }
      return '?';
    }

    final int rss = int.parse(read('VmRSS:'));
    final int peak = int.parse(read('VmHWM:'));
    return 'RSS ${(rss / 1024).toStringAsFixed(0)} MB · peak ${(peak / 1024).toStringAsFixed(0)} MB';
  } on Object {
    return 'unavailable';
  }
}

Future<int> seed(AppDatabase db) async {
  final DateTime today = dateOnly(DateTime.now());
  await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
        for (int i = 0; i < peopleCount; i++)
          PeopleCompanion.insert(
            id: 'p$i',
            name: 'شخص رقم $i',
            createdAt: today,
            updatedAt: today,
          ),
      ]));
  final List<DebtsCompanion> debts = <DebtsCompanion>[
    for (int p = 0; p < peopleCount; p++)
      for (int d = 0; d < debtsPerPerson; d++)
        DebtsCompanion.insert(
          id: 'd${p}_$d',
          personId: Value<String>('p$p'),
          direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
          title: Value<String>('قرض $d للشخص $p'),
          principalMinor: 100000 + d * 1000,
          currencyCode: AppCurrency.inr.code,
          issuedAt: addDays(today, -100 - d),
          dueAt: Value<DateTime>(addDays(today, d)),
          recurrence: RecurrenceFrequency.none,
          createdAt: today,
          updatedAt: today,
        ),
  ];
  await db.batch((Batch b) => b.insertAll(db.debts, debts));
  await db.batch((Batch b) => b.insertAll(db.debtPeople, <DebtPeopleCompanion>[
        for (final DebtsCompanion d in debts)
          DebtPeopleCompanion.insert(
            debtId: d.id.value,
            personId: d.personId.value!,
            createdAt: today,
          ),
      ]));
  await db.batch((Batch b) => b.insertAll(db.payments, <PaymentsCompanion>[
        for (final DebtsCompanion d in debts)
          for (int k = 0; k < 4; k++)
            PaymentsCompanion.insert(
              id: 'pay${d.id.value}_$k',
              debtId: Value<String>(d.id.value),
              personId: d.personId,
              amountMinor: 5000,
              currencyCode: AppCurrency.inr.code,
              paidAt: addDays(today, -20 + k),
              createdAt: today,
            ),
      ]));
  return debts.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phase split of create, inspect and restore',
      timeout: const Timeout(Duration(minutes: 30)), () async {
    final Directory dir =
        await Directory.systemTemp.createTemp('dhimmah-backup-phases');
    final AppDatabase db = AppDatabase.memory();

    final int debts = await seed(db);
    final BackupService backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    );
    final BackupRestoreService restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: () async {},
    );

    // ignore: avoid_print
    print('''

=== BACKUP PHASE PROFILE — $peopleCount people / $debts debts / ${debts * 4} payments ===
   memory before: ${memoryLine()}''');

    final _Timeline create = _Timeline();
    final ({File file, ParsedBackup backup}) written = await backups.create(
      kind: BackupKind.manual,
      onStep: (BackupStep step) => create.mark('create.${step.name}'),
    );
    create.report('create');
    final int bytes = await written.file.length();

    // The file itself, taken apart: how much of a read is JSON, how much is the
    // checksum, how much is the rules.
    final String text = await written.file.readAsString();
    final _Timeline fileWork = _Timeline();
    fileWork.mark('jsonDecode');
    final Object? decoded = jsonDecode(text);
    fileWork.mark('parseEnvelope (envelope + checksum)');
    BackupFormat.parseEnvelope(decoded);
    fileWork.mark('checksumOf alone');
    BackupFormat.checksumOf(
      (decoded! as Map<String, Object?>)['payload']! as Map<String, Object?>,
    );
    fileWork.mark('encode (jsonEncode)');
    BackupFormat.encode(decoded as Map<String, Object?>);
    fileWork.report('reading the file back (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)');
    // ignore: avoid_print
    print('   memory after create: ${memoryLine()}');

    final _Timeline inspect = _Timeline();
    final bool usable = (await backups.inspect(
      written.file.path,
      onStep: (RestoreStep step) => inspect.mark('inspect.${step.name}'),
    ))
        .isUsable;
    inspect.report('inspect (usable: $usable)');

    // Restore into a database that already holds the same records — the merge
    // path, which has to read the local side and compare row by row.
    final _Timeline merge = _Timeline();
    final RestoreReport merged = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.merge,
      takeSafetySnapshot: false,
      onStep: (RestoreStep step) => merge.mark('merge.${step.name}'),
    );
    merge.report('restore · merge (into the same data)');
    // ignore: avoid_print
    print('   merge result: inserted ${merged.inserted}, replaced ${merged.replaced}, '
        'skipped ${merged.skipped}, conflicts ${merged.conflicts.length}');

    // Empty, then restore — the replace path with the safety snapshot included,
    // which is what a real restore on a device does.
    await db.transaction(() async {
      await db.delete(db.payments).go();
      await db.delete(db.debtPeople).go();
      await db.delete(db.debts).go();
      await db.delete(db.people).go();
    });
    final _Timeline replace = _Timeline();
    final RestoreReport restored = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
      onStep: (RestoreStep step) => replace.mark('replace.${step.name}'),
    );
    replace.report('restore · replace (into an empty ledger)');
    // ignore: avoid_print
    print('   restored counts: ${restored.counts}');
    // ignore: avoid_print
    print('   memory after restore: ${memoryLine()}');

    // And the same restore into a *full* ledger, so the safety snapshot — a
    // second complete backup — is included. This is the real worst case.
    final _Timeline safety = _Timeline();
    final RestoreReport withSafety = await restores.apply(
      backup: written.backup,
      mode: RestoreMode.replace,
      onStep: (RestoreStep step) => safety.mark('replace+safety.${step.name}'),
    );
    safety.report('restore · replace with safety snapshot (real path)');
    // ignore: avoid_print
    print('   safety snapshot: ${withSafety.safetyBackupPath != null}');
    // ignore: avoid_print
    print('   peak memory at end: ${memoryLine()}\n');

    await db.close();
    await dir.delete(recursive: true);
  });

  test('where the read cost is', timeout: const Timeout(Duration(minutes: 10)), () async {
    // "reading" is the largest phase of a snapshot. This splits it three ways so
    // the fix targets the right layer: SQLite itself, drift's typed mapping, or
    // the codec that turns rows into JSON-ready maps.
    final AppDatabase db = AppDatabase.memory();
    await seed(db);

    // Warm the statement cache so the first read is not measured as if it were
    // representative.
    await db.customSelect('SELECT * FROM debts').get();
    await db.select(db.debts).get();

    Future<Stopwatch> time(Future<void> Function() body) async {
      final Stopwatch watch = Stopwatch()..start();
      await body();
      watch.stop();
      return watch;
    }

    final List<String> lines = <String>[];
    // The SQL names, which is what `customSelect` needs — the ORM names are the
    // Dart ones.
    for (final (String table, String sql) in <(String, String)>[
      ('people', 'people'),
      ('debts', 'debts'),
      ('debtPeople', 'debt_people'),
      ('payments', 'payments'),
    ]) {
      final Stopwatch raw = await time(() => db.customSelect('SELECT * FROM $sql').get());
      final List<QueryRow> rawRows = await db.customSelect('SELECT * FROM $sql').get();

      final Stopwatch typed = await time(() async {
        switch (table) {
          case 'people':
            await db.select(db.people).get();
          case 'debts':
            await db.select(db.debts).get();
          case 'debtPeople':
            await db.select(db.debtPeople).get();
          case 'payments':
            await db.select(db.payments).get();
        }
      });

      final Stopwatch codec = await time(() async {
        for (final QueryRow row in rawRows) {
          switch (table) {
            case 'people':
              BackupCodec.person(db.people.map(row.data));
            case 'debts':
              BackupCodec.debt(db.debts.map(row.data));
            case 'debtPeople':
              BackupCodec.link(db.debtPeople.map(row.data));
            case 'payments':
              BackupCodec.payment(db.payments.map(row.data));
          }
        }
      });

      final int rows = rawRows.length;
      lines.add('   ${table.padRight(12)} ${rows.toString().padLeft(6)} rows · '
          'raw SQL ${raw.elapsedMicroseconds} µs · '
          'typed ${typed.elapsedMicroseconds} µs · '
          'codec ${codec.elapsedMicroseconds} µs');
    }

    // ignore: avoid_print
    print('\n=== WHERE THE READ COST IS ===\n${lines.join('\n')}\n');
    await db.close();
  });

  test('the longest stall while reading',
      timeout: const Timeout(Duration(minutes: 20)), () async {
    // What "the UI is frozen" actually means: the longest stretch during which
    // the frame thread got no turn. A single `SELECT` over a big table is one
    // such stretch, because drift maps every row before it returns.
    //
    // Both paths are measured side by side on the same data: the one-shot
    // `getAll()` the backup used to call, and the paged reader it calls now.
    // The gaps between progress reports are the stalls a user would feel.
    final AppDatabase db = AppDatabase.memory();
    await seed(db);

    final List<int> oneShot = <int>[];
    for (final Future<void> Function() read in <Future<void> Function()>[
      () async => db.peopleDao.getAll(),
      () async => db.debtsDao.getAll(),
      () async => db.debtsDao.allParticipantRows(),
      () async => db.debtsDao.getAllPayments(),
    ]) {
      final Stopwatch watch = Stopwatch()..start();
      await read();
      watch.stop();
      oneShot.add(watch.elapsedMilliseconds);
    }
    int worstOneShot = 0;
    for (final int ms in oneShot) {
      if (ms > worstOneShot) worstOneShot = ms;
    }

    final List<int> gaps = <int>[];
    int last = 0;
    // Named so the figure below can be read against it: the stall is bounded by
    // the page, not by the table.
    const int pageSize = 500;
    final Stopwatch paged = Stopwatch()..start();
    await db.transaction(() async {
      // The page size is `TableReader`'s default; it is named locally because the
      // printed figure is unreadable without it.
      final TableReader reader = TableReader(
        database: db,
        onProgress: (int rows) {
          final int now = paged.elapsedMilliseconds;
          if (last != 0) gaps.add(now - last);
          last = now;
        },
      );
      await reader.people();
      await reader.debts();
      await reader.links();
      await reader.payments();
    });
    paged.stop();

    int worstGap = 0;
    int over50 = 0;
    for (final int gap in gaps) {
      if (gap > worstGap) worstGap = gap;
      if (gap > 50) over50++;
    }

    final StringBuffer out = StringBuffer()
      ..writeln()
      ..writeln('=== THE LONGEST STALL WHILE READING ($peopleCount people) ===')
      ..writeln('   one-shot getAll()     : one call per table, worst $worstOneShot ms')
      ..writeln('                           $oneShot ms')
      ..writeln('   paged, $pageSize rows a page: ${paged.elapsedMilliseconds} ms '
          'over ${gaps.length} page-gaps')
      ..writeln('                           worst page-gap $worstGap ms, '
          'gaps over 50 ms: $over50');
    // ignore: avoid_print
    print(out.toString().trimRight());

    await db.close();
  });

  test('the price of an isolate', timeout: const Timeout(Duration(minutes: 10)), () async {
    // Moving JSON work off the main isolate is only worth anything if the move
    // itself is cheaper than the work. An isolate receives a *copy* of whatever
    // it is sent, so the question has a number: how long does the copy cost,
    // against how long the work costs?
    final AppDatabase db = AppDatabase.memory();
    await seed(db);
    final Directory dir = await Directory.systemTemp.createTemp('dhimmah-isolate');
    final BackupService backups = BackupService(
      database: db,
      appVersion: '1.0.0+1',
      clock: DateTime.now,
      directory: dir,
    );
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final String text = await written.file.readAsString();
    final Map<String, Object?> payload = (jsonDecode(text)! as Map<String, Object?>)['payload']!
        as Map<String, Object?>;

    Map<String, Object?> payloadOf(String text) =>
        (jsonDecode(text)! as Map<String, Object?>)['payload']!
            as Map<String, Object?>;

    // The work inline: canonicalise the payload and hash it.
    final Stopwatch inline = Stopwatch()..start();
    BackupFormat.checksumOf(payload);
    inline.stop();

    // The same work in an isolate, on the file's text — the text is copied in,
    // and only the digest comes back.
    final Stopwatch offloaded = Stopwatch()..start();
    await Isolate.run(() => BackupFormat.checksumOf(payloadOf(text)));
    offloaded.stop();

    // The shape a "validate in an isolate" design needs: the payload itself
    // comes back, because the main isolate has to write those rows.
    final Stopwatch withPayload = Stopwatch()..start();
    final Map<String, Object?> returned = await Isolate.run(() => payloadOf(text));
    withPayload.stop();

    // ignore: avoid_print
    print('''
=== THE PRICE OF AN ISOLATE (${(text.length / 1024 / 1024).toStringAsFixed(2)} MB file) ===
   checksum inline                           : ${inline.elapsedMilliseconds} ms
   checksum in an isolate (a digest returns) : ${offloaded.elapsedMilliseconds} ms
   decode in an isolate, payload returns     : ${withPayload.elapsedMilliseconds} ms
   payload tables returned                   : ${(returned['data']! as Map<String, Object?>).keys.length}
''');

    await db.close();
    await dir.delete(recursive: true);
  });

  test('complexity curve', timeout: const Timeout(Duration(minutes: 30)), () async {
    // Four sizes, each with the same shape, so a cost per row that grows with
    // size is visible as a rising figure and a linear one stays flat.
    // ignore: avoid_print
    print('\n=== COMPLEXITY CURVE (5 debts per person, 4 payments each) ===');
    // ignore: avoid_print
    print('   people   rows    create     inspect    replace-into-full   µs/row');
    for (final int size in <int>[peopleCount ~/ 4, peopleCount ~/ 2, peopleCount, peopleCount * 2]) {
      final Directory dir =
          await Directory.systemTemp.createTemp('dhimmah-curve-$size');
      final AppDatabase db = AppDatabase.memory();
      final int rows = await seedFixed(db, size, 5);
      final BackupService backups = BackupService(
        database: db,
        appVersion: '1.0.0+1',
        clock: DateTime.now,
        directory: dir,
      );
      final BackupRestoreService restores = BackupRestoreService(
        database: db,
        backups: backups,
        rebuildDerivedState: () async {},
      );

      final Stopwatch create = Stopwatch()..start();
      final ({File file, ParsedBackup backup}) written =
          await backups.create(kind: BackupKind.manual);
      create.stop();

      final Stopwatch inspect = Stopwatch()..start();
      await backups.inspect(written.file.path);
      inspect.stop();

      final Stopwatch restore = Stopwatch()..start();
      await restores.apply(backup: written.backup, mode: RestoreMode.replace);
      restore.stop();

      // ignore: avoid_print
      print('   ${size.toString().padLeft(6)} ${rows.toString().padLeft(6)} '
          '${create.elapsedMilliseconds.toString().padLeft(8)} ms '
          '${inspect.elapsedMilliseconds.toString().padLeft(8)} ms '
          '${restore.elapsedMilliseconds.toString().padLeft(14)} ms '
          '${(restore.elapsedMicroseconds / rows).round().toString().padLeft(8)}');

      await db.close();
      await dir.delete(recursive: true);
    }
    // ignore: avoid_print
    print('');
  });
}

/// The same shape as [seed], at an arbitrary size.
Future<int> seedFixed(AppDatabase db, int people, int debtsEach) async {
  final DateTime today = dateOnly(DateTime.now());
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
      for (int d = 0; d < debtsEach; d++)
        DebtsCompanion.insert(
          id: 'd${p}_$d',
          personId: Value<String>('p$p'),
          direction: DebtDirection.iOwe,
          title: Value<String>('قرض $d للشخص $p'),
          principalMinor: 100000,
          currencyCode: AppCurrency.inr.code,
          issuedAt: addDays(today, -100),
          dueAt: Value<DateTime>(addDays(today, d)),
          recurrence: RecurrenceFrequency.none,
          createdAt: today,
          updatedAt: today,
        ),
  ];
  await db.batch((Batch b) => b.insertAll(db.debts, debts));
  await db.batch((Batch b) => b.insertAll(db.debtPeople, <DebtPeopleCompanion>[
        for (final DebtsCompanion d in debts)
          DebtPeopleCompanion.insert(
            debtId: d.id.value,
            personId: d.personId.value!,
            createdAt: today,
          ),
      ]));
  await db.batch((Batch b) => b.insertAll(db.payments, <PaymentsCompanion>[
        for (final DebtsCompanion d in debts)
          for (int k = 0; k < 4; k++)
            PaymentsCompanion.insert(
              id: 'pay${d.id.value}_$k',
              debtId: Value<String>(d.id.value),
              personId: d.personId,
              amountMinor: 5000,
              currencyCode: AppCurrency.inr.code,
              paidAt: addDays(today, -20 + k),
              createdAt: today,
            ),
      ]));
  return people + debts.length + debts.length + debts.length * 4;
}
