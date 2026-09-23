import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money_input.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/person_avatar.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/person.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../people/person_picker_sheet.dart';

/// Creates or edits a debt.
///
/// The screen is one scroll, not a wizard: a user recording a debt usually knows
/// every value already, and the fields they leave alone are the ones with
/// sensible defaults. Only the amount is genuinely required.
class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({
    this.debtId,
    this.direction = DebtDirection.iOwe,
    this.personId,
    super.key,
  });

  /// When set, the form edits this record instead of creating one.
  final String? debtId;

  final DebtDirection direction;

  /// Pre-selected person, used when adding a debt from a person's page.
  final String? personId;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  late DebtDirection _direction = widget.direction;
  AppCurrency? _currency;
  Person? _person;
  int? _amountMinor;
  DateTime _issuedAt = dateOnly(DateTime.now());
  DateTime? _dueAt;
  List<ReminderLead> _leads = const <ReminderLead>[];
  RecurrenceFrequency _recurrence = RecurrenceFrequency.none;
  int _interval = 1;
  bool _initialised = false;
  bool _busy = false;

  /// Whether the optional fields are showing. Off by default: a debt is usually
  /// a person, an amount and a date, and putting the other five fields behind a
  /// tap is the difference between a form that takes seconds and one that looks
  /// like paperwork.
  bool _showAdvanced = false;
  String? _amountError;
  String? _titleError;

  bool get _isEditing => widget.debtId != null;

  /// What the collapsed section currently holds, so nothing is hidden silently.
  String _advancedSummary(AppLocalizations localizations) {
    final List<String> parts = <String>[];
    if (_title.text.trim().isNotEmpty) parts.add(localizations.fieldTitle);
    if (_leads.isNotEmpty) {
      parts.add(localizations.leadCount(_leads.length));
    }
    if (_recurrence.repeats) parts.add(localizations.fieldRecurrence);
    if (_note.text.trim().isNotEmpty) parts.add(localizations.fieldNote);
    if (!isSameDate(_issuedAt, dateOnly(DateTime.now()))) {
      parts.add(localizations.fieldDate);
    }
    if (parts.isEmpty) return localizations.fieldAdvancedHint;
    return parts.join(' · ');
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Fills the form from the stored record the first time it is available.
  void _hydrate(Debt debt) {
    if (_initialised) return;
    _initialised = true;
    _direction = debt.direction;
    _currency = debt.currency;
    _amountMinor = debt.principalMinor;
    _issuedAt = debt.issuedAt;
    _dueAt = debt.dueAt;
    _leads = debt.reminderLeads;
    _recurrence = debt.recurrence;
    _interval = debt.effectiveInterval;
    _title.text = debt.title;
    _note.text = debt.note ?? '';
    // Nothing is hidden on a record that already uses the optional fields.
    _showAdvanced = debt.title.trim().isNotEmpty ||
        (debt.note ?? '').trim().isNotEmpty ||
        debt.reminderLeads.isNotEmpty ||
        debt.isRecurring ||
        !isSameDate(debt.issuedAt, dateOnly(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    if (_isEditing) {
      final AsyncValue<Debt?> debt =
          ref.watch(debtByIdProvider(widget.debtId!));
      return AsyncValueView<Debt?>(
        value: debt,
        onRetry: () => ref.invalidate(debtByIdProvider(widget.debtId!)),
        loading: const ListSkeleton(),
        builder: (BuildContext context, Debt? data) {
          if (data == null) {
            return Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(localizations.recordDeleted)),
            );
          }
          _hydrate(data);
          return _buildForm(context, editing: data);
        },
      );
    }

    // A new record adopts the user's default currency and reminder lead.
    final settings = ref.watch(effectiveSettingsProvider);
    _currency ??= settings.defaultCurrency;
    if (!_initialised) {
      _initialised = true;
      _leads = settings.defaultReminderLeads;
    }
    return _buildForm(context, editing: null);
  }

  Widget _buildForm(BuildContext context, {required Debt? editing}) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool isIOwe = _direction.isIOwe;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing == null
              ? (isIOwe ? localizations.debtFormNewIOwe : localizations.debtFormNewOwedToMe)
              : localizations.debtFormEdit,
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
            SegmentedField<DebtDirection>(
              label: localizations.fieldDirection,
              value: _direction,
              options: const <DebtDirection>[
                DebtDirection.iOwe,
                DebtDirection.owedToMe,
              ],
              labelOf: (DebtDirection value) => value.label(localizations),
              iconOf: (DebtDirection value) => value.isIOwe
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              onChanged: (DebtDirection value) =>
                  setState(() => _direction = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            AmountField(
              label: localizations.fieldAmount,
              currency: _currency ?? AppCurrency.inr,
              initialMinor: _amountMinor,
              errorText: _amountError,
              onChanged: (int minor) {
                setState(() {
                  _amountMinor = minor;
                  _amountError = null;
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            OptionField<AppCurrency>(
              label: localizations.fieldCurrency,
              value: _currency ?? AppCurrency.inr,
              options: AppCurrency.values,
              labelOf: (AppCurrency currency) =>
                  '${currency.code} · ${currency.symbol}',
              iconOf: (AppCurrency _) => Icons.payments_outlined,
              title: localizations.fieldCurrency,
              icon: Icons.payments_outlined,
              onChanged: (AppCurrency currency) =>
                  setState(() => _currency = currency),
            ),
            const SizedBox(height: AppSpacing.md),
            _PersonField(
              person: _person,
              onPick: _pickPerson,
              onClear: () => setState(() => _person = null),
            ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: localizations.fieldDueDate,
              value: _dueAt,
              placeholder: localizations.fieldDueDateNone,
              clearable: true,
              icon: Icons.event_outlined,
              onChanged: (DateTime? value) => setState(() => _dueAt = value),
            ),
            const SizedBox(height: AppSpacing.lg),
            _AdvancedSection(
              expanded: _showAdvanced,
              summary: _advancedSummary(localizations),
              onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppTextField(
                    label:
                        '${localizations.fieldTitle} · ${localizations.fieldOptional}',
                    controller: _title,
                    hint: localizations.fieldTitleHint,
                    errorText: _titleError,
                    prefixIcon: Icons.label_outline,
                    maxLength: 120,
                    onChanged: (_) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DateField(
                    label: localizations.fieldDate,
                    value: _issuedAt,
                    onChanged: (DateTime? value) {
                      if (value != null) setState(() => _issuedAt = value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ReminderLeadsField(
                    label: localizations.fieldReminder,
                    selected: _leads,
                    onChanged: (List<ReminderLead> leads) =>
                        setState(() => _leads = leads),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OptionField<RecurrenceFrequency>(
                    label: localizations.fieldRecurrence,
                    value: _recurrence,
                    options: const <RecurrenceFrequency>[
                      RecurrenceFrequency.none,
                      RecurrenceFrequency.weekly,
                      RecurrenceFrequency.monthly,
                      RecurrenceFrequency.quarterly,
                      RecurrenceFrequency.yearly,
                    ],
                    labelOf: (RecurrenceFrequency value) =>
                        value.label(localizations, interval: _interval),
                    iconOf: (RecurrenceFrequency _) => Icons.autorenew,
                    title: localizations.fieldRecurrence,
                    icon: Icons.autorenew,
                    onChanged: (RecurrenceFrequency value) =>
                        setState(() => _recurrence = value),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label:
                        '${localizations.fieldNote} · ${localizations.fieldOptional}',
                    controller: _note,
                    hint: localizations.fieldNoteHint,
                    prefixIcon: Icons.notes,
                    maxLines: 3,
                    maxLength: 500,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        editing == null
                            ? localizations.saveDebt
                            : localizations.saveChanges,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPerson() async {
    final Person? picked = await showPersonPicker(
      context,
      selectedId: _person?.id,
    );
    if (picked != null) setState(() => _person = picked);
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppCurrency currency = _currency ?? AppCurrency.inr;

    final int? amount = _amountMinor;
    // Either a person or a description has to identify the record; a nameless,
    // description-less debt would be unreadable in the list a week later.
    final bool needsTitle = _person == null && _title.text.trim().isEmpty;

    setState(() {
      _amountError =
          amount == null || !isAmountWithinRange(amount)
              ? localizations.validationInvalidAmount
              : null;
      _titleError = needsTitle ? localizations.validationRequired : null;
    });
    if (_amountError != null || _titleError != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_dueAt != null && _dueAt!.isBefore(_issuedAt)) {
      AppFeedback.error(context, localizations.validationDueBeforeIssue);
      return;
    }

    setState(() => _busy = true);
    final DebtDraft draft = DebtDraft(
      direction: _direction,
      personId: _person?.id,
      title: _title.text,
      principalMinor: amount!,
      currency: currency,
      issuedAt: _issuedAt,
      dueAt: _dueAt,
      note: _note.text,
      reminderLeads: _leads,
      recurrence: _recurrence,
      recurrenceInterval: _interval,
    );

    try {
      final LedgerService service = ref.read(ledgerServiceProvider);
      if (_isEditing) {
        await service.updateDebt(widget.debtId!, draft);
      } else {
        await service.createDebt(draft);
      }
      if (!mounted) return;
      AppFeedback.info(
        context,
        _isEditing ? localizations.debtUpdated : localizations.debtCreated,
      );
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}

class _PersonField extends StatelessWidget {
  const _PersonField({
    required this.person,
    required this.onPick,
    required this.onClear,
  });

  final Person? person;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(localizations.fieldPerson),
        InkWell(
          borderRadius: AppRadius.rMd,
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: AppRadius.rMd,
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: <Widget>[
                if (person != null)
                  PersonAvatar.of(person!, size: 36)
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.brandContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt,
                      size: 18,
                      color: palette.onBrandContainer,
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    person?.name ?? localizations.fieldPersonHint,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: person == null
                          ? palette.textTertiary
                          : palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (person != null)
                  IconButton(
                    tooltip: localizations.actionClear,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClear,
                  )
                else
                  Icon(Icons.expand_more, size: 20, color: palette.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The disclosure that keeps a form short without hiding anything.
class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.summary,
    required this.onToggle,
    required this.child,
  });

  final bool expanded;
  final String summary;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Material(
          color: palette.surfaceMuted,
          borderRadius: AppRadius.rMd,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          localizations.fieldAdvancedOptions,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.topStart,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
