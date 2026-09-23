import 'package:flutter/material.dart';

import '../formatting/app_formatting.dart';
import '../money/money.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// The largest number on a screen, set properly.
///
/// Two things make a financial figure feel considered rather than printed out of
/// a table. The currency symbol is set smaller and muted, so it reads as a unit
/// instead of competing with the digits; and the digits sit in a tabular box with
/// slightly tightened tracking, so they hold together as one shape and stay in
/// the same place when the value changes.
///
/// The digits come from the shared money formatter, so a numeral style or a
/// currency with an ambiguous symbol behaves here exactly as it does everywhere
/// else. This widget decides weight and size, not formatting.
class HeroAmount extends StatelessWidget {
  const HeroAmount(
    this.money, {
    this.color,
    this.symbolColor,
    this.fontSize = 40,
    this.animate = true,
    super.key,
  });

  final Money money;
  final Color? color;
  final Color? symbolColor;

  /// Digit size. The symbol is set at roughly half of it.
  final double fontSize;

  /// Counts to a new value instead of snapping to it.
  ///
  /// This is the app's main confirmation: a balance that visibly moves after a
  /// payment says more than a toast does, and it costs no extra chrome.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final AppFormatting formatting = context.formatting;
    final Color digits = color ?? palette.textPrimary;
    final Color symbol = symbolColor ?? palette.textTertiary;
    final String symbolText = money.currency.symbolFor(
      isDefaultCurrency: money.currency == formatting.defaultCurrency,
    );

    // The shared formatter prints `−₹ 39,200`: the sign leads, then the symbol,
    // then the digits. This widget draws the parts itself so it can size the
    // symbol down, which means it has to place the sign the same way — drawing it
    // inside the digit run would read as "rupees, minus thirty-nine thousand".
    final String sign = money.isNegative ? '−' : '';

    final TextStyle digitStyle = TextStyle(
      fontFamily: AppTypography.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      height: 1.05,
      color: digits,
      fontFeatures: AppTypography.moneyFeatures,
    );

    return Semantics(
      label: formatting.money.format(money),
      excludeSemantics: true,
      child: Row(
        // Forced left-to-right whatever the interface language: an amount is one
        // unit, and the rest of the app renders it the same way through the
        // shared formatter. Letting the ambient direction place the symbol would
        // print this figure differently from every other figure on the screen.
        textDirection: TextDirection.ltr,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          if (sign.isNotEmpty)
            Text(sign, textDirection: TextDirection.ltr, style: digitStyle),
          Text(
            symbolText,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: fontSize * 0.5,
              fontWeight: FontWeight.w500,
              height: 1,
              color: symbol,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: animate
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: money.asDouble,
                      end: money.asDouble,
                    ),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (
                      BuildContext context,
                      double value,
                      Widget? child,
                    ) {
                      final Money frame = Money(
                        (value * money.currency.minorFactor).round(),
                        money.currency,
                      );
                      return Text(
                        formatting.money.amount(frame),
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: digitStyle,
                      );
                    },
                  )
                : Text(
                    formatting.money.amount(money),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: digitStyle,
                  ),
          ),
        ],
      ),
    );
  }
}
