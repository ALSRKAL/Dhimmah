import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/search_text.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/person_avatar.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/person.dart';
import '../../l10n/generated/app_localizations.dart';

/// Chooses the people a record is with.
///
/// Multi-select, because one record can be shared: a dinner bill, a group gift,
/// a car bought between friends. The sheet answers the four things that asks for
/// — search, a visible selection, a way to drop someone, and a way to add a
/// person who is not in the list yet — and returns the whole selection at once.
///
/// Returns null when the sheet was dismissed, so a caller can tell "nothing
/// chosen" from "chose nothing".
Future<List<Person>?> showPeoplePicker(
  BuildContext context, {
  required List<Person> selected,
}) {
  return showAppSheet<List<Person>>(
    context,
    child: PeoplePickerSheet(selected: selected),
  );
}

class PeoplePickerSheet extends ConsumerStatefulWidget {
  const PeoplePickerSheet({required this.selected, super.key});

  /// Who is already on the record, in the user's order.
  final List<Person> selected;

  @override
  ConsumerState<PeoplePickerSheet> createState() => _PeoplePickerSheetState();
}

class _PeoplePickerSheetState extends ConsumerState<PeoplePickerSheet> {
  final TextEditingController _search = TextEditingController();
  late final List<Person> _selected = List<Person>.of(widget.selected);
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Adds a person once, keeping the order they were picked in.
  void _toggle(Person person) {
    setState(() {
      final int index = _selected.indexWhere((Person p) => p.id == person.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(person);
      }
    });
  }

  void _add(Person person) {
    setState(() {
      if (_selected.every((Person p) => p.id != person.id)) {
        _selected.add(person);
      }
      _creating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_creating) return _NewPersonForm(onCreated: _add);

    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<PersonDirectoryEntry>> directory =
        ref.watch(peopleDirectoryProvider);
    // Folded as the search screen folds it, so «احمد» finds «أحمد» here too.
    final String query = foldForSearch(_search.text.trim());

    final List<PersonDirectoryEntry> entries = <PersonDirectoryEntry>[
      for (final PersonDirectoryEntry entry
          in directory.value ?? const <PersonDirectoryEntry>[])
        if (!entry.person.isArchived)
          if (query.isEmpty ||
              searchMatches(entry.person.name, query) ||
              searchMatches(entry.person.phone, query))
            entry,
    ];

    return AppSheet(
      title: localizations.fieldPeople,
      subtitle: localizations.fieldPersonPlaceholder,
      primaryLabel: localizations.actionDone,
      onPrimary: () => Navigator.of(context).pop(_selected),
      secondaryLabel: localizations.addPersonAction,
      onSecondary: () => setState(() => _creating = true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The selection is stated above the list, not left to the ticks down
          // it: a user who has scrolled to find a fourth name can still see who
          // the first three were.
          if (_selected.isNotEmpty) ...<Widget>[
            FieldLabel(localizations.participantsSelected),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final Person person in _selected)
                  InputChip(
                    avatar: PersonAvatar.of(person, size: 24),
                    label: Text(person.name),
                    onDeleted: () => _toggle(person),
                    deleteButtonTooltipMessage: localizations.actionClear,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: localizations.participantsSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.person_search_outlined,
                    size: 32,
                    color: context.palette.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    localizations.peopleEmptyTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    localizations.peopleEmptyBody,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            for (final PersonDirectoryEntry entry in entries)
              _PersonOption(
                person: entry.person,
                selected: _selected.any(
                  (Person person) => person.id == entry.person.id,
                ),
                onTap: () => _toggle(entry.person),
              ),
        ],
      ),
    );
  }
}

class _PersonOption extends StatelessWidget {
  const _PersonOption({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final Person person;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
      child: Semantics(
        selected: selected,
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: <Widget>[
              PersonAvatar.of(person, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  person.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: selected ? palette.brand : palette.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // A tick, not a tint: the state has to survive a greyscale screen.
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? palette.brand : palette.borderStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inline "create a person" form.
class _NewPersonForm extends ConsumerStatefulWidget {
  const _NewPersonForm({required this.onCreated});

  final ValueChanged<Person> onCreated;

  @override
  ConsumerState<_NewPersonForm> createState() => _NewPersonFormState();
}

class _NewPersonFormState extends ConsumerState<_NewPersonForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return AppSheet(
      title: localizations.personNew,
      busy: _busy,
      primaryLabel: localizations.actionSave,
      onPrimary: _busy ? null : _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppTextField(
              label: localizations.personNameLabel,
              controller: _name,
              hint: localizations.fieldPersonHint,
              autofocus: true,
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              maxLength: 120,
              validator: (String? value) {
                final String text = value?.trim() ?? '';
                if (text.isEmpty) return localizations.validationRequired;
                if (text.length < 2) return localizations.validationNameTooShort;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label:
                  '${localizations.personPhoneLabel} · ${localizations.fieldOptional}',
              controller: _phone,
              // LTR isolate: the bare hint rendered group-reversed in the
              // RTL field (see person_form_screen for the device evidence).
              hint: '\u2066+967 7XX XXX XXX\u2069',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 32,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      final Person person = await ref.read(ledgerServiceProvider).createPerson(
            PersonDraft(
              name: _name.text,
              phone: _phone.text,
              // Spread new people across the accent palette so avatars differ.
              colorIndex: DateTime.now().microsecond % 8,
            ),
          );
      if (!mounted) return;
      widget.onCreated(person);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}
