import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/text_direction.dart';

/// What a [DirectionalField] hands the text field it builds.
@immutable
class FieldLayout {
  const FieldLayout({
    required this.controller,
    required this.direction,
    required this.align,
    required this.onTap,
  });

  /// The field's controller: the one given, or one the wrapper owns.
  final TextEditingController controller;

  /// The direction of the text, for the field's `textDirection`.
  final TextDirection direction;

  /// The field's `textAlign`: against the app's start edge, under the label,
  /// whichever way the text itself runs.
  final TextAlign align;

  /// For the field's `onTap`.
  final VoidCallback onTap;
}

/// Keeps a text field's caret where the user puts it, in either language.
///
/// Wraps one text field and gives it, through [builder]:
///
/// * **Its direction, from its own text.** A field used to take the app's
///   direction whatever it held, so in Arabic an amount, a phone number or an
///   English name ran against its field: a trailing full stop jumped to the
///   front, and the caret logic worked backwards. The direction now follows the
///   text's first letter (see [textDirectionOf]), and the app's language while
///   the field is empty, as Android's own fields do.
/// * **A tap handler.** A tap on the empty space beside a line used to put the
///   caret at whichever character was painted nearest: in Arabic, the empty
///   space beside "1500" is next to the 1, so the next digit landed at the
///   start, and beside «دفعة 500» it is next to the 5, in the middle. That tap
///   now continues the line from its end ([caretForTapBesideLine]); a tap on
///   the characters still goes exactly where it lands.
///
/// [direction] fixes the direction instead: an amount is written left to right
/// whatever it holds.
class DirectionalField extends StatefulWidget {
  const DirectionalField({
    required this.builder,
    this.controller,
    this.direction,
    super.key,
  });

  /// Null lets the wrapper own one, as a text field would.
  final TextEditingController? controller;

  /// Replaces the direction read from the text.
  final TextDirection? direction;

  final Widget Function(BuildContext context, FieldLayout field) builder;

  @override
  State<DirectionalField> createState() => _DirectionalFieldState();
}

class _DirectionalFieldState extends State<DirectionalField> {
  TextEditingController? _owned;

  /// The app's direction, as of the last build.
  TextDirection _ambient = TextDirection.ltr;

  /// The direction the field was last built with.
  TextDirection? _built;

  /// Where the last touch went down: the point the framework placed the caret
  /// from.
  Offset? _lastDown;

  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_textChanged);
  }

  @override
  void didUpdateWidget(DirectionalField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final TextEditingController previous = oldWidget.controller ?? _owned!;
    if (previous != _controller) {
      previous.removeListener(_textChanged);
      _controller.addListener(_textChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_textChanged);
    _owned?.dispose();
    super.dispose();
  }

  TextDirection _directionFor(String text) =>
      widget.direction ?? textDirectionOf(text, fallback: _ambient);

  /// Rebuilds when the direction turns, not on every keystroke.
  void _textChanged() {
    if (_directionFor(_controller.text) != _built) setState(() {});
  }

  /// Runs after the framework has placed the caret for a tap.
  void _tapped() {
    final Offset? down = _lastDown;
    final RenderEditable? editable = _findEditable();
    if (down == null || editable == null) return;
    final TextEditingValue value = _controller.value;
    final TextSelection selection = value.selection;
    if (value.text.isEmpty || !selection.isValid || !selection.isCollapsed) {
      return;
    }

    final TextSelection line = editable.getLineAtOffset(selection.extent);
    final List<TextBox> boxes = editable.getBoxesForSelection(line);
    if (boxes.isEmpty) return;
    double left = boxes.first.left;
    double right = boxes.first.right;
    for (final TextBox box in boxes) {
      if (box.left < left) left = box.left;
      if (box.right > right) right = box.right;
    }

    final TextSelection? moved = caretForTapBesideLine(
      tapX: editable.globalToLocal(down).dx,
      lineLeft: left,
      lineRight: right,
      line: TextRange(start: line.start, end: line.end),
      direction: editable.textDirection,
      alignedToStart:
          isAlignedToStart(editable.textAlign, editable.textDirection),
    );
    if (moved != null && moved != selection) _controller.selection = moved;
  }

  RenderEditable? _findEditable() {
    RenderEditable? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderEditable) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    final RenderObject? root = context.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  @override
  Widget build(BuildContext context) {
    _ambient = Directionality.of(context);
    final TextDirection direction = _directionFor(_controller.text);
    _built = direction;
    return Listener(
      onPointerDown: (PointerDownEvent event) => _lastDown = event.position,
      child: widget.builder(
        context,
        FieldLayout(
          controller: _controller,
          direction: direction,
          align: _ambient == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,
          onTap: _tapped,
        ),
      ),
    );
  }
}
