import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// The standard content container.
///
/// One card shape for the whole app: a surface, a hairline border and a large
/// radius. Elevation is used only where something genuinely floats above the
/// page, which is what keeps the interface calm.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.margin,
    this.background,
    this.borderColor,
    this.radius = AppRadius.lg,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color? background;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final BorderRadius borderRadius = BorderRadius.circular(radius);

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: background ?? palette.surface,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(color: borderColor ?? palette.border),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.action,
    this.actionLabel,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.md),
    super.key,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null && actionLabel != null)
            TextButton(
              onPressed: action,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A labelled row used inside sheets and detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.secondary,
    this.footnote,
    this.footnoteColor,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  /// A quieter second line under the value — "in 2 days" under a date. Two
  /// facts joined by " · " in one value broke at whatever width the phone
  /// had, and the dot was left hanging at the end of a line.
  final String? secondary;

  /// A sentence about the row, given the card's full width under it. A
  /// warning squeezed into the value's half of the row broke into four short
  /// lines.
  final String? footnote;
  final Color? footnoteColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: palette.textTertiary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        // The value takes the other half and is drawn against its trailing
        // edge. It must be a *tight* box with end-aligned content: a loose
        // `Flexible` is packed where the row's start leaves it, so the value
        // began on the 50% line and the trailing half of the card stood empty
        // — which in Arabic is the middle of the screen. The `Align` keeps the
        // painted figure measurable at the edge; the box around it does not
        // matter to the eye.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(color: valueColor),
                ),
                if (secondary != null && secondary!.isNotEmpty)
                  Text(
                    secondary!,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: footnote == null || footnote!.isEmpty
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                row,
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: icon == null ? 0 : 18 + AppSpacing.sm,
                  ),
                  child: Text(
                    footnote!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: footnoteColor ?? palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// A thin divider that respects the theme's border colour.
class AppDivider extends StatelessWidget {
  const AppDivider({this.indent = 0, this.endIndent = 0, super.key});

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: context.palette.border,
    );
  }
}
