import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/app_formatting.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money_input.dart';
import '../../../core/widgets/bottom_sheet_shell.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/form_fields.dart';
import '../../../core/widgets/money_text.dart';
import '../../../data/services/ledger_service.dart';
import '../../../domain/entities/drafts.dart';
import '../../../domain/entities/ledger_views.dart';
import '../../../domain/entities/payment.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Records a payment against a debt.
///
/// The sheet keeps the consequence visible at all times: what will be left after
/// this amount, and whether it settles the debt. Confirming a payment without
/// knowing that is how a user ends up surprised by a balance.
///
/// With [existing], the same sheet corrects that payment instead of adding a
/// new one.
Future<bool> showPaymentSheet(
  BuildContext context, {
  required DebtView view,
  Payment? existing,
}) async {
  final bool? recorded = await showAppSheet<bool>(
    context,
    child: PaymentSheet(view: view, existing: existing),
  );
  return recorded ?? false;
}

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({required this.view, this.existing, super.key});

  final DebtView view;

  /// When set, the sheet edits an existing payment instead of adding one.
  final Payment? existing;

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  late final TextEditingController _noteController =
      TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _paidAt = widget.existing?.paidAt ?? dateOnly(DateTime.now());
  late int _amountMinor = widget.existing?.amountMinor ?? widget.view.remainingMinor;

  /// The amount's text, owned here so "pay in full" can write into it.
  ///
  /// The field used to own it, and the button only changed the number the sheet
  /// would save: the field went on showing what had been typed, so a user who
  /// typed 2,500 and pressed the button saw 2,500 and saved the full balance.
  late final TextEditingController _amountController = TextEditingController(
    text: formatMinorForInput(_amountMinor, widget.view.currency),
  );
  bool _busy = false;

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Puts [minor] in the field and in the amount the sheet will save, together.
  void _setAmount(int minor) {
    final String text = formatMinorForInput(minor, widget.view.currency);
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() => _amountMinor = minor);
  }

  /// What is left to pay before this payment counts.
  ///
  /// When correcting a payment, the amount it already covers is still open from
  /// the correction's point of view: the new amount replaces it rather than
  /// adding to it. Reading the debt's plain remaining balance here called a
  /// correction of a settled debt an overpayment, and "pay in full" offered 0.
  int get _remainingBefore {
    final int paidWithoutThis = widget.view.paidMinor -
        (widget.existing?.amountMinor ?? 0);
    final int remaining = widget.view.debt.principalMinor - paidWithoutThis;
    return remaining < 0 ? 0 : remaining;
  }

  int get _remainingAfter {
    final int remaining = _remainingBefore - _amountMinor;
    return remaining < 0 ? 0 : remaining;
  }

  bool get _settles => _remainingAfter <= 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppCurrency currency = widget.view.currency;
    final bool isEditing = widget.existing != null;
    final int remainingBefore = _remainingBefore;

    return AppSheet(
      title: isEditing ? localizations.paymentEditTitle : localizations.paymentTitle,
      subtitle: widget.view.displayName,
      busy: _busy,
      primaryLabel: localizations.paymentSave,
      onPrimary: _busy ? null : _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AmountField(
            label: localizations.paymentAmount,
            currency: currency,
            controller: _amountController,
            autofocus: !isEditing,
            onChanged: (int minor) => setState(() => _amountMinor = minor),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _setAmount(remainingBefore),
              icon: const Icon(Icons.done_all, size: 16),
              label: Text(localizations.paymentPayFull),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DateField(
            label: localizations.paymentDate,
            value: _paidAt,
            onChanged: (DateTime? value) {
              if (value != null) setState(() => _paidAt = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: '${localizations.paymentNote} · ${localizations.fieldOptional}',
            controller: _noteController,
            hint: localizations.fieldNoteHint,
            maxLines: 2,
            maxLength: 200,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ConsequenceCard(
            settles: _settles,
            remainingAfter: Money(_remainingAfter, currency),
            remainingBefore: Money(remainingBefore, currency),
            overpaid: _amountMinor > remainingBefore,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 13,
                color: palette.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  localizations.settingsPrivacyNote,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!isAmountWithinRange(_amountMinor)) {
      AppFeedback.error(context, localizations.validationInvalidAmount);
      return;
    }
    setState(() => _busy = true);

    final LedgerService service = ref.read(ledgerServiceProvider);
    final PaymentDraft draft = PaymentDraft(
      amountMinor: _amountMinor,
      paidAt: _paidAt,
      note: _noteController.text,
    );

    try {
      final Payment? existing = widget.existing;
      if (existing == null) {
        await service.recordPayment(widget.view.debt.id, draft);
      } else {
        await service.updatePayment(existing.id, draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppFeedback.info(
        context,
        _settles
            ? localizations.debtSettled
            // A correction is saved, not recorded: "payment recorded" after an
            // edit reads as though a second payment had been added.
            : existing == null
                ? localizations.paymentSaved
                : localizations.recordSaved,
        icon: _settles ? Icons.check_circle_outline : Icons.payments_outlined,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}

/// The card that explains what this payment does to the balance.
class _ConsequenceCard extends StatelessWidget {
  const _ConsequenceCard({
    required this.settles,
    required this.remainingAfter,
    required this.remainingBefore,
    required this.overpaid,
  });

  final bool settles;
  final Money remainingAfter;
  final Money remainingBefore;
  final bool overpaid;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final Color accent = settles ? palette.settled : palette.neutralStatus;
    final Color container =
        settles ? palette.settledContainer : palette.neutralStatusContainer;

    final String message = overpaid
        ? localizations.paymentExceedsRemaining(
            context.formatting.amount(remainingBefore),
          )
        : settles
            ? localizations.paymentWillSettle
            : localizations.paymentRemainingAfter(
                context.formatting.amount(remainingAfter),
              );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: container,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            settles ? Icons.verified_outlined : Icons.info_outline,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact row summarising a recorded payment, with edit and delete actions.
class PaymentRow extends ConsumerWidget {
  const PaymentRow({
    required this.payment,
    required this.view,
    super.key,
  });

  final Payment payment;
  final DebtView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: () => _showActions(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.settledContainer,
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(
                Icons.payments_outlined,
                size: 17,
                color: palette.settled,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    localizations.paymentTitle,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    payment.note?.trim().isNotEmpty == true
                        ? '${context.formatting.date(payment.paidAt)} · ${payment.note}'
                        : context.formatting.date(payment.paidAt),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            MoneyText(
              Money(payment.amountMinor, payment.currency),
              style: theme.textTheme.titleSmall,
              color: palette.settled,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    await showAppSheet<void>(
      context,
      isScrollControlled: false,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(localizations.actionEdit),
              onTap: () async {
                Navigator.of(context).pop();
                // The payment itself, so the sheet corrects it. Without it the
                // sheet opened as "record a payment" and saving added a second
                // payment beside the one being corrected.
                await showPaymentSheet(context, view: view, existing: payment);
              },
            ),
            ListTile(
              leading: Icon(Icons.undo, color: palette.overdue),
              textColor: palette.overdue,
              title: Text(localizations.paymentDeleteTitle),
              onTap: () async {
                Navigator.of(context).pop();
                await _delete(context, ref);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed = await AppFeedback.confirmDestructive(
      context,
      title: localizations.paymentDeleteTitle,
      body: localizations.paymentDeleteBody,
      confirmLabel: localizations.actionDelete,
    );
    if (!confirmed || !context.mounted) return;

    final LedgerService service = ref.read(ledgerServiceProvider);
    final Payment removed = payment;
    await service.deletePayment(payment.id);
    if (!context.mounted) return;

    AppFeedback.undoable(
      context,
      message: localizations.paymentDeleted,
      onUndo: () => service.restorePaymentRecord(removed),
    );
  }
}
