import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/money/currency.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/person_avatar.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/person.dart';
import '../../domain/enums/debt_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../domain/services/amount_rules.dart';
import '../../domain/services/participant_rules.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../people/person_picker_sheet.dart';

/// Creates or edits a debt.
///
/// The screen is one scroll, not a wizard: a user recording a debt usually knows
/// every value already, and the fields they leave alone are the ones with
/// sensible defaults. Three things are genuinely required — the side, the amount
/// and who it is with — and each of them says so before Save is pressed.
///
/// The form keeps *ids* for the people, not objects. That is what makes editing
/// safe: the record's participants are read back from the stored debt, so
/// changing the amount cannot quietly drop the person the debt is with.
class DebtFormScreen extends ConsumerStatefulWidget {
  const DebtFormScreen({
    this.debtId,
    this.direction,
    this.personId,
    super.key,
  });

  /// When set, the form edits this record instead of creating one.
  final String? debtId;

  /// The side of the ledger the user already chose, when they chose one.
  ///
  /// Null when nothing has been chosen — adding from the dashboard, or from a
  /// person — and the form then asks rather than answering for them.
  final DebtDirection? direction;

  /// Pre-attached person, used when adding a debt from a person's page.
  final String? personId;

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// Anchors for the two fields the save can jump to.
  final GlobalKey _directionKey = GlobalKey();
  final GlobalKey _amountKey = GlobalKey();
  final GlobalKey _peopleKey = GlobalKey();
  final FocusNode _amountFocus = FocusNode();

  late DebtDirection? _direction = widget.direction;
  AppCurrency? _currency;

  /// Who the record is with, in the order the user chose them.
  late final List<String> _personIds = <String>[
    if (widget.personId != null) widget.personId!,
  ];

  /// Whether the participant editor is showing.
  ///
  /// False when the form was opened from a person's page: the app already knows
  /// who the debt is with, so it states that instead of asking again, and adding
  /// more people is one explicit tap away.
  late bool _peopleExpanded = widget.personId == null;

  int? _amountMinor;
  DateTime _issuedAt = dateOnly(DateTime.now());
  DateTime? _dueAt;
  List<ReminderLead> _leads = const <ReminderLead>[];
  RecurrenceFrequency _recurrence = RecurrenceFrequency.none;
  int _interval = 1;

  /// The stored end of a repeating record's series. The form has no field for
  /// it, but it writes the whole record, and an edit used to erase it.
  DateTime? _recurrenceEndAt;
  bool _initialised = false;
  bool _busy = false;

  /// Set by any edit the user makes, so leaving can be confirmed.
  bool _dirty = false;

  /// Set once a save has succeeded, so its own pop is never questioned.
  bool _saved = false;

  /// The side the record had when the form opened, to explain a move.
  DebtDirection? _initialDirection;

  /// Whether the optional fields are showing. Off by default: a debt is usually
  /// a person, an amount and a date, and putting the other five fields behind a
  /// tap is the difference between a form that takes seconds and one that looks
  /// like paperwork.
  bool _showAdvanced = false;

  /// One message per field, set by a save that could not proceed. Null means the
  /// field is fine.
  String? _directionError;
  String? _amountError;
  String? _peopleError;

  /// How many required fields the last save found missing, for the summary.
  int _missingFields = 0;

  bool get _isEditing => widget.debtId != null;

  /// What the collapsed section currently holds, so nothing is hidden silently.
  String _advancedSummary(AppLocalizations localizations) {
    final List<String> parts = <String>[];
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
    _amountFocus.dispose();
    super.dispose();
  }

  /// Fills the form from the stored record the first time it is available.
  ///
  /// Every field the form owns is filled here — the people included. A form that
  /// hydrates all but one of its fields does not edit a record, it rewrites the
  /// part it forgot.
  void _hydrate(Debt debt) {
    if (_initialised) return;
    _initialised = true;
    _direction = debt.direction;
    _initialDirection = debt.direction;
    _currency = debt.currency;
    _amountMinor = debt.principalMinor;
    _issuedAt = debt.issuedAt;
    _dueAt = debt.dueAt;
    _leads = debt.reminderLeads;
    _recurrence = debt.recurrence;
    _interval = debt.effectiveInterval;
    _recurrenceEndAt = debt.recurrenceEndAt;
    _title.text = debt.title;
    _note.text = debt.note ?? '';
    _personIds
      ..clear()
      ..addAll(debt.personIds);
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

  /// Why a reminder chosen here will not reach the phone, or null when it will.
  ///
  /// Read from the live permission rather than from a value captured at
  /// start-up: the user can grant or revoke notifications without restarting.
  String? _reminderUnavailableReason(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    if (!ref.watch(effectiveSettingsProvider).notificationsEnabled) {
      return localizations.reminderNotArmedOff;
    }
    final NotificationPermission permission =
        ref.watch(notificationPermissionProvider).value ??
            ref.read(notificationServiceProvider).permission;
    return permission == NotificationPermission.denied
        ? localizations.reminderNotArmedDenied
        : null;
  }

  Widget _buildForm(BuildContext context, {required Debt? editing}) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return PopScope<Object?>(
      // Leaving with unsaved edits is confirmed, but only when there is
      // something to lose: a form the user opened and closed is not a decision.
      // A save in flight owns the screen — backing out mid-write is not a
      // question worth asking, and answering it either way would race the write.
      canPop: _saved || (!_dirty && !_busy),
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop || _busy) return;
        final bool leave = await _confirmDiscard(localizations);
        if (leave && mounted) this.context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenTitle(localizations, editing)),
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
              if (_missingFields > 0) ...<Widget>[
                _MissingFieldsBanner(
                  message: localizations.requiredFieldsMissing(_missingFields),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _DirectionField(
                key: _directionKey,
                value: _direction,
                errorText: _directionError,
                onChanged: (DebtDirection value) => setState(() {
                  _dirty = true;
                  _direction = value;
                  _directionError = null;
                  _missingFields = 0;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              AmountField(
                key: _amountKey,
                label: _required(localizations.fieldAmount),
                currency: _currency ?? AppCurrency.inr,
                initialMinor: _amountMinor,
                errorText: _amountError,
                focusNode: _amountFocus,
                onChanged: (int minor) {
                  setState(() {
                    _dirty = true;
                    _amountMinor = minor;
                    _amountError = null;
                    _missingFields = 0;
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
                onChanged: (AppCurrency currency) => setState(() {
                  _dirty = true;
                  _currency = currency;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              // The description sits in the open form, directly under the
              // amount it labels — it used to live inside «خيارات إضافية»,
              // where a user naming their debt had to find the toggle first.
              // The amount itself stays out here, never inside the section.
              AppTextField(
                label:
                    '${localizations.fieldTitle} · ${localizations.fieldOptional}',
                controller: _title,
                hint: localizations.fieldTitleHint,
                prefixIcon: Icons.label_outline,
                maxLength: 120,
                onChanged: (_) => setState(() => _dirty = true),
              ),
              const SizedBox(height: AppSpacing.md),
              _PeopleField(
                key: _peopleKey,
                personIds: _personIds,
                expanded: _peopleExpanded,
                contextPersonId: widget.personId,
                errorText: _peopleError,
                onAdd: _addPeople,
                onRemove: (String personId) => setState(() {
                  _dirty = true;
                  _personIds.remove(personId);
                  _peopleError = null;
                  _missingFields = 0;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              DateField(
                label: localizations.fieldDueDate,
                value: _dueAt,
                placeholder: localizations.fieldDueDateNone,
                clearable: true,
                icon: Icons.event_outlined,
                onChanged: (DateTime? value) => setState(() {
                  _dirty = true;
                  _dueAt = value;
                }),
              ),
              const SizedBox(height: AppSpacing.lg),
              _AdvancedSection(
                expanded: _showAdvanced,
                summary: _advancedSummary(localizations),
                onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    DateField(
                      label: localizations.fieldDate,
                      value: _issuedAt,
                      onChanged: (DateTime? value) {
                        if (value != null) {
                          setState(() {
                            _dirty = true;
                            _issuedAt = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ReminderLeadsField(
                      label: localizations.fieldReminder,
                      selected: _leads,
                      unavailableReason: _reminderUnavailableReason(
                        context,
                        localizations,
                      ),
                      onChanged: (List<ReminderLead> leads) => setState(() {
                        _dirty = true;
                        _leads = leads;
                      }),
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
                      onChanged: (RecurrenceFrequency value) => setState(() {
                        _dirty = true;
                        _recurrence = value;
                      }),
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
                      onChanged: (_) => setState(() => _dirty = true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
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
        ),
      ),
    );
  }

  /// Marks a label as required, the same way on every field that is.
  static String _required(String label) => '$label *';

  /// The screen's title: the side when the user already chose one, otherwise
  /// the plain act of adding a debt.
  String _screenTitle(AppLocalizations localizations, Debt? editing) {
    if (editing != null) return localizations.debtFormEdit;
    final DebtDirection? direction = _direction;
    if (direction == null) return localizations.addDebtAction;
    return direction.isIOwe
        ? localizations.debtFormNewIOwe
        : localizations.debtFormNewOwedToMe;
  }

  Future<void> _addPeople(AppLocalizations localizations) async {
    final List<Person>? picked = await showPeoplePicker(
      context,
      selected: _selectedPeople(localizations),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _dirty = true;
      _peopleExpanded = true;
      _personIds
        ..clear()
        ..addAll(picked.map((Person person) => person.id));
      _peopleError = null;
      _missingFields = 0;
    });
  }

  /// The chosen people, resolved from the live directory.
  List<Person> _selectedPeople(AppLocalizations localizations) {
    final List<PersonDirectoryEntry> directory =
        ref.read(peopleDirectoryProvider).value ??
            const <PersonDirectoryEntry>[];
    final Map<String, Person> byId = <String, Person>{
      for (final PersonDirectoryEntry entry in directory) entry.person.id: entry.person,
    };
    return <Person>[
      for (final String id in _personIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Checks every required field, marks the ones that are missing, and returns
  /// how many there were.
  ///
  /// Runs before anything is written, and touches nothing the user typed: the
  /// draft is the form, so the fixes are made in place and Save can be pressed
  /// again.
  int _validate(AppLocalizations localizations) {
    final int? amount = _amountMinor;
    final bool directionMissing = _direction == null;
    final bool amountMissing = amount == null || !AmountRules.isValid(amount);
    final bool peopleMissing = !ParticipantRules.isValid(
      ParticipantRules.normalise(_personIds),
    );
    final int missing =
        (directionMissing ? 1 : 0) + (amountMissing ? 1 : 0) + (peopleMissing ? 1 : 0);

    setState(() {
      _directionError =
          directionMissing ? localizations.validationSelectDirection : null;
      _amountError =
          amountMissing ? localizations.validationInvalidAmount : null;
      _peopleError =
          peopleMissing ? localizations.validationSelectParticipant : null;
      _missingFields = missing;
    });
    return missing;
  }

  /// Scrolls to the first field the save stopped on, in the form's own order.
  Future<void> _revealFirstMissing() async {
    final GlobalKey target = _direction == null
        ? _directionKey
        : (_amountMinor == null || !AmountRules.isValid(_amountMinor!)
            ? _amountKey
            : _peopleKey);
    final BuildContext? field = target.currentContext;
    if (field != null) {
      await Scrollable.ensureVisible(
        field,
        alignment: 0.2,
        duration: AppMotion.screen,
        curve: AppMotion.standard,
      );
    }
    if (!mounted) return;
    // The amount is a text field, so it can take the caret as well; the other
    // two are choices, and stealing focus for a segmented control or a chip row
    // would only hide the keyboard-less explanation under a keyboard.
    if (identical(target, _amountKey)) _amountFocus.requestFocus();
  }

  Future<bool> _confirmDiscard(AppLocalizations localizations) async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(localizations.unsavedChangesTitle),
        content: Text(localizations.unsavedChangesBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.unsavedChangesStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.unsavedChangesLeave),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (_validate(localizations) > 0) {
      await _revealFirstMissing();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_dueAt != null && _dueAt!.isBefore(_issuedAt)) {
      AppFeedback.error(context, localizations.validationDueBeforeIssue);
      return;
    }

    final DebtDirection direction = _direction!;
    final AppCurrency currency = _currency ?? AppCurrency.inr;
    final List<String> personIds =
        ParticipantRules.normalise(_personIds);

    setState(() => _busy = true);
    final DebtDraft draft = DebtDraft(
      direction: direction,
      personIds: personIds,
      title: _title.text,
      principalMinor: _amountMinor!,
      currency: currency,
      issuedAt: _issuedAt,
      dueAt: _dueAt,
      note: _note.text,
      reminderLeads: _leads,
      recurrence: _recurrence,
      recurrenceInterval: _interval,
      // Kept while the record still repeats; a record that stops repeating
      // has no series to end.
      recurrenceEndAt: _recurrence.repeats ? _recurrenceEndAt : null,
    );

    try {
      final LedgerService service = ref.read(ledgerServiceProvider);
      if (_isEditing) {
        await service.updateDebt(widget.debtId!, draft);
      } else {
        await service.createDebt(draft);
      }
      if (!mounted) return;
      _saved = true;
      AppFeedback.info(
        context,
        _explainWhereItWent(localizations, direction, personIds) ??
            (_isEditing ? localizations.debtUpdated : localizations.debtCreated),
      );
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }

  /// Says where a saved record went when the answer is "somewhere else".
  ///
  /// Changing the side of a ledger, or removing the person the form was opened
  /// from, takes the record off the list the user came from. Without a word about
  /// it, a successful save looks exactly like a record that vanished.
  String? _explainWhereItWent(
    AppLocalizations localizations,
    DebtDirection direction,
    List<String> personIds,
  ) {
    if (!_isEditing) return null;
    final String? contextPersonId = widget.personId;
    if (contextPersonId != null && !personIds.contains(contextPersonId)) {
      final Person? person = _personById(contextPersonId);
      if (person != null) {
        return localizations.debtSavedParticipantRemoved(person.name);
      }
    }
    if (_initialDirection != null && _initialDirection != direction) {
      return localizations.debtSavedMoved(direction.label(localizations));
    }
    return null;
  }

  Person? _personById(String id) {
    for (final PersonDirectoryEntry entry
        in ref.read(peopleDirectoryProvider).value ??
            const <PersonDirectoryEntry>[]) {
      if (entry.person.id == id) return entry.person;
    }
    return null;
  }
}

/// The side of the ledger, with nothing chosen until the user chooses.
///
/// A segmented control that can be empty: a debt that was recorded as "I owe"
/// because that is what the form happened to open on is a wrong record, and the
/// only way to never write one is to have no answer until there is one.
class _DirectionField extends StatelessWidget {
  const _DirectionField({
    required this.value,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final DebtDirection? value;
  final ValueChanged<DebtDirection> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel('${localizations.fieldDirection} *'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<DebtDirection>(
            segments: <ButtonSegment<DebtDirection>>[
              ButtonSegment<DebtDirection>(
                value: DebtDirection.iOwe,
                label: Text(localizations.ledgerSwitchIOwe),
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              ),
              ButtonSegment<DebtDirection>(
                value: DebtDirection.owedToMe,
                label: Text(localizations.ledgerSwitchOwedToMe),
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              ),
            ],
            selected: value == null
                ? const <DebtDirection>{}
                : <DebtDirection>{value!},
            // The whole point: nothing is highlighted until the user says so.
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (Set<DebtDirection> selection) {
              if (selection.isNotEmpty) onChanged(selection.first);
            },
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.overdue),
            ),
          ),
      ],
    );
  }
}

/// Who the record is with: chips when shown, a line and one action when the
/// screen was opened from someone's page.
class _PeopleField extends ConsumerWidget {
  const _PeopleField({
    required this.personIds,
    required this.expanded,
    required this.contextPersonId,
    required this.onAdd,
    required this.onRemove,
    this.errorText,
    super.key,
  });

  final List<String> personIds;
  final bool expanded;
  final String? contextPersonId;
  final Future<void> Function(AppLocalizations localizations) onAdd;
  final ValueChanged<String> onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<PersonDirectoryEntry>> directory =
        ref.watch(peopleDirectoryProvider);
    final Map<String, Person> byId = <String, Person>{
      for (final PersonDirectoryEntry entry
          in directory.value ?? const <PersonDirectoryEntry>[])
        entry.person.id: entry.person,
    };
    final List<Person> people = <Person>[
      for (final String id in personIds)
        if (byId[id] != null) byId[id]!,
    ];
    // The person this form was opened for, when it is still on the record.
    final Person? contextPerson =
        contextPersonId == null ? null : byId[contextPersonId!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel('${localizations.fieldPeople} *'),
        if (!expanded && contextPerson != null)
          // Opened from a person's page: the app knows who this is with, so it
          // states that instead of asking a second time.
          Row(
            children: <Widget>[
              Expanded(
                child: InputChip(
                  avatar: PersonAvatar.of(contextPerson, size: 24),
                  label: Text(
                    localizations.debtFormWithPerson(contextPerson.name),
                  ),
                  onDeleted: () => onRemove(contextPerson.id),
                  deleteButtonTooltipMessage: localizations.actionClear,
                ),
              ),
            ],
          )
        // The empty row is also what shows while the directory is still
        // loading: one tap opens the picker, which has its own empty state.
        else if (people.isEmpty)
          // The whole row is the tap target, not a chip beside a button: with
          // nothing chosen yet, "who is this with" is the one thing the field is
          // asking for.
          InkWell(
            borderRadius: AppRadius.rMd,
            onTap: () => onAdd(localizations),
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
                      localizations.fieldPersonHint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: palette.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.expand_more, size: 20, color: palette.textTertiary),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final Person person in people)
                InputChip(
                  avatar: PersonAvatar.of(person, size: 24),
                  label: Text(person.name),
                  onDeleted: () => onRemove(person.id),
                  deleteButtonTooltipMessage: localizations.actionClear,
                ),
            ],
          ),
        if (people.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => onAdd(localizations),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: Text(
                expanded
                    ? localizations.participantsAdd
                    : localizations.participantsAddMore,
              ),
            ),
          ),
        ],
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: theme.textTheme.bodySmall?.copyWith(color: palette.overdue),
            ),
          ),
      ],
    );
  }
}

/// What a save found missing, stated once at the top as well as at each field.
///
/// Not a replacement for the per-field messages — both, because a long form
/// scrolled to its middle shows neither the top nor the field that is wrong.
class _MissingFieldsBanner extends StatelessWidget {
  const _MissingFieldsBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.overdueContainer,
          borderRadius: AppRadius.rMd,
          border: Border.all(color: palette.overdue),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline, size: 20, color: palette.overdue),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: palette.overdue),
              ),
            ),
          ],
        ),
      ),
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
