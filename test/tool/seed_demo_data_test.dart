import 'dart:io';

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
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Writes a populated database to a file, for reviewing the app's screens with
/// real data in them. Not part of the normal test run.
///
///   flutter test test/tool/seed_demo_data_test.dart
///   adb push build/demo/dhimmah.sqlite /data/local/tmp/
///
void main() {
  test('writes a demo database', () async {
    final Directory dir = Directory('build/demo');
    await dir.create(recursive: true);
    final File file = File('${dir.path}/dhimmah.sqlite');
    if (file.existsSync()) await file.delete();

    final AppDatabase db = AppDatabase(NativeDatabase(file));
    final DateTime today = dateOnly(DateTime.now());
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
    final AppFormatting formatting = AppFormatting(
      language: AppLanguage.arabic,
      numerals: NumeralsStyle.latin,
      defaultCurrency: AppCurrency.inr,
      localizations: l10n,
    );
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
        formatting: formatting,
      ),
      clock: DateTime.now,
    );

    // Start from the state a real user would be in.
    await SettingsRepositoryImpl(db).save(
      AppSettings.initial.copyWith(
        onboardingCompleted: true,
        defaultCurrency: AppCurrency.inr,
        language: AppLanguage.arabic,
        dueSoonWindowDays: 7,
      ),
    );

    Future<Person> person(String name, int color) => service.createPerson(
          PersonDraft(name: name, colorIndex: color),
        );

    // --- Money I owe ------------------------------------------------------
    final Person ahmed = await person('أحمد محمد', 0);
    final Person khalid = await person('خالد العلي', 3);
    final Person office = await person('مكتب المحاسبة', 5);

    final Debt rent = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personId: khalid.id,
        title: 'سلفة',
        principalMinor: 2000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -40),
        dueAt: addDays(today, 3),
        reminderLeads: const <ReminderLead>[
          ReminderLead.oneDayBefore,
          ReminderLead.threeDaysBefore,
        ],
        note: 'سلفة شخصية لظرف طارئ',
      ),
    );
    await service.recordPayment(
      rent.id,
      PaymentDraft(
        amountMinor: 500000,
        paidAt: addDays(today, -12),
        note: 'دفعة أولى',
      ),
    );

    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personId: ahmed.id,
        title: 'قرض سيارة',
        principalMinor: 3500000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -90),
        dueAt: addDays(today, -4),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personId: office.id,
        title: 'أتعاب',
        principalMinor: 850000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -20),
        dueAt: addDays(today, 12),
      ),
    );
    // No due date at all: the "ongoing" state.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personId: khalid.id,
        title: 'مصاريف مشتركة',
        principalMinor: 320000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -60),
      ),
    );

    // --- Money owed to me --------------------------------------------------
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personId: ahmed.id,
        title: 'قرض',
        principalMinor: 1500000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -30),
        dueAt: addDays(today, 1),
        reminderLeads: const <ReminderLead>[ReminderLead.onDueDate],
      ),
    );
    final Debt settled = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personId: office.id,
        title: 'فاتورة خدمات',
        principalMinor: 3000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -50),
        dueAt: addDays(today, -10),
      ),
    );
    await service.recordPayment(
      settled.id,
      PaymentDraft(
        amountMinor: 3000000,
        paidAt: addDays(today, -8),
        note: 'سُدّد بالكامل',
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personId: khalid.id,
        title: 'مشاركة في رحلة',
        principalMinor: 750000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -5),
        dueAt: addDays(today, 20),
      ),
    );

    // A second currency, to show that balances are never added together.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personId: ahmed.id,
        title: 'تحويل بالدولار',
        principalMinor: 120000,
        currency: AppCurrency.usd,
        issuedAt: addDays(today, -3),
        dueAt: addDays(today, 25),
      ),
    );

    // --- Recurring commitments --------------------------------------------
    await service.createObligation(
      ObligationDraft(
        name: 'إيجار المنزل',
        category: ObligationCategory.housing,
        amountMinor: 2000000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month),
        dayOfMonth: 1,
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );
    await service.createObligation(
      ObligationDraft(
        name: 'فاتورة الإنترنت',
        category: ObligationCategory.telecom,
        amountMinor: 120000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month, 5),
        dayOfMonth: 5,
        reminderLeads: const <ReminderLead>[ReminderLead.twoDaysBefore],
      ),
    );
    await service.createObligation(
      ObligationDraft(
        name: 'قسط السيارة',
        category: ObligationCategory.installment,
        amountMinor: 1800000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month, 15),
        dayOfMonth: 15,
      ),
    );
    await service.createObligation(
      ObligationDraft(
        name: 'اشتراك الصالة الرياضية',
        category: ObligationCategory.subscription,
        amountMinor: 25000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(today.year, today.month, 20),
        dayOfMonth: 20,
      ),
    );

    // Pay the month's rent, so history and an upcoming period both exist.
    await service.ensureOccurrences();
    final ObligationInstance? due = await _firstPayable(db);
    if (due != null) await service.markObligationPaid(due);

    // --- Reminders ---------------------------------------------------------
    await service.createReminder(
      ReminderDraft(
        title: 'تجديد التأمين الطبي',
        dueAt: addDays(today, 4),
        note: 'قبل انتهاء المهلة بأسبوع',
      ),
    );
    await service.createReminder(
      ReminderDraft(
        title: 'مراجعة كشف الحساب البنكي',
        dueAt: addDays(today, 1),
      ),
    );
    await service.createReminder(
      ReminderDraft(title: 'تسليم تقرير الضريبة', dueAt: addDays(today, 21)),
    );

    await db.close();
    // ignore: avoid_print
    print('SEEDED ${file.path}');
  });
}

/// The first obligation period that still needs paying.
Future<ObligationInstance?> _firstPayable(AppDatabase db) async {
  final ObligationRepositoryImpl obligations = ObligationRepositoryImpl(db);
  for (final Obligation obligation in await obligations.getAll()) {
    for (final ObligationOccurrence occurrence
        in await obligations.occurrencesFor(obligation.id)) {
      if (occurrence.isPayable) {
        return ObligationInstance(obligation: obligation, occurrence: occurrence);
      }
    }
  }
  return null;
}
