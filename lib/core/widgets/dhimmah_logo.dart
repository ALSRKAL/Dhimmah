import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_palette.dart';

/// The Dhimmah mark.
///
/// The identity is a picture — a green wallet holding a receipt and a coin — and
/// the app shows that picture rather than a reconstruction of it. The asset is
/// the same master `tool/generate_icons.py` derives the launcher icons from, so
/// the logo in the app and the icon on the home screen are one image.
///
/// It is drawn with [Image.asset] at the exact size asked for, so it stays crisp
/// from a 30pt header mark to an 84pt lockup on the About screen.
class DhimmahLogo extends StatelessWidget {
  const DhimmahLogo({required this.size, super.key});

  /// Width and height of the square the mark is drawn in.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/icon.png',
      width: size,
      height: size,
      // The mark is a rounded tile: it carries its own shape and needs no
      // decoration around it.
      excludeFromSemantics: true,
    );
  }
}

/// The app's name as it is set: the wordmark, with the brass rule beneath it.
///
/// The rule is one of the gold accent's two uses in the whole app (the other is
/// the terminal on the mark), so it is drawn here and nowhere else — the
/// dashboard's identity row and the first screen of onboarding are the same
/// wordmark, not two drawings of it.
class DhimmahWordmark extends StatelessWidget {
  const DhimmahWordmark({
    required this.style,
    this.alignment = CrossAxisAlignment.start,
    super.key,
  });

  final TextStyle? style;

  /// Where the rule sits under the name: at the reading edge beside other
  /// content, centred when the wordmark stands alone.
  final CrossAxisAlignment alignment;

  /// The rule's size, fixed by the design rather than scaled with the name.
  static const Size ruleSize = Size(22, 2);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(AppLocalizations.of(context).appName, style: style),
        const SizedBox(height: 3),
        Container(
          width: ruleSize.width,
          height: ruleSize.height,
          decoration: BoxDecoration(
            color: context.palette.gold,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}
