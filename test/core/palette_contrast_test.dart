import 'dart:math' as math;

import 'package:dhimmah/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every colour pair the app relies on, checked against WCAG.
///
/// A palette reads as "tuned by eye", and the failures hide: a tint that looks
/// fine next to the swatch it was mixed from can be 3.2:1 on the surface it
/// actually lands on. That is not hypothetical — the onboarding discs shipped at
/// 3.23:1 before this test existed, because the wash had been mixed from the
/// icon colour instead of taken from the container token designed to pair with
/// it. Checking the numbers here is cheaper than noticing on a device.
///
/// Thresholds are WCAG 2.1: 4.5:1 for text, 3:1 for large text and meaningful
/// graphics. Icons that carry meaning are held to the text bar when they are
/// small, because at 13–20dp a 3:1 icon is not comfortably readable.
/// Relative luminance, WCAG 2.1.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

void main() {
  void expectAtLeast(Color fg, Color bg, double ratio, String what) {
    final double actual = _contrast(fg, bg);
    expect(
      actual,
      greaterThanOrEqualTo(ratio),
      reason: '$what measures ${actual.toStringAsFixed(2)}:1, '
          'below the $ratio:1 it needs',
    );
  }

  for (final ({String name, AppPalette palette}) theme in <({
    String name,
    AppPalette palette
  })>[
    (name: 'light', palette: AppPalette.light),
    (name: 'dark', palette: AppPalette.dark),
  ]) {
    final AppPalette p = theme.palette;
    final String mode = theme.name;

    group('$mode theme', () {
      test('body and secondary text clear 4.5:1 on every surface', () {
        for (final ({String name, Color surface}) s in <({
          String name,
          Color surface
        })>[
          (name: 'background', surface: p.background),
          (name: 'surface', surface: p.surface),
          (name: 'surfaceMuted', surface: p.surfaceMuted),
          (name: 'surfaceRaised', surface: p.surfaceRaised),
        ]) {
          expectAtLeast(p.textPrimary, s.surface, 4.5, 'textPrimary on ${s.name}');
          expectAtLeast(
            p.textSecondary,
            s.surface,
            4.5,
            'textSecondary on ${s.name}',
          );
        }
      });

      test('tertiary text stays readable', () {
        // Tertiary carries real content — currency codes, dates beside an
        // amount — so it is held to the text bar rather than excused as
        // decoration.
        expectAtLeast(p.textTertiary, p.background, 4.5, 'textTertiary on background');
        expectAtLeast(p.textTertiary, p.surface, 4.5, 'textTertiary on surface');
      });

      test('money semantics clear 4.5:1 on both surfaces', () {
        for (final ({String name, Color surface}) s in <({
          String name,
          Color surface
        })>[
          (name: 'background', surface: p.background),
          (name: 'surface', surface: p.surface),
        ]) {
          for (final ({String name, Color colour}) c in <({
            String name,
            Color colour
          })>[
            (name: 'owedToMe', colour: p.owedToMe),
            (name: 'iOwe', colour: p.iOwe),
            (name: 'overdue', colour: p.overdue),
            (name: 'dueSoon', colour: p.dueSoon),
            (name: 'settled', colour: p.settled),
            (name: 'neutralStatus', colour: p.neutralStatus),
          ]) {
            expectAtLeast(c.colour, s.surface, 4.5, '${c.name} on ${s.name}');
          }
        }
      });

      test('brand text on brand fills clear 4.5:1', () {
        expectAtLeast(p.textOnBrand, p.brand, 4.5, 'textOnBrand on brand');
        expectAtLeast(
          p.textOnBrand,
          p.brandStrong,
          4.5,
          'textOnBrand on brandStrong',
        );
      });

      test('every status pair clears 4.5:1 inside its own container', () {
        // These are the pairings a chip or a disc actually renders: the status
        // colour on the container tinted to sit behind it.
        for (final ({String name, Color fg, Color bg}) pair in <({
          String name,
          Color fg,
          Color bg
        })>[
          (name: 'brand', fg: p.onBrandContainer, bg: p.brandContainer),
          (name: 'gold', fg: p.gold, bg: p.goldContainer),
          (name: 'owedToMe', fg: p.owedToMe, bg: p.owedToMeContainer),
          (name: 'iOwe', fg: p.iOwe, bg: p.iOweContainer),
          (name: 'overdue', fg: p.overdue, bg: p.overdueContainer),
          (name: 'dueSoon', fg: p.dueSoon, bg: p.dueSoonContainer),
          (name: 'settled', fg: p.settled, bg: p.settledContainer),
          (
            name: 'neutralStatus',
            fg: p.neutralStatus,
            bg: p.neutralStatusContainer,
          ),
        ]) {
          expectAtLeast(
            pair.fg,
            pair.bg,
            4.5,
            '${pair.name} on its container',
          );
        }
      });

      test('container fills separate from the surfaces they sit on', () {
        // A container the same shade as the page reads as a printing error
        // rather than as a shape, so each has to be distinguishable from both.
        for (final ({String name, Color colour}) c in <({
          String name,
          Color colour
        })>[
          (name: 'brandContainer', colour: p.brandContainer),
          (name: 'owedToMeContainer', colour: p.owedToMeContainer),
          (name: 'overdueContainer', colour: p.overdueContainer),
          (name: 'dueSoonContainer', colour: p.dueSoonContainer),
        ]) {
          expectAtLeast(
            c.colour,
            p.background,
            1.03,
            '${c.name} against background',
          );
        }
      });

      test('the hero figure and its label are legible', () {
        expectAtLeast(p.textPrimary, p.background, 7, 'hero figure on background');
      });

      test('borders are visible without shouting', () {
        // A hairline is a graphic, so it only needs to be perceptible; making it
        // meet 3:1 would turn every card into a box.
        expectAtLeast(p.border, p.surface, 1.08, 'border on surface');
        expectAtLeast(p.borderStrong, p.surface, 1.2, 'borderStrong on surface');
      });
    });
  }
}
