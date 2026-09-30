import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/theme/app_theme.dart';
import 'package:dhimmah/core/widgets/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The caret goes where the user puts it, in both languages.
///
/// In Arabic, tapping an amount field beside "1500" put the caret before the
/// 1, so the next digit landed at the front; beside «دفعة 500» it landed in the
/// middle; and in English, tapping beside an Arabic name put it at the start.
/// Measured first against a plain field, where each of those taps went to
/// offset 0 or 5 rather than to the end.
void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    required TextDirection app,
    required String text,
    bool amount = false,
  }) async {
    final TextEditingController controller = TextEditingController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: app,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: amount
                  ? AmountField(
                      label: 'amount',
                      currency: AppCurrency.inr,
                      controller: controller,
                      onChanged: (_) {},
                    )
                  : AppTextField(label: 'text', controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  RenderEditable editable(WidgetTester tester) =>
      tester.renderObject<RenderEditable>(
        find.descendant(
          of: find.byType(EditableText),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget.runtimeType.toString() == '_Editable',
          ),
        ),
      );

  /// Taps the field's empty stretch: the far side from where the text is
  /// aligned, which is the left in Arabic and the right in English.
  Future<void> tapBeside(WidgetTester tester, TextDirection app) async {
    final Rect field = tester.getRect(find.byType(EditableText));
    final double x =
        app == TextDirection.rtl ? field.left + 12 : field.right - 12;
    await tester.tapAt(Offset(x, field.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// What an IME does with one typed character: it goes in at the caret.
  Future<void> type(
    WidgetTester tester,
    TextEditingController controller,
    String character,
  ) async {
    final TextEditingValue now = controller.value;
    final String text =
        now.text.replaceRange(now.selection.start, now.selection.end, character);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: now.selection.start + character.length,
        ),
      ),
    );
    await tester.pump();
  }

  group('in Arabic', () {
    testWidgets('a tap beside an amount continues it from the end',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.rtl, text: '1500', amount: true);

      await tapBeside(tester, TextDirection.rtl);
      expect(controller.selection.baseOffset, 4);

      await type(tester, controller, '5');
      expect(controller.text, '15005', reason: 'it used to become 51500');
    });

    testWidgets('a tap between digits goes exactly there',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.rtl, text: '1500', amount: true);

      final RenderEditable render = editable(tester);
      final Rect caret =
          render.getLocalRectForCaret(const TextPosition(offset: 2));
      await tester.tapAt(render.localToGlobal(caret.center));
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.selection.baseOffset, 2);
      await type(tester, controller, '9');
      expect(controller.text, '15900');
    });

    testWidgets('an amount keeps its place beside the currency symbol',
        (WidgetTester tester) async {
      await pump(tester, app: TextDirection.rtl, text: '1500', amount: true);

      final RenderEditable render = editable(tester);
      expect(render.textDirection, TextDirection.ltr);
      expect(render.textAlign, TextAlign.right,
          reason: 'the digits stay on the Arabic start side, as before');
    });

    testWidgets('a tap beside an English name continues it from the end',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.rtl, text: 'Ahmed');

      expect(editable(tester).textDirection, TextDirection.ltr,
          reason: 'the text runs the way its letters do');
      await tapBeside(tester, TextDirection.rtl);
      expect(controller.selection.baseOffset, 5);
    });

    testWidgets('a tap beside Arabic that ends in a number goes to the end',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.rtl, text: 'دفعة 500');

      await tapBeside(tester, TextDirection.rtl);
      expect(controller.selection.baseOffset, 8,
          reason: 'it used to land at 5, between the word and the number');
    });

    testWidgets('an empty field starts in Arabic and turns with the text',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.rtl, text: '');

      expect(editable(tester).textDirection, TextDirection.rtl);
      controller.text = 'Ali';
      await tester.pump();
      expect(editable(tester).textDirection, TextDirection.ltr);
      controller.text = 'علي';
      await tester.pump();
      expect(editable(tester).textDirection, TextDirection.rtl);
    });
  });

  group('in English', () {
    testWidgets('a tap beside an Arabic name continues it from the end',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.ltr, text: 'أحمد علي');

      expect(editable(tester).textDirection, TextDirection.rtl);
      await tapBeside(tester, TextDirection.ltr);
      expect(controller.selection.baseOffset, 8,
          reason: 'it used to land at the start');
    });

    testWidgets('a tap beside an amount continues it from the end',
        (WidgetTester tester) async {
      final TextEditingController controller =
          await pump(tester, app: TextDirection.ltr, text: '1500', amount: true);

      await tapBeside(tester, TextDirection.ltr);
      expect(controller.selection.baseOffset, 4);
      expect(editable(tester).textAlign, TextAlign.left);
    });
  });
}
