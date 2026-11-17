import 'package:share_plus/share_plus.dart';

import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../formatting/app_formatting.dart';
import '../money/money.dart';
import '../pdf/statement_models.dart';
import 'share_origin.dart';

/// Builds and sends the shareable text for a record or a payment.
///
/// Kept apart from the screens so what gets shared is reviewable in one place,
/// and so a shared summary always reads the same way regardless of which screen
/// offered the button.
class ShareService {
  const ShareService({required this.localizations, required this.formatting});

  final AppLocalizations localizations;
  final AppFormatting formatting;

  /// The plain-text summary of a debt.
  ///
  /// Amounts are printed with the currency code, because the person receiving
  /// this cannot rely on the colour or the context that the app provides.
  String debtSummary(DebtView view) {
    final StringBuffer buffer = StringBuffer();
    final String name = view.displayName;
    if (name.isNotEmpty) buffer.writeln(name);
    buffer.writeln(
      view.debt.direction.isIOwe
          ? localizations.shareLineDirectionIOwe
          : localizations.shareLineDirectionOwedToMe,
    );
    // A record linked to several people is not announced as such: the summary
    // states what the record costs, and its own name line already carries who it
    // is with. The amount is the record's, printed once.
    buffer.writeln();
    buffer.writeln(
      localizations.shareLineTotal(
        formatting.amount(view.principal, showCode: true),
      ),
    );
    buffer.writeln(
      localizations.shareLinePaid(
        formatting.amount(view.paid, showCode: true),
      ),
    );
    buffer.writeln(
      localizations.shareLineRemaining(
        formatting.amount(view.remaining, showCode: true),
      ),
    );
    final DateTime? due = view.debt.dueAt;
    if (due != null) {
      buffer.writeln(localizations.shareLineDue(formatting.date(due)));
    }
    buffer.writeln();
    buffer.write(localizations.shareFooter);
    return buffer.toString();
  }

  /// A single payment, phrased for the person on the other side of it.
  String paymentSummary({
    required DebtView view,
    required Payment payment,
  }) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(localizations.sharePaymentTitle);
    buffer.writeln(
      localizations.sharePaymentBody(
        view.displayName,
        formatting.amount(
          Money(payment.amountMinor, payment.currency),
          showCode: true,
        ),
        formatting.date(payment.paidAt),
      ),
    );
    if (payment.note != null && payment.note!.trim().isNotEmpty) {
      buffer.writeln(payment.note!.trim());
    }
    buffer.writeln();
    buffer.writeln(
      localizations.shareLineRemaining(
        formatting.amount(view.remaining, showCode: true),
      ),
    );
    buffer.writeln();
    buffer.write(localizations.shareFooter);
    return buffer.toString();
  }

  /// The lines that travel with a shared statement.
  ///
  /// A chat app shows the message before anyone opens the file; the reader
  /// sees who it is for, what is left and when the next amount falls due
  /// without opening a PDF.
  String statementCaption(StatementData data) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(localizations.shareStatementFor(data.personName));
    final DateTime? from = data.periodFrom;
    final DateTime? to = data.periodTo;
    if (from != null && to != null) {
      // A period is read at its own end. The caption says so, and says which
      // days it is about; a due date is a today fact and is left out.
      final String period = localizations.reportPeriodRange(
        formatting.date(from),
        formatting.date(to),
      );
      buffer.writeln(
        localizations.shareLinePeriodBalance(
          period,
          formatting.amount(
            Money(data.closingBalanceMinor ?? 0, data.currency),
            showCode: true,
          ),
        ),
      );
      return buffer.toString().trimRight();
    }
    buffer.writeln(
      localizations.shareLineRemaining(
        formatting.amount(data.remaining, showCode: true),
      ),
    );
    final DateTime? due = data.dueAt;
    if (due != null && data.remainingMinor > 0) {
      buffer.writeln(localizations.shareLineDue(formatting.date(due)));
    }
    return buffer.toString().trimRight();
  }

  /// Opens the system share sheet.
  Future<ShareResult> shareText(String text, {String? subject}) {
    return SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject ?? localizations.shareSubject,
        // An iPad does not open a share sheet that has nowhere to point.
        sharePositionOrigin: shareOriginFallback(),
      ),
    );
  }
}
