import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/backup_providers.dart';
import '../../core/files/backup_folder_channel.dart';
import '../../core/files/backup_location.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/settings_tile.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/external_backup_service.dart';
import '../../domain/services/backup_format.dart';
import '../../domain/services/backup_progress.dart';
import '../../domain/services/backup_protection.dart';
import '../../domain/services/backup_validation.dart';
import '../../l10n/generated/app_localizations.dart';

/// Backup and restore, in one screen.
///
/// Three questions, in the order a person asks them: *is my data safe?* — the
/// answer is the card at the top, in words rather than in a log; *can I take a
/// copy?* — one button, and the copy goes wherever the user chooses; *can I come
/// back?* — restore from a file, with the file inspected and shown before
/// anything changes.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  /// What the app is doing right now, in the user's words — or null when it is
  /// doing nothing.
  ///
  /// This is not a percentage and not a timer: it is the name of the step the
  /// service says it reached. A copy of a small ledger finishes before the first
  /// step could be read, and then nothing is shown at all; a copy of a large one
  /// says "reading the records", then "computing the check digest", and so on,
  /// because those are the steps that are actually running.
  String? _working;

  bool get _busy => _working != null;

  /// Names the step that just started.
  void _reportStep(Object step) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final String? label = switch (step) {
      BackupStep.reading => localizations.backupStepReading,
      BackupStep.building => localizations.backupStepBuilding,
      BackupStep.hashing => localizations.backupStepHashing,
      BackupStep.writing => localizations.backupStepWriting,
      BackupStep.verifying => localizations.backupStepVerifying,
      BackupStep.retaining => localizations.backupStepRetaining,
      RestoreStep.reading => localizations.restoreStepReading,
      RestoreStep.decoding => localizations.restoreStepDecoding,
      RestoreStep.checking => localizations.restoreStepChecking,
      RestoreStep.validating => localizations.restoreStepValidating,
      RestoreStep.planning => localizations.restoreStepPlanning,
      RestoreStep.snapshot => localizations.restoreStepSnapshot,
      RestoreStep.writing => localizations.restoreStepWriting,
      RestoreStep.verifying => localizations.restoreStepVerifying,
      RestoreStep.rebuilding => localizations.restoreStepRebuilding,
      _ => null,
    };
    if (label == null || !mounted) return;
    setState(() => _working = label);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<BackupStatus> status = ref.watch(backupStatusProvider);
    final AsyncValue<BackupLocationHealth> folder =
        ref.watch(backupLocationHealthProvider);
    // The protection report folds the two above together. It is watched here
    // rather than replacing the status read, because the rest of the screen still
    // needs the raw counts — how many copies there are, whether the ledger has
    // anything in it — and re-deriving those from a folded state would be a
    // second source of truth for the same numbers.
    final BackupProtectionReport? protection =
        ref.watch(backupProtectionProvider).value;
    // The history is worth opening when either layer has something in it: the
    // app's own snapshots, or the user's folder. A folder with copies but no
    // internal snapshot yet is exactly the state after a reinstall, and hiding
    // the history then would hide the only copies there are.
    final BackupLocationHealth? folderHealth = folder.value;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.settingsBackup)),
      body: Stack(
        children: <Widget>[
          AsyncValueView<BackupStatus>(
            value: status,
            onRetry: () => ref.invalidate(backupStatusProvider),
            loading: const Center(child: CircularProgressIndicator()),
            builder: (BuildContext context, BackupStatus data) {
              // The history is worth opening when either layer has something in
              // it: the app's own snapshots, or the user's folder. A folder with
              // copies but no internal snapshot yet is exactly the state after a
              // reinstall, and hiding the history then would hide the only
              // copies there are.
              final bool hasHistory = data.snapshots > 0 ||
                  (folderHealth?.validBackups ?? 0) > 0;
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.massive,
            ),
            children: <Widget>[
              // The head of the screen is the answer to the question the user
              // arrived with. Everything below it is what they can do, and it is
              // deliberately second: when automatic saving is working, the app's
              // own advice is that there is nothing to do.
              if (protection != null)
                _ProtectionHeader(
                  report: protection,
                  primaryLabel: _primaryActionLabel(protection, localizations),
                  onPrimary: _primaryActionFor(protection),
                )
              else
                const SkeletonBox(height: 132),
              const SizedBox(height: AppSpacing.lg),
              _LocationSection(
                health: folder,
                onChoose: () => _chooseFolder(),
                onSetup: _showFolderSetup,
                onChange: () => _chooseFolder(),
                onCheck: () => _checkFolder(deep: true),
                onReauthorize: () => _chooseFolder(),
              ),
              // The engine's own verdict rather than a second guess at it:
              // `recoverable` means the ledger is empty and there is a copy
              // somewhere to put back. This condition used to be
              // `!hasLocalData && hasBackup`, and `hasBackup` only looks inside
              // the app — so a reinstall that found seven copies in the user's
              // own folder showed a headline saying a copy could be restored and
              // offered nothing to press. Found on the phone, on the recovery
              // path itself, which is the one path a reinstall has to walk.
              if (protection?.state == BackupProtection.recoverable) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _FoundBackupCard(
                  onRestore: () => _restoreFromFile(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              // The control says its own state in words as well as by position.
              // A switch alone makes the user read the answer off a piece of
              // furniture; the subtitle says "مفعّل" or "متوقف", and the footer
              // changes with it — because what the app does when it is off is a
              // different sentence, not the same one with a different switch
              // position. Neither sentence is alarming: off means no new copies,
              // not lost data, and it says so.
              SettingsSection(
                title: localizations.backupAutoTitle,
                footer: data.autoEnabled
                    ? localizations.backupAutoOnBody
                    : localizations.backupAutoOffBody,
                children: <Widget>[
                  SettingsSwitchTile(
                    title: localizations.backupAutoTitle,
                    subtitle: data.autoEnabled
                        ? localizations.backupAutoStateOn
                        : localizations.backupAutoStateOff,
                    icon: data.autoEnabled
                        ? Icons.autorenew
                        : Icons.pause_circle_outline,
                    value: data.autoEnabled,
                    onChanged: _busy ? null : _setAuto,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SettingsSection(
                title: localizations.settingsBackup,
                children: <Widget>[
                  // The two are different acts, and they are listed as such.
                  // Saving a file is how a backup leaves the app: the user picks
                  // the place, and the app writes and then verifies the document.
                  // Sharing asks another application to take a copy, which is
                  // convenient and is not the same thing — on some phones the
                  // share sheet has nowhere that keeps a file at all.
                  SettingsTile(
                    title: localizations.backupNowAction,
                    subtitle: localizations.backupSaveExternalBody,
                    icon: Icons.save_alt_outlined,
                    enabled: !_busy && data.hasLocalData,
                    onTap: _saveExternal,
                  ),
                  SettingsTile(
                    title: localizations.backupShareTile,
                    subtitle: localizations.backupShareTileBody,
                    icon: Icons.ios_share,
                    enabled: !_busy && data.hasLocalData,
                    onTap: _shareNow,
                  ),
                  SettingsTile(
                    title: localizations.backupRestoreAction,
                    icon: Icons.restore_outlined,
                    enabled: !_busy,
                    onTap: _restoreFromFile,
                  ),
                  SettingsTile(
                    title: localizations.backupPreviousAction,
                    icon: Icons.history,
                    // The number of copies, not a number of days. The row used
                    // the day-count plural, so four stored backups read as
                    // "4 أيام" — four *days* — on the row that leads to them.
                    valueText: localizations.backupCopiesCount(
                      data.snapshots + (folderHealth?.validBackups ?? 0),
                    ),
                    enabled: !_busy && hasHistory,
                    onTap: _showPrevious,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _PrivacyNote(),
              const SizedBox(height: AppSpacing.lg),
              _HowItProtects(),
            ],
          );
            },
          ),
          if (_working != null)
            _WorkingOverlay(
              key: const ValueKey<String>('backup-working'),
              label: _working!,
            ),
        ],
      ),
    );
  }

  /// The one action worth offering in this state, in the user's words.
  ///
  /// Deliberately narrow. The states where the screen already carries the action
  /// — no folder (the setup card), a folder that needs re-linking (its own row),
  /// a wiped device with a copy to put back (the found-copy card) — return null
  /// here, because two buttons for one act is clutter rather than emphasis. And
  /// `protected` returns null because the whole point of that state is that
  /// there is nothing to do.
  String? _primaryActionLabel(
    BackupProtectionReport report,
    AppLocalizations localizations,
  ) {
    return switch (report.state) {
      // Nothing has ever been saved and there is somewhere to save it to.
      BackupProtection.neverBackedUp when report.folderConfigured =>
        localizations.backupNowAction,
      // The app's own writes keep failing: the useful act is to look again.
      BackupProtection.storageIssue => localizations.backupFolderCheck,
      BackupProtection.attentionNeeded
          when report.consecutiveFailures > 0 &&
              report.folderConfigured =>
        localizations.backupFolderCheck,
      _ => null,
    };
  }

  VoidCallback? _primaryActionFor(BackupProtectionReport report) {
    final String? label = _primaryActionLabel(
      report,
      AppLocalizations.of(context),
    );
    if (label == null) return null;
    return switch (report.state) {
      BackupProtection.neverBackedUp => _saveExternal,
      _ => () => _checkFolder(deep: true),
    };
  }

  Future<void> _setAuto(bool enabled) async {
    setState(() => _working = AppLocalizations.of(context).backupAutoTitle);
    try {
      await ref.read(backupControllerProvider).setAutoEnabled(enabled);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  /// Offers the folder setup, as a first-run state rather than an error.
  Future<void> _showFolderSetup() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ChosenFolder? chosen = await showAppSheet<ChosenFolder>(
      context,
      child: _FolderSetupSheet(onChoose: _chooseFolder),
    );
    if (!mounted || chosen == null) {
      if (mounted) {
        AppFeedback.info(context, localizations.backupFolderLater);
      }
      return;
    }
    await _settleFolderChoice(chosen);
  }

  /// Chooses the folder from the settings row, and settles what was chosen.
  Future<void> _chooseFolder() async {
    if (_busy) return;
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _working = localizations.backupFolderVerifying);
    ChosenFolder? chosen;
    try {
      chosen = await ref.read(backupControllerProvider).chooseFolder();
    } on FolderException catch (error) {
      if (mounted) {
        setState(() => _working = null);
        AppFeedback.error(context, _folderProblemText(error, localizations));
      }
      return;
    } on Object {
      if (mounted) {
        setState(() => _working = null);
        AppFeedback.error(context, localizations.backupFolderError);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = null);
    if (chosen == null) return;
    await _settleFolderChoice(chosen);
  }

  /// What a chosen folder turns into: a confirmation when the app could not
  /// make `Dhimmah Backups` inside it, otherwise just the card updating.
  Future<void> _settleFolderChoice(ChosenFolder chosen) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (chosen.disposition == FolderDisposition.needsConfirmation) {
      final bool? useIt = await showAppSheet<bool>(
        context,
        child: AppSheet(
          title: localizations.backupFolderConfirmTitle,
          subtitle: localizations.backupFolderConfirmBody,
          primaryLabel: localizations.backupFolderUseIt,
          onPrimary: () => Navigator.of(context).pop(true),
          secondaryLabel: localizations.backupFolderDecline,
          onSecondary: () => Navigator.of(context).pop(false),
          child: const SizedBox.shrink(),
        ),
      );
      if (!mounted) return;
      if (useIt != true) {
        await ref.read(backupControllerProvider).forgetFolder();
        await _chooseFolder();
        return;
      }
    }
    ref.invalidate(backupLocationHealthProvider);
    AppFeedback.info(context, localizations.backupFolderAvailable);
  }

  /// Checks the folder, deeply or not, and says what it found.
  Future<void> _checkFolder({required bool deep}) async {
    if (_busy) return;
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _working = localizations.backupFolderVerifying);
    try {
      final BackupLocationHealth health =
          await ref.read(backupControllerProvider).checkFolder(deep: deep);
      if (!mounted) return;
      switch (health.status) {
        case BackupLocationStatus.available:
          AppFeedback.info(
            context,
            localizations.backupFolderBackupsCount(health.validBackups),
          );
        case BackupLocationStatus.readOnly:
          AppFeedback.error(context, localizations.backupFolderNotWritable);
        case BackupLocationStatus.permissionRevoked:
          AppFeedback.error(context, localizations.backupFolderMissing);
        default:
          // The app's own sentence, never the platform's. `health.detail` is
          // what the provider said, and what it says is programmer prose — on
          // the phone it read "Failed to determine if primary:Documents/Dhimmah
          // Backups is child of primary:Documents: java.io.FileNotFoundException…"
          // in English, in a message box, under an Arabic screen.
          AppFeedback.error(context, localizations.backupFolderError);
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  /// Saves a verified copy into a file the user chooses.
  ///
  /// Every ending is stated: a document that was written and read back is
  /// reported as saved, a document that was not is reported with the reason, and
  /// a user who changed their mind at the chooser is told nothing at all —
  /// cancelling is an answer, not a failure.
  Future<void> _saveExternal() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    _reportStep(BackupStep.reading);
    final ExternalSaveReport report;
    try {
      report = await ref
          .read(backupControllerProvider)
          .saveExternal(onStep: _reportStep);
    } on Object {
      if (mounted) {
        setState(() => _working = null);
        AppFeedback.error(context, localizations.backupExternalFailedWrite);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = null);

    switch (report.outcome) {
      case ExternalSaveOutcome.needsFolder:
        // Nothing has gone wrong: there is simply no folder yet. This is the
        // first-run state, and it is offered as such.
        await _showFolderSetup();
        break;
      case ExternalSaveOutcome.cancelled:
        return;
      case ExternalSaveOutcome.failed:
        AppFeedback.error(
          context,
          _saveProblemText(report.problem!, localizations),
        );
        break;
      case ExternalSaveOutcome.saved:
        await showAppSheet<void>(
          context,
          child: _ExternalSavedSheet(report: report),
        );
    }
  }

  /// Sends a copy to another application. The convenience, not the backup.
  Future<void> _shareNow() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    _reportStep(BackupStep.reading);
    try {
      await ref.read(backupControllerProvider).shareNow(onStep: _reportStep);
      if (!mounted) return;
      AppFeedback.info(context, localizations.backupCreated);
    } on Object {
      if (!mounted) return;
      AppFeedback.error(context, localizations.backupCreateFailed);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  /// Restoring from a file the user picks.
  Future<void> _restoreFromFile() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    _reportStep(RestoreStep.reading);
    final InspectedBackup? inspected;
    try {
      inspected = await ref
          .read(backupControllerProvider)
          .pickAndInspect(onStep: _reportStep);
    } on Object {
      if (mounted) {
        setState(() => _working = null);
        AppFeedback.error(context, localizations.backupRestoreFailed);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = null);
    if (inspected == null) return; // The user closed the picker.
    await _restoreInspected(inspected);
  }

  /// Restoring a copy the app can reach itself — an internal snapshot, or a
  /// document in the backup folder.
  ///
  /// This is the recovery path that used to be missing: the app kept complete,
  /// verified snapshots, and the only way back from one was to go and find a
  /// file in the system picker. Now one press inspects the copy and shows the
  /// same preview, the same modes, and the same safety rules as a picked file.
  Future<void> _restoreInternal(BackupFileInfo info) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _working = localizations.restoreStepReading);
    final InspectedBackup? inspected;
    try {
      inspected = await ref
          .read(backupControllerProvider)
          .inspectInternal(info, onStep: _reportStep);
    } on Object {
      if (mounted) {
        setState(() => _working = null);
        AppFeedback.error(context, localizations.backupRestoreFailed);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = null);
    if (inspected == null) return; // The copy could not be read at all.
    await _restoreInspected(inspected);
  }

  /// Restoring a copy that lives in the user's folder.
  Future<void> _restoreExternal(ExternalBackupFile file) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _working = localizations.restoreStepReading);
    final InspectedBackup? inspected;
    try {
      inspected = await ref
          .read(backupControllerProvider)
          .inspectExternal(file, onStep: _reportStep);
    } on Object {
      if (mounted) {
        setState(() => _working = null);
        AppFeedback.error(context, localizations.backupRestoreFailed);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _working = null);
    if (inspected == null) return; // The copy could not be read at all.
    await _restoreInspected(inspected);
  }

  /// The one restore flow every source goes through: preview, mode, apply.
  ///
  /// A copy the app cannot vouch for is refused here with the reason, exactly
  /// as a picked file would be — the source changes nothing about the checks.
  Future<void> _restoreInspected(InspectedBackup inspected) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!inspected.canRestore) {
      AppFeedback.error(context, _problemText(inspected, localizations));
      return;
    }
    final _RestoreChoice? choice = await showAppSheet<_RestoreChoice>(
      context,
      child: _RestoreSheet(inspected: inspected),
    );
    if (choice == null || !mounted) return;

    _reportStep(RestoreStep.planning);
    try {
      final RestoreReport report = await ref
          .read(backupControllerProvider)
          .apply(inspected: inspected, mode: choice.mode, onStep: _reportStep);
      if (!mounted) return;
      await showAppSheet<void>(context, child: _RestoreResultSheet(report: report));
      if (!mounted) return;
      // The ledger under every other screen is different now.
      ref
        ..invalidate(backupStatusProvider)
        ..invalidate(backupLocationHealthProvider);
    } on BackupFormatException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, _problemText(error, localizations));
    } on Object {
      if (!mounted) return;
      AppFeedback.error(context, localizations.backupRestoreFailed);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _showPrevious() async {
    final BackupController controller = ref.read(backupControllerProvider);
    final (List<BackupFileInfo>, List<ExternalBackupFile>) initial =
        await _bothHistories();
    if (!mounted) return;
    await showAppSheet<void>(
      context,
      child: _PreviousSheet(
        internal: initial.$1,
        external: initial.$2,
        load: _bothHistories,
        onShare: (BackupFileInfo info) => controller.share(info),
        onDelete: (BackupFileInfo info) async {
          await controller.delete(info);
          if (!mounted) return;
          AppFeedback.info(context, AppLocalizations.of(context).backupDeleted);
        },
        onDeleteExternal: (ExternalBackupFile file) async {
          await controller.deleteExternal(file);
          if (!mounted) return;
          AppFeedback.info(
            context,
            AppLocalizations.of(context).backupExternalDeleted,
          );
        },
        onRestoreInternal: (BackupFileInfo info) async {
          // The sheet closes first: the restore covers the screen while it
          // runs, and a history sheet underneath it would only be in the way.
          Navigator.of(context).pop();
          await _restoreInternal(info);
        },
        onRestoreExternal: (ExternalBackupFile file) async {
          Navigator.of(context).pop();
          await _restoreExternal(file);
        },
      ),
    );
    if (mounted) {
      ref
        ..invalidate(backupStatusProvider)
        ..invalidate(backupLocationHealthProvider);
    }
  }

  /// Both layers, side by side: the app's own snapshots and the user's folder.
  ///
  /// They are read together because the sheet shows them together, and the
  /// folder is read fresh every time — it is the authority on what is in it.
  Future<(List<BackupFileInfo>, List<ExternalBackupFile>)> _bothHistories() async {
    final List<BackupFileInfo> internal =
        await ref.read(backupServiceProvider).list();
    List<ExternalBackupFile> external = const <ExternalBackupFile>[];
    try {
      external = await ref.read(backupControllerProvider).externalBackups();
    } on FolderException {
      // An unreachable folder leaves the folder section empty rather than
      // blocking the history the user asked to see.
      external = const <ExternalBackupFile>[];
    }
    return (internal, external);
  }
}

/// What the app is doing, named, while the user waits.
///
/// It covers the screen because it must: a restore rewrites the ledger under
/// every other screen, and letting someone open a record mid-restore would show
/// them a state that is about to change. It has no percentage and no countdown —
/// there is no honest one to give — and no way to cancel, because abandoning a
/// restore halfway is not a thing this app does: the transaction either commits
/// or it does not.
class _WorkingOverlay extends StatelessWidget {
  const _WorkingOverlay({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Positioned.fill(
      child: ColoredBox(
        color: palette.overlay,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: palette.surfaceRaised,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Is my data safe?", answered in one card.
///
/// The screen is built around this rather than around its buttons, because the
/// question is the one the user came with. Everything they can *do* is below it
/// and secondary: with automatic saving working, the app's own advice is that
/// there is nothing to do.
///
/// The card says three things and no more: the state, when the data last reached
/// a readable file, and where the copies are. Anything further is behind
/// [localizations.backupProtectionDetails], because a screen that shows every
/// number it has is a screen that has decided the user is the one who has to
/// work out what they mean.
class _ProtectionHeader extends StatefulWidget {
  const _ProtectionHeader({required this.report, this.primaryLabel, this.onPrimary});

  final BackupProtectionReport report;

  /// The one thing worth doing in this state, when there is one.
  ///
  /// Null in the states where the screen already offers the action further down
  /// — choosing a folder, re-linking one, restoring a found copy. A second
  /// button for the same act is not emphasis, it is clutter, and the brief for
  /// this screen is one clear action per state.
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  State<_ProtectionHeader> createState() => _ProtectionHeaderState();
}

class _ProtectionHeaderState extends State<_ProtectionHeader> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppFormatting formatting = context.formatting;
    final BackupProtectionReport report = widget.report;

    final (IconData icon, Color color, String headline) = switch (report.state) {
      BackupProtection.protected => (
          Icons.verified_outlined,
          palette.settled,
          localizations.backupProtectionProtected,
        ),
      BackupProtection.pending => (
          Icons.schedule_outlined,
          // Not the warning colour. Changes waiting to be saved is where this
          // screen spends most of its life — it is what being in the app looks
          // like between an edit and the next snapshot — so painting it amber
          // tells the user something is wrong every time they change a record.
          // The words carry it: they say the work is waiting, not lost.
          palette.brand,
          localizations.backupProtectionPending,
        ),
      BackupProtection.backingUp => (
          Icons.autorenew,
          palette.brand,
          localizations.backupProtectionBackingUp,
        ),
      BackupProtection.recoverable => (
          Icons.restore_outlined,
          palette.brand,
          localizations.backupProtectionRecoverable,
        ),
      BackupProtection.noLocation => (
          Icons.folder_off_outlined,
          palette.dueSoon,
          localizations.backupProtectionNoLocation,
        ),
      BackupProtection.automaticOff => (
          Icons.pause_circle_outline,
          palette.dueSoon,
          localizations.backupProtectionAutoOff,
        ),
      BackupProtection.storageIssue => (
          Icons.sd_card_alert_outlined,
          palette.overdue,
          localizations.backupProtectionStorage,
        ),
      BackupProtection.attentionNeeded => (
          Icons.error_outline,
          palette.overdue,
          localizations.backupProtectionAttention,
        ),
      BackupProtection.neverBackedUp => (
          Icons.gpp_maybe_outlined,
          palette.overdue,
          localizations.backupProtectionNever,
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(headline, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            report.lastSuccess == null
                ? localizations.backupProtectionNeverWorked
                : localizations.backupProtectionLastSuccess(
                    formatting.date(report.lastSuccess!),
                  ),
            // A fact, not a second heading. It was `titleSmall` — 15pt semibold,
            // the same weight as the headline two points below it — and the card
            // read as two titles stacked, the eye with no ladder to climb. Body
            // weight in the secondary colour puts it where it belongs: under the
            // state, over the counts.
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // Joined by a separator rather than a space: "5 copies inside the
            // app 7 in your folder" reads as one long number when it is only
            // spacing that divides them.
            '${localizations.backupProtectionCopiesInside(report.appCopies)}'
            ' · '
            '${localizations.backupProtectionCopiesOutside(report.folderCopies)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
          // A failure the app can still handle says the one thing the user
          // actually fears, before anything else on the screen has a chance to
          // imply the opposite.
          if (report.state == BackupProtection.attentionNeeded ||
              report.state == BackupProtection.storageIssue) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.backupProtectionDataSafe,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ],
          if (widget.primaryLabel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: widget.onPrimary,
                child: Text(widget.primaryLabel!),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _open = !_open),
              // The label lines up with the headline's icon. A text button's own
              // padding pushed it a few points in from the card's edge, which on
              // a card this narrow is the difference between a column and a
              // near-miss; the tap target is untouched, so it is still 48 tall.
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
                alignment: AlignmentDirectional.centerStart,
              ),
              child: Text(
                _open
                    ? localizations.backupProtectionHideDetails
                    : localizations.backupProtectionDetails,
              ),
            ),
          ),
          if (_open) ..._details(context, localizations, palette, theme, report),
        ],
      ),
    );
  }

  /// The depth, for the user who opens it.
  ///
  /// Five facts, each in words rather than codes: whether the app is saving on
  /// its own, when it last managed it, how many copies are restorable, whether
  /// changes are waiting, and whether the folder is reachable. No URIs, no
  /// providers, no checksums — those live in the app's own diagnostics, not on a
  /// screen somebody opened to feel reassured.
  ///
  /// "When the last copy was made" and "when the last change was saved" are the
  /// same moment in this design, so they are one line rather than two: a copy is
  /// a snapshot of everything up to its own instant, which is what makes it
  /// restorable. Two rows printing the same timestamp would be padding.
  List<Widget> _details(
    BuildContext context,
    AppLocalizations localizations,
    AppPalette palette,
    ThemeData theme,
    BackupProtectionReport report,
  ) {
    final AppFormatting formatting = context.formatting;
    return <Widget>[
      const Divider(height: AppSpacing.lg),
      _DetailRow(
        label: localizations.backupDetailAutomatic,
        // The value alone, not the sentence: the label beside it already says
        // "automatic saving", and the first version of this row read
        // "automatic saving: automatic saving is on".
        value: report.autoEnabled
            ? localizations.backupAutoStateOn
            : localizations.backupAutoStateOff,
        tone: report.autoEnabled ? null : palette.dueSoon,
      ),
      _DetailRow(
        label: localizations.backupDetailLastCopy,
        value: report.lastSuccess == null
            ? localizations.backupProtectionNeverWorked
            : formatting.date(report.lastSuccess!),
      ),
      _DetailRow(
        label: localizations.backupDetailRestorable,
        value: localizations.backupCopiesCount(report.copies),
      ),
      // Both of these rows used to borrow a headline as their label, so the row
      // read "changes are waiting to be saved: 3 records are waiting to be
      // saved", and the failure row read "backups need your attention: the
      // backup could not be made 3 times" — a sentence in the label column of a
      // column that is a third of the width, wrapping to three lines beside a
      // value that says the same thing again. Labels label.
      if (report.pendingChanges > 0)
        _DetailRow(
          label: localizations.backupDetailPending,
          value: localizations.backupProtectionWaiting(report.pendingChanges),
        ),
      _DetailRow(
        label: localizations.backupDetailFolder,
        value: report.folderConfigured
            ? localizations.backupFolderAvailable
            : localizations.backupProtectionFolderNone,
        tone: report.folderConfigured ? null : palette.dueSoon,
      ),
      if (report.lastFailure != null)
        _DetailRow(
          label: localizations.backupDetailAttempts,
          value: localizations.backupProtectionFailedTimes(
            report.consecutiveFailures,
          ),
          tone: palette.overdue,
        ),
    ];
  }
}

/// One line of the protection details.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Equal columns rather than a third and two thirds. The values here
          // are short — a date, a count, a word — and the labels are Arabic
          // phrases, so the old split gave the narrow side to the long text and
          // `نسخ قابلة للاستعادة` broke across two lines in the middle of a
          // phrase while the value beside it sat in space it did not need.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone ?? palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when there is nothing on this device but a copy exists.
class _FoundBackupCard extends StatelessWidget {
  const _FoundBackupCard({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.backupFoundTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.backupFoundBody,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRestore,
              child: Text(localizations.backupRestoreAction),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the app promises about backups, in plain sentences.
///
/// Sits at the foot of the screen, where an explanation belongs: present for the
/// user who wants to know what "protected" is based on, and out of the way for
/// the one who does not. No jargon, no percentages, no "military-grade" — each
/// sentence is a claim the code actually keeps.
class _HowItProtects extends StatelessWidget {
  const _HowItProtects();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    // Aligned with the section headings above and with the privacy note below:
    // those sit on the list's edge plus the heading inset, and this one did not,
    // so the two foot sections were four points apart from each other on a
    // screen where everything else lines up.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.backupProtectionHowTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.backupProtectionHowBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
/// The truth about where a copy lives, in three sentences.
class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.backupPrivacyTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.backupPrivacyBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.backupSeparateFromExport,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the user chose in the preview.
class _RestoreChoice {
  const _RestoreChoice(this.mode);

  final RestoreMode mode;
}

/// The preview: what is in the file, what will happen, and the two ways to do it.
class _RestoreSheet extends StatefulWidget {
  const _RestoreSheet({required this.inspected});

  final InspectedBackup inspected;

  @override
  State<_RestoreSheet> createState() => _RestoreSheetState();
}

class _RestoreSheetState extends State<_RestoreSheet> {
  RestoreMode _mode = RestoreMode.replace;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final AppFormatting formatting = context.formatting;
    final BackupPreview? preview = widget.inspected.preview;

    if (!widget.inspected.canRestore || preview == null) {
      return AppSheet(
        title: localizations.backupRestoreTitle,
        primaryLabel: localizations.actionClose,
        onPrimary: () => Navigator.of(context).pop(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              // The whole inspection, not just its verdict list: the reason is
              // in the code the validation carries, and only `_problemText` can
              // turn that into the sentence the user needs — "this is not a
              // Dhimmah backup" rather than "invalid or corrupted".
              _problemText(widget.inspected, localizations),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      );
    }

    return AppSheet(
      title: localizations.backupRestoreTitle,
      subtitle: localizations.backupRestoreQuestion,
      primaryLabel: localizations.backupRestoreConfirm,
      onPrimary: () => Navigator.of(context).pop(_RestoreChoice(_mode)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${localizations.backupRestoreFrom} '
            '${preview.createdAt == null ? '' : formatting.date(preview.createdAt!)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.backupRestoreCounts(
              preview.people,
              preview.debts,
              preview.payments,
            ),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            localizations.backupRestoreMore(
              preview.obligations,
              preview.reminders,
              preview.links,
            ),
            style: theme.textTheme.bodySmall,
          ),
          if (preview.newestChangeAt != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.backupRestoreLastChange(
                formatting.date(preview.newestChangeAt!),
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (preview.currencies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              localizations.backupRestoreCurrencies(
                preview.currencies
                  .map((AppCurrency currency) => currency.code)
                  .join(' · '),
                preview.currencies.length,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            localizations.backupRestoreMode,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModeOption(
            selected: _mode == RestoreMode.replace,
            title: localizations.backupModeReplace,
            body: localizations.backupModeReplaceBody,
            onTap: () => setState(() => _mode = RestoreMode.replace),
          ),
          const SizedBox(height: AppSpacing.sm),
          _ModeOption(
            selected: _mode == RestoreMode.merge,
            title: localizations.backupModeMerge,
            body: localizations.backupModeMergeBody,
            onTap: () => setState(() => _mode = RestoreMode.merge),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            localizations.backupRestoreSafetyNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.backupRestoreUnencrypted,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.selected,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.rMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selected ? palette.brand : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(body, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Shown only after the document was written **and read back and verified**.
///
/// There is no version of this sheet for a hopeful copy: when the verification
/// did not pass the screen shows a failure instead, so "saved and verified" is
/// never said about a file that was not read again.
class _ExternalSavedSheet extends StatelessWidget {
  const _ExternalSavedSheet({required this.report});

  final ExternalSaveReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final BackupPreview? preview = report.preview;

    return AppSheet(
      title: localizations.backupExternalSaved,
      primaryLabel: localizations.actionClose,
      onPrimary: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.backupExternalSavedBody(
              report.displayName ?? '',
              fmtBytes(report.bytes),
            ),
            style: theme.textTheme.titleSmall,
          ),
          if (preview != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.backupRestoreSummary(
                preview.counts['people'] ?? 0,
                preview.counts['debts'] ?? 0,
                preview.counts['payments'] ?? 0,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            // The honest limit of what was just proven: this file was read back
            // and checked now. Whether it is there next year is the user's
            // business, because it lives where they put it.
            localizations.backupPrivacyBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}


/// The user's backup folder, and how it is right now.
///
/// This is where the two layers stay visibly separate: the card above is about
/// the copies inside the app, and this one is about the folder the user owns.
/// Its state is a fact about the folder *now*, checked when the screen opens,
/// and the actions on it are the ones that change that fact.
class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.health,
    required this.onChoose,
    required this.onSetup,
    required this.onChange,
    required this.onCheck,
    required this.onReauthorize,
  });

  final AsyncValue<BackupLocationHealth> health;
  final VoidCallback onChoose;
  final VoidCallback onSetup;
  final VoidCallback onChange;
  final VoidCallback onCheck;
  final VoidCallback onReauthorize;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return switch (health) {
      AsyncData<BackupLocationHealth>(:final BackupLocationHealth value) =>
        _locationBody(context, value, palette),
      AsyncError<BackupLocationHealth>() => _Row(
          icon: Icons.folder_off_outlined,
          title: localizations.backupFolderTitle,
          value: localizations.backupFolderMissing,
          action: localizations.backupFolderReauthorize,
          onAction: onReauthorize,
        ),
      _ => const _Row(
          icon: Icons.folder_outlined,
          title: null,
          value: null,
          action: null,
          onAction: null,
        ),
    };
  }

  Widget _locationBody(
    BuildContext context,
    BackupLocationHealth value,
    AppPalette palette,
  ) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    if (value.status == BackupLocationStatus.notConfigured) {
      // First use. The state is offered as a place to set up, not as a failure,
      // because nothing has gone wrong yet.
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.folder_outlined, size: 20, color: palette.textTertiary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    localizations.backupFolderSetupTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.backupFolderSetupBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onChoose,
              child: Text(localizations.backupFolderChoose),
            ),
          ],
        ),
      );
    }

    // A folder that cannot be used right now is a row with the way back on it,
    // not a card that only states the problem.
    if (value.status == BackupLocationStatus.permissionRevoked ||
        value.status == BackupLocationStatus.unavailable) {
      return _Row(
        icon: Icons.folder_off_outlined,
        title: localizations.backupFolderTitle,
        // In the user's words. This row used to fall back to the platform's
        // own message, so the screen explained the problem with the provider's
        // exception text — a URI and a Java class name — and said nothing about
        // what the person reading it could do.
        value: localizations.backupFolderLostAccess,
        action: localizations.backupFolderReauthorize,
        onAction: onReauthorize,
      );
    }

    final (String status, Color statusColor) = switch (value.status) {
      BackupLocationStatus.available => (
          localizations.backupFolderAvailable,
          palette.brand,
        ),
      BackupLocationStatus.readOnly => (
          localizations.backupFolderNotWritable,
          palette.dueSoon,
        ),
      BackupLocationStatus.configured ||
      BackupLocationStatus.verifying => (
          localizations.backupFolderVerifying,
          palette.textTertiary,
        ),
      _ => (
          // Same reason as the row above: the card states the problem in the
          // app's words, and the provider's message stays in the diagnostics.
          localizations.backupFolderError,
          palette.dueSoon,
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.folder_outlined, size: 20, color: statusColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  localizations.backupFolderTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value.validBackups == 0
                ? localizations.backupFolderEmpty
                : localizations.backupFolderBackupsCount(value.validBackups),
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
          if (value.invalidFiles > 0) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              localizations.backupFolderInvalidNote(value.invalidFiles),
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.dueSoon,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onChange,
                  child: Text(localizations.backupFolderChange),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCheck,
                  child: Text(localizations.backupFolderCheck),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One row of the location section, used for the states that have no card.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.value,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String? title;
  final String? value;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: palette.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title ?? localizations.backupFolderTitle,
                    style: theme.textTheme.titleSmall),
                if (value != null)
                  Text(
                    value!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// The first-run setup, offered when a save is asked for with no folder yet.
class _FolderSetupSheet extends StatelessWidget {
  const _FolderSetupSheet({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return AppSheet(
      title: localizations.backupFolderSetupTitle,
      primaryLabel: localizations.backupFolderChoose,
      onPrimary: () => onChoose(),
      secondaryLabel: localizations.backupFolderLater,
      onSecondary: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.backupFolderSetupBody,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.backupFolderTitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the restore did, and what it left for the user to look at.
class _RestoreResultSheet extends StatelessWidget {
  const _RestoreResultSheet({required this.report});

  final RestoreReport report;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return AppSheet(
      title: localizations.backupRestoreDone,
      primaryLabel: localizations.backupRestoreContinue,
      onPrimary: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localizations.backupRestoreSummary(
              report.counts['people'] ?? 0,
              report.counts['debts'] ?? 0,
              report.counts['payments'] ?? 0,
            ),
            style: theme.textTheme.titleSmall,
          ),
          if (report.skipped > 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.backupRestoreSkipped(report.skipped),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (report.hasConflicts) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.backupRestoreConflictsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.dueSoon,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              localizations.backupRestoreConflictsBody(report.conflicts.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (report.safetyBackupPath != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.backupRestoreSafetyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The snapshots on the device, newest first, kept in step with the files.
///
/// This used to be stateless, handed a list that had been read *before* the
/// sheet opened. Deleting a file invalidated the provider the screen behind it
/// watches, so the file was gone while the sheet went on showing it — until the
/// user closed and reopened the sheet, which read the list again. That is the
/// defect this state exists to remove: after a confirmed delete the sheet asks
/// the source of truth for the list, while it is still open.
class _PreviousSheet extends StatefulWidget {
  const _PreviousSheet({
    required this.internal,
    required this.external,
    required this.onShare,
    required this.onDelete,
    required this.onDeleteExternal,
    required this.onRestoreInternal,
    required this.onRestoreExternal,
    required this.load,
  });

  /// What the caller already has, so the sheet opens without a second read.
  final List<BackupFileInfo> internal;
  final List<ExternalBackupFile> external;

  final Future<void> Function(BackupFileInfo info) onShare;
  final Future<void> Function(BackupFileInfo info) onDelete;
  final Future<void> Function(ExternalBackupFile file) onDeleteExternal;

  /// Restoring: one press on a copy the app can reach itself.
  final Future<void> Function(BackupFileInfo info) onRestoreInternal;
  final Future<void> Function(ExternalBackupFile file) onRestoreExternal;

  /// Re-reads both layers from their own sources, while the sheet is open.
  final Future<(List<BackupFileInfo>, List<ExternalBackupFile>)> Function() load;

  @override
  State<_PreviousSheet> createState() => _PreviousSheetState();
}

class _PreviousSheetState extends State<_PreviousSheet> {
  late List<BackupFileInfo> _internal = widget.internal;
  late List<ExternalBackupFile> _external = widget.external;

  /// Deletes, then shows what is actually there.
  ///
  /// The deletion is reported by the service rather than assumed — if it fails,
  /// the entry stays — and the re-read decides the list either way. A file that
  /// had already gone is simply absent, which is the right outcome for a second
  /// delete of the same row.
  ///
  /// A failure is caught rather than allowed to escape: an exception thrown out
  /// of an `onPressed` reaches no one, so the row would stay put with no
  /// explanation. The list is reconciled first, then the failure is named — the
  /// re-read is the authority, and a deletion that reported a failure may still
  /// have removed the file.
  Future<void> _delete(BackupFileInfo info) async {
    Object? failure;
    try {
      await widget.onDelete(info);
    } on Object catch (error) {
      failure = error;
    }
    final (List<BackupFileInfo> internal, List<ExternalBackupFile> external) =
        await widget.load();
    if (!mounted) return;
    setState(() {
      _internal = internal;
      _external = external;
    });
    if (failure != null) {
      AppFeedback.error(context, AppLocalizations.of(context).backupDeleteFailed);
    }
  }

  /// The same rule for the user's folder, where the folder is the authority: a
  /// delete that reported failure may still have happened, and one that
  /// reported success may not have.
  Future<void> _deleteExternal(ExternalBackupFile file) async {
    Object? failure;
    try {
      await widget.onDeleteExternal(file);
    } on Object catch (error) {
      failure = error;
    }
    final (List<BackupFileInfo> internal, List<ExternalBackupFile> external) =
        await widget.load();
    if (!mounted) return;
    setState(() {
      _internal = internal;
      _external = external;
    });
    if (failure != null) {
      AppFeedback.error(
        context,
        AppLocalizations.of(context).backupExternalDeleteFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PreviousSheetBody(
      internal: _internal,
      external: _external,
      onShare: widget.onShare,
      onDelete: _delete,
      onDeleteExternal: _deleteExternal,
      onRestoreInternal: widget.onRestoreInternal,
      onRestoreExternal: widget.onRestoreExternal,
    );
  }
}

class _PreviousSheetBody extends StatelessWidget {
  const _PreviousSheetBody({
    required this.internal,
    required this.external,
    required this.onShare,
    required this.onDelete,
    required this.onDeleteExternal,
    required this.onRestoreInternal,
    required this.onRestoreExternal,
  });

  final List<BackupFileInfo> internal;
  final List<ExternalBackupFile> external;
  final Future<void> Function(BackupFileInfo info) onShare;
  final Future<void> Function(BackupFileInfo info) onDelete;
  final Future<void> Function(ExternalBackupFile file) onDeleteExternal;
  final Future<void> Function(BackupFileInfo info) onRestoreInternal;
  final Future<void> Function(ExternalBackupFile file) onRestoreExternal;

  /// One copy in the user's folder, described the way a person reads it.
  ///
  /// The date shown is the one inside the file, not the one the filesystem
  /// reports: a copy that was moved or downloaded has a modification time that
  /// says when *that* happened, and the question a restore asks is when the data
  /// was captured.
  Widget _externalRow(BuildContext context, ExternalBackupFile file) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppFormatting formatting = context.formatting;
    final DateTime? when = file.createdAt ?? file.modifiedAt;
    final bool unusable = file.validity == ExternalFileValidity.invalid ||
        file.validity == ExternalFileValidity.unrelated;
    final String kind = file.kind == null
        ? localizations.backupEntryManual
        : _kindName(file.kind!, localizations);

    return _HistoryRow(
      title: unusable ? localizations.backupRestoreInvalid : kind,
      detail: <String>[
        if (when != null) formatting.date(when),
        fmtBytes(file.sizeBytes),
      ].join(' · '),
      fileName: file.displayName,
      isLatest: identical(file, _newestExternal),
      isVerified: file.isValid,
      isUnusable: unusable,
      actions: unusable
          ? const <Widget>[]
          : <Widget>[
              IconButton(
                tooltip: localizations.backupRestoreAction,
                icon: const Icon(Icons.restore_outlined, size: 20),
                onPressed: () => onRestoreExternal(file),
              ),
              IconButton(
                tooltip: localizations.backupDeleteAction,
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => onDeleteExternal(file),
              ),
            ],
    );
  }

  /// The newest copy in the folder, so its row can say so.
  ExternalBackupFile? get _newestExternal {
    ExternalBackupFile? newest;
    for (final ExternalBackupFile file in external) {
      if (!file.isValid) continue;
      if (newest == null) {
        newest = file;
        continue;
      }
      final DateTime a = file.createdAt ?? file.modifiedAt ?? DateTime(0);
      final DateTime b = newest.createdAt ?? newest.modifiedAt ?? DateTime(0);
      if (a.isAfter(b)) newest = file;
    }
    return newest;
  }



  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppFormatting formatting = context.formatting;
    final AppPalette palette = context.palette;

    if (internal.isEmpty && external.isEmpty) {
      return AppSheet(
        title: localizations.backupPreviousTitle,
        primaryLabel: localizations.actionClose,
        onPrimary: () => Navigator.of(context).pop(),
        child: Text(localizations.backupPreviousEmpty),
      );
    }

    return AppSheet(
      title: localizations.backupPreviousTitle,
      primaryLabel: localizations.actionClose,
      onPrimary: () => Navigator.of(context).pop(),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (external.isNotEmpty) ...<Widget>[
              // The user's own folder comes first: these are the copies that
              // survive the app being deleted, and the ones restore looks in.
              Text(
                localizations.backupHistoryFolder,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final ExternalBackupFile file in external) ...<Widget>[
                _externalRow(context, file),
                const Divider(height: 1),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
            if (internal.isNotEmpty) ...<Widget>[
              Text(
                localizations.backupHistoryInternal,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final BackupFileInfo info in internal) ...<Widget>[
                _HistoryRow(
                  title: _kindLabel(info.kind, localizations),
                  detail:
                      '${formatting.date(info.createdAt)} · ${fmtBytes(info.sizeBytes)}',
                  isLatest: external.isEmpty && identical(info, internal.first),
                  actions: <Widget>[
                    IconButton(
                      tooltip: localizations.backupRestoreAction,
                      icon: const Icon(Icons.restore_outlined, size: 20),
                      onPressed: () => onRestoreInternal(info),
                    ),
                    IconButton(
                      tooltip: localizations.backupShareAction,
                      icon: const Icon(Icons.ios_share, size: 20),
                      onPressed: () => onShare(info),
                    ),
                    IconButton(
                      tooltip: localizations.backupDeleteAction,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => onDelete(info),
                    ),
                  ],
                ),
                const Divider(height: 1),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// One document in the user's folder.
///
/// There is no share button here on purpose: the file already lives where the
/// user put it, and sending a copy of it means copying it back into the app's
/// sandbox first. The file manager the user opened it from can share it
/// directly.
/// One copy in the history, described the way a person reads it.
///
/// The row used to lead with the file name — `dhimmah-manual-20260927T1431….dhimmah`
/// — which is a file listing, not a history: the user is choosing *when* to go
/// back to, and the kind of copy is what tells them why it exists. So the
/// headline is the kind, the second line is the date, the size and whether the
/// app checked it, and the file name is kept in small print underneath because
/// it is how the file is found in the user's own folder.
///
/// The newest copy is marked, because that is the one a restore normally wants
/// and making the user compare timestamps to find it is work the app can do.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.title,
    required this.detail,
    this.fileName,
    this.isLatest = false,
    this.isVerified = true,
    this.isUnusable = false,
    this.actions = const <Widget>[],
  });

  final String title;
  final String detail;

  /// Shown only where the user has a file of their own to find.
  final String? fileName;
  final bool isLatest;
  final bool isVerified;
  final bool isUnusable;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isUnusable ? palette.dueSoon : null,
                      ),
                    ),
                  ),
                  if (isLatest) ...<Widget>[
                    const SizedBox(width: AppSpacing.sm),
                    _Marker(localizations.backupHistoryLatest),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isVerified && !isUnusable
                    ? '$detail · ${localizations.backupHistoryVerified}'
                    : detail,
                style: theme.textTheme.bodySmall,
              ),
              if (fileName != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  fileName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// A quiet word beside a row — never a loud badge.
class _Marker extends StatelessWidget {
  const _Marker(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

String _folderProblemText(FolderException error, AppLocalizations localizations) =>
    switch (error.failure) {
      FolderFailure.unavailable => localizations.backupFolderMissing,
      FolderFailure.forbidden => localizations.backupFolderMissing,
      FolderFailure.readOnly => localizations.backupFolderNotWritable,
      FolderFailure.identifier => localizations.backupFolderError,
      FolderFailure.io => localizations.backupFolderError,
    };

/// Why an external save did not produce a verified file, in words a person can
/// act on — and never as the name of an enum.
String _saveProblemText(
  ExternalSaveProblem problem,
  AppLocalizations localizations,
) =>
    switch (problem) {
      ExternalSaveProblem.unavailable =>
        localizations.backupExternalFailedUnavailable,
      ExternalSaveProblem.write => localizations.backupExternalFailedWrite,
      ExternalSaveProblem.readBack => localizations.backupExternalFailedReadBack,
      ExternalSaveProblem.incomplete =>
        localizations.backupExternalFailedIncomplete,
      ExternalSaveProblem.invalid => localizations.backupExternalFailedInvalid,
    };

/// The envelope's own word for a kind, as the folder's files spell it out.
String _kindName(String kind, AppLocalizations localizations) => switch (kind) {
      'auto' => localizations.backupEntryAuto,
      'manual' => localizations.backupEntryManual,
      'safety' => localizations.backupEntrySafety,
      _ => kind,
    };

String _kindLabel(BackupKind kind, AppLocalizations localizations) =>
    switch (kind) {
      BackupKind.auto => localizations.backupEntryAuto,
      BackupKind.manual => localizations.backupEntryManual,
      BackupKind.safety => localizations.backupEntrySafety,
    };

/// A reason the user can act on, never a code.
String _problemText(Object problem, AppLocalizations localizations) {
  if (problem is InspectedBackup) {
    final BackupIssue? first =
        problem.validation.errors.isEmpty ? null : problem.validation.errors.first;
    return _codeText(first?.code, localizations);
  }
  if (problem is BackupFormatException) {
    return _codeText(problem.problem.name, localizations);
  }
  return localizations.backupRestoreInvalid;
}

String _codeText(String? code, AppLocalizations localizations) => switch (code) {
      'notADhimmahBackup' ||
      'notJson' ||
      'notAnObject' ||
      'unreadableEnvelope' ||
      'unreadablePayload' =>
        localizations.backupRestoreNotOurs,
      'formatTooNew' || 'schema_too_new' => localizations.backupRestoreTooNew,
      'encrypted' => localizations.backupRestoreUnencrypted,
      _ => localizations.backupRestoreInvalid,
    };

/// A file size the way a person reads it.
String fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
