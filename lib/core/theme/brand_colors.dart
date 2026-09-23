import 'package:flutter/material.dart';

/// The Dhimmah brand palette.
///
/// The identity is **deep pine ink on warm paper**, with brass as the accent: a
/// pocket holding a receipt and a coin, which is what the app is for. The hues
/// are the reference identity's own — a green at 180° and a gold at 73° — rather
/// than a house colour chosen here.
///
/// The brand ramp is the previous teal ramp rotated to that hue with its
/// lightness and chroma held. That is not a stylistic detail: WCAG contrast is a
/// function of relative luminance alone, and rotating a colour's hue at constant
/// L\* leaves its luminance untouched — so every ratio the palette was built
/// around, and the sixteen assertions that pin them, still hold exactly.
///
/// The neutrals keep their deliberate warmth rather than the blue-grey that
/// every finance app reaches for, at very low chroma on purpose. A warm grey
/// reads as "paper"; push it further and it becomes a cream palette, which is
/// its own reflex and makes white cards look like stickers.
abstract final class BrandColors {
  const BrandColors._();

  /// Ink for a filled brand surface in dark mode. The dark brand is *lifted*
  /// so it holds on warm charcoal, which is exactly why white stops working on
  /// it: the label has to go dark instead, as it already does on gold.
  static const Color onBrandInk = Color(0xFF05322B);

  /// Deepest ink. The dark end of the mark's tile.
  static const Color ink = Color(0xFF06241F);

  // --- Brand: deep pine ----------------------------------------------------
  static const Color green900 = Color(0xFF0C2B26);
  static const Color green800 = Color(0xFF143D36);
  static const Color green700 = Color(0xFF194A42);
  static const Color green600 = Color(0xFF1E554C);
  static const Color green500 = Color(0xFF297366);
  static const Color green400 = Color(0xFF3E9687);
  static const Color green300 = Color(0xFF77BEB0);
  static const Color green200 = Color(0xFFACDAD0);
  static const Color green100 = Color(0xFFD7EBE6);
  static const Color green50 = Color(0xFFEAF2F0);

  /// The brand colour in light mode: dark enough to be read as text.
  static const Color primaryLight = green600;

  /// The brand colour in dark mode, lifted so it holds on warm charcoal.
  static const Color primaryDark = Color(0xFF5DA99B);

  // --- The mark's own colours ---------------------------------------------
  //
  // The identity's four tones. They are not part of the semantic palette: they
  // belong to the drawing, the way the colours of a photograph do, and every
  // renderer of the mark — the launcher icon, the app's logo widget, the
  // statement header — takes them from here.

  /// The top-left of the icon's ground.
  static const Color tileDark = Color(0xFF12362C);

  /// The bottom-right of the icon's ground.
  static const Color tileLight = Color(0xFF1E4E3F);

  /// The receipt.
  static const Color cream = Color(0xFFFBF4E8);

  /// The pocket, lifted off the ground so it reads without a shadow.
  static const Color pocket = Color(0xFF2E6B58);

  // --- Gold: brand accent only --------------------------------------------
  static const Color gold700 = Color(0xFF7A611A);
  static const Color gold600 = Color(0xFF84691B);
  static const Color gold500 = Color(0xFFC8A24A);
  static const Color gold400 = Color(0xFFE0C177);
  static const Color gold100 = Color(0xFFF6EEDA);

  // --- Warm neutrals (light) ----------------------------------------------
  /// The page. A warm off-white, the colour of good paper.
  static const Color paper = Color(0xFFF7F5F2);

  /// Cards sit on the page in white, so they lift without a shadow.
  static const Color paperRaised = Color(0xFFFFFFFF);

  /// Recessed wells: input fills, icon tiles, grouped rows.
  static const Color paperSunken = Color(0xFFF1EEE9);

  static const Color paperBorder = Color(0xFFE5E1DA);
  static const Color paperBorderStrong = Color(0xFFD3CEC6);

  /// Warm ink, not a blue-black. The difference is small and the page reads as
  /// printed rather than as a screen.
  static const Color inkPrimary = Color(0xFF1C1917);
  static const Color inkSecondary = Color(0xFF6B655C);
  static const Color inkTertiary = Color(0xFF726B62);

  // --- Warm neutrals (dark) -----------------------------------------------
  static const Color nightPage = Color(0xFF131211);
  static const Color nightSurface = Color(0xFF1C1A18);
  static const Color nightRaised = Color(0xFF2B2825);
  static const Color nightSunken = Color(0xFF26231F);
  static const Color nightBorder = Color(0xFF35312C);
  static const Color nightBorderStrong = Color(0xFF453F39);

  static const Color nightTextPrimary = Color(0xFFF2EFEA);
  static const Color nightTextSecondary = Color(0xFFABA49B);
  static const Color nightTextTertiary = Color(0xFF958E85);

  /// Accent colours offered when tagging a person or an obligation.
  ///
  /// Muted and warmed to sit beside the pine and the paper rather than shout
  /// across them. Every one of these is used as a tint behind initials, never as
  /// a large fill.
  static const List<Color> accentSwatches = <Color>[
    Color(0xFF297366),
    Color(0xFF3E9687),
    Color(0xFF0B8A63),
    Color(0xFFC8A24A),
    Color(0xFFC0453F),
    Color(0xFF6B5BA8),
    Color(0xFFC77B33),
    Color(0xFF6B655C),
  ];
}
