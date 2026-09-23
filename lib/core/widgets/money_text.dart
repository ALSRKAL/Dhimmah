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
    super.key,
  });

  final Money money;
  final TextStyle? style;
  final Color? color;
  final bool compact;
  final bool showCode;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final AppFormatting formatting = context.formatting;
    return Text(
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
  }
}

