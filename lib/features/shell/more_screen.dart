import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/dhimmah_logo.dart';
import '../../core/widgets/settings_tile.dart';
import '../../l10n/generated/app_localizations.dart';

/// The "More" tab: everything that is not one of the four daily destinations.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.moreTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.addButtonClearance + AppSpacing.lg,
        ),
        children: <Widget>[
          SettingsSection(
            // Not `navReminders`: that is the title of the row *inside* this
            // group, so the heading named the group after one of its members and
            // the card read as "Reminders: Reports, Reminders".
            title: localizations.moreFollowUpSection,
            children: <Widget>[
              SettingsTile(
                title: localizations.navReports,
                subtitle: localizations.reportsSubtitle,
                icon: AppIcons.insights,
                onTap: () => context.push(AppRoutes.reports),
              ),
              SettingsTile(
                title: localizations.navReminders,
                subtitle: localizations.remindersSubtitle,
                icon: AppIcons.notificationsNone,
                onTap: () => context.push(AppRoutes.reminders),
              ),
            ],
          ),
          SettingsSection(
            title: localizations.settingsTitle,
            children: <Widget>[
              SettingsTile(
                title: localizations.settingsTitle,
                subtitle: localizations.settingsAppearance,
                icon: AppIcons.settings,
                onTap: () => context.push(AppRoutes.settings),
              ),
              // "About" lived both here and in Settings. It stays in Settings
              // beside the privacy policy and the licences it belongs with;
              // this place goes to the backup, which is reached far more often
              // and was two screens deep.
              SettingsTile(
                title: localizations.settingsBackup,
                subtitle: localizations.backupSectionHint,
                icon: AppIcons.cloudOff,
                onTap: () => context.push(AppRoutes.backup),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: <Widget>[
                const DhimmahLogo(size: 44),
                const SizedBox(height: AppSpacing.md),
                Text(
                  localizations.appTagline,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      AppIcons.cloudOff,
                      size: 13,
                      color: palette.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      localizations.noInternetNeeded,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
