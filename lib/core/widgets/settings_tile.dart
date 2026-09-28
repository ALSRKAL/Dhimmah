import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// A grouped block of settings rows with an optional heading.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    this.footer,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(const Divider(height: 1, indent: AppSpacing.huge));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.textTertiary,
              ),
            ),
          ),
          Material(
            color: palette.surface,
            borderRadius: AppRadius.rLg,
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.rLg,
                border: Border.all(color: palette.border),
              ),
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              child: Text(footer!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// One settings row: an icon, a label, an optional explanation and a control.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.onTap,
    this.trailing,
    this.valueText,
    this.enabled = true,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// A read-only value shown before the chevron.
  final String? valueText;

  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ThemeData theme = Theme.of(context);
    final Color titleColor = !enabled
        ? palette.textTertiary
        : (destructive ? palette.overdue : palette.textPrimary);

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              // A plain icon rather than a tinted tile. A settings list is
              // scanned by its labels, and thirty coloured squares turn a quiet
              // screen into a grid of buttons that are not buttons.
              Icon(
                icon,
                size: 20,
                color: iconColor ?? palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(color: titleColor),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (valueText != null) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Text(
                valueText!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ],
            if (trailing != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
            if (onTap != null && trailing == null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                // Mirrored automatically in RTL by the icon's own text direction.
                Icons.chevron_right,
                size: 20,
                color: palette.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A switch row, wired so the whole row is the hit target.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.enabled = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // One control, read as one thing.
    //
    // Without this the switch announces itself with an empty label — a screen
    // reader says "switch, on" and never says *what* is on, which was measured
    // on this tile rather than assumed. Merging makes the row a single node
    // whose name is the title and whose state is the switch.
    return MergeSemantics(
      child: SettingsTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        enabled: enabled,
        onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
        trailing: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
