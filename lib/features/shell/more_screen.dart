import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/backup_providers.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/dhimmah_logo.dart';
import '../../core/widgets/settings_tile.dart';
import '../../domain/entities/monthly_report.dart';
import '../../l10n/generated/app_localizations.dart';

/// The "More" tab: everything that is not one of the four daily destinations.
///
/// It opens with the month's movement, from the same report the Reports screen
/// reads, then two groups: what the user follows up on, and the app itself.
/// The backup row says when the last copy was made, because that is the
/// question the row is usually opened to answer.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final AppFormatting formatting = context.formatting;
    final DateTime today = ref.watch(todayProvider);
    final AppCurrency currency = _currency(ref);
    final MonthlyReport? report = ref
        .watch(
          monthlyReportProvider(
            (year: today.year, month: today.month, currency: currency),
          ),
        )
        .value;
    final DateTime? lastBackup =
        ref.watch(backupProtectionProvider).value?.lastSuccess;

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
          AppCard(
            onTap: () => context.push(AppRoutes.reports),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      AppIcons.insights,
                      size: 20,
                      color: palette.brand,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        localizations.reportMonthMovement,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: 18,
                      color: palette.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _MonthFigure(
                        label: localizations.reportReceived,
                        money: Money(report?.receivedMinor ?? 0, currency),
                        color: palette.owedToMe,
                        icon: AppIcons.arrowDownward,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _MonthFigure(
                        label: localizations.reportPaidOut,
                        money: Money(report?.paidOutMinor ?? 0, currency),
                        color: palette.iOwe,
                        icon: AppIcons.arrowUpward,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
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
            title: localizations.moreAppSection,
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
                subtitle: lastBackup == null
                    ? localizations.backupSectionHint
                    : localizations.backupLastDone(
                        formatting.date(lastBackup),
                      ),
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

  /// The currency the month's figures are in: the first one in use, as the
  /// Reports screen opens, or the saved default when nothing is recorded yet.
  AppCurrency _currency(WidgetRef ref) {
    final List<AppCurrency> inUse = ref.watch(currenciesInUseProvider);
    if (inUse.isNotEmpty) return inUse.first;
    return ref.watch(effectiveSettingsProvider).defaultCurrency;
  }
}

/// One side of the month's movement: what came in, or what went out.
class _MonthFigure extends StatelessWidget {
  const _MonthFigure({
    required this.label,
    required this.money,
    required this.color,
    required this.icon,
  });

  final String label;
  final Money money;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          context.formatting.amount(money),
          style: theme.textTheme.titleMedium?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
