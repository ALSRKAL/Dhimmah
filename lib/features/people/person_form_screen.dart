import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/person.dart';
import '../../l10n/generated/app_localizations.dart';

/// Creates or edits a person.
class PersonFormScreen extends ConsumerStatefulWidget {
  const PersonFormScreen({this.personId, super.key});

  final String? personId;

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();

  int _colorIndex = 0;
  bool _initialised = false;
  bool _busy = false;

  bool get _isEditing => widget.personId != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _hydrate(Person person) {
    if (_initialised) return;
    _initialised = true;
    _name.text = person.name;
    _phone.text = person.phone ?? '';
    _note.text = person.note ?? '';
    _colorIndex = person.colorIndex;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!_isEditing) return _build(context);

    final AsyncValue<Person?> person =
        ref.watch(personByIdProvider(widget.personId!));
    return AsyncValueView<Person?>(
      value: person,
      onRetry: () => ref.invalidate(personByIdProvider(widget.personId!)),
      loading: Scaffold(appBar: AppBar(), body: const ListSkeleton(rows: 4)),
      isEmpty: (Person? value) => value == null,
      empty: Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(localizations.personDeleted)),
      ),
      builder: (BuildContext context, Person? data) {
        if (data == null) return const SizedBox.shrink();
        _hydrate(data);
        return _build(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? localizations.personFormEdit : localizations.personNew,
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
              label: localizations.personNameLabel,
              controller: _name,
              hint: localizations.fieldPersonHint,
              prefixIcon: Icons.person_outline,
              autofocus: !_isEditing,
              maxLength: 120,
              textInputAction: TextInputAction.next,
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
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: '${localizations.fieldNote} · ${localizations.fieldOptional}',
              controller: _note,
              hint: localizations.fieldNoteHint,
              prefixIcon: Icons.notes,
              maxLines: 3,
              maxLength: 300,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: AppSpacing.lg),
            FieldLabel(localizations.personAvatarColor),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                for (int i = 0; i < BrandColors.accentSwatches.length; i++)
                  _Swatch(
                    color: BrandColors.accentSwatches[i],
                    selected: i == _colorIndex,
                    onTap: () => setState(() => _colorIndex = i),
                  ),
              ],
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
              : Text(
                  _isEditing ? localizations.saveChanges : localizations.actionSave,
                ),
        ),
      ),
      backgroundColor: palette.background,
    );
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final PersonDraft draft = PersonDraft(
      name: _name.text,
      phone: _phone.text,
      note: _note.text,
      colorIndex: _colorIndex,
    );

    try {
      final LedgerService service = ref.read(ledgerServiceProvider);
      if (_isEditing) {
        await service.updatePerson(widget.personId!, draft);
      } else {
        await service.createPerson(draft);
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

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? palette.textPrimary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
