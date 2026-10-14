import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../auth_repository.dart';

/// FR-AUTH-03: drivers can't self-register. After sign-in we look for the record an
/// agent created at the park. Found: the session gains the driver role and the gate
/// moves on to the PIN. Not found: explain how to get onboarded.
class DriverClaimScreen extends StatefulWidget {
  const DriverClaimScreen({super.key, required this.phone, required this.onClaim, required this.onSignOut, this.demo = false});
  final String phone;
  final Future<DriverInvite?> Function() onClaim;
  final VoidCallback onSignOut;
  final bool demo;

  @override
  State<DriverClaimScreen> createState() => _DriverClaimScreenState();
}

enum _Look { searching, notFound, failed }

class _DriverClaimScreenState extends State<DriverClaimScreen> {
  _Look _look = _Look.searching;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _look = _Look.searching;
      _error = null;
    });
    try {
      final invite = await widget.onClaim();
      if (invite == null && mounted) setState(() => _look = _Look.notFound);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _look = _Look.failed;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final searching = _look == _Look.searching;
    return FlowScaffold(
      kicker: searching ? 'One moment' : 'Driver sign-in',
      title: switch (_look) {
        _Look.searching => 'Finding your vehicle…',
        _Look.notFound => 'We don\'t have you yet.',
        _Look.failed => 'Couldn\'t check right now.',
      },
      subtitle: Text(switch (_look) {
        _Look.searching => 'Matching ${prettyPhone(widget.phone)} to a verified driver.',
        _Look.notFound => 'Drivers are signed up in person by a Konduct agent at the park, after checking your ID, vehicle and payout details.',
        _Look.failed => _error ?? 'Check your data and try again.',
      }),
      demo: widget.demo,
      bottom: searching
          ? null
          : Column(
              children: [
                KButton(label: 'Check again', icon: Icons.refresh_rounded, onTap: _run),
                const SizedBox(height: 10),
                Pressable(
                  onTap: widget.onSignOut,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Use a different number', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            ),
      child: Center(child: searching ? const _Radar() : _NotFoundCard(phone: widget.phone, look: _look)),
    );
  }
}

class _Radar extends StatefulWidget {
  const _Radar();
  @override
  State<_Radar> createState() => _RadarState();
}

class _RadarState extends State<_Radar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => CustomPaint(painter: _RadarPainter(_c.value), child: child),
          child: Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.directions_bus_filled_rounded, size: 44, color: K.ink),
            ),
          ),
        ),
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(c, 44 + 66 * p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = K.yellow.withValues(alpha: (1 - p) * 0.6));
    }
    canvas.drawArc(Rect.fromCircle(center: c, radius: 104), t * 2 * math.pi, 0.9, true, Paint()
      ..shader = SweepGradient(
        startAngle: t * 2 * math.pi,
        endAngle: t * 2 * math.pi + 0.9,
        colors: [K.yellow.withValues(alpha: 0), K.yellow.withValues(alpha: 0.28)],
        transform: GradientRotation(t * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: c, radius: 104)));
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard({required this.phone, required this.look});
  final String phone;
  final _Look look;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final steps = [
      ('Find a Konduct agent at the park', Icons.storefront_rounded),
      ('Bring your ID, vehicle papers and bank details', Icons.badge_rounded),
      ('Sign in again with ${prettyPhone(phone)}', Icons.phone_iphone_rounded),
    ];
    return Entrance(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(26), border: Border.all(color: p.border)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, (text, icon)) in steps.indexed)
              Entrance(
                delay: Duration(milliseconds: 120 * i),
                child: Padding(
                  padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(13)),
                        child: Icon(icon, color: K.ink, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(text, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
