import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money_input.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/money_text.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/services/payment_allocator.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the sheet that records one payment against everything a person owes on
/// one side of the ledger.
Future<bool> showPersonPaymentSheet(
  BuildContext context, {
  required String personId,
  required PersonLedger ledger,
}) async {
  final bool? recorded = await showAppSheet<bool>(
    context,
    // The shell's add button is a sibling of the tab's navigator, so anything the
    // tab pushes paints under it — including this sheet's own save button.
    useRootNavigator: true,
    child: PersonPaymentSheet(personId: personId, ledger: ledger),
  );
  return recorded ?? false;
}

/// Records a payment that is split across a person's open debts.
///
/// The whole screen is built around one promise: *what you see is what gets
/// written*. The preview is drawn by [PaymentAllocator] — the same function the
/// service calls inside its transaction — over the same live list of debts, so
/// the split the user approves cannot differ from the split that is saved.
///
/// Nothing is prefilled. A blank amount costs one tap; a prefilled total on a
/// person with five debts is "settle everything" waiting to be confirmed by
/// accident.
class PersonPaymentSheet extends ConsumerStatefulWidget {
  const PersonPaymentSheet({
    required this.personId,
    required this.ledger,
    super.key,
  });

  final String personId;

  /// The snapshot the caller already had, used for the first frame. Live values
  /// take over as soon as the stream delivers them.
  final PersonLedger ledger;

  @override
  ConsumerState<PersonPaymentSheet> createState() => _PersonPaymentSheetState();
}

class _PersonPaymentSheetState extends ConsumerState<PersonPaymentSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  /// Which side of the ledger, and which currency. Null means "not chosen yet",
  /// so the default is worked out from what the person actually owes rather than
  /// frozen in a field that a later change could make wrong.
  DebtDirection? _direction;
  AppCurrency? _currency;

  /// Debts the user unchecked. Their share flows to the ones after them.
  final Set<String> _excluded = <String>{};

  PaymentAllocationOrder _order = PaymentAllocationOrder.mostUrgent;
  int _amountMinor = 0;
  DateTime _paidAt = dateOnly(DateTime.now());
  bool _busy = false;
  String? _amountError;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Puts [minor] in the field and in the amount the sheet will save, together.
  ///
  /// They are written together because they were once allowed to drift: a quick
  /// button changed the number that would be saved while the field went on
  /// showing what had been typed, so a user who typed 2,500 pressed "pay all"
  /// and watched 2,500 stay on screen — then saved the full balance.
  void _setAmount(int minor, AppCurrency currency) {
    final String text = formatMinorForInput(minor, currency);
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {
      _amountMinor = minor;
      _amountError = null;
    });
  }

  void _toggleExcluded(String debtId) {
    setState(() {
      if (!_excluded.remove(debtId)) _excluded.add(debtId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    // The caller's snapshot first, then the live one: the sheet draws instantly
    // and follows the ledger from then on.
    final PersonLedger ledger =
        ref.watch(personLedgerProvider(widget.personId)).value ?? widget.ledger;

    final List<DebtView> payable = _payableDebts(ledger);
    final AppCurrency currency = _activeCurrencyOf(payable);
    final DebtDirection direction = _activeDirectionOf(payable, currency);

    final List<DebtView> candidates = _candidatesFor(payable, direction, currency);
    final List<DebtView> shared = _sharedFor(ledger, direction, currency);
    final int cap = PaymentAllocator.capacityMinor(
      candidates,
      excludedDebtIds: _excluded,
    );
    final List<DebtAllocation> plan = PaymentAllocator.plan(
      openDebts: candidates,
      amountMinor: _amountMinor,
      order: _order,
      excludedDebtIds: _excluded,
    );
    final Map<String, DebtView> viewById = <String, DebtView>{
      for (final DebtView view in candidates) view.debt.id: view,
    };
    final int settling = plan.where((DebtAllocation a) => a.willSettle).length;
    final int changing = plan
        .where((DebtAllocation a) => a.allocatedMinor > 0 && !a.willSettle)
        .length;

    final bool hasAmount = _amountMinor > 0 && _amountMinor <= cap;
    final bool canSave = hasAmount && !_busy && candidates.isNotEmpty;

    return AppSheet(
      title: localizations.detailRecordPayment,
      subtitle: ledger.person.name,
      busy: _busy,
      // Drawn as an explicit action rather than through `primaryLabel`, because
      // the bar is only built when a callback is given: with the label alone the
      // save button would vanish until an amount was typed, and a button that
      // appears out of nowhere teaches the user nothing about where it is. This
      // one is always there and disabled while there is nothing to save.
      primaryAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: canSave ? _save : null,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(localizations.paymentSave),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _DirectionField(
            value: direction,
            totals: _totalsByDirection(payable, currency),
            currency: currency,
            onChanged: (DebtDirection value) =>
                setState(() => _direction = value),
          ),
          if (_currenciesOf(payable).length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _CurrencyChips(
              currencies: _currenciesOf(payable),
              selected: currency,
              onChanged: (AppCurrency value) => setState(() => _currency = value),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _AmountBlock(
            controller: _amountController,
            currency: currency,
            capMinor: cap,
            errorText: _amountError,
            onChanged: (int minor) => setState(() {
              _amountMinor = minor;
              _amountError = null;
            }),
            onRejected: () => setState(() {
              _amountMinor = 0;
              _amountError = localizations.personPaymentOverCap(
                context.formatting.amount(Money(cap, currency)),
              );
            }),
            onQuickPick: (int minor) => _setAmount(minor, currency),
          ),
          const SizedBox(height: AppSpacing.lg),
          _AllocationSection(
            order: _order,
            onOrderChanged: (PaymentAllocationOrder value) =>
                setState(() => _order = value),
            plan: plan,
            viewById: viewById,
            currency: currency,
            excluded: _excluded,
            onToggle: _toggleExcluded,
            personId: widget.personId,
          ),
          if (shared.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _SharedNotice(
              count: shared.length,
              onConvert: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.debtPath(shared.first.debt.id));
              },
            ),
          ],
          if (candidates.isEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.personPaymentEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (settling > 0 || changing > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _ImpactCard(
              settling: settling,
              changing: changing,
              settlesAll:
                  _amountMinor >= cap && cap > 0,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
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
          Row(
            children: <Widget>[
              Icon(
                Icons.lock_outline,
                size: 13,
                color: context.palette.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  localizations.settingsPrivacyNote,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Selection ------------------------------------------------------------

  /// Every debt the person owes on, in any direction or currency, that money can
  /// still be applied to.
  ///
  /// Archived and settled records are out, and so are legacy shared records: a
  /// payment on one of those settles everybody at once, which is why
  /// `recordPayment` refuses them outright. They are shown as a notice rather
  /// than silently dropped, so the user knows why their balance is not all here.
  static List<DebtView> _payableDebts(PersonLedger ledger) => <DebtView>[
        for (final DebtView view in ledger.debts)
          if (view.isOpen && !view.debt.isShared) view,
      ];

  static List<DebtView> _candidatesFor(
    List<DebtView> payable,
    DebtDirection direction,
    AppCurrency currency,
  ) =>
      <DebtView>[
        for (final DebtView view in payable)
          if (view.debt.direction == direction && view.currency == currency)
            view,
      ];

  static List<DebtView> _sharedFor(
    PersonLedger ledger,
    DebtDirection direction,
    AppCurrency currency,
  ) =>
      <DebtView>[
        for (final DebtView view in ledger.debts)
          if (view.debt.isShared &&
              view.isOpen &&
              view.debt.direction == direction &&
              view.currency == currency)
            view,
      ];

  static List<AppCurrency> _currenciesOf(List<DebtView> payable) {
    final Set<AppCurrency> used = <AppCurrency>{
      for (final DebtView view in payable) view.currency,
    };
    final List<AppCurrency> sorted = used.toList()
      ..sort((AppCurrency a, AppCurrency b) => a.code.compareTo(b.code));
    return sorted;
  }

  /// Outstanding money per direction, for the chosen currency.
  ///
  /// Added up here rather than read from `CurrencyTotals`, which folds both
  /// directions into one net. The sheet asks the opposite question — how much is
  /// on each side on its own — and a net would hide the reason a side is offered.
  Map<DebtDirection, int> _totalsByDirection(
    List<DebtView> payable,
    AppCurrency currency,
  ) {
    final Map<DebtDirection, int> out = <DebtDirection, int>{
      DebtDirection.iOwe: 0,
      DebtDirection.owedToMe: 0,
    };
    for (final DebtView view in payable) {
      if (view.currency != currency) continue;
      out[view.debt.direction] =
          (out[view.debt.direction] ?? 0) + view.remainingMinor;
    }
    return out;
  }

  /// The currency the sheet leads with: the user's own default when the person
  /// owes in it, otherwise the one that carries the most.
  AppCurrency _activeCurrencyOf(List<DebtView> payable) {
    final List<AppCurrency> available = _currenciesOf(payable);
    if (available.isEmpty) {
      return ref.read(effectiveSettingsProvider).defaultCurrency;
    }
    final AppCurrency chosen = _currency ?? AppCurrency.inr;
    if (_currency != null && available.contains(chosen)) return chosen;

    final AppCurrency preferred =
        ref.read(effectiveSettingsProvider).defaultCurrency;
    if (available.contains(preferred)) return preferred;

    AppCurrency best = available.first;
    int bestTotal = -1;
    for (final AppCurrency currency in available) {
      int total = 0;
      for (final DebtView view in payable) {
        if (view.currency == currency) total += view.remainingMinor;
      }
      if (total > bestTotal) {
        bestTotal = total;
        best = currency;
      }
    }
    return best;
  }

  /// The side the sheet leads with: the larger of the two, so the common case —
  /// one direction has everything — needs no tap at all.
  DebtDirection _activeDirectionOf(
    List<DebtView> payable,
    AppCurrency currency,
  ) {
    final Map<DebtDirection, int> totals = _totalsByDirection(payable, currency);
    final bool owes = (totals[DebtDirection.iOwe] ?? 0) > 0;
    final bool owed = (totals[DebtDirection.owedToMe] ?? 0) > 0;

    final DebtDirection? chosen = _direction;
    if (chosen != null) {
      // A currency switch can leave the chosen side empty. Falling back keeps
      // the sheet usable instead of showing an empty plan with no way out.
      if (chosen == DebtDirection.iOwe && owes) return chosen;
      if (chosen == DebtDirection.owedToMe && owed) return chosen;
    }
    if (!owes) return DebtDirection.owedToMe;
    if (!owed) return DebtDirection.iOwe;
    return (totals[DebtDirection.iOwe] ?? 0) >=
            (totals[DebtDirection.owedToMe] ?? 0)
        ? DebtDirection.iOwe
        : DebtDirection.owedToMe;
  }

  // --- Writing --------------------------------------------------------------

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    // Checked here and not only in `canSave`. The button is disabled while
    // `_busy`, but it learns that from a rebuild, and a second tap dispatched
    // before the next frame reaches the *old* widget and runs this again —
    // writing the same money into the ledger twice. The flag is the guard; the
    // disabled button is only how the user is told about it.
    if (_busy) return;
    if (!isAmountWithinRange(_amountMinor)) {
      AppFeedback.error(context, localizations.validationInvalidAmount);
      return;
    }
    setState(() => _busy = true);

    final LedgerService service = ref.read(ledgerServiceProvider);
    final PersonLedger ledger =
        ref.read(personLedgerProvider(widget.personId)).value ?? widget.ledger;
    final List<DebtView> payable = _payableDebts(ledger);
    final AppCurrency currency = _activeCurrencyOf(payable);
    final DebtDirection direction =
        _activeDirectionOf(payable, currency);
    final int cap = PaymentAllocator.capacityMinor(
      _candidatesFor(payable, direction, currency),
      excludedDebtIds: _excluded,
    );

    // The ceiling is enforced here as well as in the field: the balances can
    // move under an open sheet, and the write must not be the place where a
    // stale ceiling is discovered.
    if (_amountMinor > cap) {
      setState(() {
        _busy = false;
        _amountError = localizations.personPaymentOverCap(
          context.formatting.amount(Money(cap, currency)),
        );
      });
      return;
    }

    final PersonPaymentDraft draft = PersonPaymentDraft(
      personId: widget.personId,
      direction: direction,
      currency: currency,
      amountMinor: _amountMinor,
      paidAt: _paidAt,
      note: _noteController.text,
      order: _order,
      excludedDebtIds: Set<String>.of(_excluded),
    );

    try {
      final List<Payment> written = await service.recordPersonPayment(draft);
      if (!mounted) return;
      final int settled = _settledCount(written, payable);
      Navigator.of(context).pop(true);
      AppFeedback.undoable(
        context,
        message: <String>[
          localizations.personPaymentRecordedToast(written.length),
          if (settled > 0) localizations.personPaymentSettledToast(settled),
        ].join(' · '),
        onUndo: () => service.deletePaymentsBatch(
          written.map((Payment payment) => payment.id).toList(),
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }

  /// How many of the debts the payment touched it also cleared.
  ///
  /// Counted from the written payments against the balances read before them,
  /// rather than from the preview: the preview was drawn a moment earlier, and
  /// the toast has to describe what actually happened.
  static int _settledCount(List<Payment> written, List<DebtView> payable) {
    final Map<String, int> paidByDebt = <String, int>{};
    for (final Payment payment in written) {
      final String? debtId = payment.debtId;
      if (debtId == null) continue;
      paidByDebt[debtId] = (paidByDebt[debtId] ?? 0) + payment.amountMinor;
    }
    int settled = 0;
    for (final DebtView view in payable) {
      final int paid = paidByDebt[view.debt.id] ?? 0;
      if (paid > 0 && paid >= view.remainingMinor) settled++;
    }
    return settled;
  }
}

/// Which side of the ledger the money moves against.
///
/// Shown whenever the person owes anything, with the empty side disabled rather
/// than hidden: seeing "لي 0" explains why that side cannot be chosen, where a
/// missing button would just look broken.
class _DirectionField extends StatelessWidget {
  const _DirectionField({
    required this.value,
    required this.totals,
    required this.currency,
    required this.onChanged,
  });

  final DebtDirection value;
  final Map<DebtDirection, int> totals;
  final AppCurrency currency;
  final ValueChanged<DebtDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;
    final bool owes = (totals[DebtDirection.iOwe] ?? 0) > 0;
    final bool owed = (totals[DebtDirection.owedToMe] ?? 0) > 0;

    String labelOf(DebtDirection direction) {
      final int total = totals[direction] ?? 0;
      return '${direction.label(localizations)} · '
          '${formatting.amount(Money(total, currency))}';
    }

    // One side only: no choice to offer, so it is stated instead of asked.
    if (!owes || !owed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FieldLabel(localizations.personPaymentSide),
          Text(
            labelOf(value),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      );
    }

    return SegmentedField<DebtDirection>(
      label: localizations.personPaymentSide,
      value: value,
      options: const <DebtDirection>[
        DebtDirection.iOwe,
        DebtDirection.owedToMe,
      ],
      labelOf: labelOf,
      onChanged: onChanged,
    );
  }
}

/// One currency chip per currency the person owes in. Drawn only when there is
/// more than one — two currencies are two sets of debts and are never added
/// together, so the sheet has to say which one it is speaking about.
class _CurrencyChips extends StatelessWidget {
  const _CurrencyChips({
    required this.currencies,
    required this.selected,
    required this.onChanged,
  });

  final List<AppCurrency> currencies;
  final AppCurrency selected;
  final ValueChanged<AppCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final AppCurrency currency in currencies)
          ChoiceChip(
            label: Text(currency.codeAndSymbol),
            selected: currency == selected,
            onSelected: (_) => onChanged(currency),
          ),
      ],
    );
  }
}

/// The amount, its ceiling, and the three shortcuts that skip the keyboard.
class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.controller,
    required this.currency,
    required this.capMinor,
    required this.errorText,
    required this.onChanged,
    required this.onRejected,
    required this.onQuickPick,
  });

  final TextEditingController controller;
  final AppCurrency currency;
  final int capMinor;
  final String? errorText;
  final ValueChanged<int> onChanged;
  final VoidCallback onRejected;
  final ValueChanged<int> onQuickPick;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;

    // Deliberately not autofocused. The amount is not the first control on this
    // sheet — the side and the currency come before it and decide what it means
    // — and asking for the keyboard would scroll those choices off the top
    // before the user had read them.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AmountField(
          label: localizations.paymentAmount,
          currency: currency,
          controller: controller,
          onChanged: onChanged,
          onRejected: onRejected,
          errorText: errorText,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ActionChip(
              label: Text(localizations.personPaymentQuickQuarter),
              onPressed: () => onQuickPick(capMinor ~/ 4),
            ),
            ActionChip(
              label: Text(localizations.personPaymentQuickHalf),
              onPressed: () => onQuickPick(capMinor ~/ 2),
            ),
            ActionChip(
              avatar: const Icon(Icons.done_all, size: 16),
              label: Text(localizations.personPaymentPayAll),
              onPressed: () => onQuickPick(capMinor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          localizations.personPaymentOutstanding(
            formatting.amount(Money(capMinor, currency)),
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// The live split: every debt in plan order, what each one takes, and where that
/// leaves it.
class _AllocationSection extends StatelessWidget {
  const _AllocationSection({
    required this.order,
    required this.onOrderChanged,
    required this.plan,
    required this.viewById,
    required this.currency,
    required this.excluded,
    required this.onToggle,
    required this.personId,
  });

  final PaymentAllocationOrder order;
  final ValueChanged<PaymentAllocationOrder> onOrderChanged;
  final List<DebtAllocation> plan;
  final Map<String, DebtView> viewById;
  final AppCurrency currency;
  final Set<String> excluded;
  final ValueChanged<String> onToggle;
  final String personId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FieldLabel(localizations.personPaymentAllocation),
            ),
            // One tap swaps the rule and the plan is redrawn: the order is the
            // whole decision, so the control for it sits on the heading rather
            // than behind a menu. Flexible, and its label may take two lines:
            // at the largest text size on a narrow phone the heading and this
            // button together were 59 pixels wider than the sheet.
            Flexible(
              child: TextButton.icon(
                onPressed: () => onOrderChanged(
                  order == PaymentAllocationOrder.mostUrgent
                      ? PaymentAllocationOrder.oldestFirst
                      : PaymentAllocationOrder.mostUrgent,
                ),
                icon: const Icon(Icons.swap_vert, size: 16),
                label: Text(
                  order.label(localizations),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          borderColor: palette.border,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < plan.length; i++) ...<Widget>[
                if (i > 0) const AppDivider(),
                _AllocationRow(
                  allocation: plan[i],
                  view: viewById[plan[i].debtId],
                  currency: currency,
                  isExcluded: excluded.contains(plan[i].debtId),
                  onToggle: () => onToggle(plan[i].debtId),
                  personId: personId,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One debt in the preview, with its checkbox.
///
/// Rows stay in place when one is unchecked — the money simply moves to the ones
/// below — because a list that reorders itself under the user's finger is how a
/// split gets approved by accident.
class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.allocation,
    required this.view,
    required this.currency,
    required this.isExcluded,
    required this.onToggle,
    required this.personId,
  });

  final DebtAllocation allocation;
  final DebtView? view;
  final AppCurrency currency;
  final bool isExcluded;
  final VoidCallback onToggle;
  final String personId;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final DebtView? debt = view;
    if (debt == null) return const SizedBox.shrink();

    final bool settles = allocation.willSettle;
    final bool touched = allocation.allocatedMinor > 0;
    final Color titleColor = isExcluded || !touched
        ? palette.textTertiary
        : palette.textPrimary;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: !isExcluded,
                onChanged: (_) => onToggle(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    debt.displayNameFor(personId),
                    style: theme.textTheme.bodyMedium?.copyWith(color: titleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusLine(context, localizations, debt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Flexible, because this cell is the widest thing in the row and it
            // grows with the amount: at the largest amount Dhimmah accepts the
            // "takes X of Y, leaving Z" line was 120 pixels wider than the
            // sheet, and the row was laid out past its own edge. Loose, so an
            // ordinary figure still takes exactly the width it needs.
            Flexible(
              child: _AmountCell(
                allocation: allocation,
                currency: currency,
                settles: settles,
                touched: touched,
                isExcluded: isExcluded,
                localizations: localizations,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// What the row says under the title: how late it is, when it falls due, or
  /// that it never does.
  static String _statusLine(
    BuildContext context,
    AppLocalizations l,
    DebtView debt,
  ) {
    if (debt.status == DebtLifecycleStatus.overdue) return l.statusOverdue;
    final DateTime? due = debt.debt.dueAt;
    if (due == null) return l.fieldDueDateNone;
    return context.formatting.date(due);
  }
}

/// The right-hand side of a preview row: what it takes, and where that leaves it.
class _AmountCell extends StatelessWidget {
  const _AmountCell({
    required this.allocation,
    required this.currency,
    required this.settles,
    required this.touched,
    required this.isExcluded,
    required this.localizations,
  });

  final DebtAllocation allocation;
  final AppCurrency currency;
  final bool settles;
  final bool touched;
  final bool isExcluded;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppFormatting formatting = context.formatting;

    if (isExcluded) {
      return Text(
        localizations.personPaymentExcluded,
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.textTertiary,
        ),
      );
    }
    if (!touched) {
      return Text(
        localizations.personPaymentNoShare,
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.textTertiary,
        ),
      );
    }
    if (settles) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 16, color: palette.settled),
          const SizedBox(width: AppSpacing.xs),
          // The mark already says it; the words may take two lines rather than
          // push the row past its edge, which is what they did at the largest
          // text size.
          Flexible(
            child: Text(
              localizations.personPaymentWillSettle,
              style: theme.textTheme.labelLarge?.copyWith(color: palette.settled),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MoneyText(
          Money(allocation.allocatedMinor, currency),
          style: theme.textTheme.titleSmall,
          color: palette.owedToMe,
          shrinkToFit: true,
        ),
        const SizedBox(height: 2),
        Text(
          localizations.personPaymentRowTakes(
            formatting.amount(Money(allocation.allocatedMinor, currency)),
            formatting.amount(Money(allocation.remainingBeforeMinor, currency)),
            formatting.amount(Money(allocation.remainingAfterMinor, currency)),
          ),
          style: theme.textTheme.labelSmall?.copyWith(
            color: palette.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// A legacy shared record is not part of the split, and the reason is not
/// obvious from the balance — so it is said, with the way to fix it.
class _SharedNotice extends StatelessWidget {
  const _SharedNotice({required this.count, required this.onConvert});

  final int count;
  final VoidCallback onConvert;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.dueSoonContainer,
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline, size: 18, color: palette.dueSoon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  localizations.personPaymentSharedNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.dueSoon,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onConvert,
              child: Text(localizations.legacySharedSplit),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the payment adds up to, in one sentence.
class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.settling,
    required this.changing,
    required this.settlesAll,
  });

  final int settling;
  final int changing;
  final bool settlesAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final Color accent = settlesAll ? palette.settled : palette.neutralStatus;
    final Color container = settlesAll
        ? palette.settledContainer
        : palette.neutralStatusContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: container, borderRadius: AppRadius.rMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            settlesAll ? Icons.verified_outlined : Icons.info_outline,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  localizations.personPaymentSettlingCount(settling),
                  style: theme.textTheme.bodySmall?.copyWith(color: accent),
                ),
                if (changing > 0)
                  Text(
                    localizations.personPaymentLeftoverCount(changing),
                    style: theme.textTheme.bodySmall?.copyWith(color: accent),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
