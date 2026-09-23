import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
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
          AppSpacing.massive,
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
                icon: Icons.insights_outlined,
                onTap: () => context.push(AppRoutes.reports),
              ),
              SettingsTile(
                title: localizations.navReminders,
                subtitle: localizations.remindersSubtitle,
                icon: Icons.notifications_none,
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
                icon: Icons.settings_outlined,
                onTap: () => context.push(AppRoutes.settings),
              ),
              SettingsTile(
                title: localizations.settingsAbout,
                subtitle: localizations.settingsPrivacyNote,
                icon: Icons.info_outline,
                onTap: () => context.push(AppRoutes.about),
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
                      Icons.cloud_off_outlined,
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
