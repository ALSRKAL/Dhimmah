import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/record_rows.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A list of people reads with the language's own comma.
///
/// A record linked to several people used to be named with a plus, as if the
/// names were an addition. The separator is a translation: «،» in Arabic and a
/// comma in English, whatever script the names are written in.
void main() {
  final DateTime today = DateTime(2026, 11, 18);
  final Debt debt = Debt(
    id: 'd1',
    personIds: const <String>['a', 'b'],
    direction: DebtDirection.owedToMe,
    title: 'سفر',
    principalMinor: 100000,
    currency: AppCurrency.inr,
    issuedAt: today,
    createdAt: today,
    updatedAt: today,
  );
  final DebtView view = DebtView(
    debt: debt,
    paidMinor: 0,
    remainingMinor: 100000,
    status: DebtLifecycleStatus.active,
    paymentCount: 0,
    participants: <Person>[
      Person(
        id: 'a',
        name: 'Ahmed',
        colorIndex: 0,
        createdAt: today,
        updatedAt: today,
      ),
      Person(
        id: 'b',
        name: 'Khalid',
        colorIndex: 1,
        createdAt: today,
        updatedAt: today,
      ),
    ],
  );

  Widget host(AppLanguage language, Locale locale) {
    final AppLocalizations l10n = lookupAppLocalizations(locale);
    return MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.light(),
      home: AppFormattingScope(
        formatting: AppFormatting(
          language: language,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: l10n,
        ),
        child: Scaffold(
          body: DebtRowTile(view: view, onTap: () {}, asOf: today),
        ),
      ),
    );
  }

  testWidgets('Arabic joins two Latin names with the Arabic comma', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(AppLanguage.arabic, const Locale('ar')));
    expect(find.text('Ahmed، Khalid'), findsOneWidget);
  });

  testWidgets('English joins the same two names with its comma', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(AppLanguage.english, const Locale('en')));
    expect(find.text('Ahmed, Khalid'), findsOneWidget);
  });
}
