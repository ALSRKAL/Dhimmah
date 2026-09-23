import 'package:flutter/material.dart';

import '../../domain/entities/person.dart';
import '../theme/app_palette.dart';
import '../theme/brand_colors.dart';

/// An initials avatar.
///
/// The accent is derived from the person's stored colour index and blended into
/// the active theme, so avatars stay distinguishable in dark mode without
/// introducing a second palette.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.initials,
    required this.colorIndex,
    this.size = 44,
    this.archived = false,
    super.key,
  });

  PersonAvatar.of(
    Person person, {
    this.size = 44,
    super.key,
  })  : initials = person.initials,
        colorIndex = person.colorIndex,
        archived = person.isArchived;

  final String initials;
  final int colorIndex;
  final double size;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color accent = BrandColors
        .accentSwatches[colorIndex.abs() % BrandColors.accentSwatches.length];

    final Color background = archived
        ? palette.surfaceMuted
        : Color.alphaBlend(
            accent.withValues(alpha: palette.isDark ? 0.30 : 0.16),
            palette.surface,
          );
    final Color foreground = archived
        ? palette.textTertiary
        : (palette.isDark
            ? Color.lerp(accent, Colors.white, 0.55)!
            : Color.lerp(accent, Colors.black, 0.28)!);

    return Semantics(
      label: initials,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foreground,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
        ),
      ),
    );
  }
}
