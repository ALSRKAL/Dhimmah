import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/dhimmah_logo.dart';
import '../../core/widgets/settings_tile.dart';
import '../../data/services/data_export_service.dart';
import '../../l10n/generated/app_localizations.dart';

/// About Dhimmah, and the export choices.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    // Async, so the screen draws immediately and the version fills in: reading
    // it blocks on a platform channel, and a settings page must not wait for it.
    final AppVersion version =
        ref.watch(appVersionProvider).value ?? const AppVersion(name: '—', build: '—');

    return Scaffold(
      appBar: AppBar(title: Text(localizations.settingsAbout)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.massive,
        ),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                const DhimmahLogo(size: 84),
                const SizedBox(height: AppSpacing.lg),
                Text(localizations.appName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.appTagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // The real version, from the installed package. It used to be a
                // hardcoded string, which is right until the first release and
                // then reports the wrong build to whoever is helping the user.
                Text(
                  localizations.appVersion(
                    version.name,
                    version.build,
                  ),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppCard(
            child: Column(
              children: <Widget>[
                Icon(Icons.verified_user_outlined, size: 22, color: palette.brand),
                const SizedBox(height: AppSpacing.md),
                Text(
                  localizations.brandPromise,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  localizations.settingsAboutBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SettingsSection(
            title: localizations.settingsPrivacyNote,
            children: <Widget>[
              SettingsTile(
                title: localizations.noInternetNeeded,
                subtitle: localizations.settingsPrivacyNote,
                icon: Icons.cloud_off_outlined,
              ),
              SettingsTile(
                title: localizations.settingsNotifications,
                subtitle: localizations.settingsRemindersEnabledBody,
                icon: Icons.notifications_none,
                valueText: _notificationLabel(context, ref, localizations),
              ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsExport,
            children: <Widget>[
              for (final ExportFormat format in ExportFormat.values)
                SettingsTile(
                  title: format == ExportFormat.json
                      ? localizations.exportJson
                      : localizations.exportCsv,
                  subtitle: format == ExportFormat.json
                      ? localizations.exportJsonBody
                      : localizations.exportCsvBody,
                  icon: format == ExportFormat.json
                      ? Icons.data_object
                      : Icons.table_chart_outlined,
                  onTap: () => _export(context, ref, format),
                ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsTitle,
            children: <Widget>[
              SettingsTile(
                title: localizations.settingsLicenses,
                icon: Icons.description_outlined,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: localizations.appName,
                  applicationVersion: localizations.appVersion(
                    version.name,
                    version.build,
                  ),
                  applicationLegalese: localizations.settingsAboutBody,
                ),
              ),
              SettingsTile(
                title: localizations.navSettings,
                icon: Icons.settings_outlined,
                onTap: () => context.push(AppRoutes.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _notificationLabel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations localizations,
  ) {
    return switch (ref.watch(notificationServiceProvider).permission) {
      NotificationPermission.granted => localizations.actionEnable,
      NotificationPermission.denied => localizations.actionDisable,
      NotificationPermission.unsupported => localizations.noInternetNeeded,
    };
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    ExportFormat format,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final DataExportService service = ref.read(dataExportServiceProvider);
      final String path = await service.export(format);
      await service.share(path);
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.exportDone)),
      );
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.exportFailed)),
      );
    }
  }
}

/// Picks which file format to export.
class ExportFormatSheet extends StatelessWidget {
  const ExportFormatSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                localizations.settingsExport,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SettingsTile(
            title: localizations.exportJson,
            subtitle: localizations.exportJsonBody,
            icon: Icons.data_object,
            onTap: () => Navigator.of(context).pop(ExportFormat.json),
          ),
          SettingsTile(
            title: localizations.exportCsv,
            subtitle: localizations.exportCsvBody,
            icon: Icons.table_chart_outlined,
            onTap: () => Navigator.of(context).pop(ExportFormat.csv),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
