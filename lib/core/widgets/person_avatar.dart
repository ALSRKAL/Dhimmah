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
    this.heroTag,
    super.key,
  });

  PersonAvatar.of(
    Person person, {
    this.size = 44,
    this.heroTag,
    super.key,
  })  : initials = person.initials,
        colorIndex = person.colorIndex,
        archived = person.isArchived;

  final String initials;
  final int colorIndex;
  final double size;
  final bool archived;

  /// The tag that lets this avatar fly between two screens, or null to stay
  /// where it is.
  ///
  /// Given on the people list and the person's page, which both draw the same
  /// person's avatar: tapping a row then carries the picture into the header
  /// instead of cutting to it. It is per person and passed in rather than
  /// derived here, because the same person can be drawn twice on one screen —
  /// in a picker and in the form behind it — and two heroes with one tag is an
  /// exception, not a transition.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color accent = BrandColors
        .accentSwatches[colorIndex.abs() % BrandColors.accentSwatches.length];

    final Color background = archived
        ? palette.surfaceMuted
        : BrandColors.discColor(
            accent,
            dark: palette.isDark,
            surface: palette.surface,
          );
    final Color foreground = archived
        ? palette.textTertiary
        : BrandColors.initialsInk(
            accent,
            dark: palette.isDark,
            surface: palette.surface,
          );

    final Widget avatar = Semantics(
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

    final Object? tag = heroTag;
    // A flight is motion like any other: with the system's "remove animations"
    // on, the destination avatar is simply there.
    if (tag == null || MediaQuery.disableAnimationsOf(context)) return avatar;
    return Hero(tag: tag, child: avatar);
  }
}
