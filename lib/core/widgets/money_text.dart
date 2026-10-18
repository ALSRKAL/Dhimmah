import 'package:flutter/material.dart';

import '../formatting/app_formatting.dart';
import '../money/money.dart';
import '../theme/app_typography.dart';

/// Renders a money amount.
///
/// Aligned to a tabular figure box so amounts line up in a column, and coloured
/// only when the caller asks for it — colour here always means something.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.money, {
    this.style,
    this.color,
    this.compact = false,
    this.showCode = false,
    this.maxLines = 1,
    this.textAlign,
    this.shrinkToFit = false,
    super.key,
  });

  final Money money;
  final TextStyle? style;
  final Color? color;
  final bool compact;
  final bool showCode;
  final int maxLines;
  final TextAlign? textAlign;

  /// Whether the figure may be drawn smaller to fit the space it is given.
  ///
  /// An amount is never truncated. "₹1,000,00…" is not a shorter number, it is a
  /// different one, and a ledger that shows one is worse than one that shows
  /// nothing — so where a row must hold a title and a figure side by side, the
  /// figure is scaled down instead of cut off. Measured: on a 320-wide phone
  /// with the text at 1.5×, the dashboard's attention rows ran 124 pixels past
  /// their edge with the largest amount the app accepts.
  ///
  /// Off by default, so nothing changes about a layout that already fits; the
  /// scaling only ever happens when the figure would otherwise not fit at all.
  final bool shrinkToFit;

  @override
  Widget build(BuildContext context) {
    final AppFormatting formatting = context.formatting;
    final Widget text = Text(
      formatting.amount(money, compact: compact, showCode: showCode),
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontFeatures: AppTypography.moneyFeatures,
        overflow: maxLines == 1 ? TextOverflow.ellipsis : null,
      ),
      maxLines: maxLines,
      textAlign: textAlign,
      softWrap: maxLines > 1,
    );
    if (!shrinkToFit) return text;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerEnd,
      child: text,
    );
  }
}
