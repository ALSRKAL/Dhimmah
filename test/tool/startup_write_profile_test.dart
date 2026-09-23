import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/drift.dart' as drift show Value;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// What start-up waits for, and what one recorded payment costs end to end.
const int peopleCount = int.fromEnvironment('people', defaultValue: 10);
const int debtsPerPerson = int.fromEnvironment('debts', defaultValue: 5);
const int paymentsPerDebt = int.fromEnvironment('payments', defaultValue: 4);
const int obligationCount = int.fromEnvironment('obligations', defaultValue: 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Seeding a ledger at scale takes longer than the default budget.
  test('startup warm-up and one write', timeout: const Timeout(Duration(minutes: 3)), () async {
    final AppDatabase db = AppDatabase.memory();
    final DateTime today = dateOnly(DateTime.now());
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

    // The scale is chosen by the caller; see the two runs in the audit.
    await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
          for (int i = 0; i < peopleCount; i++)
            PeopleCompanion.insert(
              id: 'p$i',
              name: 'شخص $i',
              createdAt: today,
              updatedAt: today,
            ),
        ]));
    final List<DebtsCompanion> debts = <DebtsCompanion>[
      for (int p = 0; p < peopleCount; p++)
        for (int d = 0; d < debtsPerPerson; d++)
          DebtsCompanion.insert(
            id: 'd${p}_$d',
            personId: drift.Value<String>('p$p'),
            direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
            title: drift.Value<String>('قرض $d'),
            principalMinor: 100000,
            currencyCode: AppCurrency.inr.code,
            issuedAt: addDays(today, -100),
            dueAt: drift.Value<DateTime>(addDays(today, d * 3 - 10)),
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
    await db.batch((Batch b) => b.insertAll(db.obligations, <ObligationsCompanion>[
          for (int i = 0; i < obligationCount; i++)
            ObligationsCompanion.insert(
              id: 'o$i',
              name: 'التزام $i',
              category: ObligationCategory.other,
              amountMinor: 20000,
              currencyCode: AppCurrency.inr.code,
              frequency: RecurrenceFrequency.monthly,
              intervalCount: const drift.Value<int>(1),
              startAt: addDays(today, -400),
              nextDueAt: addDays(today, 1),
              createdAt: today,
              updatedAt: today,
            ),
        ]));

    final LedgerService service = LedgerService(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
      settings: SettingsRepositoryImpl(db),
      notifications: NotificationService(),
      localizations: () => l10n,
      composer: () => NotificationComposer(
        localizations: l10n,
        formatting: AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: l10n,
        ),
      ),
      clock: DateTime.now,
    );

    Future<int> timed(Future<void> Function() body) async {
      final Stopwatch w = Stopwatch()..start();
      try {
        await body();
      } on Object catch (e) {
        // The notification plugin is absent under `flutter test`; the ledger
        // work around it still runs and is what is being measured.
        // ignore: avoid_print
        print('   (notification plugin unavailable: ${e.runtimeType})');
      }
      w.stop();
      return w.elapsedMilliseconds;
    }

    // ignore: avoid_print
    print('''
=== START-UP WARM-UP AND ONE WRITE — $peopleCount people / ${debts.length} debts / $obligationCount obligations ===
   ensureOccurrences        : ${await timed(service.ensureOccurrences)} ms
   refreshNotifications     : ${await timed(service.refreshNotifications)} ms''');

    final int write = await timed(() async {
      await service.recordPayment(
        'd0_0',
        PaymentDraft(amountMinor: 100, paidAt: today),
      );
    });
    // ignore: avoid_print
    print('   recordPayment (total)    : $write ms');

    await db.close();
  });
}
