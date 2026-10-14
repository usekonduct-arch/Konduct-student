import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'art.dart';

/// Lays out a fixed 820 x 420 world so it covers the box, anchored to the bottom
/// (like the landing page's `xMidYMax slice`).
void _cover(Canvas canvas, Size size, {double worldW = 820, double worldH = 420, double focusX = 410}) {
  final s = math.max(size.width / worldW, size.height / worldH);
  final visibleW = size.width / s;
  final left = (focusX - visibleW / 2).clamp(0.0, worldW - visibleW);
  canvas.translate(0, size.height - worldH * s);
  canvas.scale(s);
  canvas.translate(-left, 0);
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Looping drives a [CustomPainter] from a repeating controller and pauses when the
/// route is covered or the app is backgrounded (TickerMode).
abstract class _LoopScene extends StatefulWidget {
  const _LoopScene({super.key});
  Duration get period;
  CustomPainter painter(Animation<double> t);
  @override
  State<_LoopScene> createState() => _LoopSceneState();
}

class _LoopSceneState extends State<_LoopScene> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.repeat();
    } else {
      _c.value = 0.45;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: CustomPaint(painter: widget.painter(_c), size: Size.infinite));
}

/// Rider welcome: the shuttle pulls into the park, two students scan and board,
/// the second pays for a friend, the bus pulls away. 9s loop.
class ParkScene extends _LoopScene {
  const ParkScene({super.key});
  @override
  Duration get period => const Duration(milliseconds: 9500);
  @override
  CustomPainter painter(Animation<double> t) => _ParkPainter(t);
}

class _ParkPainter extends CustomPainter {
  _ParkPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static const busScale = 0.7, busY = 210.0, stopX = 190.0, doorX = 455.0;
  static const sticker = Offset(stopX + 286 * busScale, busY + 82 * busScale);

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    _cover(canvas, size, focusX: 470);
    paintCampus(canvas, twinkle: v * 3);

    // bus: in, stop, out
    final inP = Curves.easeOutCubic.transform(_seg(v, 0, 0.26));
    final outP = Curves.easeInCubic.transform(_seg(v, 0.8, 1));
    final startX = -460.0, endX = 900.0;
    final x = startX + (stopX - startX) * inP + (endX - stopX) * outP;
    final travelled = (x - startX);
    final moving = (v < 0.26) || (v > 0.8);
    final door = _seg(v, 0.27, 0.31) - _seg(v, 0.74, 0.78);

    // riders: three walk in from the right, then board one by one.
    // Rider 2 scans once for rider 3 (pay for a friend).
    final queue = [535.0, 600.0, 665.0];
    final boards = [0.33, 0.50, 0.62];
    final seats = <double>[];
    final people = <({Offset at, double stride, double arm, double alpha, double scale})>[];
    for (var i = 0; i < 3; i++) {
      final arrive = Curves.easeOut.transform(_seg(v, 0.02 + i * 0.03, 0.2 + i * 0.03));
      var px = 900 + (queue[i] - 900) * arrive;
      var stride = arrive > 0 && arrive < 1 ? v * 90 : 0.0;
      // shuffle forward as people ahead board
      for (var j = 0; j < i; j++) {
        final step = Curves.easeInOut.transform(_seg(v, boards[j], boards[j] + 0.04));
        px -= (queue[i - j] - queue[i - j - 1]) * step;
        if (step > 0 && step < 1) stride = v * 90;
      }
      final b = boards[i];
      final toDoor = Curves.easeInOut.transform(_seg(v, b, b + 0.04));
      px = px + (doorX - px) * toDoor;
      if (toDoor > 0 && toDoor < 1) stride = v * 90;
      final scans = i < 2;
      final armUp = scans ? _seg(v, b + 0.04, b + 0.06) - _seg(v, b + 0.1, b + 0.115) : 0.0;
      final step = _seg(v, b + (scans ? 0.115 : 0.045), b + (scans ? 0.15 : 0.08));
      final alpha = 1 - step;
      seats.add(_seg(v, b + (scans ? 0.14 : 0.075), b + (scans ? 0.17 : 0.1)) * (1 - outP * 0));
      people.add((
        at: Offset(px - 8 * step, 410 - 40 * step),
        stride: stride,
        arm: 2.45 * Curves.easeOutBack.transform(armUp.clamp(0, 1)),
        alpha: alpha,
        scale: 0.62 * (1 - 0.15 * step),
      ));
    }

    paintBus(
      canvas,
      at: Offset(x, busY),
      scale: busScale,
      wheelTurns: travelled / wheelCircumference(busScale),
      door: door,
      seats: seats,
      bob: moving ? math.sin(v * 260) * 2 : 0,
    );

    // scan beams, ping and chips
    for (var i = 0; i < 2; i++) {
      final b = boards[i] + 0.06;
      final beam = _seg(v, b, b + 0.04);
      if (beam > 0 && beam < 1) {
        final a = math.sin(beam * math.pi * 3).abs() * 0.55;
        final hand = Offset(doorX - 20, 410 - 0.62 * 132);
        canvas.drawPath(
          Path()
            ..moveTo(hand.dx, hand.dy)
            ..lineTo(sticker.dx + 14, sticker.dy - 10)
            ..lineTo(sticker.dx - 14, sticker.dy + 10)
            ..close(),
          Paint()..color = K.yellow.withValues(alpha: a),
        );
      }
      final ring = _seg(v, b + 0.02, b + 0.08);
      if (ring > 0 && ring < 1) {
        canvas.drawCircle(sticker, 12 + 40 * ring, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = K.yellow.withValues(alpha: 1 - ring));
      }
      final chipIn = _seg(v, b + 0.02, b + 0.05);
      final chipOut = _seg(v, b + 0.13, b + 0.17);
      if (chipIn > 0 && chipOut < 1) {
        paintChip(canvas, Offset(sticker.dx, 150 - 26 * chipOut), i == 0 ? '+₦200 · paid' : '+₦400 · 2 riders', t: chipIn - chipOut);
      }
    }

    for (var i = 0; i < people.length; i++) {
      final p = people[i];
      paintPerson(canvas, p.at, looks[i], scale: p.scale, stride: p.stride, arm: p.arm, opacity: p.alpha);
    }
  }

  @override
  bool shouldRepaint(_ParkPainter old) => false;
}

/// Driver side: the shuttle cruising, the campus scrolling past. Used on the driver
/// welcome and as the splash backdrop.
class DriveScene extends _LoopScene {
  const DriveScene({super.key, this.seats = 3});
  final int seats;
  @override
  Duration get period => const Duration(seconds: 6);
  @override
  CustomPainter painter(Animation<double> t) => _DrivePainter(t, seats);
}

class _DrivePainter extends CustomPainter {
  _DrivePainter(this.t, this.seats) : super(repaint: t);
  final Animation<double> t;
  final int seats;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    _cover(canvas, size, focusX: 410);
    final scroll = v * 820 * 2; // two screen-widths per loop, so the dashes loop seamlessly
    paintCampus(canvas, scroll: scroll, twinkle: v * 2, parkSign: false);
    paintBus(
      canvas,
      at: const Offset(230, 210),
      scale: 0.7,
      wheelTurns: scroll / wheelCircumference(0.7),
      seats: List.filled(seats, 1.0),
      bob: math.sin(v * 2 * math.pi * 14) * 1.6,
    );
  }

  @override
  bool shouldRepaint(_DrivePainter old) => false;
}

/// Pulsing sound rings behind the driver's "₦200 received" alert.
class SoundRings extends StatefulWidget {
  const SoundRings({super.key, required this.child, this.color = K.yellow});
  final Widget child;
  final Color color;
  @override
  State<SoundRings> createState() => _SoundRingsState();
}

class _SoundRingsState extends State<SoundRings> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RingsPainter(_c, widget.color),
        child: widget.child,
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(28));
    for (var i = 0; i < 3; i++) {
      final p = (t.value + i / 3) % 1;
      canvas.drawRRect(r.inflate(p * 34), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: (1 - p) * 0.5));
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => false;
}
