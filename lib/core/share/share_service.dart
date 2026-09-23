import 'package:share_plus/share_plus.dart';

import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../formatting/app_formatting.dart';
import '../money/money.dart';

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

  /// Opens the system share sheet.
  Future<ShareResult> shareText(String text, {String? subject}) {
    return SharePlus.instance.share(
      ShareParams(text: text, subject: subject ?? localizations.shareSubject),
    );
  }
}
