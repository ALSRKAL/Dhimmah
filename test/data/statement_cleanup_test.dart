import 'dart:io';

import 'package:dhimmah/data/services/statement_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Removing generated statements.
///
/// This is a delete that runs inside the directory the ledger lives in, so the
/// tests here are mostly about what it must **not** touch. Each one builds a
/// directory shaped like the app's documents folder — a database file, a
/// backups folder, the statements folder — runs the purge, and reads back what
/// is left.
void main() {
  late Directory root;
  late File database;
  late File walFile;
  late File backup;
  late Directory statements;

  File statement(String name) => File(p.join(statements.path, name));

  Future<File> write(File file, {DateTime? modified}) async {
    await file.create(recursive: true);
    await file.writeAsString('content of ${p.basename(file.path)}');
    if (modified != null) await file.setLastModified(modified);
    return file;
  }

  final DateTime now = DateTime(2026, 11, 13, 12);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dhimmah-cleanup');
    database = await write(File(p.join(root.path, 'dhimmah.sqlite')));
    walFile = await write(File(p.join(root.path, 'dhimmah.sqlite-wal')));
    backup = await write(
      File(p.join(root.path, 'backups', 'dhimmah-backup.dhimmah')),
    );
    statements = Directory(p.join(root.path, StatementService.generatedFolder));
    await statements.create();
  });

  tearDown(() async => root.delete(recursive: true));

  void expectLedgerUntouched() {
    expect(database.existsSync(), isTrue, reason: 'the database was deleted');
    expect(
      database.readAsStringSync(),
      'content of dhimmah.sqlite',
      reason: 'the database was rewritten',
    );
    expect(walFile.existsSync(), isTrue, reason: 'the write-ahead log is gone');
    expect(backup.existsSync(), isTrue, reason: 'a backup was deleted');
    expect(root.existsSync(), isTrue);
  }

  test('removes every generated statement and nothing else', () async {
    await write(statement('Dhimmah_أحمد_2026-11-01.pdf'));
    await write(statement('Dhimmah_Khalid_2026-11-13.PDF'));

    final int removed = await StatementService.purgeGenerated(root: root);

    expect(removed, 2);
    expect(statements.listSync(), isEmpty);
    expect(
      statements.existsSync(),
      isTrue,
      reason: 'the folder itself is left in place',
    );
    expectLedgerUntouched();
  });

  test('with an age, only the old ones go', () async {
    final File old = await write(
      statement('old.pdf'),
      modified: now.subtract(const Duration(hours: 25)),
    );
    final File fresh = await write(
      statement('fresh.pdf'),
      modified: now.subtract(const Duration(hours: 1)),
    );

    final int removed = await StatementService.purgeGenerated(
      root: root,
      olderThan: const Duration(hours: 24),
      now: now,
    );

    expect(removed, 1);
    expect(old.existsSync(), isFalse);
    expect(
      fresh.existsSync(),
      isTrue,
      reason: 'a statement being shared right now must survive start-up',
    );
    expectLedgerUntouched();
  });

  test('a file that is not a PDF is not its to delete', () async {
    // Nothing else is written to this folder today. If something ever is — or
    // a user drops a file there — it is left alone.
    final File stray = await write(statement('notes.txt'));
    final File lookalike = await write(statement('dhimmah.sqlite'));
    await write(statement('real.pdf'));

    expect(await StatementService.purgeGenerated(root: root), 1);
    expect(stray.existsSync(), isTrue);
    expect(lookalike.existsSync(), isTrue);
    expectLedgerUntouched();
  });

  test('it does not descend into folders', () async {
    final File nested = await write(
      File(p.join(statements.path, 'kept', 'inside.pdf')),
    );

    expect(await StatementService.purgeGenerated(root: root), 0);
    expect(nested.existsSync(), isTrue);
    expectLedgerUntouched();
  });

  test('a PDF beside the database is not a statement', () async {
    // Only the statements folder is searched. A PDF in the documents directory
    // itself, or among the backups, was not put there by this.
    final File beside = await write(File(p.join(root.path, 'export.pdf')));
    final File amongBackups =
        await write(File(p.join(root.path, 'backups', 'copy.pdf')));
    await write(statement('real.pdf'));

    expect(await StatementService.purgeGenerated(root: root), 1);
    expect(beside.existsSync(), isTrue);
    expect(amongBackups.existsSync(), isTrue);
    expectLedgerUntouched();
  });

  test('a link is not followed out of the folder', () async {
    final Link link = Link(p.join(statements.path, 'linked.pdf'));
    await link.create(database.path);

    await StatementService.purgeGenerated(root: root);

    expectLedgerUntouched();
  });

  test('no statements folder at all is not an error', () async {
    await statements.delete();
    expect(await StatementService.purgeGenerated(root: root), 0);
    expectLedgerUntouched();
  });

  test('a documents directory that does not exist is not an error', () async {
    final Directory missing = Directory(p.join(root.path, 'nowhere'));
    expect(await StatementService.purgeGenerated(root: missing), 0);
    expectLedgerUntouched();
  });
}
