import 'package:dhimmah/core/utils/text_direction.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which way typed text runs, and where a tap beside it leaves the caret.
void main() {
  group('the first letter decides the direction', () {
    TextDirection of(String text, [TextDirection fallback = TextDirection.rtl]) =>
        textDirectionOf(text, fallback: fallback);

    test('Arabic runs right to left, other scripts left to right', () {
      expect(of('أحمد', TextDirection.ltr), TextDirection.rtl);
      expect(of('Ahmed'), TextDirection.ltr);
      expect(of('Ωmega'), TextDirection.ltr);
    });

    test('the first letter wins in mixed text', () {
      expect(of('دفعة 500 for Ali', TextDirection.ltr), TextDirection.rtl);
      expect(of('500 Ahmed علي'), TextDirection.ltr);
      expect(of('(٥٠٠) ريال', TextDirection.ltr), TextDirection.rtl);
    });

    test('numbers alone run left to right, in either digit system', () {
      expect(of('1500'), TextDirection.ltr);
      expect(of('+967 771 234 567'), TextDirection.ltr);
      expect(of('١٥٠٠'), TextDirection.ltr);
      expect(of('۱۲۳'), TextDirection.ltr);
    });

    test('nothing to go by keeps the app language', () {
      expect(of(''), TextDirection.rtl);
      expect(of('', TextDirection.ltr), TextDirection.ltr);
      expect(of(' - . '), TextDirection.rtl);
    });
  });

  group('a tap beside a line', () {
    const TextRange line = TextRange(start: 0, end: 8);

    TextSelection? tap(
      double x, {
      TextDirection direction = TextDirection.rtl,
      bool alignedToStart = true,
    }) =>
        caretForTapBesideLine(
          tapX: x,
          lineLeft: 100,
          lineRight: 300,
          line: line,
          direction: direction,
          alignedToStart: alignedToStart,
        );

    test('on the text leaves the framework its choice', () {
      expect(tap(150), isNull);
      expect(tap(100), isNull);
      expect(tap(300), isNull);
    });

    test('past the end goes to the end', () {
      expect(tap(40)!.baseOffset, 8, reason: 'left of right-to-left text');
      expect(tap(360, direction: TextDirection.ltr)!.baseOffset, 8);
    });

    test('in the margin before a start-aligned line goes to the start', () {
      expect(tap(320)!.baseOffset, 0);
      expect(tap(60, direction: TextDirection.ltr)!.baseOffset, 0);
    });

    test('before a line aligned away from its start goes to the end', () {
      // An English name under an Arabic label: left to right, aligned right,
      // so the empty stretch is on its left, before its first letter.
      expect(
        tap(40, direction: TextDirection.ltr, alignedToStart: false)!
            .baseOffset,
        8,
      );
    });
  });

  test('alignment is read against the paragraph direction', () {
    expect(isAlignedToStart(TextAlign.start, TextDirection.rtl), isTrue);
    expect(isAlignedToStart(TextAlign.right, TextDirection.rtl), isTrue);
    expect(isAlignedToStart(TextAlign.right, TextDirection.ltr), isFalse);
    expect(isAlignedToStart(TextAlign.left, TextDirection.ltr), isTrue);
    expect(isAlignedToStart(TextAlign.end, TextDirection.ltr), isFalse);
  });
}
