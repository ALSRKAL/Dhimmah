import 'dart:convert';
import 'dart:io';

import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/data_export_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// What leaves the app in a file.
///
/// An export is a copy somebody keeps, so the two things that matter are that
/// every record appears exactly once — an export that repeats a shared debt
/// three times triples the money on the reader's side — and that it says who each
/// record is with.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LedgerService service;
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dhimmah-export');
    // `path_provider` has no implementation under a plain test run, so the
    // directory it would have asked the platform for is stubbed.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => temp.path,
    );

    db = AppDatabase.memory();
    service = buildService(db);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  DataExportService exporter() {
    final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
    return DataExportService(
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    );
  }

  Future<({Person ahmed, Person ali, Person mohammed})> seed() async {
    final Person ahmed = await service.createPerson(const PersonDraft(name: 'أحمد'));
    final Person ali = await service.createPerson(const PersonDraft(name: 'علي'));
    final Person mohammed =
        await service.createPerson(const PersonDraft(name: 'محمد'));
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id, ali.id, mohammed.id],
        title: 'فاتورة العشاء',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: dateOnly(DateTime.now()),
      ),
    );
    return (ahmed: ahmed, ali: ali, mohammed: mohammed);
  }

  test('the CSV has one row per record, naming everyone on it', () async {
    final ({Person ahmed, Person ali, Person mohammed}) people = await seed();

    final String path = await exporter().export(ExportFormat.csv);
    final List<String> lines =
        (await File(path).readAsString()).trim().split('\n');

    expect(lines.first, startsWith('date,kind,person,description'));
    // The header, one debt row, one activity row per creation — and exactly one
    // row for the shared record, not one per participant.
    final List<String> debtRows =
        lines.where((String line) => line.contains(',debt,')).toList();
    expect(debtRows, hasLength(1));
    expect(
      debtRows.single,
      contains('أحمد، علي، محمد'),
      reason: 'the people column names all three',
    );
    expect(people.ahmed.id, isNotEmpty);
  });

  test('the JSON carries every participant and still one record', () async {
    final ({Person ahmed, Person ali, Person mohammed}) people = await seed();

    final String path = await exporter().export(ExportFormat.json);
    final Map<String, Object?> payload =
        jsonDecode(await File(path).readAsString()) as Map<String, Object?>;

    final List<Object?> debts = payload['debts']! as List<Object?>;
    expect(debts, hasLength(1));
    final Map<String, Object?> debt = debts.single as Map<String, Object?>;
    expect(debt['personId'], people.ahmed.id, reason: 'the first person named');
    expect(
      debt['personIds'],
      <String>[people.ahmed.id, people.ali.id, people.mohammed.id],
    );
    expect(debt['amountMinor'], 150000);
  });
}
