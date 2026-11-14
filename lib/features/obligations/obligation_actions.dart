import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/feedback.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../l10n/generated/app_localizations.dart';

/// The three things a user can do with one obligation period.
///
/// Shared by the list card and the detail screen so the same period can never
/// offer different actions depending on where it is opened from.
class ObligationActionButtons extends ConsumerStatefulWidget {
  const ObligationActionButtons({
    required this.instance,
    this.compact = true,
    super.key,
  });

  final ObligationInstance instance;

  /// Compact renders icon buttons for the list; the detail screen uses full
  /// labelled buttons.
  final bool compact;

  @override
  ConsumerState<ObligationActionButtons> createState() =>
      _ObligationActionButtonsState();
}

class _ObligationActionButtonsState
    extends ConsumerState<ObligationActionButtons> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final bool isPaid = widget.instance.occurrence.isPaid;
    final bool isSkipped =
        widget.instance.occurrence.status == ObligationStatus.skipped;

    if (isPaid || isSkipped) {
      return widget.compact
          ? TextButton.icon(
              onPressed: _busy ? null : () => _run(
                        () => ref
                            .read(ledgerServiceProvider)
                            .undoObligationPayment(widget.instance),
                        localizations.recordSaved,
                      ),
              icon: const Icon(AppIcons.undo, size: 16),
              label: Text(
                isPaid
                    ? localizations.obligationUndoPayment
                    : localizations.reminderReopen,
              ),
            )
          : SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(
                          () => ref
                              .read(ledgerServiceProvider)
                              .undoObligationPayment(widget.instance),
                          localizations.recordSaved,
                        ),
                icon: const Icon(AppIcons.undo, size: 18),
                label: Text(localizations.obligationUndoPayment),
              ),
            );
    }

    if (!widget.compact) {
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _run(
                        () => ref
                            .read(ledgerServiceProvider)
                            .markObligationPaid(widget.instance),
                        localizations.obligationMarkedPaid,
                      ),
              icon: const Icon(AppIcons.taskAlt, size: 18),
              label: Text(localizations.obligationMarkPaid),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Named, not a bare ▷| beside the primary button: on the device
          // nobody could tell what it did without pressing it.
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref
                            .read(ledgerServiceProvider)
                            .skipObligationPeriod(widget.instance),
                        localizations.obligationMarkedSkipped,
                      ),
              icon: const Icon(AppIcons.skipNext, size: 18),
              label: Text(
                localizations.obligationSkipShort,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.borderStrong),
              ),
            ),
          ),
        ],
      );
    }

    // One labelled action and a menu. Two labelled buttons side by side took
    // two lines each on a narrow card and only four cards fitted on a screen;
    // skipping a period is the rarer act, so it waits behind ⋮ with its name.
    return Row(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _run(
                        () => ref
                            .read(ledgerServiceProvider)
                            .markObligationPaid(widget.instance),
                        localizations.obligationMarkedPaid,
                      ),
              icon: const Icon(AppIcons.taskAlt, size: 16),
              label: Text(
                localizations.obligationMarkPaid,
                maxLines: 2,
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: localizations.obligationMoreActions,
          enabled: !_busy,
          icon: const Icon(AppIcons.moreVert, size: 20),
          onSelected: (_) => _run(
            () => ref
                .read(ledgerServiceProvider)
                .skipObligationPeriod(widget.instance),
            localizations.obligationMarkedSkipped,
          ),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'skip',
              child: Row(
                children: <Widget>[
                  const Icon(AppIcons.skipNext, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Text(localizations.obligationSkip),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Runs a write and reports the outcome.
  ///
  /// Lives on the State rather than inside `build` so `mounted` and `context`
  /// refer to the same object across the await, which is what makes the guard
  /// after it meaningful.
  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      AppFeedback.info(context, message);
      setState(() => _busy = false);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(
        context,
        AppLocalizations.of(context).somethingWentWrong,
      );
    }
  }
}
