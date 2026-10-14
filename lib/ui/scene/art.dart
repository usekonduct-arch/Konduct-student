import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Canvas ports of the landing page's SVG art (konduct-landing/src/components/art).
/// Bus local box is 562 x 240, facing right, wheels touching y = 236.

const _glassDark = Color(0xFF1B222B);
const _tyre = Color(0xFF07090B);

final _textCache = <String, TextPainter>{};
TextPainter _label(String text, TextStyle style) => _textCache.putIfAbsent('$text${style.hashCode}', () => TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout());

Paint _fill(Color c) => Paint()..color = c;

final Path _busBody = Path()
  ..moveTo(30, 30)
  ..lineTo(468, 30)
  ..quadraticBezierTo(496, 30, 511, 52)
  ..lineTo(548, 112)
  ..quadraticBezierTo(557, 125, 557, 143)
  ..lineTo(557, 188)
  ..quadraticBezierTo(557, 200, 545, 200)
  ..lineTo(18, 200)
  ..quadraticBezierTo(8, 200, 8, 188)
  ..lineTo(8, 52)
  ..quadraticBezierTo(8, 30, 30, 30)
  ..close();

final Path _windshield = Path()
  ..moveTo(490, 44)
  ..lineTo(505, 44)
  ..quadraticBezierTo(512, 44, 516, 51)
  ..lineTo(547, 108)
  ..quadraticBezierTo(549, 114, 543, 114)
  ..lineTo(490, 114)
  ..close();

const seatColors = [Color(0xFFFF6B4A), Color(0xFF3D7BFF), Color(0xFF19B86A), Color(0xFFB483FF)];
const seatSkins = [Color(0xFF8D5524), Color(0xFF5C3A1E), Color(0xFFC68642), Color(0xFF3D2412)];
const _seatX = [222.0, 142.0, 56.0, 84.0];
const _seatWindow = [2, 1, 0, 0];
const _windows = [26.0, 106.0, 186.0];

/// [door] 0 closed .. 1 open. [seats] pop-in progress per seat (0..1).
void paintBus(
  Canvas canvas, {
  required Offset at,
  double scale = 1,
  double wheelTurns = 0,
  double door = 0,
  List<double> seats = const [],
  double bob = 0,
  String route = 'MAIN GATE ⇄ FACULTY',
}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(scale);

  canvas.drawOval(const Rect.fromLTRB(10, 230, 554, 244), _fill(Colors.black.withValues(alpha: 0.35)));

  canvas.save();
  canvas.translate(0, bob);
  // roof rack + route board
  canvas.drawRect(const Rect.fromLTWH(240, 8, 6, 24), _fill(K.ink));
  canvas.drawRect(const Rect.fromLTWH(452, 8, 6, 24), _fill(K.ink));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(226, 0, 246, 24), const Radius.circular(7)), _fill(K.ink));
  final board = _label(route, const TextStyle(fontFamily: K.mono, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.2, color: K.yellow));
  board.paint(canvas, Offset(349 - board.width / 2, 12 - board.height / 2));

  // body, skirt, stripe, sheen
  canvas.drawPath(_busBody, _fill(K.yellow));
  canvas.save();
  canvas.clipPath(_busBody);
  canvas.drawRect(const Rect.fromLTWH(0, 170, 562, 40), _fill(const Color(0xFFE3AB00)));
  canvas.drawRect(const Rect.fromLTWH(0, 160, 562, 10), _fill(K.ink));
  canvas.drawRect(const Rect.fromLTWH(0, 30, 562, 14), _fill(Colors.white.withValues(alpha: 0.22)));
  canvas.restore();

  // windows and seated riders
  for (var w = 0; w < 3; w++) {
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(_windows[w], 44, 72, 70), const Radius.circular(9));
    canvas.drawRRect(r, _fill(_glassDark));
    canvas.save();
    canvas.clipRRect(r);
    for (var s = 0; s < 4; s++) {
      final p = s < seats.length ? seats[s] : 0.0;
      if (_seatWindow[s] != w || p <= 0) continue;
      final k = K.springy.transform(p.clamp(0, 1));
      canvas.save();
      canvas.translate(_seatX[s], 136);
      canvas.scale(k);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, -16), width: 40, height: 32), _fill(seatColors[s]));
      canvas.drawCircle(const Offset(0, -46), 13, _fill(seatSkins[s]));
      canvas.restore();
    }
    canvas.restore();
    canvas.drawLine(Offset(_windows[w] + 10, 108), Offset(_windows[w] + 46, 50), Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
  }

  // QR sticker beside the door
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(264, 60, 44, 44), const Radius.circular(7)), _fill(Colors.white));
  final qr = _fill(K.ink);
  for (final r in const [
    [270.0, 66.0, 10.0, 10.0], [292.0, 66.0, 10.0, 10.0], [270.0, 88.0, 10.0, 10.0], [284.0, 66.0, 4.0, 4.0], [284.0, 74.0, 4.0, 8.0],
    [292.0, 82.0, 4.0, 4.0], [298.0, 80.0, 4.0, 8.0], [284.0, 88.0, 6.0, 4.0], [292.0, 92.0, 10.0, 6.0], [284.0, 96.0, 4.0, 2.0],
  ]) {
    canvas.drawRect(Rect.fromLTWH(r[0], r[1], r[2], r[3]), qr);
  }
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(264, 106, 44, 10), const Radius.circular(3)), qr);

  // doorway and folding door (folds toward the front)
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(316, 42, 74, 152), const Radius.circular(7)), _fill(_tyre));
  canvas.drawRect(const Rect.fromLTWH(322, 180, 62, 8), _fill(const Color(0xFF3A424D)));
  final dw = 74 * (1 - 0.88 * door.clamp(0, 1));
  final doorRect = Rect.fromLTWH(390 - dw, 42, dw, 152);
  canvas.drawRRect(RRect.fromRectAndRadius(doorRect, const Radius.circular(7)), _fill(K.yellow));
  canvas.drawRRect(RRect.fromRectAndRadius(doorRect, const Radius.circular(7)), Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFFC99600));
  if (dw > 20) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(390 - dw + 8, 50, dw - 16, 62), const Radius.circular(7)), _fill(_glassDark));
  }

  // driver cabin + windshield
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(398, 44, 86, 70), const Radius.circular(9)), _fill(_glassDark));
  canvas.save();
  canvas.clipRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(398, 44, 86, 70), const Radius.circular(9)));
  canvas.drawOval(Rect.fromCenter(center: const Offset(446, 118), width: 44, height: 32), _fill(const Color(0xFF2A3340)));
  canvas.drawCircle(const Offset(448, 88), 13, _fill(const Color(0xFF5C3A1E)));
  canvas.restore();
  canvas.drawPath(_windshield, Paint()
    ..shader = const LinearGradient(colors: [Color(0xFFD9F0FA), Color(0xFF8FC6DE)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        .createShader(const Rect.fromLTWH(490, 44, 60, 70)));

  // wordmark
  final mark = _label('konduct', const TextStyle(fontFamily: K.display, fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: -0.5, color: K.ink));
  mark.paint(canvas, Offset(28, 148 - mark.computeDistanceToActualBaseline(TextBaseline.alphabetic)));

  // lights, mirror, bumper
  canvas.drawCircle(const Offset(552, 156), 22, _fill(const Color(0xFFFFF6C2).withValues(alpha: 0.18)));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(541, 148, 15, 15), const Radius.circular(4)), _fill(const Color(0xFFFFF6C2)));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(8, 122, 9, 24), const Radius.circular(3)), _fill(const Color(0xFFFF4D4F)));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(548, 60, 12, 18), const Radius.circular(4)), _fill(K.ink));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 192, 564, 11), const Radius.circular(5.5)), _fill(K.ink));
  canvas.restore();

  for (final cx in const [112.0, 450.0]) {
    canvas.drawCircle(Offset(cx, 202), 40, _fill(K.ink));
    canvas.drawCircle(Offset(cx, 204), 32, _fill(_tyre));
    canvas.drawCircle(Offset(cx, 204), 19, _fill(const Color(0xFFC9CED5)));
    canvas.save();
    canvas.translate(cx, 204);
    canvas.rotate(wheelTurns * 2 * math.pi);
    final spoke = Paint()
      ..color = const Color(0xFF6B7480)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(const Offset(0, -16), const Offset(0, 16), spoke);
      canvas.rotate(math.pi / 4);
    }
    canvas.restore();
    canvas.drawCircle(Offset(cx, 204), 6, _fill(K.ink));
  }
  canvas.restore();
}

/// Distance a wheel of the bus at [scale] covers per full turn, for skid-free spinning.
double wheelCircumference(double scale) => 2 * math.pi * 32 * scale;

class Look {
  const Look(this.skin, this.shirt, this.shirtDark, this.pants, this.bag);
  final Color skin, shirt, shirtDark, pants, bag;
}

const looks = [
  Look(Color(0xFF8D5524), Color(0xFFFF6B4A), Color(0xFFD9472A), Color(0xFF26303D), K.yellow),
  Look(Color(0xFF5C3A1E), Color(0xFF3D7BFF), Color(0xFF2A5AD1), Color(0xFF1D2530), K.paper),
  Look(Color(0xFFC68642), Color(0xFF19B86A), Color(0xFF0E8A4E), Color(0xFF2C2340), K.ink),
  Look(Color(0xFF3D2412), Color(0xFFB483FF), Color(0xFF8A5AE0), Color(0xFF26303D), Color(0xFFFF6B4A)),
];

/// A student facing left, feet at [feet], ~140 units tall at scale 1.
/// [stride] is the walk cycle in radians (0 = standing), [arm] raises the phone (radians).
void paintPerson(Canvas canvas, Offset feet, Look look, {double scale = 1, double stride = 0, double arm = 0, double opacity = 1}) {
  if (opacity <= 0) return;
  canvas.save();
  canvas.translate(feet.dx, feet.dy);
  canvas.scale(scale);
  if (opacity < 1) canvas.saveLayer(const Rect.fromLTRB(-60, -160, 60, 20), Paint()..color = Colors.black.withValues(alpha: opacity));
  canvas.drawOval(const Rect.fromLTRB(-22, -5, 22, 5), _fill(Colors.black.withValues(alpha: 0.3)));
  final swing = math.sin(stride) * 0.45;
  final bob = stride == 0 ? 0.0 : -math.sin(stride * 2).abs() * 3;
  canvas.translate(0, bob);

  void leg(double angle, Color c, Color shoe) {
    canvas.save();
    canvas.translate(0, -54);
    canvas.rotate(angle);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 0, 12, 52), const Radius.circular(6)), _fill(c));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-12, 46, 20, 7), const Radius.circular(3)), _fill(shoe));
    canvas.restore();
  }

  leg(-swing, const Color(0xFF151A21), K.ink);
  leg(swing, look.pants, K.paper);
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(6, -104, 20, 42), const Radius.circular(8)), _fill(look.bag));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-17, -108, 34, 60), const Radius.circular(15)), _fill(look.shirt));
  canvas.drawCircle(const Offset(0, -124), 17, _fill(look.skin));
  canvas.drawArc(const Rect.fromLTWH(-17, -142, 34, 30), math.pi, math.pi, true, _fill(const Color(0xFF120B06)));
  canvas.drawCircle(const Offset(-10, -124), 2.2, _fill(K.ink));

  canvas.save();
  canvas.translate(0, -102);
  canvas.rotate(arm);
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, 0, 10, 44), const Radius.circular(5)), _fill(look.shirtDark));
  canvas.drawCircle(const Offset(0, 44), 6, _fill(look.skin));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-6, 42, 12, 18), const Radius.circular(3)), _fill(K.ink));
  canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, 44, 8, 12), const Radius.circular(1.5)), _fill(K.yellow));
  canvas.restore();
  if (opacity < 1) canvas.restore();
  canvas.restore();
}

/// Rounded "paid" chip with a tick, centred on [c].
void paintChip(Canvas canvas, Offset c, String text, {double t = 1, Color bg = K.go}) {
  if (t <= 0) return;
  final label = _label(text, const TextStyle(fontFamily: K.body, fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white));
  final w = label.width + 64;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(K.springy.transform(t.clamp(0, 1)));
  final paint = Paint()..color = bg.withValues(alpha: t.clamp(0, 1));
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: 42), const Radius.circular(21)), paint);
  canvas.drawCircle(Offset(-w / 2 + 22, 0), 11, _fill(Colors.white));
  final tick = Path()
    ..moveTo(-w / 2 + 16, 0)
    ..lineTo(-w / 2 + 20.5, 4.5)
    ..lineTo(-w / 2 + 28.5, -4.5);
  canvas.drawPath(tick, Paint()
    ..color = bg
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round);
  label.paint(canvas, Offset(-w / 2 + 42, -label.height / 2));
  canvas.restore();
}

/// Dusk campus backdrop: sky, sun, skyline with lit windows, trees, road, curb.
/// World is 820 x 420. [scroll] shifts the buildings for a driving parallax.
void paintCampus(Canvas canvas, {double scroll = 0, double twinkle = 0, bool parkSign = true}) {
  canvas.drawRect(const Rect.fromLTWH(-2000, 0, 5000, 420), Paint()
    ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.ink, Color(0xFF1A1D27), Color(0xFF3A2A24)], stops: [0.2, 0.6, 1])
        .createShader(const Rect.fromLTWH(0, 0, 820, 300)));
  canvas.drawCircle(const Offset(600, 190), 180, Paint()
    ..shader = RadialGradient(colors: [K.yellow.withValues(alpha: 0.2), K.yellow.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: const Offset(600, 190), radius: 180)));
  canvas.drawCircle(const Offset(600, 190), 88, Paint()
    ..shader = const RadialGradient(colors: [Color(0xFFFFE066), K.yellow, Color(0xFFFF9F1A)], stops: [0, 0.7, 1]).createShader(Rect.fromCircle(center: const Offset(600, 190), radius: 88)));

  final stars = Paint()..color = K.paper;
  for (var i = 0; i < 14; i++) {
    final x = (i * 137.0) % 820, y = 20.0 + (i * 53) % 120;
    stars.color = K.paper.withValues(alpha: 0.35 + 0.65 * (0.5 + 0.5 * math.sin(twinkle * 2 * math.pi + i)));
    canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 1.8 : 1.2, stars);
  }

  void skyline(double offset, Color color, List<List<double>> b, {bool windows = false}) {
    canvas.save();
    final span = 820.0;
    final o = -(offset % span);
    for (final dx in [o, o + span]) {
      for (final r in b) {
        canvas.drawRect(Rect.fromLTWH(r[0] + dx, r[2], r[1], 300 - r[2]), _fill(color));
        if (!windows) continue;
        for (var x = r[0] + 10; x < r[0] + r[1] - 10; x += 16) {
          for (var y = r[2] + 14; y < 288; y += 20) {
            final h = ((x * 7 + y * 13).toInt()) % 9;
            canvas.drawRect(Rect.fromLTWH(x + dx, y, 7, 10), _fill(h == 0 ? K.yellow.withValues(alpha: 0.6) : const Color(0xFF252E3A)));
          }
        }
      }
    }
    canvas.restore();
  }

  skyline(scroll * 0.2, const Color(0xFF161C24), const [[20, 70, 168], [150, 80, 150], [320, 60, 140], [470, 90, 150], [640, 70, 130], [740, 80, 160]]);
  skyline(scroll * 0.4, const Color(0xFF1C232D), const [[0, 90, 206], [96, 70, 186], [176, 34, 140], [218, 110, 214], [340, 120, 196], [470, 80, 176], [560, 110, 210], [680, 70, 168], [756, 64, 200]], windows: true);
  // clock tower
  canvas.save();
  canvas.translate(-(scroll * 0.4 % 820), 0);
  for (final dx in [0.0, 820.0]) {
    canvas.drawCircle(Offset(193 + dx, 156), 8, _fill(K.yellow.withValues(alpha: 0.85)));
  }
  canvas.restore();

  // trees
  canvas.save();
  canvas.translate(-(scroll * 0.7 % 820), 0);
  for (final dx in [0.0, 820.0]) {
    for (final x in [60.0, 300.0, 520.0, 760.0]) {
      canvas.drawRect(Rect.fromLTWH(x + dx - 3, 250, 6, 50), _fill(const Color(0xFF0A5836)));
      canvas.drawCircle(Offset(x + dx, 240), 26, _fill(const Color(0xFF0E7A4B)));
      canvas.drawCircle(Offset(x + dx - 12, 252), 18, _fill(const Color(0xFF0C6B42)));
    }
  }
  canvas.restore();

  // far sidewalk, optional park canopy
  canvas.drawRect(const Rect.fromLTWH(-2000, 296, 5000, 18), _fill(const Color(0xFF232A34)));
  if (parkSign) {
    canvas.drawRect(const Rect.fromLTWH(560, 240, 6, 60), _fill(const Color(0xFF0B0E12)));
    canvas.drawRect(const Rect.fromLTWH(780, 240, 6, 60), _fill(const Color(0xFF0B0E12)));
    canvas.drawPath(Path()
      ..moveTo(546, 244)
      ..lineTo(566, 226)
      ..lineTo(786, 226)
      ..lineTo(806, 244)
      ..close(), _fill(K.yellow));
    final s = _label('KONDUCT PARK', const TextStyle(fontFamily: K.mono, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 2, color: K.ink));
    s.paint(canvas, Offset(676 - s.width / 2, 235 - s.height / 2));
  }

  // road with moving centre dashes, curb painted at the stop
  canvas.drawRect(const Rect.fromLTWH(-2000, 314, 5000, 76), _fill(const Color(0xFF1A1F26)));
  final dash = _fill(K.paper.withValues(alpha: 0.5));
  for (var x = -(scroll % 90) - 90; x < 900; x += 90) {
    canvas.drawRect(Rect.fromLTWH(x, 348, 52, 4), dash);
  }
  canvas.drawRect(const Rect.fromLTWH(-2000, 390, 5000, 40), _fill(const Color(0xFF262D37)));
  for (var i = 0; i < 40; i++) {
    final x = -(scroll % 60) + i * 30.0 - 60;
    canvas.drawRect(Rect.fromLTWH(x, 390, 30, 7), _fill(i.isEven ? K.yellow : K.ink));
  }
}
