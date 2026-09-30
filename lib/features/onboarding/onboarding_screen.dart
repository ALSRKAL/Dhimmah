import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/formatting/app_formatting.dart';
import '../../core/money/currency.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/dhimmah_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/enums/preference_enums.dart';
import '../../domain/enums/recurrence.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// First run: what Dhimmah is, the currency new records use, and reminders.
///
/// Three steps, each with one primary action, because the screen exists to set
/// the two things the app cannot guess — not to sell anything.
///
/// The language is deliberately *not* a step. It is the phone's, so the very
/// first frame is already in a language the person reads, and the switch in the
/// top bar offers the other one on every step for someone whose phone is in a
/// language they would rather not use here. The old flow opened in Arabic
/// whatever the phone said and asked the question four screens in — by which
/// point an English reader had already read three screens they could not.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// How the last step's answer is turned into the stored reminder switch.
enum _Reminders {
  /// "Turn on reminders": ask the platform, and store what it granted.
  ask,

  /// Skip: no dialog, and the switch records what the platform already allows.
  asTheyAre,

  /// "Not now": the person answered the question, and the answer was no.
  off,
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;
  late AppCurrency _currency = ref
      .read(effectiveSettingsProvider)
      .defaultCurrency;
  bool _busy = false;

  static const int _stepCount = 3;

  bool get _isFirst => _index == 0;
  bool get _isLast => _index == _stepCount - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The system back gesture walks back through the steps, and only leaves
      // from the first one — as it would through any other set of screens.
      // While the last write is in flight it does nothing: leaving then could
      // close the app between "chosen" and "stored".
      canPop: _isFirst && !_busy,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !_busy) _goTo(_index - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: <Widget>[
                  _TopBar(
                    onBack: _isFirst || _busy ? null : () => _goTo(_index - 1),
                    onSwitchLanguage: _busy ? null : _switchLanguage,
                    // The last step answers the same question with "Not now";
                    // two buttons for one choice is one too many.
                    showSkip: !_isLast,
                    onSkip: _busy ? null : () => _finish(_Reminders.asTheyAre),
                  ),
                  _Progress(index: _index, count: _stepCount),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: _busy
                          ? const NeverScrollableScrollPhysics()
                          : const PageScrollPhysics(),
                      onPageChanged: (int index) =>
                          setState(() => _index = index),
                      children: <Widget>[
                        _WelcomeStep(onContinue: () => _goTo(1)),
                        _CurrencyStep(
                          selected: _currency,
                          onSelected: (AppCurrency currency) =>
                              setState(() => _currency = currency),
                          onContinue: () => _goTo(2),
                        ),
                        _RemindersStep(
                          busy: _busy,
                          onEnable: () => _finish(_Reminders.ask),
                          onLater: () => _finish(_Reminders.off),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goTo(int index) {
    if (index < 0 || index >= _stepCount || !_pages.hasClients) return;
    // A person who asked the system to remove animations gets the step without
    // the slide.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(index);
      return;
    }
    _pages.animateToPage(
      index,
      duration: AppMotion.screen,
      curve: AppMotion.standard,
    );
  }

  /// Switches to the other language, and stores the switch at once so the rest
  /// of the app — and the reminder channels — agree with what is on screen.
  ///
  /// Switching back to the phone's own language stores "follow the phone" rather
  /// than a pinned copy of it: someone who tried English and came back to Arabic
  /// on an Arabic phone has not asked for Arabic forever, and a phone that later
  /// changes language should still take the app with it.
  Future<void> _switchLanguage() async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppLanguage target = ref.read(appLanguageProvider).other;
    final LanguagePreference next = target == ref.read(deviceLanguageProvider)
        ? LanguagePreference.system
        : LanguagePreference.of(target);
    try {
      await ref.read(settingsControllerProvider).setLanguagePreference(next);
    } on Object {
      if (!mounted) return;
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }

  /// Finishes onboarding, recording the *real* notification state.
  ///
  /// The stored flag used to be set to true unconditionally. On a fresh install
  /// the platform has not granted anything yet, so Settings showed reminders as
  /// on while the scheduler — which bails when permission is denied — scheduled
  /// nothing at all. Now only "Turn on reminders" raises the system dialog, Skip
  /// keeps whatever the platform already allows, and "Not now" is a no.
  Future<void> _finish(_Reminders reminders) async {
    if (_busy) return;
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final NotificationService notifications = ref.read(
        notificationServiceProvider,
      );
      final bool enabled = switch (reminders) {
        _Reminders.ask =>
          (await notifications.requestPermission()).isGrantedOrUnsupported,
        // On desktop, where there is no runtime permission, this is
        // unsupported and counts as on.
        _Reminders.asTheyAre => notifications.permission.isGrantedOrUnsupported,
        _Reminders.off => false,
      };
      if (reminders == _Reminders.ask && !enabled && mounted) {
        AppFeedback.error(context, localizations.onboardingNotificationsDenied);
      }
      await ref
          .read(settingsControllerProvider)
          .completeOnboarding(
            currency: _currency,
            notificationsEnabled: enabled,
          );
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, localizations.somethingWentWrong);
    }
  }
}

/// Back, the other language, and Skip.
class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onBack,
    required this.onSwitchLanguage,
    required this.showSkip,
    required this.onSkip,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSwitchLanguage;
  final bool showSkip;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    // Offered by its own name, in its own script: the person who needs this
    // button is the one who cannot read the language the screen is in.
    final AppLanguage other = ref.watch(appLanguageProvider).other;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          if (onBack != null)
            IconButton(
              tooltip: localizations.onboardingBack,
              onPressed: onBack,
              icon: const BackButtonIcon(),
            ),
          // All the width the other two leave, so at a large text size the
          // name shortens rather than pushing the row off the screen.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Tooltip(
                message: localizations.onboardingChangeLanguage,
                child: TextButton.icon(
                  onPressed: onSwitchLanguage,
                  icon: const Icon(Icons.translate, size: 18),
                  // The locale is on the span so a screen reader pronounces
                  // the name in its own language rather than spelling it out
                  // in the current one.
                  label: Text.rich(
                    TextSpan(text: other.endonym, locale: other.locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          // Closes on the last step rather than leaving a hole, so the language
          // switch settles at the edge instead of floating in the middle.
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            child: showSkip
                ? TextButton(
                    onPressed: onSkip,
                    child: Text(localizations.onboardingSkip),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Where the person is: one segment per step, filled up to this one.
class _Progress extends StatelessWidget {
  const _Progress({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Semantics(
      liveRegion: true,
      label: AppLocalizations.of(context).onboardingStepOf(index + 1, count),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < count; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.sm - 2),
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.normal,
                    curve: AppMotion.standard,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= index ? palette.brand : palette.border,
                      borderRadius: AppRadius.rPill,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One step: content that scrolls when it has to, and its actions pinned
/// beneath it so the way forward is never scrolled out of reach — at 1.5x text
/// on a small phone the content is taller than the screen.
class _StepLayout extends StatefulWidget {
  const _StepLayout({
    required this.children,
    required this.actions,
    this.centered = false,
  });

  final List<Widget> children;
  final List<Widget> actions;

  /// Centred in the space when there is room: the welcome is a title page, the
  /// questions read from the top.
  final bool centered;

  @override
  State<_StepLayout> createState() => _StepLayoutState();
}

class _StepLayoutState extends State<_StepLayout> {
  static const double _gutter = AppSpacing.xl;

  /// Whether the content runs on under the actions.
  ///
  /// A card cut off by the button bar reads as the end of the screen; the
  /// hairline above the bar says there is more, and goes once there is not.
  bool _moreBelow = false;

  bool _track(ScrollMetrics metrics, int depth) {
    if (depth != 0) return false;
    final bool more = metrics.extentAfter > 0.5;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (ScrollMetricsNotification n) =>
                _track(n.metrics, n.depth),
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification n) =>
                  _track(n.metrics, n.depth),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _gutter,
                      vertical: AppSpacing.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0,
                          constraints.maxHeight - AppSpacing.xxl * 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: widget.centered
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.children,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Visibility(
          visible: _moreBelow,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: const AppDivider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _gutter,
            AppSpacing.sm,
            _gutter,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: widget.actions,
          ),
        ),
      ],
    );
  }
}

/// A question's title and the sentence that explains why it is asked.
class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// A point in a short list: an icon, a line, and the sentence behind it.
class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  static const double iconSize = 22;

  /// Where the text starts, so a divider between rows can start there too.
  static const double textInset = AppSpacing.lg + iconSize + AppSpacing.lg;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: iconSize, color: context.palette.brand),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The points in one card, separated by hairlines that start with the text.
class _PointList extends StatelessWidget {
  const _PointList({required this.points});

  final List<_PointRow> points;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < points.length; i++) ...<Widget>[
            if (i > 0) const AppDivider(indent: _PointRow.textInset),
            points[i],
          ],
        ],
      ),
    );
  }
}

/// The title page: the mark, the name, the promise, and what the app does.
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return _StepLayout(
      centered: true,
      actions: <Widget>[
        FilledButton(
          onPressed: onContinue,
          child: Text(localizations.onboardingStart),
        ),
      ],
      children: <Widget>[
        const Center(child: DhimmahLogo(size: 88)),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Semantics(
            header: true,
            child: DhimmahWordmark(
              // A taller line box than the style's own: the name carries a
              // shadda and a kasra, and they must not touch the rule.
              style: theme.textTheme.headlineMedium?.copyWith(height: 1.45),
              alignment: CrossAxisAlignment.center,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          localizations.appTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        _PointList(
          points: <_PointRow>[
            _PointRow(
              icon: Icons.swap_vert,
              title: localizations.onboardingFeatureBooksTitle,
              body: localizations.onboardingFeatureBooksBody,
            ),
            _PointRow(
              icon: Icons.notifications_none,
              title: localizations.onboardingFeatureRemindersTitle,
              body: localizations.onboardingFeatureRemindersBody,
            ),
            _PointRow(
              icon: Icons.lock_outline,
              title: localizations.settingsPrivacyNote,
              body: localizations.onboardingFeaturePrivateBody,
            ),
          ],
        ),
      ],
    );
  }
}

/// The currency new records start in.
class _CurrencyStep extends StatelessWidget {
  const _CurrencyStep({
    required this.selected,
    required this.onSelected,
    required this.onContinue,
  });

  final AppCurrency selected;
  final ValueChanged<AppCurrency> onSelected;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return _StepLayout(
      actions: <Widget>[
        FilledButton(
          onPressed: onContinue,
          child: Text(localizations.onboardingNext),
        ),
      ],
      children: <Widget>[
        _StepHeading(
          title: localizations.onboardingCurrencyTitle,
          body: localizations.onboardingCurrencyBody,
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final AppCurrency currency in AppCurrency.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CurrencyOption(
              currency: currency,
              selected: currency == selected,
              onTap: () => onSelected(currency),
            ),
          ),
      ],
    );
  }
}

/// One currency: its symbol, its name and its code, one of a set.
///
/// The name is what tells ﷼ the Saudi riyal apart from ﷼ the Yemeni rial; the
/// code is what the rest of the app prints beside a shared symbol.
class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  final AppCurrency currency;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Color ink = selected ? palette.onBrandContainer : palette.textPrimary;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AppCard(
        onTap: onTap,
        background: selected ? palette.brandContainer : palette.surface,
        borderColor: selected ? palette.brand : palette.border,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? palette.surface : palette.surfaceMuted,
                  borderRadius: AppRadius.rSm,
                ),
                child: Text(
                  currency.symbol,
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    currency.label(localizations),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    currency.code,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? palette.onBrandContainer
                          : palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: selected ? palette.brand : palette.borderStrong,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reminders: what they will actually do, then the one question.
///
/// The card states the real defaults — the lead, the hour, the month-end
/// summary — read from the settings the reminders will use, so "turn on" is a
/// decision about something the person can see.
class _RemindersStep extends ConsumerWidget {
  const _RemindersStep({
    required this.busy,
    required this.onEnable,
    required this.onLater,
  });

  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppSettings settings = ref.watch(effectiveSettingsProvider);
    final ThemeData theme = Theme.of(context);
    final DateFormatter dates = context.formatting.dates;

    return _StepLayout(
      actions: <Widget>[
        FilledButton.icon(
          onPressed: busy ? null : onEnable,
          icon: const Icon(Icons.notifications_active_outlined, size: 20),
          label: Text(localizations.onboardingEnableNotifications),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: busy ? null : onLater,
          child: Text(localizations.onboardingMaybeLater),
        ),
      ],
      children: <Widget>[
        _StepHeading(
          title: localizations.onboardingNotificationsTitle,
          body: localizations.onboardingNotificationsBody,
        ),
        const SizedBox(height: AppSpacing.xl),
        _PointList(
          points: <_PointRow>[
            _PointRow(
              icon: Icons.notifications_active_outlined,
              title: _leadTitle(localizations, settings.defaultReminderLeads),
              body: localizations.onboardingReminderTime(
                dates.time(
                  context,
                  settings.notificationHour,
                  settings.notificationMinute,
                ),
              ),
            ),
            if (settings.monthEndSummaryEnabled)
              _PointRow(
                icon: Icons.insights_outlined,
                title: localizations.settingsMonthEnd,
                body: localizations.onboardingMonthEndWhen(
                  settings.monthEndDay.label(localizations),
                  dates.time(
                    context,
                    settings.monthEndHour,
                    settings.monthEndMinute,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          localizations.onboardingChangeLater,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// "Reminder: 1 day before", or how many there are when there are several.
  static String _leadTitle(AppLocalizations l, List<ReminderLead> leads) {
    final List<ReminderLead> active = <ReminderLead>[
      for (final ReminderLead lead in leads)
        if (lead != ReminderLead.none) lead,
    ];
    if (active.isEmpty) return l.leadNone;
    if (active.length == 1) return l.leadSummary(active.single.label(l));
    return l.leadCount(active.length);
  }
}
