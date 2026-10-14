import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Scales down while pressed and springs back. Wrap anything tappable.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.95, this.haptic = true});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 380),
        curve: _down ? Curves.easeOut : K.springy,
        child: widget.child,
      ),
    );
  }
}

/// Big pill button. Morphs into a spinner while [loading].
class KButton extends StatelessWidget {
  const KButton({super.key, required this.label, this.onTap, this.loading = false, this.dark = false, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool dark;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    final bg = dark ? K.ink : K.yellow;
    final fg = dark ? K.yellow : K.ink;
    return Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.4 : 1,
        child: LayoutBuilder(
          builder: (context, c) => Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: K.outExpo,
              height: 60,
              width: loading ? 60 : c.maxWidth,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [if (!dark && onTap != null) BoxShadow(color: K.yellow.withValues(alpha: 0.3), blurRadius: 22, spreadRadius: -8, offset: const Offset(0, 12))],
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: loading
                    ? SizedBox(key: const ValueKey('l'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: fg))
                    : FittedBox(
                        key: const ValueKey('t'),
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label, maxLines: 1, style: TextStyle(fontFamily: K.body, fontWeight: FontWeight.w800, fontSize: 17, color: fg)),
                              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: fg, size: 20)],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Number pad used for phone, code and PIN entry, so all three feel identical.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.onDigit, required this.onBackspace, this.enabled = true});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: Pressable(
            scale: 0.86,
            onTap: enabled ? onTap : null,
            child: Container(
              height: 62,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: label.isEmpty ? Colors.transparent : p.surface),
              alignment: Alignment.center,
              child: child ?? Text(label, style: TextStyle(fontFamily: K.display, fontWeight: FontWeight.w700, fontSize: 27, color: p.text)),
            ),
          ),
        );
    Widget row(List<String> d) => Row(children: [for (final x in d) key(x, onTap: () => onDigit(x))]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(children: [
          key(''),
          key('0', onTap: () => onDigit('0')),
          key('⌫', onTap: onBackspace, child: Icon(Icons.backspace_outlined, color: p.text, size: 24)),
        ]),
      ],
    );
  }
}

/// Call [ShakeState.shake] to wobble the child horizontally (wrong code, PIN mismatch).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.child});
  final Widget child;
  @override
  State<Shake> createState() => ShakeState();
}

class ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  void shake() {
    HapticFeedback.heavyImpact();
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(math.sin(_c.value * math.pi * 6) * 14 * (1 - _c.value), 0),
          child: child,
        ),
        child: widget.child,
      );
}

/// One-shot fade + rise on first build, after [delay]. Staggers screen content.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.dy = 24});
  final Widget child;
  final Duration delay;
  final double dy;
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: K.outExpo);
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(
        opacity: a.value.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - a.value) * widget.dy), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Boxes for a one-time code. Each filled box pops; [state] tints them.
enum SlotState { idle, busy, error, ok }

class CodeSlots extends StatelessWidget {
  const CodeSlots({super.key, required this.length, required this.value, this.state = SlotState.idle});
  final int length;
  final String value;
  final SlotState state;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final filled = i < value.length;
        final active = i == value.length && state == SlotState.idle;
        final border = switch (state) {
          SlotState.error => K.coral,
          SlotState.ok => K.go,
          _ => active ? K.yellowDeep : (filled ? p.text : p.border),
        };
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 64,
            decoration: BoxDecoration(
              color: state == SlotState.ok ? K.go.withValues(alpha: 0.12) : p.field,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: active || filled ? 2.4 : 1.4),
            ),
            alignment: Alignment.center,
            child: state == SlotState.busy
                ? _Pulse(index: i)
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: K.springy), child: c),
                    child: Text(filled ? value[i] : '', key: ValueKey('$i${filled ? value[i] : ''}'), style: KText.mono(p.text, size: 26)),
                  ),
          ),
        );
      }),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.index});
  final int index;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = (_c.value - widget.index * 0.1) % 1;
          final s = 0.5 + 0.5 * math.sin(t * math.pi);
          return Container(width: 10 * s + 4, height: 10 * s + 4, decoration: const BoxDecoration(color: K.yellowDeep, shape: BoxShape.circle));
        },
      );
}

/// PIN dots: hollow until filled, then pop to solid.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled, this.error = false});
  final int length, filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final on = i < filled;
        return AnimatedContainer(
          duration: Duration(milliseconds: on ? 380 : 180),
          curve: on ? K.springy : Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          width: on ? 22 : 18,
          height: on ? 22 : 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? (error ? K.coral : K.yellow) : Colors.transparent,
            border: Border.all(color: error ? K.coral : (on ? K.yellow : p.subtle), width: 2.4),
            boxShadow: [if (on && !error) BoxShadow(color: K.yellow.withValues(alpha: 0.5), blurRadius: 12)],
          ),
        );
      }),
    );
  }
}

/// The K mark from the landing favicon. [progress] 0..1 pops the tile and draws the K.
class KMark extends StatelessWidget {
  const KMark({super.key, this.size = 72, this.progress = 1});
  final double size, progress;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _KMarkPainter(progress));
}

class _KMarkPainter extends CustomPainter {
  _KMarkPainter(this.t);
  final double t;

  static final Path _k = Path()
    ..moveTo(17, 13)
    ..lineTo(27, 13)
    ..lineTo(27, 30)
    ..lineTo(42, 13)
    ..lineTo(54, 13)
    ..lineTo(37, 32)
    ..lineTo(55, 53)
    ..lineTo(42, 53)
    ..lineTo(27, 35)
    ..lineTo(27, 53)
    ..lineTo(17, 53)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.scale(s);
    final tile = K.springy.transform((t / 0.45).clamp(0, 1));
    canvas.save();
    canvas.translate(32, 32);
    canvas.scale(tile);
    canvas.rotate((1 - tile) * -0.6);
    canvas.translate(-32, -32);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 64, 64), const Radius.circular(16)), Paint()..color = K.yellow);
    canvas.restore();

    final draw = ((t - 0.3) / 0.45).clamp(0.0, 1.0);
    if (draw <= 0) return;
    final stroke = Paint()
      ..color = K.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;
    for (final m in _k.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * Curves.easeInOut.transform(draw)), stroke);
    }
    final fill = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
    if (fill > 0) canvas.drawPath(_k, Paint()..color = K.ink.withValues(alpha: fill));
  }

  @override
  bool shouldRepaint(_KMarkPainter old) => old.t != t;
}
