import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../../ui/scene/scenes.dart';
import '../auth_repository.dart';

/// End of sign-up: a moment of celebration, then into the wallet.
class ReadyScreen extends StatelessWidget {
  const ReadyScreen({super.key, required this.session, required this.onContinue, this.demo = false});
  final Session session;
  final VoidCallback onContinue;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final name = session.firstName.isEmpty ? 'friend' : session.firstName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: K.ink,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.42,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DriveScene(seats: 2),
                  const Align(alignment: Alignment(0, -0.62), child: _BigTick()),
                  if (demo) const SafeArea(child: Align(alignment: Alignment.topRight, child: Padding(padding: EdgeInsets.all(16), child: DemoBadge()))),
                ],
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Entrance(delay: const Duration(milliseconds: 500), child: Text('YOU\'RE ON BOARD', style: KText.kicker(K.go))),
                      const SizedBox(height: 10),
                      Entrance(delay: const Duration(milliseconds: 580), child: Text('Welcome aboard,\n$name.', style: KText.hero(K.paper))),
                      const SizedBox(height: 18),
                      Entrance(
                        delay: const Duration(milliseconds: 680),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          _Chip(Icons.alternate_email_rounded, session.email),
                          _Chip(Icons.lock_rounded, 'PIN set'),
                          _Chip(Icons.school_rounded, AppConfig.campusName),
                        ]),
                      ),
                      const Spacer(),
                      Entrance(
                        delay: const Duration(milliseconds: 780),
                        child: Text('Top up once, then scan the sticker on any Konduct shuttle or bike to pay.', style: KText.body(K.muteDark)),
                      ),
                      const SizedBox(height: 18),
                      Entrance(
                        delay: const Duration(milliseconds: 860),
                        child: KButton(label: 'Open my wallet', icon: Icons.arrow_forward_rounded, onTap: onContinue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: K.ink2, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFF2A313C))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: K.yellow),
          const SizedBox(width: 7),
          Text(text, style: KText.small(K.paper)),
        ]),
      );
}

/// Green disc that springs in and draws its tick.
class _BigTick extends StatefulWidget {
  const _BigTick();
  @override
  State<_BigTick> createState() => _BigTickState();
}

class _BigTickState extends State<_BigTick> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: const Size.square(110), painter: _TickPainter(_c.value)),
      );
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final pop = K.springy.transform((t / 0.5).clamp(0, 1));
    canvas.drawCircle(c, 55 * pop, Paint()..color = K.go.withValues(alpha: 0.25 * pop));
    canvas.drawCircle(c, 44 * pop, Paint()..color = K.go);
    final draw = ((t - 0.4) / 0.45).clamp(0.0, 1.0);
    if (draw == 0) return;
    final path = Path()
      ..moveTo(c.dx - 18, c.dy + 1)
      ..lineTo(c.dx - 5, c.dy + 14)
      ..lineTo(c.dx + 20, c.dy - 13);
    final m = path.computeMetrics().first;
    canvas.drawPath(m.extractPath(0, m.length * Curves.easeOut.transform(draw)), Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t;
}

/// Wrong app, or suspended account.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, required this.title, required this.message, required this.onSignOut});
  final String title, message;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => FlowScaffold(
        kicker: 'Heads up',
        title: title,
        subtitle: Text(message),
        bottom: KButton(label: 'Sign out', onTap: onSignOut),
        child: const Center(child: Icon(Icons.info_outline_rounded, size: 96, color: K.yellowDeep)),
      );
}
