import 'dart:io';

import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/services/attention_list.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Backward compatibility.
///
/// Opens a database file written by an earlier build of the app and reads it with
/// the current code. New features read the same tables and add no columns, so an
/// existing install must keep every record and the app must be able to build a
/// statement from it.
///
/// The file is produced by `test/tool/seed_demo_data_test.dart`; if it is absent
/// the test is skipped rather than failing, so a clean checkout still passes.
void main() {
  final File databaseFile = File('build/demo/dhimmah.sqlite');

  test('an existing database opens and every record survives', () async {
    if (!databaseFile.existsSync()) {
      markTestSkipped('no sample database; run the seed tool first');
      return;
    }

    // Copied so the fixture is never mutated by a read.
    final Directory temp = await Directory.systemTemp.createTemp('dhimmah-compat');
    final File copy = await databaseFile.copy('${temp.path}/dhimmah.sqlite');
    final AppDatabase db = AppDatabase(NativeDatabase(copy));
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
    final AppFormatting formatting = AppFormatting(
      language: AppLanguage.arabic,
      numerals: NumeralsStyle.latin,
      defaultCurrency: AppCurrency.inr,
      localizations: l10n,
    );

    final PersonRepositoryImpl people = PersonRepositoryImpl(db);
    final DebtRepositoryImpl debts = DebtRepositoryImpl(db);
    final PaymentRepositoryImpl payments = PaymentRepositoryImpl(db);
    final ObligationRepositoryImpl obligations = ObligationRepositoryImpl(db);
    final LedgerQueries queries = LedgerQueries(
      database: db,
      people: people,
      debts: debts,
      payments: payments,
      obligations: obligations,
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );

    addTearDown(() async {
      await db.close();
      await temp.delete(recursive: true);
    });

    // Nothing in the file was lost.
    expect(await people.getAll(), hasLength(3));
    expect(await debts.getAll(), hasLength(8));
    expect(await payments.getAll(), hasLength(3));
    expect(await obligations.getAll(), hasLength(4));

    // The stored settings row is read with the current model.
    final Setting? settings = await db.settingsDao.get();
    expect(settings, isNotNull);
    expect(settings!.onboardingCompleted, isTrue);

    // The ledger still resolves, and the new attention list works off it.
    final DateTime asOf = dateOnly(DateTime.now());
    final List<DebtView> views = await queries
        .watchDebtViews(dueSoonWindowDays: 7, asOf: asOf)
        .first;
    expect(views, hasLength(8));
    expect(
      views.any((DebtView v) => v.status == DebtLifecycleStatus.overdue),
      isTrue,
    );

    final List<ObligationInstance> instances =
        await queries.watchObligationInstances(asOf: asOf).first;
    final List<AttentionItem> attention = AttentionList.build(
      debts: views,
      obligations: instances,
      asOf: asOf,
    );
    expect(attention, isNotEmpty);

    // And a statement can be assembled from the old records.
    final PersonLedger? ledger = await queries
        .watchPersonLedger(
          views.first.debt.personId!,
          dueSoonWindowDays: 7,
          asOf: asOf,
        )
        .first;
    expect(ledger, isNotNull);
    final StatementData data = StatementService(
      localizations: l10n,
      formatting: formatting,
      settings: settings.toEntity(),
    ).buildData(
      ledger: ledger!,
      payments: await payments.getAll(),
      currency: AppCurrency.inr,
      now: asOf,
    );
    expect(data.remainingMinor, greaterThanOrEqualTo(0));
    expect(data.entries, isNotEmpty);
    expect(data.fileName, endsWith('.pdf'));
    expect(data.documentNumber, startsWith('DHM-'));
  });
}
