import 'dart:io';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

StatementData _data(String personName) => StatementData(
  documentNumber: 'DHM-2026-0001',
  generatedAt: DateTime(2026, 11, 24),
  language: AppLanguage.english,
  personName: personName,
  phone: null,
  currency: AppCurrency.usd,
  totalMinor: 10000,
  paidMinor: 0,
  remainingMinor: 10000,
  status: DebtLifecycleStatus.active,
  debts: const <StatementDebtLine>[],
  entries: const <StatementEntry>[],
  options: const StatementOptions(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a person name with separators and an emoji still yields a safe file',
    () {
      final String name = StatementData.sanitiseFileName('a/b:c *?<>|😀.');
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('*')));
      expect(name, isNot(contains('?')));
      expect(name, isNot(contains('<')));
      expect(name, isNot(contains('>')));
      expect(name, isNot(contains('|')));
      expect(name, isNot(startsWith('_')));
      expect(name, isNot(endsWith('_')));
      expect(name, isNotEmpty);

      final Directory dir = Directory.systemTemp.createTempSync(
        'dhimmah_name_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final String fileName = _data('a/b:c *?<>|😀.').fileName;
      final File file = File('${dir.path}/$fileName')..writeAsStringSync('x');
      expect(file.existsSync(), isTrue);
      expect(fileName, endsWith('.pdf'));
    },
  );

  test('an empty name still gets a usable file name', () {
    expect(StatementData.sanitiseFileName('   '), 'Statement');
  });

  test('the two document fonts load from the shipped assets', () async {
    final ByteData regular = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final ByteData semiBold = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    );
    expect(pw.Font.ttf(regular), isNotNull);
    expect(pw.Font.ttf(semiBold), isNotNull);
  });
}
