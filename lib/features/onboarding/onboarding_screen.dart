import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../core/money/currency.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/dhimmah_logo.dart';
import '../../core/widgets/feedback.dart';
import '../../domain/enums/preference_enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// First run: three promises, then language, currency and notifications.
///
/// Short on purpose. The screen exists to set three things the app cannot guess,
/// not to sell anything, so every step is skippable and the whole flow is five
/// taps.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _step = 0;
  AppLanguage _language = AppLanguage.arabic;
  AppCurrency _currency = AppCurrency.inr;
  bool _busy = false;

  static const int _slideCount = 3;

  @override
  void initState() {
    super.initState();
    // Start from the user's configured language so the first thing they see is
    // already in the language they chose at install time.
    _language = ref.read(effectiveSettingsProvider).language;
    _currency = ref.read(effectiveSettingsProvider).defaultCurrency;
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Slide count plus the language, currency and notification steps.
  int get _stepCount => _slideCount + 3;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final bool isLast = _step == _stepCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: <Widget>[
                  const DhimmahLogo(size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      localizations.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _finish(requestPermission: false),
                    child: Text(localizations.onboardingSkip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (int index) => setState(() => _step = index),
                children: <Widget>[
                  _PromiseSlide(
                    icon: Icons.menu_book_outlined,
                    title: localizations.onboardingSlide1Title,
                    body: localizations.onboardingSlide1Body,
                    background: palette.brandContainer,
                    foreground: palette.onBrandContainer,
                  ),
                  _PromiseSlide(
                    icon: Icons.swap_vert,
                    title: localizations.onboardingSlide2Title,
                    body: localizations.onboardingSlide2Body,
                    background: palette.owedToMeContainer,
                    foreground: palette.owedToMe,
                  ),
                  _PromiseSlide(
                    icon: Icons.notifications_active_outlined,
                    title: localizations.onboardingSlide3Title,
                    body: localizations.onboardingSlide3Body,
                    background: palette.dueSoonContainer,
                    foreground: palette.dueSoon,
                  ),
                  _ChoiceStep(
                    title: localizations.onboardingLanguageTitle,
                    body: localizations.onboardingLanguageBody,
                    children: <Widget>[
                      for (final AppLanguage language in AppLanguage.values)
                        _ChoiceTile(
                          label: language.label(localizations),
                          selected: _language == language,
                          onTap: () {
                            setState(() => _language = language);
                            // Switch immediately so the rest of onboarding is
                            // read in the language just chosen.
                            ref
                                .read(settingsControllerProvider)
                                .setLanguage(language);
                          },
                        ),
                    ],
                  ),
                  _ChoiceStep(
                    title: localizations.onboardingCurrencyTitle,
                    body: localizations.onboardingCurrencyBody,
                    children: <Widget>[
                      for (final AppCurrency currency in AppCurrency.values)
                        _ChoiceTile(
                          label: '${currency.code} · ${currency.symbol}',
                          selected: _currency == currency,
                          onTap: () => setState(() => _currency = currency),
                        ),
                    ],
                  ),
                  _NotificationStep(
                    onEnable: _enableNotifications,
                    busy: _busy,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _pages.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Text(localizations.onboardingBack),
                    ),
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < _stepCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsetsDirectional.only(
                            start: AppSpacing.xs,
                          ),
                          width: i == _step ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _step
                                ? palette.brand
                                : palette.borderStrong,
                            borderRadius: AppRadius.rPill,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : isLast
                            ? _finish
                            : () => _pages.nextPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                ),
                    child: Text(
                      isLast
                          ? localizations.onboardingStart
                          : localizations.onboardingNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableNotifications() async {
    setState(() => _busy = true);
    final NotificationPermission permission =
        await ref.read(notificationServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!permission.isGrantedOrUnsupported) {
      AppFeedback.error(context, AppLocalizations.of(context).onboardingNotificationsDenied);
    }
    await _finish(requestPermission: false);
  }

  /// Finishes onboarding, recording the *real* notification state.
  ///
  /// The stored flag used to be set to true unconditionally, from the "Start" and
  /// "Skip" buttons as well as from the enable button. On a fresh install the
  /// platform has not granted anything yet, so Settings showed reminders as on
  /// while the scheduler — which bails when permission is denied — scheduled
  /// nothing at all. The user was promised reminders and silently got none.
  ///
  /// [requestPermission] is false for Skip: a permission dialog is not a fair
  /// reward for leaving.
  Future<void> _finish({bool requestPermission = true}) async {
    setState(() => _busy = true);
    try {
      final NotificationService notifications =
          ref.read(notificationServiceProvider);
      final NotificationPermission permission = requestPermission
          ? await notifications.requestPermission()
          : notifications.permission;
      await ref.read(settingsControllerProvider).completeOnboarding(
            language: _language,
            currency: _currency,
            // Only what the platform actually granted. On desktop, where there
            // is no runtime permission, this is unsupported and counts as on.
            notificationsEnabled: permission.isGrantedOrUnsupported,
          );
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      AppFeedback.error(context, AppLocalizations.of(context).somethingWentWrong);
    }
  }
}


class _PromiseSlide extends StatelessWidget {
  const _PromiseSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String title;
  final String body;

  /// The disc behind the icon and the icon's own colour, both semantic tokens.
  ///
  /// A wash mixed from the icon colour looked reasonable in isolation and was
  /// wrong in two ways: it is not a token, so it could not follow the warm ramp,
  /// and mixing a pale tint with the accent left the darkest of the three (the
  /// gold) at 3.2:1 — under the floor for a graphic that size. The container
  /// tokens are designed as a pair and measure 4.6:1 or better.
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 42, color: foreground),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({
    required this.title,
    required this.body,
    required this.children,
  });

  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          ...children,
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        background: selected ? palette.brandContainer : palette.surface,
        borderColor: selected ? palette.brand : palette.border,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: selected ? palette.onBrandContainer : null,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 20, color: palette.brand),
          ],
        ),
      ),
    );
  }
}

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({required this.onEnable, required this.busy});

  final Future<void> Function() onEnable;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: palette.brandContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 42,
              color: palette.onBrandContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            localizations.onboardingNotificationsTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.onboardingNotificationsBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : () => onEnable(),
              icon: const Icon(Icons.notifications_active_outlined, size: 20),
              label: Text(localizations.onboardingEnableNotifications),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.lock_outline, size: 13, color: palette.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                localizations.settingsPrivacyNote,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
