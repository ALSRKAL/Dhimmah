import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_update_controller.dart';
import '../../domain/services/app_update_service.dart';
import '../../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import 'app_card.dart';

/// The update prompt, when Google Play has a newer version.
///
/// A card on the dashboard rather than a dialog, and drawn only there: the
/// dashboard is where the user arrives and where nothing is half-typed. A
/// prompt that could appear over a form — while a debt is being entered, while a
/// payment is being recorded, while a statement is being built — would be
/// asking the user to choose between an update and losing what they were doing,
/// and an app that holds personal financial records does not get to do that.
///
/// Nothing is drawn when there is no update. A user on the current version never
/// learns that an update system exists.
class AppUpdateCard extends ConsumerWidget {
  const AppUpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUpdateState update = ref.watch(appUpdateControllerProvider);
    if (!update.isVisible) return const SizedBox.shrink();

    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final AppUpdateInfo info = update.info!;

    final (String title, String body) = switch (update.phase) {
      AppUpdatePhase.downloading => (
          localizations.updateDownloadingTitle,
          localizations.updateDownloadingBody,
        ),
      AppUpdatePhase.downloaded => (
          localizations.updateReadyTitle,
          localizations.updateReadyBody,
        ),
      _ => (
          localizations.updateAvailableTitle,
          localizations.updateAvailableBody,
        ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The brand lane, the same mark a section heading uses: this is
              // part of the app, not an interruption from outside it.
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsetsDirectional.only(top: 3, end: AppSpacing.sm),
                color: palette.brand,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (update.phase == AppUpdatePhase.downloading) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _DownloadProgress(info: info, localizations: localizations),
          ],
          const SizedBox(height: AppSpacing.md),
          _Actions(update: update),
        ],
      ),
    );
  }
}

/// How far along a flexible download is.
///
/// A bar rather than a spinner: Play reports the bytes, and a download the user
/// started should look like it is going somewhere. When Play has not reported a
/// total yet the bar is indeterminate, which is the honest thing to draw.
class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.info, required this.localizations});

  final AppUpdateInfo info;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double? progress = info.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.rSm,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: palette.surfaceMuted,
            valueColor: AlwaysStoppedAnimation<Color>(palette.brand),
          ),
        ),
        if (progress != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.updatePercent((progress * 100).round()),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textTertiary,
                ),
          ),
        ],
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.update});

  final AppUpdateState update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppUpdateController controller =
        ref.read(appUpdateControllerProvider.notifier);

    if (update.phase == AppUpdatePhase.downloading) {
      // Nothing to press while Play is downloading: the download is Play's, and
      // a button that only says "wait" is a button that lies about what it does.
      return const SizedBox.shrink();
    }

    if (update.phase == AppUpdatePhase.downloaded) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton(
          onPressed: controller.install,
          child: Text(localizations.updateRestartAndInstall),
        ),
      );
    }

    return Row(
      children: <Widget>[
        FilledButton(
          onPressed: update.isBusy ? null : controller.start,
          child: Text(localizations.updateNow),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          onPressed: controller.dismiss,
          child: Text(localizations.updateLater),
        ),
      ],
    );
  }
}
