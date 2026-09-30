import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/reminder.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/app_harness.dart';

/// What the reminders screen says after a write, and when it says it.
///
/// The delete used to be fired without waiting for it: "deleted" was shown
/// before anything had happened, and a delete that failed was an error nothing
/// caught. Saving an edit said "reminder created".
void main() {
  late AppDatabase db;

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  const String title = 'تجديد الإقامة';

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<Reminder> seedReminder() => buildService(db).createReminder(
        ReminderDraft(
          title: title,
          dueAt: addDays(dateOnly(DateTime.now()), 3),
        ),
      );

  Future<void> open(WidgetTester tester, String location) async {
    await pumpDhimmah(tester, db: db);
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await settle(tester);
  }

  Future<void> deleteFromTheList(WidgetTester tester) async {
    await open(tester, AppRoutes.reminders);
    await tester.tap(find.text(title));
    await settle(tester);
    await tester.tap(find.text(l10n.actionDelete));
    await settle(tester);
  }

  testWidgets('a deleted reminder is said to be deleted once it is gone',
      (WidgetTester tester) async {
    await seedReminder();
    await deleteFromTheList(tester);

    expect(find.text(l10n.recordDeleted), findsOneWidget);
    expect(await db.select(db.reminders).get(), isEmpty);
    expect(find.text(title), findsNothing);
  });

  testWidgets('a delete that fails says so, and the reminder stays',
      (WidgetTester tester) async {
    await seedReminder();
    // The database refuses the delete, the way a failing disk would.
    await db.customStatement(
      'CREATE TRIGGER refuse_reminder_delete BEFORE DELETE ON reminders '
      "BEGIN SELECT RAISE(ABORT, 'refused'); END",
    );
    await deleteFromTheList(tester);

    expect(find.text(l10n.somethingWentWrong), findsOneWidget);
    expect(
      find.text(l10n.recordDeleted),
      findsNothing,
      reason: 'nothing was deleted, so nothing may say it was',
    );
    expect(await db.select(db.reminders).get(), hasLength(1));
    expect(find.text(title), findsOneWidget, reason: 'the row is still there');
  });

  testWidgets('saving an edit says it was saved, not created',
      (WidgetTester tester) async {
    await seedReminder();
    // The way a user gets there: the row, then Edit.
    await open(tester, AppRoutes.reminders);
    await tester.tap(find.text(title));
    await settle(tester);
    await tester.tap(find.text(l10n.actionEdit));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField).first, 'تجديد الجواز');
    await settle(tester);
    await tester.tap(find.text(l10n.saveChanges));
    await settle(tester);

    expect(find.text(l10n.recordSaved), findsOneWidget);
    expect(find.text(l10n.reminderCreated), findsNothing);
    expect(
      (await db.select(db.reminders).get()).single.title,
      'تجديد الجواز',
    );
  });
}
