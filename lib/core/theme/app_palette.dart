import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Semantic colours for the whole app.
///
/// Everything that is not a brand constant is read from here so that light and
/// dark mode stay in step and so that money semantics are defined in exactly one
/// place. Access it with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnBrand,
    required this.brand,
    required this.brandStrong,
    required this.brandContainer,
    required this.onBrandContainer,
    required this.gold,
    required this.goldContainer,
    required this.owedToMe,
    required this.owedToMeContainer,
    required this.iOwe,
    required this.iOweContainer,
    required this.overdue,
    required this.overdueContainer,
    required this.dueSoon,
    required this.dueSoonContainer,
    required this.settled,
    required this.settledContainer,
    required this.neutralStatus,
    required this.neutralStatusContainer,
    required this.shadow,
    required this.overlay,
    required this.heroGradient,
  });

  final Brightness brightness;

  final Color background;
  final Color surface;

  /// Slightly recessed surface, used for grouped rows and input fills.
  final Color surfaceMuted;

  /// Raised surface used for sheets and elevated cards.
  final Color surfaceRaised;

  final Color border;
  final Color borderStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnBrand;

  final Color brand;
  final Color brandStrong;
  final Color brandContainer;
  final Color onBrandContainer;

  final Color gold;
  final Color goldContainer;

  /// Money owed *to* the user. Positive.
  final Color owedToMe;
  final Color owedToMeContainer;

  /// Money the user owes. Negative.
  final Color iOwe;
  final Color iOweContainer;

  /// Past its due date and still unpaid.
  final Color overdue;
  final Color overdueContainer;

  /// Approaching its due date.
  final Color dueSoon;
  final Color dueSoonContainer;

  /// Fully paid / closed.
  final Color settled;
  final Color settledContainer;

  /// Informational, no money pressure attached.
  final Color neutralStatus;
  final Color neutralStatusContainer;

  final Color shadow;
  final Color overlay;

  /// Gradient used behind the dashboard hero and the onboarding slides.
  final List<Color> heroGradient;

  bool get isDark => brightness == Brightness.dark;

  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: BrandColors.paper,
    surface: BrandColors.paperRaised,
    surfaceMuted: BrandColors.paperSunken,
    surfaceRaised: BrandColors.paperRaised,
    border: BrandColors.paperBorder,
    borderStrong: BrandColors.paperBorderStrong,
    textPrimary: BrandColors.inkPrimary,
    textSecondary: BrandColors.inkSecondary,
    textTertiary: BrandColors.inkTertiary,
    textOnBrand: Colors.white,
    brand: BrandColors.green600,
    brandStrong: BrandColors.green800,
    brandContainer: BrandColors.green50,
    onBrandContainer: BrandColors.green800,
    gold: BrandColors.gold600,
    goldContainer: BrandColors.gold100,
    // Money semantics. Each is dark enough to be read as text on paper, and each
    // is a different hue from the next so two states never look alike.
    owedToMe: Color(0xFF0B7A54),
    owedToMeContainer: Color(0xFFE4F1EA),
    iOwe: Color(0xFFC1362F),
    iOweContainer: Color(0xFFFAEBE8),
    overdue: Color(0xFFB3261E),
    overdueContainer: Color(0xFFF9E7E3),
    dueSoon: Color(0xFF9E5C00),
    dueSoonContainer: Color(0xFFF8F0E0),
    settled: Color(0xFF0B7A54),
    settledContainer: Color(0xFFE4F1EA),
    neutralStatus: BrandColors.inkSecondary,
    neutralStatusContainer: Color(0xFFEFEDE8),
    shadow: Color(0x14140F0A),
    overlay: Color(0x66131009),
    // The header's identity plate: warm ink, not a coloured billboard.
    heroGradient: <Color>[BrandColors.green800, BrandColors.green600],
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: BrandColors.nightPage,
    surface: BrandColors.nightSurface,
    surfaceMuted: BrandColors.nightSunken,
    surfaceRaised: BrandColors.nightRaised,
    border: BrandColors.nightBorder,
    borderStrong: BrandColors.nightBorderStrong,
    textPrimary: BrandColors.nightTextPrimary,
    textSecondary: BrandColors.nightTextSecondary,
    textTertiary: BrandColors.nightTextTertiary,
    // Dark ink, not white: the dark brand is lifted to hold on warm charcoal,
    // and white on that measured 2.75:1 — on the primary button and the add
    // button, the two most prominent controls in the app.
    textOnBrand: BrandColors.onBrandInk,
    brand: BrandColors.primaryDark,
    brandStrong: BrandColors.green300,
    brandContainer: Color(0xFF10322E),
    onBrandContainer: BrandColors.green200,
    gold: BrandColors.gold400,
    goldContainer: Color(0xFF2E2712),
    // The light palette's semantic colours are not inverted here: a red that
    // reads on paper is unreadable on charcoal, so each is lifted separately
    // until it clears 4.5:1 on the warm dark surface.
    owedToMe: Color(0xFF3ED598),
    owedToMeContainer: Color(0xFF10302A),
    iOwe: Color(0xFFFF9B92),
    iOweContainer: Color(0xFF38201E),
    overdue: Color(0xFFFF7A70),
    overdueContainer: Color(0xFF3D201C),
    dueSoon: Color(0xFFF5BE5B),
    dueSoonContainer: Color(0xFF382C17),
    settled: Color(0xFF3ED598),
    settledContainer: Color(0xFF10302A),
    neutralStatus: BrandColors.nightTextSecondary,
    neutralStatusContainer: Color(0xFF26231F),
    shadow: Color(0x66000000),
    overlay: Color(0x99000000),
    heroGradient: <Color>[BrandColors.green800, BrandColors.green600],
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnBrand,
    Color? brand,
    Color? brandStrong,
    Color? brandContainer,
    Color? onBrandContainer,
    Color? gold,
    Color? goldContainer,
    Color? owedToMe,
    Color? owedToMeContainer,
    Color? iOwe,
    Color? iOweContainer,
    Color? overdue,
    Color? overdueContainer,
    Color? dueSoon,
    Color? dueSoonContainer,
    Color? settled,
    Color? settledContainer,
    Color? neutralStatus,
    Color? neutralStatusContainer,
    Color? shadow,
    Color? overlay,
    List<Color>? heroGradient,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnBrand: textOnBrand ?? this.textOnBrand,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandContainer: brandContainer ?? this.brandContainer,
      onBrandContainer: onBrandContainer ?? this.onBrandContainer,
      gold: gold ?? this.gold,
      goldContainer: goldContainer ?? this.goldContainer,
      owedToMe: owedToMe ?? this.owedToMe,
      owedToMeContainer: owedToMeContainer ?? this.owedToMeContainer,
      iOwe: iOwe ?? this.iOwe,
      iOweContainer: iOweContainer ?? this.iOweContainer,
      overdue: overdue ?? this.overdue,
      overdueContainer: overdueContainer ?? this.overdueContainer,
      dueSoon: dueSoon ?? this.dueSoon,
      dueSoonContainer: dueSoonContainer ?? this.dueSoonContainer,
      settled: settled ?? this.settled,
      settledContainer: settledContainer ?? this.settledContainer,
      neutralStatus: neutralStatus ?? this.neutralStatus,
      neutralStatusContainer:
          neutralStatusContainer ?? this.neutralStatusContainer,
      shadow: shadow ?? this.shadow,
      overlay: overlay ?? this.overlay,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textOnBrand: c(textOnBrand, other.textOnBrand),
      brand: c(brand, other.brand),
      brandStrong: c(brandStrong, other.brandStrong),
      brandContainer: c(brandContainer, other.brandContainer),
      onBrandContainer: c(onBrandContainer, other.onBrandContainer),
      gold: c(gold, other.gold),
      goldContainer: c(goldContainer, other.goldContainer),
      owedToMe: c(owedToMe, other.owedToMe),
      owedToMeContainer: c(owedToMeContainer, other.owedToMeContainer),
      iOwe: c(iOwe, other.iOwe),
      iOweContainer: c(iOweContainer, other.iOweContainer),
      overdue: c(overdue, other.overdue),
      overdueContainer: c(overdueContainer, other.overdueContainer),
      dueSoon: c(dueSoon, other.dueSoon),
      dueSoonContainer: c(dueSoonContainer, other.dueSoonContainer),
      settled: c(settled, other.settled),
      settledContainer: c(settledContainer, other.settledContainer),
      neutralStatus: c(neutralStatus, other.neutralStatus),
      neutralStatusContainer:
          c(neutralStatusContainer, other.neutralStatusContainer),
      shadow: c(shadow, other.shadow),
      overlay: c(overlay, other.overlay),
      heroGradient: <Color>[
        c(heroGradient.first, other.heroGradient.first),
        c(heroGradient.last, other.heroGradient.last),
      ],
    );
  }
}

/// `context.palette` — the semantic colour set for the active theme.
extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
