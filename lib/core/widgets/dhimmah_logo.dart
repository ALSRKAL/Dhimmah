import 'package:flutter/material.dart';

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
