import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money_input.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// Creates or edits a recurring commitment.
///
/// The form asks for the schedule once — how much, how often, starting when —
/// and derives every period from the anchor date. That is what keeps the 31st the
/// 31st in a 30-day month instead of silently sliding.
class ObligationFormScreen extends ConsumerStatefulWidget {
  const ObligationFormScreen({this.obligationId, super.key});

  final String? obligationId;

  @override
  ConsumerState<ObligationFormScreen> createState() =>
      _ObligationFormScreenState();
}

class _ObligationFormScreenState extends ConsumerState<ObligationFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _dayOfMonth = TextEditingController();

  ObligationCategory _category = ObligationCategory.housing;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  AppCurrency? _currency;
  int? _amountMinor;
  DateTime _startAt = dateOnly(DateTime.now());
  DateTime? _endAt;
  List<ReminderLead> _leads = const <ReminderLead>[];
  int _dayOfMonthValue = dateOnly(DateTime.now()).day;
  bool _usesDayOfMonth = true;
  bool _initialised = false;
  bool _busy = false;
  String? _amountError;

  bool get _isEditing => widget.obligationId != null;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _dayOfMonth.dispose();
    super.dispose();
  }

  void _hydrate(Obligation obligation) {
    if (_initialised) return;
    _initialised = true;
    _name.text = obligation.name;
    _note.text = obligation.note ?? '';
    _category = obligation.category;
    _frequency = obligation.frequency;
    _currency = obligation.currency;
    _amountMinor = obligation.amountMinor;
    _startAt = obligation.startAt;
    _endAt = obligation.endAt;
    _leads = obligation.reminderLeads;
    _dayOfMonthValue = obligation.dayOfMonth ?? obligation.startAt.day;
    _usesDayOfMonth = obligation.dayOfMonth != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final AsyncValue<Obligation?> obligation =
          ref.watch(obligationByIdProvider(widget.obligationId!));
      return AsyncValueView<Obligation?>(
        value: obligation,
        onRetry: () =>
            ref.invalidate(obligationByIdProvider(widget.obligationId!)),
        loading: Scaffold(appBar: AppBar(), body: const ListSkeleton()),
        isEmpty: (Obligation? value) => value == null,
        empty: Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(AppLocalizations.of(context).recordDeleted)),
        ),
        builder: (BuildContext context, Obligation? data) {
          if (data == null) return const SizedBox.shrink();
          _hydrate(data);
          return _build(context);
        },
      );
    }

    _currency ??= ref.watch(effectiveSettingsProvider).defaultCurrency;
    if (!_initialised) {
      _initialised = true;
      _leads = ref.read(effectiveSettingsProvider).defaultReminderLeads;
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppCurrency currency = _currency ?? AppCurrency.inr;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? localizations.obligationFormEdit
              : localizations.obligationFormNew,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.massive,
          ),
          children: <Widget>[
            AppTextField(
              label: localizations.fieldObligationName,
              controller: _name,
              hint: localizations.fieldObligationNameHint,
              prefixIcon: Icons.label_outline,
              autofocus: !_isEditing,
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
            ),
            const SizedBox(height: AppSpacing.md),
            OptionField<AppCurrency>(
              label: localizations.fieldCurrency,
              value: currency,
              options: AppCurrency.values,
              labelOf: (AppCurrency value) => '${value.code} · ${value.symbol}',
              iconOf: (AppCurrency _) => Icons.payments_outlined,
              title: localizations.fieldCurrency,
              icon: Icons.payments_outlined,
              onChanged: (AppCurrency value) =>
                  setState(() => _currency = value),
            ),
            const SizedBox(height: AppSpacing.md),
            OptionField<ObligationCategory>(
              label: localizations.fieldCategory,
              value: _category,
              options: ObligationCategory.values,
              labelOf: (ObligationCategory value) => value.label(localizations),
              iconOf: (ObligationCategory value) => value.icon,
              title: localizations.fieldCategory,
              icon: Icons.category_outlined,
              onChanged: (ObligationCategory value) =>
                  setState(() => _category = value),
            ),
            const SizedBox(height: AppSpacing.md),
            OptionField<RecurrenceFrequency>(
              label: localizations.fieldFrequency,
              value: _frequency,
              options: const <RecurrenceFrequency>[
                RecurrenceFrequency.weekly,
                RecurrenceFrequency.monthly,
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
                  if (_usesDayOfMonth) _dayOfMonthValue = value.day;
                });
              },
            ),
            if (_frequency != RecurrenceFrequency.weekly) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _DayOfMonthField(
                enabled: _usesDayOfMonth,
                value: _dayOfMonthValue,
                onToggle: (bool value) =>
                    setState(() => _usesDayOfMonth = value),
                onChanged: (int day) =>
                    setState(() => _dayOfMonthValue = day),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            DateField(
              label:
                  '${localizations.fieldEndDate} · ${localizations.fieldOptional}',
              value: _endAt,
              placeholder: localizations.fieldOptional,
              clearable: true,
              icon: Icons.event_busy_outlined,
              onChanged: (DateTime? value) => setState(() => _endAt = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            ReminderLeadsField(
              label: localizations.fieldReminder,
              selected: _leads,
              onChanged: (List<ReminderLead> leads) =>
                  setState(() => _leads = leads),
            ),
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
      // The pinned Save rides above the IME by hand: with edge-to-edge the
      // window never resizes, and the Scaffold leaves its bottomNavigationBar
      // at the window bottom — behind the keyboard.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: FilledButton(
            onPressed: _busy ? null : _save,
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
                : Text(_isEditing ? localizations.saveChanges : localizations.actionSave),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final int? amount = _amountMinor;
    setState(() {
      _amountError = amount == null || !isAmountWithinRange(amount)
          ? localizations.validationInvalidAmount
          : null;
    });
    if (_amountError != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_endAt != null && _endAt!.isBefore(_startAt)) {
      AppFeedback.error(context, localizations.validationEndBeforeStart);
      return;
    }

    setState(() => _busy = true);
    final ObligationDraft draft = ObligationDraft(
      name: _name.text,
      category: _category,
      amountMinor: amount!,
      currency: _currency ?? AppCurrency.inr,
      frequency: _frequency,
      startAt: _startAt,
      dayOfMonth:
          _frequency == RecurrenceFrequency.weekly || !_usesDayOfMonth
              ? null
              : _dayOfMonthValue,
      endAt: _endAt,
      note: _note.text,
      reminderLeads: _leads,
    );

    try {
      final LedgerService service = ref.read(ledgerServiceProvider);
      if (_isEditing) {
        await service.updateObligation(widget.obligationId!, draft);
      } else {
        await service.createObligation(draft);
      }
      if (!mounted) return;
      AppFeedback.info(context, localizations.recordSaved);
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}

/// Lets the user pin the schedule to a specific day of the month.
///
/// Without this, a commitment that lands on the 31st would drift to the 28th and
/// stay there; with it, the schedule clamps per month and recovers the 31st.
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
            Expanded(
              child: FieldLabel(localizations.fieldDayOfMonth),
            ),
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
            localizations.obligationNextDue(
              context.formatting.date(DateTime.now()),
            ),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}
