import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
// drift exports its own `isNull` / `isNotNull` SQL expressions, which collide
// with the matchers of the same name.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

/// Exercises the real schema against a real SQLite engine.
///
/// This is the test that proves the persistence layer is wired correctly:
/// converters, enums, foreign keys and the seeded settings row.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    // Touch the database so `onCreate` runs before the first assertion.
    await db.settings.select().get();
  });

  tearDown(() async => db.close());

  test('seeds a single settings row with the documented defaults', () async {
    final List<Setting> rows = await db.settings.select().get();
    expect(rows, hasLength(1));

    final Setting settings = rows.single;
    expect(settings.id, 1);
    // A new install follows the phone rather than assuming Arabic.
    expect(settings.languagePreference, LanguagePreference.system);
    expect(settings.defaultCurrencyCode, 'INR');
    expect(settings.monthEndDay.isLastDay, isTrue);
    expect(settings.notificationsEnabled, isTrue);
    expect(settings.onboardingCompleted, isFalse);
  });

  test('round-trips a person with a nullable phone and archive stamp',
      () async {
    final DateTime now = DateTime(2026, 9, 22, 10, 30);
    await db.peopleDao.upsert(
      PersonRow(
        id: 'p1',
        name: 'أحمد محمد',
        note: 'صديق',
        colorIndex: 3,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final PersonRow? loaded = await db.peopleDao.getById('p1');
    expect(loaded, isNotNull);
    expect(loaded!.name, 'أحمد محمد');
    expect(loaded.phone, isNull);
    expect(loaded.colorIndex, 3);
    // Timestamps survive the UTC round-trip to the second.
    expect(
      loaded.createdAt.millisecondsSinceEpoch ~/ 1000,
      now.millisecondsSinceEpoch ~/ 1000,
    );

    await db.peopleDao.setArchived('p1', DateTime(2026, 10), now);
    expect((await db.peopleDao.getById('p1'))!.archivedAt, isNotNull);
  });

  test('stores calendar dates without a time component', () async {
    final DateTime now = DateTime(2026, 9, 22, 23, 59);
    await db.debtsDao.upsert(
      DebtRow(
        id: 'd1',
        direction: DebtDirection.iOwe,
        title: 'سلفة',
        principalMinor: 500000,
        currencyCode: 'INR',
        issuedAt: DateTime(2026, 9, 22),
        dueAt: DateTime(2026, 12, 31),
        reminderLeads: const <ReminderLead>[
          ReminderLead.oneWeekBefore,
          ReminderLead.onDueDate,
        ],
        recurrence: RecurrenceFrequency.none,
        recurrenceInterval: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Read the raw column to prove it is stored as a plain calendar date.
    final QueryRow raw = await db
        .customSelect('SELECT due_at FROM debts WHERE id = ?',
            variables: <Variable<String>>[Variable<String>('d1')])
        .getSingle();
    expect(raw.data['due_at'], '2026-12-31');

    final DebtRow loaded = (await db.debtsDao.getById('d1'))!;
    expect(loaded.dueAt, DateTime(2026, 12, 31));
    expect(loaded.issuedAt, DateTime(2026, 9, 22));
    expect(loaded.currencyCode, 'INR');
    expect(loaded.direction, DebtDirection.iOwe);
    // Lead times come back normalised, furthest out first.
    expect(loaded.reminderLeads, <ReminderLead>[
      ReminderLead.oneWeekBefore,
      ReminderLead.onDueDate,
    ]);
  });

  test('keeps a nullable due date null', () async {
    final DateTime now = DateTime(2026, 9, 22);
    await db.debtsDao.upsert(
      DebtRow(
        id: 'd2',
        direction: DebtDirection.owedToMe,
        title: '',
        principalMinor: 1000,
        currencyCode: 'USD',
        issuedAt: dateOnly(now),
        reminderLeads: const <ReminderLead>[],
        recurrence: RecurrenceFrequency.monthly,
        recurrenceInterval: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final DebtRow loaded = (await db.debtsDao.getById('d2'))!;
    expect(loaded.dueAt, isNull);
    expect(loaded.reminderLeads, isEmpty);
    expect(loaded.recurrence, RecurrenceFrequency.monthly);
  });

  test('records payments against a debt and reports them back', () async {
    final DateTime now = DateTime(2026, 9, 22);
    await db.debtsDao.upsert(
      DebtRow(
        id: 'd3',
        direction: DebtDirection.iOwe,
        title: '',
        principalMinor: 500000,
        currencyCode: 'INR',
        issuedAt: dateOnly(now),
        reminderLeads: const <ReminderLead>[],
        recurrence: RecurrenceFrequency.none,
        recurrenceInterval: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.debtsDao.upsertPayment(
      PaymentRow(
        id: 'pay1',
        debtId: 'd3',
        amountMinor: 100000,
        currencyCode: 'INR',
        paidAt: DateTime(2026, 9, 25),
        note: 'دفعة أولى',
        createdAt: now,
      ),
    );

    final List<PaymentRow> payments = await db.debtsDao.getPaymentsForDebt('d3');
    expect(payments, hasLength(1));
    expect(payments.single.amountMinor, 100000);
    expect(payments.single.paidAt, DateTime(2026, 9, 25));
    expect(AppCurrency.parse(payments.single.currencyCode), AppCurrency.inr);
  });

  test('generates obligation occurrences and enforces one row per period',
      () async {
    final DateTime now = DateTime(2026, 9, 22);
    await db.obligationsDao.upsert(
      ObligationRow(
        id: 'o1',
        name: 'إيجار المنزل',
        category: ObligationCategory.housing,
        amountMinor: 2000000,
        currencyCode: 'INR',
        frequency: RecurrenceFrequency.monthly,
        intervalCount: 1,
        dayOfMonth: 1,
        startAt: DateTime(2026),
        nextDueAt: DateTime(2026, 10),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        createdAt: now,
        updatedAt: now,
      ),
    );

    Future<void> insertOccurrence(String id, String periodKey) {
      return db.obligationsDao.upsertOccurrence(
        ObligationOccurrenceRow(
          id: id,
          obligationId: 'o1',
          periodKey: periodKey,
          dueAt: DateTime(2026, 9),
          amountMinor: 2000000,
          status: ObligationStatus.paid,
          paidAt: DateTime(2026, 9),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    await insertOccurrence('occ1', '2026-09');
    expect(await db.obligationsDao.existingPeriodKeys('o1'), <String>{'2026-09'});

    // The unique constraint on (obligation_id, period_key) is the backstop that
    // stops a schedule from ever double-billing a month.
    await expectLater(
      insertOccurrence('occ2', '2026-09'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('deleting a person leaves their debts intact but unlinked', () async {
    final DateTime now = DateTime(2026, 9, 22);
    await db.peopleDao.upsert(
      PersonRow(
        id: 'p2',
        name: 'خالد',
        colorIndex: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.debtsDao.upsert(
      DebtRow(
        id: 'd4',
        personId: 'p2',
        direction: DebtDirection.iOwe,
        title: 'دين',
        principalMinor: 100,
        currencyCode: 'SAR',
        issuedAt: dateOnly(now),
        reminderLeads: const <ReminderLead>[],
        recurrence: RecurrenceFrequency.none,
        recurrenceInterval: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.peopleDao.deleteById('p2');

    final DebtRow? debt = await db.debtsDao.getById('d4');
    expect(debt, isNotNull, reason: 'financial history must survive');
    expect(debt!.personId, isNull);
  });

  group('the table that joins a debt to its people', () {
    Future<void> addPerson(String id, String name) => db.peopleDao.upsert(
          PersonRow(
            id: id,
            name: name,
            colorIndex: 0,
            createdAt: DateTime(2026, 9, 22),
            updatedAt: DateTime(2026, 9, 22),
          ),
        );

    Future<void> addDebt(String id) => db.debtsDao.upsert(
          DebtRow(
            id: id,
            direction: DebtDirection.iOwe,
            title: 'دين',
            principalMinor: 100,
            currencyCode: 'SAR',
            issuedAt: DateTime(2026, 9, 22),
            reminderLeads: const <ReminderLead>[],
            recurrence: RecurrenceFrequency.none,
            recurrenceInterval: 0,
            createdAt: DateTime(2026, 9, 22),
            updatedAt: DateTime(2026, 9, 22),
          ),
          personIds: <String>['p1'],
        );

    test('refuses the same person twice on one record', () async {
      await addPerson('p1', 'أحمد');
      await addDebt('d1');

      await expectLater(
        db.customStatement(
          'INSERT INTO debt_people (debt_id, person_id, position, created_at) '
          "VALUES ('d1', 'p1', 5, 0)",
        ),
        throwsA(isA<SqliteException>()),
        reason: 'the pair is the primary key, so the rule holds in the database '
            'and not only in the screen that collects it',
      );
    });

    test('removes a debt’s links when the debt goes', () async {
      await addPerson('p1', 'أحمد');
      await addDebt('d1');
      expect(await db.debtsDao.participantsFor('d1'), <String>['p1']);

      await db.debtsDao.deleteById('d1');

      expect(await db.debtsDao.allParticipants(), isEmpty);
    });

    test('removes a person’s links when the person goes', () async {
      await addPerson('p1', 'أحمد');
      await addPerson('p2', 'علي');
      await addDebt('d1');
      await db.debtsDao.setParticipants('d1', <String>['p1', 'p2']);

      await db.peopleDao.deleteById('p2');

      // The link is gone and the record's one-value column now names the person
      // who is still there rather than the one who is not.
      expect(await db.debtsDao.participantsFor('d1'), <String>['p1']);
      expect((await db.debtsDao.getById('d1'))!.personId, 'p1');
    });
  });

  test('clearAllData empties user tables but keeps settings', () async {
    final DateTime now = DateTime(2026, 9, 22);
    await db.remindersDao.upsert(
      ReminderRow(
        id: 'r1',
        title: 'تذكير',
        dueAt: dateOnly(now),
        relatedType: RelatedEntityType.none,
        status: ReminderStatus.upcoming,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.clearAllData();

    expect(await db.remindersDao.getAll(), isEmpty);
    expect(await db.settings.select().get(), hasLength(1));
  });
}
