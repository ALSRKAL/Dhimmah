import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/formatting/app_formatting.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';

/// The formats a user can export to.
enum ExportFormat { json, csv }

/// Writes the user's records to a file they can keep.
///
/// This is deliberately the *whole* database, not a report: the point of an
/// export is that a user can get their data out and keep it, and a file that
/// cannot be read back is not a backup. The JSON is the canonical form; the CSV
/// files are for opening in a spreadsheet.
class DataExportService {
  const DataExportService({
    required this.people,
    required this.debts,
    required this.payments,
    required this.obligations,
    required this.reminders,
    required this.activity,
    required this.localizations,
    required this.formatting,
  });

  final PersonRepository people;
  final DebtRepository debts;
  final PaymentRepository payments;
  final ObligationRepository obligations;
  final ReminderRepository reminders;
  final ActivityRepository activity;
  final AppLocalizations localizations;
  final AppFormatting formatting;

  /// Writes the export and returns the file path.
  Future<String> export(ExportFormat format) async {
    final Directory dir = await getTemporaryDirectory();
    final String stamp = toIsoDate(DateTime.now());
    switch (format) {
      case ExportFormat.json:
        final Map<String, Object?> payload = await _payload();
        final File file = File(p.join(dir.path, 'dhimmah-$stamp.json'));
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(payload),
          flush: true,
        );
        return file.path;
      case ExportFormat.csv:
        final String csv = await _csv();
        final File file = File(p.join(dir.path, 'dhimmah-$stamp.csv'));
        // A UTF-8 BOM so Excel opens Arabic text correctly instead of mojibake.
        await file.writeAsString('\uFEFF$csv', flush: true);
        return file.path;
    }
  }

  Future<void> share(String path) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path)],
        subject: localizations.settingsExport,
      ),
    );
  }

  Future<Map<String, Object?>> _payload() async {
    final List<Person> peopleList = await people.getAll();
    final List<Debt> debtList = await debts.getAll();
    final List<Payment> paymentList = await payments.getAll();
    final List<Obligation> obligationList = await obligations.getAll();
    final List<ObligationOccurrence> occurrenceList =
        await obligations.allOccurrences();
    final List<Reminder> reminderList = await reminders.getAll();
    final List<ActivityEntry> activityList = await activity.recent(limit: 5000);

    return <String, Object?>{
      'application': 'dhimmah',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'people': peopleList.map(_person).toList(),
      'debts': debtList.map(_debt).toList(),
      'payments': paymentList.map(_payment).toList(),
      'obligations': obligationList.map(_obligation).toList(),
      'obligationOccurrences': occurrenceList.map(_occurrence).toList(),
      'reminders': reminderList.map(_reminder).toList(),
      'activity': activityList.map(_activity).toList(),
    };
  }

  // Amounts are exported in minor units alongside their currency so anything
  // reading the file can reconstruct them exactly, without floating point.
  Map<String, Object?> _person(Person person) => <String, Object?>{
        'id': person.id,
        'name': person.name,
        'phone': person.phone,
        'note': person.note,
        'createdAt': person.createdAt.toIso8601String(),
        'archivedAt': person.archivedAt?.toIso8601String(),
      };

  // A record can be shared, so the export carries the whole participant list as
  // well as the one-value `personId`, which names the first of them. The record
  // itself appears once: exporting it per participant would multiply the money.
  Map<String, Object?> _debt(Debt debt) => <String, Object?>{
        'id': debt.id,
        'personId': debt.personId,
        'personIds': debt.personIds,
        'direction': debt.direction.name,
        'title': debt.title,
        'amountMinor': debt.principalMinor,
        'currency': debt.currency.code,
        'issuedAt': toIsoDate(debt.issuedAt),
        'dueAt': debt.dueAt == null ? null : toIsoDate(debt.dueAt!),
        'note': debt.note,
        'reminderLeads': debt.reminderLeads
            .map((lead) => lead.daysBefore)
            .toList(),
        'recurrence': debt.recurrence.name,
        'recurrenceInterval': debt.recurrenceInterval,
        'closedAt': debt.closedAt?.toIso8601String(),
        'archivedAt': debt.archivedAt?.toIso8601String(),
        'createdAt': debt.createdAt.toIso8601String(),
      };

  Map<String, Object?> _payment(Payment payment) => <String, Object?>{
        'id': payment.id,
        'debtId': payment.debtId,
        'obligationId': payment.obligationId,
        'occurrenceId': payment.occurrenceId,
        'amountMinor': payment.amountMinor,
        'currency': payment.currency.code,
        'paidAt': toIsoDate(payment.paidAt),
        'note': payment.note,
      };

  Map<String, Object?> _obligation(Obligation obligation) => <String, Object?>{
        'id': obligation.id,
        'name': obligation.name,
        'category': obligation.category.name,
        'amountMinor': obligation.amountMinor,
        'currency': obligation.currency.code,
        'frequency': obligation.frequency.name,
        'intervalCount': obligation.intervalCount,
        'dayOfMonth': obligation.dayOfMonth,
        'startAt': toIsoDate(obligation.startAt),
        'nextDueAt': toIsoDate(obligation.nextDueAt),
        'endAt': obligation.endAt == null ? null : toIsoDate(obligation.endAt!),
        'note': obligation.note,
        'archivedAt': obligation.archivedAt?.toIso8601String(),
      };

  Map<String, Object?> _occurrence(ObligationOccurrence occurrence) =>
      <String, Object?>{
        'id': occurrence.id,
        'obligationId': occurrence.obligationId,
        'periodKey': occurrence.periodKey,
        'dueAt': toIsoDate(occurrence.dueAt),
        'amountMinor': occurrence.amountMinor,
        'status': occurrence.status.name,
        'paidAt': occurrence.paidAt == null ? null : toIsoDate(occurrence.paidAt!),
      };

  Map<String, Object?> _reminder(Reminder reminder) => <String, Object?>{
        'id': reminder.id,
        'title': reminder.title,
        'note': reminder.note,
        'dueAt': toIsoDate(reminder.dueAt),
        'status': reminder.status.name,
      };

  Map<String, Object?> _activity(ActivityEntry entry) => <String, Object?>{
        'id': entry.id,
        'type': entry.type.name,
        'entityType': entry.entityType.name,
        'entityId': entry.entityId,
        'title': entry.title,
        'amountMinor': entry.amountMinor,
        'currency': entry.currency?.code,
        'occurredAt': entry.occurredAt.toIso8601String(),
      };

  /// A flat ledger: one row per money movement, which is what a spreadsheet is
  /// good at.
  Future<String> _csv() async {
    final List<Person> peopleList = await people.getAll();
    final Map<String, String> nameById = <String, String>{
      for (final Person person in peopleList) person.id: person.name,
    };
    final List<Debt> debtList = await debts.getAll();
    final Map<String, Debt> debtById = <String, Debt>{
      for (final Debt debt in debtList) debt.id: debt,
    };
    final List<Payment> paymentList = await payments.getAll();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      <String>[
        'date',
        'kind',
        'person',
        'description',
        'direction',
        'amount',
        'currency',
        'note',
      ].join(','),
    );

    for (final Debt debt in debtList) {
      buffer.writeln(
        <String>[
          toIsoDate(debt.issuedAt),
          'debt',
          _csvCell(_participantNames(debt, nameById)),
          _csvCell(debt.title),
          debt.direction.name,
          (debt.principalMinor / debt.currency.minorFactor).toStringAsFixed(2),
          debt.currency.code,
          _csvCell(debt.note ?? ''),
        ].join(','),
      );
    }

    for (final Payment payment in paymentList) {
      final Debt? debt = payment.debtId == null ? null : debtById[payment.debtId];
      buffer.writeln(
        <String>[
          toIsoDate(payment.paidAt),
          'payment',
          _csvCell(
            nameById[payment.personId] ??
                (debt == null ? '' : _participantNames(debt, nameById)),
          ),
          _csvCell(debt?.title ?? ''),
          debt?.direction.name ?? '',
          (payment.amountMinor / payment.currency.minorFactor)
              .toStringAsFixed(2),
          payment.currency.code,
          _csvCell(payment.note ?? ''),
        ].join(','),
      );
    }

    return buffer.toString();
  }

  /// `أحمد، علي`, or an empty cell for a record that names nobody.
  static String _participantNames(Debt debt, Map<String, String> nameById) =>
      <String>[
        for (final String id in debt.personIds)
          if (nameById[id] != null) nameById[id]!,
      ].join('، ');

  /// Quotes and escapes a CSV cell.
  ///
  /// A cell a spreadsheet would take for a formula — one that starts with `=`,
  /// `+`, `-` or `@` — is written with a leading `'`, so a name or a note typed
  /// as `=HYPERLINK(…)` opens as the text it is instead of running when the
  /// file is opened. Only free text passes through here; amounts, dates and
  /// codes are written as they are.
  static String _csvCell(String value) {
    String text = value.trim();
    if (text.isEmpty) return '';
    if (_formulaLeads.contains(text[0])) text = "'$text";
    final bool needsQuotes = text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    if (!needsQuotes) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  /// The characters a spreadsheet reads as the start of a formula.
  static const String _formulaLeads = '=+-@';

  /// A readable amount, used by the PDF report path.
  String formatMoney(Money money) =>
      formatting.amount(money, showCode: true);
}
