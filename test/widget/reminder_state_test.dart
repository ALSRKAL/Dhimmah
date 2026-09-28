import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// A reminder that cannot arrive is stated, not implied.
///
/// "A reminder is set" and "a reminder will arrive" are different statements,
/// and the app must not make the first while the second is impossible. These
/// drive the real screens: the form where the choice is made, and the record's
/// own page where it is read later.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.memory());
  tearDown(() async => db.close());

  const String personName = 'محمد أحمد عبدالرحمن';
  const String debtTitle = 'قرض سيارة';

  Future<void> seed(WidgetTester tester, {required bool remindersOn}) async {
    final Person person = await buildService(db).createPerson(
      const PersonDraft(name: personName),
    );
    await buildService(db).createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: debtTitle,
        principalMinor: 1000000,
        currency: AppCurrency.inr,
        issuedAt: dateOnly(DateTime.now()),
        dueAt: addDays(dateOnly(DateTime.now()), 5),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );
    await pumpDhimmah(
      tester,
      db: db,
      settings: AppSettings.initial.copyWith(notificationsEnabled: remindersOn),
      // The host has no notification permission to read, so the screens are
      // given the answer a phone would give.
      notificationPermission: NotificationPermission.granted,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  /// Scrolls the form until [target] exists: the reminder lives in the section
  /// below the required fields, which on this viewport starts off-screen.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (int i = 0; i < 12 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -240));
      await settle(tester);
    }
    expect(target, findsWidgets, reason: 'the field should be reachable');
  }

  /// Ledger → the record → edit, where the reminder is chosen.
  Future<void> openEditForm(WidgetTester tester) async {
    await tester.tap(find.text('السجل').last);
    await settle(tester);
    await tester.tap(find.textContaining(debtTitle).first);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await settle(tester);
    await reveal(tester, find.text('قبل يوم'));
  }

  /// Ledger → the record, whose facts card repeats the reminder.
  Future<void> openDetail(WidgetTester tester) async {
    await tester.tap(find.text('السجل').last);
    await settle(tester);
    await tester.tap(find.textContaining(debtTitle).first);
    await settle(tester);
  }

  testWidgets('the form says the reminder will not arrive', (
    WidgetTester tester,
  ) async {
    await seed(tester, remindersOn: false);
    await openEditForm(tester);

    expect(
      find.textContaining('التذكيرات متوقفة'),
      findsOneWidget,
      reason: 'a chosen reminder that cannot fire has to say so where it is '
          'chosen',
    );
  });

  testWidgets('the form says so when the system blocks notifications', (
    WidgetTester tester,
  ) async {
    await seed(tester, remindersOn: true);
    // Re-pump with a phone that refuses notifications.
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    await pumpDhimmah(
      tester,
      db: db,
      notificationPermission: NotificationPermission.denied,
    );
    await openEditForm(tester);

    expect(
      find.textContaining('الإشعارات غير مسموح بها من النظام'),
      findsOneWidget,
    );
  });

  testWidgets('the record’s page repeats it', (WidgetTester tester) async {
    await seed(tester, remindersOn: false);
    await openDetail(tester);

    expect(
      find.textContaining('التذكيرات متوقفة'),
      findsOneWidget,
      reason: 'the record must not promise a notification that will not come',
    );
  });

  testWidgets('nothing is said when the reminder will arrive', (
    WidgetTester tester,
  ) async {
    await seed(tester, remindersOn: true);
    await openEditForm(tester);
    expect(find.textContaining('التذكيرات متوقفة'), findsNothing);
    expect(find.textContaining('غير مسموح'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    await pumpDhimmah(
      tester,
      db: db,
      notificationPermission: NotificationPermission.granted,
    );
    await openDetail(tester);
    expect(find.textContaining('التذكيرات متوقفة'), findsNothing);
    expect(find.textContaining('قبل يوم'), findsWidgets,
        reason: 'the reminder itself is still shown');
  });
}
