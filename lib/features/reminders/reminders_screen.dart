import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/status_style.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/services/ledger_service.dart';
import '../../domain/entities/drafts.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// The reminders screen, grouped by when they fall.
///
/// Grouping by "today / tomorrow / this week / later" is how the spec asks for
/// it, and it matches how people plan: the exact date matters far less than
/// whether something is imminent.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _showCompleted = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<List<Reminder>> reminders = ref.watch(remindersProvider);
    final DateTime asOf = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.remindersTitle),
        actions: <Widget>[
          IconButton(
            tooltip: localizations.remindersCompleted,
            icon: Icon(
              _showCompleted ? Icons.done_all : Icons.check_circle_outline,
              size: 20,
            ),
            onPressed: () => setState(() => _showCompleted = !_showCompleted),
          ),
        ],
      ),
      body: AsyncValueView<List<Reminder>>(
        value: reminders,
        onRetry: () => ref.invalidate(remindersProvider),
        loading: const ListSkeleton(),
        isEmpty: (List<Reminder> data) =>
            data.where((Reminder r) => _visible(r)).isEmpty,
        empty: EmptyState(
          title: localizations.remindersEmptyTitle,
          body: localizations.remindersEmptyBody,
          actionLabel: localizations.reminderNew,
          onAction: () => context.push(AppRoutes.reminderNew),
        ),
        builder: (BuildContext context, List<Reminder> data) {
          final List<Reminder> visible = <Reminder>[
            for (final Reminder reminder in data)
              if (_visible(reminder)) reminder,
          ];
          final Map<ReminderBucket, List<Reminder>> buckets = _bucket(visible, asOf);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.massive,
            ),
            children: <Widget>[
              Text(
                localizations.remindersSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final ReminderBucket bucket in ReminderBucket.values)
                if ((buckets[bucket] ?? const <Reminder>[]).isNotEmpty) ...<Widget>[
                  SectionHeader(title: bucket.label(localizations)),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0;
                            i < buckets[bucket]!.length;
                            i++)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _ReminderRow(
                                reminder: buckets[bucket]![i],
                                asOf: asOf,
                              ),
                              if (i != buckets[bucket]!.length - 1)
                                const AppDivider(indent: 64),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.reminderNew),
        backgroundColor: context.palette.brand,
        foregroundColor: context.palette.textOnBrand,
        icon: const Icon(Icons.add, size: 20),
        label: Text(localizations.reminderNew),
      ),
    );
  }

  bool _visible(Reminder reminder) =>
      _showCompleted ? true : !reminder.isCompleted;

  static Map<ReminderBucket, List<Reminder>> _bucket(
    List<Reminder> reminders,
    DateTime asOf,
  ) {
    final Map<ReminderBucket, List<Reminder>> out =
        <ReminderBucket, List<Reminder>>{};
    for (final Reminder reminder in reminders) {
      final ReminderBucket bucket;
      if (reminder.isCompleted) {
        bucket = ReminderBucket.completed;
      } else {
        final int days = daysBetween(asOf, reminder.dueAt);
        if (days < 0) {
          bucket = ReminderBucket.overdue;
        } else if (days == 0) {
          bucket = ReminderBucket.today;
        } else if (days == 1) {
          bucket = ReminderBucket.tomorrow;
        } else if (days <= 7) {
          bucket = ReminderBucket.thisWeek;
        } else {
          bucket = ReminderBucket.later;
        }
      }
      out.putIfAbsent(bucket, () => <Reminder>[]).add(reminder);
    }
    return out;
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.reminder, required this.asOf});

  final Reminder reminder;
  final DateTime asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final StatusStyle style = _style(palette);

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
                color: style.container,
                borderRadius: AppRadius.rSm,
              ),
              child: Icon(style.icon, size: 17, color: style.foreground),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    reminder.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: reminder.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: reminder.isCompleted
                          ? palette.textTertiary
                          : palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // The relative phrase falls back to an absolute date for
                  // anything far out, so pairing the two would print the same
                  // date twice.
                  Text(
                    context.formatting.relativeDue(reminder.dueAt, asOf),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (!reminder.isCompleted)
              IconButton(
                tooltip: localizations.reminderMarkDone,
                icon: const Icon(Icons.check_circle_outline, size: 22),
                onPressed: () => ref
                    .read(ledgerServiceProvider)
                    .setReminderDone(reminder.id, true),
              )
            else
              IconButton(
                tooltip: localizations.reminderReopen,
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => ref
                    .read(ledgerServiceProvider)
                    .setReminderDone(reminder.id, false),
              ),
          ],
        ),
      ),
    );
  }

  StatusStyle _style(AppPalette palette) => switch (reminder.status) {
        ReminderStatus.overdue => StatusStyle(
            foreground: palette.overdue,
            container: palette.overdueContainer,
            icon: Icons.error_outline,
          ),
        ReminderStatus.today => StatusStyle(
            foreground: palette.dueSoon,
            container: palette.dueSoonContainer,
            icon: Icons.today_outlined,
          ),
        ReminderStatus.completed => StatusStyle(
            foreground: palette.settled,
            container: palette.settledContainer,
            icon: Icons.check_circle_outline,
          ),
        _ => StatusStyle(
            foreground: palette.neutralStatus,
            container: palette.neutralStatusContainer,
            icon: Icons.notifications_none,
          ),
      };

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(localizations.actionEdit),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.reminderPath(reminder.id));
              },
            ),
            ListTile(
              leading: Icon(
                reminder.isCompleted ? Icons.refresh : Icons.check_circle_outline,
              ),
              title: Text(
                reminder.isCompleted
                    ? localizations.reminderReopen
                    : localizations.reminderMarkDone,
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref
                    .read(ledgerServiceProvider)
                    .setReminderDone(reminder.id, !reminder.isCompleted);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: palette.overdue),
              textColor: palette.overdue,
              title: Text(localizations.actionDelete),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(ledgerServiceProvider).deleteReminder(reminder.id);
                AppFeedback.info(context, localizations.recordDeleted);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// Creates or edits a standalone reminder.
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen({this.reminderId, super.key});

  final String? reminderId;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  DateTime _dueAt = dateOnly(DateTime.now());
  bool _initialised = false;
  bool _busy = false;

  bool get _isEditing => widget.reminderId != null;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    if (_isEditing) {
      final AsyncValue<Reminder?> reminder =
          ref.watch(reminderByIdProvider(widget.reminderId!));
      return AsyncValueView<Reminder?>(
        value: reminder,
        onRetry: () =>
            ref.invalidate(reminderByIdProvider(widget.reminderId!)),
        loading: Scaffold(appBar: AppBar(), body: const ListSkeleton(rows: 4)),
        isEmpty: (Reminder? value) => value == null,
        empty: Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(localizations.recordDeleted)),
        ),
        builder: (BuildContext context, Reminder? data) {
          if (data == null) return const SizedBox.shrink();
          if (!_initialised) {
            _initialised = true;
            _title.text = data.title;
            _note.text = data.note ?? '';
            _dueAt = data.dueAt;
          }
          return _build(context);
        },
      );
    }
    return _build(context);
  }

  Widget _build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? localizations.reminderFormEdit : localizations.reminderNew,
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
              label: localizations.reminderTitleLabel,
              controller: _title,
              hint: localizations.reminderTitleHint,
              prefixIcon: Icons.notifications_none,
              autofocus: !_isEditing,
              maxLength: 200,
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                if ((value?.trim() ?? '').isEmpty) {
                  return localizations.validationRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DateField(
              label: localizations.fieldDueDate,
              value: _dueAt,
              icon: Icons.event_outlined,
              onChanged: (DateTime? value) {
                if (value != null) setState(() => _dueAt = value);
              },
            ),
            const SizedBox(height: AppSpacing.md),
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
          child: Text(
            _isEditing ? localizations.saveChanges : localizations.actionSave,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    final ReminderDraft draft = ReminderDraft(
      title: _title.text,
      dueAt: _dueAt,
      note: _note.text,
    );

    try {
      final LedgerService service = ref.read(ledgerServiceProvider);
      if (_isEditing) {
        await service.updateReminder(widget.reminderId!, draft);
      } else {
        await service.createReminder(draft);
      }
      if (!mounted) return;
      AppFeedback.info(context, localizations.reminderCreated);
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}
