import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../l10n/language_sheet.dart';
import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../../ui/scene/scenes.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart, this.demo = false});
  final VoidCallback onStart;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: K.ink,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: h * 0.5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ParkScene(),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const KMark(size: 34),
                          const SizedBox(width: 9),
                          Text('konduct', style: KText.h3(K.paper).copyWith(fontWeight: FontWeight.w800, fontSize: 22)),
                          const Spacer(),
                          if (demo) const DemoBadge(),
                          const SizedBox(width: 8),
                          const _LanguageButton(),
                        ],
                      ),
                    ),
                  ),
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
                      Entrance(
                        child: Text('CASHLESS CAMPUS RIDES', style: KText.kicker(K.muteDark)),
                      ),
                      const SizedBox(height: 12),
                      Entrance(
                        delay: const Duration(milliseconds: 80),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Scan the bus.\n'),
                            TextSpan(text: 'Skip the change.', style: const TextStyle(color: K.yellow)),
                          ]),
                          style: KText.hero(K.paper),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Entrance(delay: const Duration(milliseconds: 160), child: _Ticker(items: _riderPoints)),
                      const Spacer(),
                      Entrance(
                        delay: const Duration(milliseconds: 240),
                        child: KButton(label: 'Get started', icon: Icons.arrow_forward_rounded, onTap: onStart),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Cash still works on every bus. Switch when it suits you.',
                          textAlign: TextAlign.center,
                          style: KText.small(K.muteDark),
                        ),
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

const _riderPoints = ['No change needed, ever', 'Pay for your squad in one scan', 'The driver is paid in seconds', 'Same receipt on both phones'];

/// Cycles one benefit at a time with a rolling transition.
class _Ticker extends StatefulWidget {
  const _Ticker({required this.items});
  final List<String> items;
  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  int _i = 0;
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2400), (_) => setState(() => _i = (_i + 1) % widget.items.length));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: K.outExpo,
        transitionBuilder: (child, a) => ClipRect(
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
        ),
        layoutBuilder: (cur, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?cur]),
        child: Row(
          key: ValueKey(_i),
          children: [
            Container(width: 20, height: 20, decoration: BoxDecoration(color: K.go.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 14, color: K.go)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(widget.items[_i], maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.body(const Color(0xFFD5D9DE)).copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's language, before signing up: shows the current one in its own name.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr('Language'),
    child: Pressable(
      onTap: () => pickLanguage(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.translate_rounded, color: K.paper, size: 16),
            const SizedBox(width: 6),
            Text(L10nScope.watch(context).nativeName, translate: false, style: KText.small(K.paper).copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}
