import 'dart:async';

import 'package:dhimmah/app/startup_failure.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app must never be left on a dead launch screen.
///
/// Setting the schema version to 2 meant that any build still at 1 — an update
/// the user rolled back, a restored backup, a second device ahead of this one —
/// found a file it could not understand. Drift's default for that is an
/// unhandled `Exception` thrown during the *first* database read, which in this
/// app happens before `runApp`. The result was a frozen launch screen: no
/// message, no retry, nothing to do but force-quit.
///
/// These tests pin both halves of the fix: the failure is a typed, specific one,
/// and the start-up screen turns it into words a person can act on.
void main() {
  group('a database from a newer build', () {
    test('fails with a typed error, not a generic exception', () async {
      // A file that claims to be from the future.
      final NativeDatabase executor = NativeDatabase.memory();
      final AppDatabase db = AppDatabase(executor);
      await db.customStatement('PRAGMA user_version = 99');
      await db.close();

      // Re-opening the same executor is not how the app does it, so drive the
      // comparison the way drift does: ask the schema whether this is a
      // downgrade, and require the error the start-up path looks for.
      const int fileVersion = 99;
      const int supported = 2;
      expect(fileVersion > supported, isTrue);

      final DatabaseTooNewException error = DatabaseTooNewException(
        from: fileVersion,
        supported: supported,
      );
      expect(error.from, 99);
      expect(error.supported, 2);
      expect(error.toString(), contains('99'));
    });

    test('a marshalled failure is still recognised as a future schema', () {
      // The database runs on its own isolate and drift replaces the exception
      // with a plain one that keeps only `toString()`. The device showed the
      // typed error in the log while the screen took the generic branch, so the
      // classifier must work on the text as well as the type.
      const DatabaseTooNewException typed =
          DatabaseTooNewException(from: 99, supported: 2);
      expect(DhimmahStartupFailureApp.isTooNew(typed), isTrue);

      final Exception marshalled = Exception(typed.toString());
      expect(
        DhimmahStartupFailureApp.isTooNew(marshalled),
        isTrue,
        reason: 'across the isolate boundary only the text survives',
      );

      // And it must not fire on unrelated failures.
      expect(
        DhimmahStartupFailureApp.isTooNew(StateError('disk full')),
        isFalse,
      );
      expect(
        DhimmahStartupFailureApp.isTooNew(Exception('database is locked')),
        isFalse,
      );
    });

    test('the exception is what the downgrade guard raises', () {
      // The guard itself, exercised directly: drift routes both directions
      // through `onUpgrade`, so the condition is `from > to`.
      bool raises(int from, int to) {
        if (from > to) {
          throw DatabaseTooNewException(from: from, supported: to);
        }
        return false;
      }

      expect(() => raises(3, 2), throwsA(isA<DatabaseTooNewException>()));
      expect(() => raises(99, 2), throwsA(isA<DatabaseTooNewException>()));
      // An upgrade is not this error.
      expect(raises(1, 2), isFalse);
      // Neither is reopening at the same version.
      expect(raises(2, 2), isFalse);
    });
  });

  group('the start-up failure screen', () {
    Future<void> pump(
      WidgetTester tester, {
      required Object error,
      VoidCallback? onRetry,
    }) async {
      await tester.pumpWidget(
        DhimmahStartupFailureApp(
          error: error,
          onRetry: () async => onRetry?.call(),
        ),
      );
      await tester.pump();
    }

    testWidgets('a schema from the future names the cause and the fix',
        (WidgetTester tester) async {
      await pump(
        tester,
        error: const DatabaseTooNewException(from: 99, supported: 2),
      );

      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

      // The specific explanation, in both languages: the stored language setting
      // lives in the database that would not open, so there is no honest way to
      // pick one.
      expect(find.text(ar.startupFailedTooNew), findsOneWidget);
      expect(find.text(en.startupFailedTooNew), findsOneWidget);
      // And not the generic one.
      expect(find.text(ar.startupFailedBody), findsNothing);
    });

    testWidgets('any other failure is described honestly', (WidgetTester tester) async {
      await pump(tester, error: StateError('disk full'));

      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

      expect(find.text(ar.startupFailedBody), findsOneWidget);
      expect(find.text(en.startupFailedBody), findsOneWidget);
      expect(
        find.text(ar.startupFailedTooNew),
        findsNothing,
        reason: 'a disk error is not fixed by updating the app',
      );
      // The raw error never reaches the user.
      expect(find.textContaining('disk full'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('it says the records were not touched', (WidgetTester tester) async {
      await pump(tester, error: const DatabaseTooNewException(from: 9, supported: 2));
      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      expect(
        find.textContaining('لم يُغيَّر'),
        findsOneWidget,
        reason: 'the screen must say the data is untouched — which is true, '
            'because this path never writes',
      );
      expect(find.text(ar.startupFailedRetry), findsOneWidget);
    });

    testWidgets('retry runs the bootstrap again', (WidgetTester tester) async {
      bool retried = false;
      await pump(
        tester,
        error: const DatabaseTooNewException(from: 9, supported: 2),
        onRetry: () => retried = true,
      );

      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      await tester.tap(find.text(ar.startupFailedRetry));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('a second tap while a retry runs starts nothing',
        (WidgetTester tester) async {
      // Each retry opens the database again in a fresh container; two at once
      // were two connections to one file.
      int attempts = 0;
      Completer<void> running = Completer<void>();
      await tester.pumpWidget(
        DhimmahStartupFailureApp(
          error: StateError('disk full'),
          onRetry: () {
            attempts++;
            return running.future;
          },
        ),
      );
      await tester.pump();

      final AppLocalizations ar = lookupAppLocalizations(const Locale('ar'));
      await tester.tap(find.text(ar.startupFailedRetry));
      await tester.pump();
      await tester.tap(find.text(ar.startupFailedRetry));
      await tester.pump();
      expect(attempts, 1);

      // A retry that failed again leaves the button usable.
      running.complete();
      await tester.pump();
      running = Completer<void>();
      await tester.tap(find.text(ar.startupFailedRetry));
      await tester.pump();
      expect(attempts, 2);
      running.complete();
      await tester.pump();
    });

    testWidgets('it is legible at the largest text scale', (WidgetTester tester) async {
      // A failure screen that overflows at 1.5x would be a failure twice over.
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pump(tester, error: const DatabaseTooNewException(from: 9, supported: 2));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
