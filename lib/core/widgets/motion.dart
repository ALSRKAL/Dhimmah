import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The app's few pieces of motion. See DESIGN.md, "Motion", for the four rules
/// each of them is held to: it says something a still frame cannot, it runs
/// once, it is short, and it can be switched off.

/// A row that fades and settles into place once, a little after the one above.
///
/// For the first rows of a list the first time it is shown, so the eye is led
/// down it rather than handed everything at once. Only the first [maxRows] move:
/// a long list must not make anyone wait for row forty, and rows further down
/// are not on screen to be seen arriving anyway.
///
/// [animate] is the list's to decide. It is true while the list is appearing
/// and false afterwards, so a row scrolled away and back does not arrive again.
class ArrivingRow extends StatelessWidget {
  const ArrivingRow({
    required this.index,
    required this.child,
    this.animate = true,
    this.onArrived,
    super.key,
  });

  /// How many rows are staggered; the rest are simply there.
  static const int maxRows = 8;

  /// The pause between one row and the next.
  static const Duration stagger = Duration(milliseconds: 35);

  final int index;
  final bool animate;
  final Widget child;

  /// Called when this row has finished arriving.
  ///
  /// A list gives this to its last staggered row and stops asking for the
  /// animation when it fires. That is how "once" is kept without a timer: a
  /// timer would outlive a list that was closed half way through.
  final VoidCallback? onArrived;

  @override
  Widget build(BuildContext context) {
    if (!animate ||
        index >= maxRows ||
        MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final Duration delay = stagger * index;
    final Duration total = delay + AppMotion.normal;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: total,
      // The wait is the flat first part of the curve, so no timer is needed
      // and nothing is left pending if the list goes away mid-arrival.
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.standard,
      ),
      onEnd: onArrived,
      child: child,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      ),
    );
  }
}

/// A tick that draws itself once, inside a ring.
///
/// The one celebratory moment in the app: a payment that settles a debt in
/// full. Drawn rather than bundled as an animation file — it is two strokes —
/// and with the system's "remove animations" on it is simply a tick.
class DrawnTick extends StatelessWidget {
  const DrawnTick({required this.color, this.size = 18, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return CustomPaint(
        size: Size.square(size),
        painter: _TickPainter(progress: 1, color: color),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.slow + AppMotion.normal,
      curve: AppMotion.emphasized,
      builder: (BuildContext context, double t, Widget? child) => CustomPaint(
        size: Size.square(size),
        painter: _TickPainter(progress: t, color: color),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter({required this.progress, required this.color});

  /// 0 to 1: the ring over the first half, the tick over the second.
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double side = size.shortestSide;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double ring = (progress / 0.5).clamp(0.0, 1.0);
    final Rect bounds = Rect.fromLTWH(0, 0, side, side).deflate(side * 0.07);
    // From the top, clockwise.
    canvas.drawArc(bounds, -1.5708, 6.2832 * ring, false, stroke);

    final double tick = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);
    if (tick <= 0) return;
    // The short stroke down, then the long stroke up: the order a hand draws
    // it in, which is why the path is not mirrored for right-to-left.
    final Offset start = Offset(side * 0.30, side * 0.52);
    final Offset corner = Offset(side * 0.45, side * 0.66);
    final Offset end = Offset(side * 0.71, side * 0.37);
    final double firstLeg = (tick / 0.4).clamp(0.0, 1.0);
    final double secondLeg = ((tick - 0.4) / 0.6).clamp(0.0, 1.0);
    final Path path = Path()..moveTo(start.dx, start.dy);
    final Offset mid = Offset.lerp(start, corner, firstLeg)!;
    path.lineTo(mid.dx, mid.dy);
    if (secondLeg > 0) {
      final Offset tip = Offset.lerp(corner, end, secondLeg)!;
      path.lineTo(tip.dx, tip.dy);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
