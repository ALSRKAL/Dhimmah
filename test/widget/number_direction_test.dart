import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/pin_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Numbers do not mirror, in any language.
///
/// This is the one place where "the app is Arabic, so lay it out from the right"
/// is the wrong answer. A dialer puts 1 at the top left in Cairo exactly as it
/// does in London, and a PIN is a sequence of digits read left to right. The
/// keypad was laid out with the ambient direction, so the top row printed
/// `3 2 1` and the dots filled from the wrong end — a four-digit code read
/// backwards to the person typing it.
void main() {
  /// Pumps [child] inside the real app theme, in Arabic, as the app runs it.
  Future<void> pumpArabic(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  group('the PIN keypad', () {
    testWidgets('reads 1 2 3 from the left', (WidgetTester tester) async {
      await pumpArabic(
        tester,
        PinKeypad(onDigit: (int _) {}, onBackspace: () {}),
      );

      final double one = tester.getCenter(find.text('1')).dx;
      final double two = tester.getCenter(find.text('2')).dx;
      final double three = tester.getCenter(find.text('3')).dx;
      expect(one, lessThan(two));
      expect(two, lessThan(three));
    });

    testWidgets('has every row in ascending order', (WidgetTester tester) async {
      await pumpArabic(
        tester,
        PinKeypad(onDigit: (int _) {}, onBackspace: () {}),
      );

      for (final List<String> row in <List<String>>[
        <String>['1', '2', '3'],
        <String>['4', '5', '6'],
        <String>['7', '8', '9'],
      ]) {
        final List<double> xs = <double>[
          for (final String digit in row) tester.getCenter(find.text(digit)).dx,
        ];
        expect(
          xs,
          orderedEquals(<double>[...xs]..sort()),
          reason: 'row $row is not left to right: $xs',
        );
      }
    });

    testWidgets('puts 0 in the middle of the bottom row',
        (WidgetTester tester) async {
      await pumpArabic(
        tester,
        PinKeypad(onDigit: (int _) {}, onBackspace: () {}),
      );

      final double zero = tester.getCenter(find.text('0')).dx;
      final double backspace =
          tester.getCenter(find.byIcon(Icons.backspace_outlined)).dx;
      final double eight = tester.getCenter(find.text('8')).dx;
      // Directly under the middle column, with the backspace to its right.
      expect(zero, closeTo(eight, 1));
      expect(backspace, greaterThan(zero));
    });
  });

  group('the PIN dots', () {
    testWidgets('fill from the left', (WidgetTester tester) async {
      await pumpArabic(tester, const PinDots(filled: 1, length: 4));

      final List<Rect> dots = <Rect>[
        for (final Element element in tester.elementList(
          find.byType(AnimatedContainer),
        ))
          tester.getRect(find.byElementPredicate((Element e) => e == element)),
      ];
      expect(dots, hasLength(4));
      expect(dots[0].left, lessThan(dots[1].left));

      // The first dot is the one that is filled.
      final AnimatedContainer first =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).first;
      final BoxDecoration decoration = first.decoration! as BoxDecoration;
      expect(decoration.color, isNot(equals(const Color(0xFFE5E1DA))));
    });
  });
}
