import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
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
import '../../domain/entities/income.dart';
import '../../domain/enums/recurrence.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the income list, where a source can be added, edited or set aside.
///
/// On the root navigator, because this sheet is opened from a shell destination
/// and carries its own action along the bottom edge — the shell's add button
/// would otherwise paint over the right-hand end of it.
Future<void> showIncomeManageSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    useRootNavigator: true,
    child: const IncomeManageSheet(),
  );
}

/// Every source of income, with the form behind a row or the add button.
///
/// One sheet rather than a screen with a route, because there is usually exactly
/// one salary and occasionally a second: a whole screen for a list that long
/// would be more navigation than content, and the budget card it belongs to
/// stays visible behind it.
class IncomeManageSheet extends ConsumerStatefulWidget {
  const IncomeManageSheet({super.key});

  @override
  ConsumerState<IncomeManageSheet> createState() => _IncomeManageSheetState();
}

class _IncomeManageSheetState extends ConsumerState<IncomeManageSheet> {
  /// The record being edited, or null while the list is showing.
  ///
  /// The form replaces the list inside the same sheet rather than opening a
  /// second one on top of it, so cancelling an edit returns to the list instead
  /// of closing everything.
  Income? _editing;

  /// Whether the form is open for a brand-new record.
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    if (_creating || _editing != null) {
      return _IncomeForm(
        income: _editing,
        onDone: () => setState(() {
          _editing = null;
          _creating = false;
        }),
      );
    }
    return _IncomeList(
      onEdit: (Income income) => setState(() => _editing = income),
      onCreate: () => setState(() => _creating = true),
    );
  }
}

class _IncomeList extends ConsumerWidget {
  const _IncomeList({required this.onEdit, required this.onCreate});

  final ValueChanged<Income> onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final List<Income> incomes =
        ref.watch(incomeListProvider).value ?? const <Income>[];

    final List<Income> active = <Income>[
      for (final Income income in incomes)
        if (!income.isArchived) income,
    ];
    final List<Income> archived = <Income>[
      for (final Income income in incomes)
        if (income.isArchived) income,
    ];

    return AppSheet(
      title: localizations.incomeManageTitle,
      primaryLabel: localizations.budgetAddIncome,
      onPrimary: onCreate,
      child: active.isEmpty && archived.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                localizations.incomeManageEmpty,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final Income income in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _IncomeTile(
                      income: income,
                      onEdit: () => onEdit(income),
                    ),
                  ),
                if (archived.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  SectionHeader(
                    title: localizations.filterArchived,
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.sm,
                    ),
                  ),
                  for (final Income income in archived)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _IncomeTile(
                        income: income,
                        onEdit: () => onEdit(income),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

/// One income in the list, with its amount and its schedule.
class _IncomeTile extends ConsumerStatefulWidget {
  const _IncomeTile({required this.income, required this.onEdit});

  final Income income;
  final VoidCallback onEdit;

  @override
  ConsumerState<_IncomeTile> createState() => _IncomeTileState();
}

class _IncomeTileState extends ConsumerState<_IncomeTile> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Income income = widget.income;
    final bool archived = income.isArchived;

    return AppCard(
      onTap: _busy ? null : widget.onEdit,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      income.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: archived ? palette.textTertiary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      archived
                          ? localizations.statusArchived
                          : income.frequency.label(
                              localizations,
                              interval: income.intervalCount,
                            ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              MoneyText(
                Money(income.amountMinor, income.currency),
                style: theme.textTheme.titleSmall,
                color: archived ? palette.textTertiary : palette.owedToMe,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => ref
                              .read(ledgerServiceProvider)
                              .setIncomeArchived(income.id, !archived),
                          archived
                              ? localizations.incomeRestoredToast
                              : localizations.incomeArchivedToast,
                        ),
                icon: Icon(
                  archived ? Icons.unarchive_outlined : Icons.inventory_2_outlined,
                  size: 16,
                ),
                label: Text(
                  archived ? localizations.actionUnarchive : localizations.actionArchive,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _confirmDelete,
                icon: Icon(Icons.delete_outline, size: 16, color: palette.overdue),
                label: Text(
                  localizations.actionDelete,
                  style: TextStyle(color: palette.overdue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(localizations.incomeDeleteTitle),
            content: Text(localizations.incomeDeleteBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizations.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: context.palette.overdue,
                ),
                child: Text(localizations.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _run(
      () => ref.read(ledgerServiceProvider).deleteIncome(widget.income.id),
      localizations.incomeDeletedToast,
    );
  }

  /// Runs a write and reports the outcome.
  ///
  /// Lives on the State so `mounted` and `context` refer to the same object
  /// across the await, which is what makes the guard after it meaningful.
  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.info(context, message);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, AppLocalizations.of(context).somethingWentWrong);
    }
  }
}

/// Adds or edits one source of income.
///
/// Deliberately much shorter than the obligation form: an income has no
/// category, no end date and no reminders, and the quick presets exist because
/// most people have exactly one salary and should not have to think about
/// recurrence at all.
class _IncomeForm extends ConsumerStatefulWidget {
  const _IncomeForm({required this.income, required this.onDone});

  final Income? income;
  final VoidCallback onDone;

  @override
  ConsumerState<_IncomeForm> createState() => _IncomeFormState();
}

class _IncomeFormState extends ConsumerState<_IncomeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();

  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  AppCurrency? _currency;
  int? _amountMinor;
  DateTime _startAt = dateOnly(DateTime.now());
  int _dayOfMonth = dateOnly(DateTime.now()).day;
  bool _usesDayOfMonth = true;
  bool _busy = false;
  String? _amountError;

  bool get _isEditing => widget.income != null;

  @override
  void initState() {
    super.initState();
    final Income? income = widget.income;
    if (income != null) {
      _name.text = income.name;
      _note.text = income.note ?? '';
      _frequency = income.frequency;
      _currency = income.currency;
      _amountMinor = income.amountMinor;
      _startAt = income.startAt;
      _dayOfMonth = income.dayOfMonth ?? income.startAt.day;
      _usesDayOfMonth = income.dayOfMonth != null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    _currency ??= ref.watch(effectiveSettingsProvider).defaultCurrency;
    final AppCurrency currency = _currency ?? AppCurrency.inr;

    return AppSheet(
      title: _isEditing
          ? localizations.incomeSheetEdit
          : localizations.incomeSheetNew,
      busy: _busy,
      primaryLabel: _isEditing ? localizations.saveChanges : localizations.actionSave,
      onPrimary: _save,
      secondaryLabel: localizations.actionCancel,
      onSecondary: _busy ? null : widget.onDone,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Offered only while creating: a name the user has already written
            // is not something to talk them out of afterwards.
            if (!_isEditing) ...<Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final String preset in <String>[
                    localizations.incomePresetSalary,
                    localizations.incomePresetAllowance,
                    localizations.incomePresetExtra,
                    localizations.incomePresetFreelance,
                  ])
                    ActionChip(
                      label: Text(preset),
                      onPressed: () => setState(() => _name.text = preset),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            AppTextField(
              label: localizations.fieldIncomeName,
              controller: _name,
              hint: localizations.fieldIncomeNameHint,
              prefixIcon: Icons.label_outline,
              // Deliberately not autofocused, unlike the obligation form. The
              // presets above are the first thing to reach for, and focusing
              // this field opened the keyboard and scrolled the sheet far enough
              // that the first line of presets was pushed off the top — the
              // quick route hidden by the slow one.
              maxLength: 160,
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return localizations.validationRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AmountField(
              label: localizations.fieldAmount,
              currency: currency,
              initialMinor: _amountMinor,
              errorText: _amountError,
              onChanged: (int minor) => setState(() {
                _amountMinor = minor;
                _amountError = null;
              }),
              // Same contract as the obligation form: the field is showing
              // something that is not money, so the amount this form would save
              // is cleared rather than left at its last accepted figure.
              onRejected: () => setState(() {
                _amountMinor = null;
                _amountError = localizations.validationInvalidAmount;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            CurrencyField(
              value: currency,
              suggested: ref.watch(regionCurrencyProvider),
              onChanged: (AppCurrency value) => setState(() => _currency = value),
            ),
            const SizedBox(height: AppSpacing.md),
            OptionField<RecurrenceFrequency>(
              label: localizations.fieldFrequency,
              value: _frequency,
              options: const <RecurrenceFrequency>[
                RecurrenceFrequency.monthly,
                RecurrenceFrequency.weekly,
                RecurrenceFrequency.quarterly,
                RecurrenceFrequency.yearly,
              ],
              labelOf: (RecurrenceFrequency value) => value.label(localizations),
              iconOf: (RecurrenceFrequency _) => Icons.autorenew,
              title: localizations.fieldFrequency,
              icon: Icons.autorenew,
              onChanged: (RecurrenceFrequency value) =>
                  setState(() => _frequency = value),
            ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: localizations.fieldStartDate,
              value: _startAt,
              icon: Icons.play_circle_outline,
              onChanged: (DateTime? value) {
                if (value == null) return;
                setState(() {
                  _startAt = value;
                  if (_usesDayOfMonth) _dayOfMonth = value.day;
                });
              },
            ),
            if (_frequency != RecurrenceFrequency.weekly) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _DayOfMonthField(
                enabled: _usesDayOfMonth,
                value: _dayOfMonth,
                onToggle: (bool value) =>
                    setState(() => _usesDayOfMonth = value),
                onChanged: (int day) => setState(() => _dayOfMonth = day),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label:
                  '${localizations.fieldNote} · ${localizations.fieldOptional}',
              controller: _note,
              hint: localizations.fieldNoteHint,
              prefixIcon: Icons.notes,
              maxLines: 3,
              maxLength: 300,
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    // The sheet disables its primary while `_busy`, but that reaches the button
    // through a rebuild, so a second tap dispatched before the next frame runs
    // this body again — and creating an income is not idempotent: the second run
    // records a second income. The flag is the guard.
    if (_busy) return;
    final int? amount = _amountMinor;
    setState(() {
      _amountError = amount == null || !isAmountWithinRange(amount)
          ? localizations.validationInvalidAmount
          : null;
    });
    if (_amountError != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final IncomeDraft draft = IncomeDraft(
      name: _name.text,
      amountMinor: amount!,
      currency: _currency ?? AppCurrency.inr,
      frequency: _frequency,
      startAt: _startAt,
      dayOfMonth: _frequency == RecurrenceFrequency.weekly || !_usesDayOfMonth
          ? null
          : _dayOfMonth,
      note: _note.text,
    );

    try {
      final LedgerService service = ref.read(ledgerServiceProvider);
      final bool editing = _isEditing;
      if (editing) {
        await service.updateIncome(widget.income!.id, draft);
      } else {
        await service.createIncome(draft);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.info(context, localizations.recordSaved);
      widget.onDone();
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}

/// Lets the user pin an income to a day of the month.
///
/// The same control the obligation form uses, and for the same reason: without
/// it, a salary landing on the 31st would read as the 28th forever after a
/// February.
class _DayOfMonthField extends StatelessWidget {
  const _DayOfMonthField({
    required this.enabled,
    required this.value,
    required this.onToggle,
    required this.onChanged,
  });

  final bool enabled;
  final int value;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: FieldLabel(localizations.fieldDayOfMonth)),
            Switch(value: enabled, onChanged: onToggle),
          ],
        ),
        if (enabled)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final int day in <int>[1, 5, 10, 15, 20, 25, 28, 30, 31])
                ChoiceChip(
                  label: Text(context.formatting.count(day)),
                  selected: value == day,
                  onSelected: (_) => onChanged(day),
                ),
            ],
          )
        else
          Text(
            localizations.incomeFollowsStartDay,
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
