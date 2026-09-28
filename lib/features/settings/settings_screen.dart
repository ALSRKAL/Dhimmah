import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/backup_providers.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/security/biometric_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/settings_tile.dart';
import '../../data/services/data_export_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/enums/preference_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import 'about_screen.dart';
import 'pin_sheet.dart';

/// Everything the user can change about Dhimmah.
///
/// Grouped the way the spec asks for it — appearance, notifications, security,
/// data, about — with each row stating its current value so the screen can be
/// read without opening anything.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppSettings settings = ref.watch(effectiveSettingsProvider);
    final SettingsController controller = ref.read(settingsControllerProvider);
    final AppPalette palette = context.palette;
    // Watched, not read: the user can change this in the system settings while
    // the app is in the background, and a footer that describes a stale phone is
    // worse than no footer.
    final bool notificationsDenied =
        (ref.watch(notificationPermissionProvider).value ??
                ref.watch(notificationServiceProvider).permission) ==
            NotificationPermission.denied;
    final AppVersion version =
        ref.watch(appVersionProvider).value ?? const AppVersion(name: '—', build: '—');

    return Scaffold(
      appBar: AppBar(title: Text(localizations.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.massive,
        ),
        children: <Widget>[
          SettingsSection(
            title: localizations.settingsAppearance,
            children: <Widget>[
              SettingsTile(
                title: localizations.settingsLanguage,
                icon: Icons.translate,
                valueText: settings.language.label(localizations),
                onTap: () => _pickLanguage(context, controller, settings),
              ),
              SettingsTile(
                title: localizations.settingsTheme,
                icon: settings.themeMode.icon,
                valueText: settings.themeMode.label(localizations),
                onTap: () => _pickTheme(context, controller, settings),
              ),
              SettingsTile(
                title: localizations.settingsNumerals,
                icon: Icons.pin_outlined,
                valueText: settings.numerals.label(localizations),
                onTap: () => _pickNumerals(context, controller, settings),
              ),
              SettingsTile(
                title: localizations.settingsCurrency,
                icon: Icons.payments_outlined,
                valueText:
                    '${settings.defaultCurrency.code} · ${settings.defaultCurrency.symbol}',
                onTap: () => _pickCurrency(context, controller, settings),
              ),
              SettingsTile(
                title: localizations.settingsDueSoonWindow,
                icon: Icons.hourglass_bottom_outlined,
                valueText: localizations.dateDayCount(settings.dueSoonWindowDays),
                onTap: () => _pickDueSoonWindow(context, controller, settings),
              ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsNotifications,
            footer: notificationsDenied ? localizations.notifPermissionDenied : null,
            children: <Widget>[
              SettingsSwitchTile(
                title: localizations.settingsRemindersEnabled,
                subtitle: localizations.settingsRemindersEnabledBody,
                icon: Icons.notifications_none,
                value: settings.notificationsEnabled,
                onChanged: (bool value) async {
                  if (value) {
                    final NotificationPermission permission = await ref
                        .read(notificationServiceProvider)
                        .requestPermission();
                    if (!context.mounted) return;
                    await controller.setNotificationsEnabled(
                      permission != NotificationPermission.denied,
                    );
                    return;
                  }
                  await controller.setNotificationsEnabled(false);
                },
              ),
              SettingsTile(
                title: localizations.settingsNotificationTime,
                subtitle: localizations.settingsReminderLead,
                icon: Icons.schedule_outlined,
                enabled: settings.notificationsEnabled,
                valueText: context.formatting.dates.time(
                  context,
                  settings.notificationHour,
                  settings.notificationMinute,
                ),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: settings.notificationHour,
                      minute: settings.notificationMinute,
                    ),
                  );
                  if (picked != null) {
                    await controller.setNotificationTime(picked.hour, picked.minute);
                  }
                },
              ),
              SettingsTile(
                title: localizations.settingsReminderLead,
                icon: Icons.notifications_active_outlined,
                enabled: settings.notificationsEnabled,
                valueText: settings.defaultReminderLeads.isEmpty
                    ? localizations.leadNone
                    : localizations.leadCount(settings.defaultReminderLeads.length),
                onTap: () => _pickDefaultLeads(context, controller, settings),
              ),
              SettingsSwitchTile(
                title: localizations.settingsMonthEnd,
                subtitle: localizations.settingsMonthEndBody,
                icon: Icons.insights_outlined,
                value: settings.monthEndSummaryEnabled,
                onChanged: controller.setMonthEndEnabled,
              ),
              if (settings.monthEndSummaryEnabled) ...<Widget>[
                SettingsTile(
                  title: localizations.settingsMonthEndDay,
                  icon: Icons.event_outlined,
                  valueText: settings.monthEndDay.label(localizations),
                  onTap: () => _pickMonthEndDay(context, controller, settings),
                ),
                SettingsTile(
                  title: localizations.settingsMonthEndTime,
                  icon: Icons.schedule_outlined,
                  valueText: context.formatting.dates.time(
                    context,
                    settings.monthEndHour,
                    settings.monthEndMinute,
                  ),
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: settings.monthEndHour,
                        minute: settings.monthEndMinute,
                      ),
                    );
                    if (picked != null) {
                      await controller.setMonthEndTime(picked.hour, picked.minute);
                    }
                  },
                ),
              ],
            ],
          ),
          SettingsSection(
            title: localizations.settingsSecurity,
            footer: settings.lockEnabled
                ? localizations.lockTitle
                : localizations.settingsAppLockBody,
            children: <Widget>[
              SettingsSwitchTile(
                title: localizations.settingsAppLock,
                subtitle: localizations.settingsAppLockBody,
                icon: Icons.lock_outline,
                value: settings.lockEnabled,
                onChanged: (bool value) =>
                    _toggleLock(context, ref, controller, value),
              ),
              SettingsSwitchTile(
                title: localizations.settingsBiometric,
                subtitle: localizations.settingsBiometricBody,
                icon: Icons.fingerprint,
                enabled: settings.lockEnabled,
                value: settings.biometricEnabled,
                onChanged: (bool value) =>
                    _toggleBiometric(context, ref, controller, value),
              ),
              if (settings.lockEnabled)
                SettingsTile(
                  title: localizations.settingsChangePin,
                  icon: Icons.password_outlined,
                  onTap: () => changePin(context, ref),
                ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsBackup,
            children: <Widget>[
              SettingsTile(
                title: localizations.settingsBackup,
                subtitle: localizations.backupSectionHint,
                icon: Icons.cloud_off_outlined,
                onTap: () => context.push(AppRoutes.backup),
              ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsData,
            children: <Widget>[
              SettingsTile(
                title: localizations.settingsExport,
                subtitle: localizations.settingsExportBody,
                icon: Icons.ios_share,
                onTap: () => _export(context, ref),
              ),
              SettingsTile(
                title: localizations.settingsAbout,
                subtitle: localizations.settingsPrivacyNote,
                icon: Icons.info_outline,
                onTap: () => context.push(AppRoutes.about),
              ),
              SettingsTile(
                title: localizations.settingsLicenses,
                icon: Icons.description_outlined,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: localizations.appName,
                  applicationLegalese: localizations.settingsAboutBody,
                ),
              ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsDangerZone,
            children: <Widget>[
              SettingsTile(
                title: localizations.settingsClearData,
                icon: Icons.delete_forever_outlined,
                destructive: true,
                onTap: () => _clearData(context, ref),
              ),
            ],
          ),
          Center(
            child: Text(
              localizations.appVersion(version.name, version.build),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: palette.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppLanguage? picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      builder: (BuildContext sheetContext) => OptionSheet<AppLanguage>(
        title: localizations.settingsLanguage,
        value: settings.language,
        options: AppLanguage.values,
        labelOf: (AppLanguage value) => value.label(localizations),
      ),
    );
    if (picked != null) await controller.setLanguage(picked);
  }

  Future<void> _pickTheme(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppThemeMode? picked = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (BuildContext sheetContext) => OptionSheet<AppThemeMode>(
        title: localizations.settingsTheme,
        value: settings.themeMode,
        options: AppThemeMode.values,
        labelOf: (AppThemeMode value) => value.label(localizations),
        iconOf: (AppThemeMode value) => value.icon,
      ),
    );
    if (picked != null) await controller.setThemeMode(picked);
  }

  Future<void> _pickNumerals(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final NumeralsStyle? picked = await showModalBottomSheet<NumeralsStyle>(
      context: context,
      builder: (BuildContext sheetContext) => OptionSheet<NumeralsStyle>(
        title: localizations.settingsNumerals,
        value: settings.numerals,
        options: NumeralsStyle.values,
        labelOf: (NumeralsStyle value) => value.label(localizations),
      ),
    );
    if (picked != null) await controller.setNumerals(picked);
  }

  Future<void> _pickCurrency(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppCurrency? picked = await showModalBottomSheet<AppCurrency>(
      context: context,
      builder: (BuildContext sheetContext) => OptionSheet<AppCurrency>(
        title: localizations.settingsCurrency,
        value: settings.defaultCurrency,
        options: AppCurrency.values,
        labelOf: (AppCurrency value) => '${value.code} · ${value.symbol}',
      ),
    );
    if (picked != null) await controller.setDefaultCurrency(picked);
  }

  Future<void> _pickDueSoonWindow(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    const List<int> options = <int>[3, 5, 7, 10, 14, 30];
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext sheetContext) => OptionSheet<int>(
        title: localizations.settingsDueSoonWindow,
        value: settings.dueSoonWindowDays,
        options: options,
        labelOf: (int value) => localizations.dateDayCount(value),
      ),
    );
    if (picked != null) await controller.setDueSoonWindow(picked);
  }

  Future<void> _pickDefaultLeads(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final List<ReminderLead>? picked =
        await showModalBottomSheet<List<ReminderLead>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => DefaultLeadsSheet(
        initial: settings.defaultReminderLeads,
      ),
    );
    if (picked != null) await controller.setDefaultReminderLeads(picked);
    if (!context.mounted) return;
    // localizations is read above to keep the sheet's strings in scope.
    assert(localizations.appName.isNotEmpty);
  }

  Future<void> _pickMonthEndDay(
    BuildContext context,
    SettingsController controller,
    AppSettings settings,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final MonthEndDay? picked = await showModalBottomSheet<MonthEndDay>(
      context: context,
      builder: (BuildContext sheetContext) => OptionSheet<MonthEndDay>(
        title: localizations.settingsMonthEndDay,
        value: settings.monthEndDay,
        options: MonthEndDay.values,
        labelOf: (MonthEndDay value) => value.label(localizations),
      ),
    );
    if (picked != null) await controller.setMonthEndDay(picked);
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    SettingsController controller,
    bool value,
  ) async {
    if (value) {
      final bool configured = await createPin(context, ref);
      if (!configured) return;
      await controller.setLockEnabled(true);
      return;
    }
    // Turning the lock off has to prove the user is the owner first, or the
    // setting would be a one-tap bypass of the PIN.
    final bool verified = await verifyPin(context, ref);
    if (!verified) return;
    await controller.setLockEnabled(false);
    await controller.setBiometricEnabled(false);
    await ref.read(pinServiceProvider).clear();
  }

  Future<void> _toggleBiometric(
    BuildContext context,
    WidgetRef ref,
    SettingsController controller,
    bool value,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!value) {
      await controller.setBiometricEnabled(false);
      return;
    }
    final BiometricService biometrics = ref.read(biometricServiceProvider);
    final BiometricAvailability availability = await biometrics.availability();
    if (!context.mounted) return;
    switch (availability) {
      case BiometricAvailability.available:
        final BiometricOutcome outcome = await biometrics.authenticate(
          reason: localizations.lockBiometricReason,
        );
        if (!context.mounted) return;
        switch (outcome) {
          case BiometricOutcome.success:
            await controller.setBiometricEnabled(true);
          // Dismissing the prompt is a decision, not an error. Saying "wrong
          // PIN" here — as this screen used to — blames the user for a PIN they
          // never typed.
          case BiometricOutcome.cancelled:
            break;
          case BiometricOutcome.unavailable:
            AppFeedback.error(context, localizations.biometricUnavailable);
        }
      case BiometricAvailability.notEnrolled:
        AppFeedback.error(context, localizations.biometricNotEnrolled);
      case BiometricAvailability.notSupported:
      case BiometricAvailability.unsupportedPlatform:
        AppFeedback.error(context, localizations.biometricUnavailable);
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ExportFormat? format = await showModalBottomSheet<ExportFormat>(
      context: context,
      builder: (BuildContext sheetContext) => ExportFormatSheet(),
    );
    if (format == null || !context.mounted) return;

    try {
      final String path =
          await ref.read(dataExportServiceProvider).export(format);
      if (!context.mounted) return;
      await ref.read(dataExportServiceProvider).share(path);
      await ref.read(ledgerServiceProvider).markExported();
      if (!context.mounted) return;
      AppFeedback.info(context, localizations.exportDone);
    } on Object {
      if (!context.mounted) return;
      AppFeedback.error(context, localizations.exportFailed);
    }
  }

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed = await AppFeedback.confirmDestructive(
      context,
      title: localizations.clearDataTitle,
      body: localizations.clearDataBody,
      confirmLabel: localizations.actionDelete,
    );
    if (!confirmed || !context.mounted) return;
    // A copy of what is about to be thrown away, made before it is thrown away.
    // The guard is freshness-based, so an automatic snapshot taken minutes ago is
    // enough and this costs nothing; when the newest copy is old, this is the one
    // that makes the action recoverable.
    try {
      await ref.read(backupControllerProvider).safetyBeforeDestructive();
    } on Object {
      // A snapshot that could not be taken must not become a reason the user
      // cannot clear their own data: the app would then be refusing an action
      // over a failure of its own bookkeeping.
    }
    if (!context.mounted) return;
    await ref.read(ledgerServiceProvider).clearAllData();
    if (!context.mounted) return;
    AppFeedback.info(context, localizations.recordDeleted);
  }
}

/// The reminder-lead multi-select, with an apply button.
class DefaultLeadsSheet extends StatefulWidget {
  const DefaultLeadsSheet({required this.initial, super.key});

  final List<ReminderLead> initial;

  @override
  State<DefaultLeadsSheet> createState() => _DefaultLeadsSheetState();
}

class _DefaultLeadsSheetState extends State<DefaultLeadsSheet> {
  late List<ReminderLead> _leads = widget.initial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return _sheetScaffold(
      context: context,
      title: localizations.settingsReminderLead,
      child: ReminderLeadsField(
        label: localizations.fieldReminder,
        selected: _leads,
        onChanged: (List<ReminderLead> leads) => setState(() => _leads = leads),
      ),
    );
  }

  Widget _sheetScaffold({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: child,
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_leads),
              child: Text(localizations.filterApply),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
