import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../ui/kit.dart';

/// K tile pops, the K draws itself, the wordmark rises, a little bus zips under it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: K.ink,
        body: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0);
            final word = K.outExpo.transform(seg(0.35, 0.8));
            final bus = Curves.easeInOutCubic.transform(seg(0.45, 1));
            return Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KMark(size: 92, progress: seg(0, 0.6)),
                      const SizedBox(height: 22),
                      ClipRect(
                        child: Transform.translate(
                          offset: Offset(0, (1 - word) * 46),
                          child: Opacity(
                            opacity: word,
                            child: Text('konduct', style: KText.hero(K.paper).copyWith(fontSize: 46)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: seg(0.6, 0.9),
                        child: Text(
                          'SCAN · PAY · RIDE',
                          style: KText.kicker(K.muteDark).copyWith(fontSize: 13, letterSpacing: 4),
                        ),
                      ),
                    ],
                  ),
                ),
                // the road and the bus dash
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 90,
                  child: LayoutBuilder(
                    builder: (context, c) => SizedBox(
                      height: 40,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 30,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: bus,
                              child: Container(height: 3, decoration: BoxDecoration(color: K.yellow.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
                            ),
                          ),
                          Positioned(left: -60 + (c.maxWidth + 60) * bus, top: 0, child: const _MiniBus()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniBus extends StatelessWidget {
  const _MiniBus();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 56,
        height: 34,
        child: Stack(
          children: [
            Container(
              height: 26,
              decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(7)),
              padding: const EdgeInsets.fromLTRB(6, 5, 12, 9),
              child: Row(
                children: List.generate(3, (_) => Expanded(child: Container(margin: const EdgeInsets.only(right: 3), decoration: BoxDecoration(color: K.ink2, borderRadius: BorderRadius.circular(2))))),
              ),
            ),
            for (final x in [9.0, 37.0])
              Positioned(left: x, top: 20, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: K.ink, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFC9CED5), width: 3)))),
          ],
        ),
      );
}
