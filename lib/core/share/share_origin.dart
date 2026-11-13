import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

/// Where a share sheet points when nothing more precise is known.
///
/// A phone slides its share sheet up from the bottom and needs no anchor. A
/// tablet shows it as a popover, which has to point at something — and on an
/// iPad a share with no anchor does not open at all: the request fails and the
/// user sees nothing happen. Every share the app makes therefore carries one.
///
/// A caller that knows which button was pressed should pass that button's own
/// rectangle. The services that share on a screen's behalf do not have it, and
/// use this instead: a point in the middle of the screen, which is inside the
/// view on every device and puts the popover where the eye already is.
Rect shareOriginFallback() {
  final Iterable<FlutterView> views =
      WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
  final FlutterView view = views.first;
  final Size size = view.physicalSize / view.devicePixelRatio;
  if (size.isEmpty) return const Rect.fromLTWH(0, 0, 1, 1);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

/// The rectangle a widget occupies on screen, or [shareOriginFallback] when it
/// has not been laid out.
Rect shareOriginOf(BuildContext context) {
  final RenderObject? object = context.findRenderObject();
  if (object is! RenderBox || !object.hasSize || object.size.isEmpty) {
    return shareOriginFallback();
  }
  return object.localToGlobal(Offset.zero) & object.size;
}
