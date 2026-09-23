import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/person_avatar.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/person.dart';
import '../../l10n/generated/app_localizations.dart';

/// Picks the person a record belongs to, and can create one on the spot.
///
/// Creating the person inline matters: the moment a user is recording a debt is
/// exactly when they know who it is for, and sending them to another screen would
/// break the flow the spec asks for.
Future<Person?> showPersonPicker(
  BuildContext context, {
  String? selectedId,
}) {
  return showAppSheet<Person>(
    context,
    child: PersonPickerSheet(selectedId: selectedId),
  );
}

class PersonPickerSheet extends ConsumerStatefulWidget {
  const PersonPickerSheet({this.selectedId, super.key});

  final String? selectedId;

  @override
  ConsumerState<PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<PersonPickerSheet> {
  final TextEditingController _search = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_creating) return _NewPersonForm(onCreated: _returnPerson);

    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<PersonDirectoryEntry>> directory =
        ref.watch(peopleDirectoryProvider);
    final String query = _search.text.trim().toLowerCase();

    final List<PersonDirectoryEntry> entries = <PersonDirectoryEntry>[
      for (final PersonDirectoryEntry entry
          in directory.value ?? const <PersonDirectoryEntry>[])
        if (!entry.person.isArchived)
          if (query.isEmpty || entry.person.name.toLowerCase().contains(query))
            entry,
    ];

    return AppSheet(
      title: localizations.fieldPerson,
      subtitle: localizations.fieldPersonHint,
      primaryLabel: localizations.addPersonAction,
      onPrimary: () => setState(() => _creating = true),
      secondaryLabel: localizations.fieldPersonNone,
      onSecondary: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: localizations.searchHint,
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
                selected: entry.person.id == widget.selectedId,
                balances: entry.totals,
                onTap: () => _returnPerson(entry.person),
              ),
        ],
      ),
    );
  }

  void _returnPerson(Person person) {
    if (!mounted) return;
    Navigator.of(context).pop(person);
  }
}

class _PersonOption extends StatelessWidget {
  const _PersonOption({
    required this.person,
    required this.selected,
    required this.balances,
    required this.onTap,
  });

  final Person person;
  final bool selected;
  final List<CurrencyTotals> balances;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
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
            if (selected)
              Icon(Icons.check, size: 20, color: palette.brand),
          ],
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
              hint: '+967 7XX XXX XXX',
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
