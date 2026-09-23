import 'package:flutter/widgets.dart';

/// Spacing scale. Every gap in the app comes from here so rhythm stays
/// consistent and can be tuned in one place.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 56;

  /// Standard horizontal padding for screen content.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);

  /// Padding inside a card.
  static const EdgeInsets card = EdgeInsets.all(lg);

  /// Padding for a dense list row.
  static const EdgeInsets listRow =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Minimum touch target required by the accessibility guidelines.
  static const double minTouchTarget = 48;

  /// Height a scrollable needs at its end so its last row can clear the floating
  /// add button: the button's [FloatingActionButton] height plus the margin
  /// `Scaffold` leaves beneath it. Anything less and the final row sits
  /// permanently under the button — which on a ledger means a hidden amount.
  static const double addButtonClearance = massive + lg;
}

/// Corner radii.
abstract final class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

/// Motion constants. Animations are short and purposeful: they explain a
/// transition, they never perform.
abstract final class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration screen = Duration(milliseconds: 280);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;
}
