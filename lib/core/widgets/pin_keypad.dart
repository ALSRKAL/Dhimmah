import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

/// The four dots that show how much of a PIN has been entered.
///
/// Laid out left to right whatever the app's language. A PIN is a sequence of
/// digits, and digits run left to right in Arabic too — the field simply was not
/// mirrored, so the dots filled from the wrong end and a four-digit code read
/// backwards to the person typing it.
class PinDots extends StatelessWidget {
  const PinDots({
    required this.filled,
    required this.length,
    this.error = false,
    super.key,
  });

  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color active = error ? palette.overdue : palette.brand;

    return Semantics(
      label: '$filled / $length',
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? active : palette.border,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A large numeric keypad.
///
/// Hand-built rather than a text field: the targets are bigger, the digits are
/// always in the same place, and the PIN is never offered to the system
/// keyboard's autofill or clipboard.
///
/// The grid is laid out left to right in every language. A dialer is not
/// mirrored — 1 is at the top left in Cairo exactly as in London — and letting
/// the ambient direction flip it printed 3 2 1 across the top row, which is what
/// a person sees when they are trying to unlock their own ledger.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    super.key,
  });

  /// Null disables the keypad while a verification is in flight.
  final ValueChanged<int>? onDigit;
  final VoidCallback? onBackspace;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _grid(context),
    );
  }

  Widget _grid(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final List<String> row in <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String digit in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: _Key(
                      onTap: onDigit == null
                          ? null
                          : () => onDigit!(int.parse(digit)),
                      child: Text(
                        digit,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: SizedBox(width: 76, height: 62),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _Key(
                onTap: onDigit == null ? null : () => onDigit!(0),
                child: Text(
                  '0',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _Key(
                onTap: onBackspace,
                child: Icon(
                  Icons.backspace_outlined,
                  size: 21,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return SizedBox(
      width: 76,
      height: 62,
      child: Material(
        color: palette.surfaceMuted,
        borderRadius: AppRadius.rMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}
