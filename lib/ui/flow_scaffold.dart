import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/text.dart';
import '../theme/tokens.dart';
import 'kit.dart';

/// Layout shared by every sign-up step: back button, animated progress bar,
/// staggered heading, body, and a bottom area that sits above the system bar.
///
/// While the keyboard is up (or the screen is short) the heading folds away, so the
/// fields being typed into keep the room instead of being squeezed off screen.
class FlowScaffold extends StatelessWidget {
  const FlowScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.kicker,
    this.progress,
    this.onBack,
    required this.child,
    this.bottom,
    this.demo = false,
  });

  final String title;
  final Widget? subtitle;
  final String? kicker;
  final double? progress;
  final VoidCallback? onBack;
  final Widget child;
  final Widget? bottom;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, box) {
            // viewInsets covers native keyboards; the height check covers mobile browsers,
            // which shrink the page instead of reporting an inset.
            final compact = MediaQuery.viewInsetsOf(context).bottom > 0 || box.maxHeight < 560;
            return Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, compact ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (onBack != null)
                        Pressable(
                          onTap: onBack,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.border)),
                            child: Icon(Icons.arrow_back_rounded, color: p.text, size: 22),
                          ),
                        ),
                      if (progress != null) ...[
                        const SizedBox(width: 14),
                        Expanded(child: _Progress(value: progress!)),
                        const SizedBox(width: 58),
                      ] else
                        const Spacer(),
                      if (demo) const DemoBadge(),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: K.outExpo,
                  alignment: Alignment.topCenter,
                  child: compact
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 22),
                            if (kicker != null) Entrance(child: Text(kicker!.toUpperCase(), style: KText.kicker(p.subtle))),
                            if (kicker != null) const SizedBox(height: 10),
                            Entrance(delay: const Duration(milliseconds: 60), child: Text(title, style: KText.title(p.text))),
                            if (subtitle != null) ...[
                              const SizedBox(height: 10),
                              Entrance(delay: const Duration(milliseconds: 120), child: DefaultTextStyle(style: KText.body(p.subtle), child: subtitle!)),
                            ],
                          ],
                        ),
                ),
                Expanded(child: child),
                ?bottom,
              ],
            ),
          );
          }),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 8,
      decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: (value - 0.25).clamp(0, 1), end: value),
        duration: const Duration(milliseconds: 900),
        curve: K.outExpo,
        builder: (_, v, _) => FractionallySizedBox(
          widthFactor: v,
          child: Container(decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(4))),
        ),
      ),
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: K.coral, borderRadius: BorderRadius.circular(999)),
        child: const Text('DEMO', style: TextStyle(fontFamily: K.mono, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.5, color: Colors.white)),
      );
}

/// Inline error line that slides in under a field.
class ErrorLine extends StatelessWidget {
  const ErrorLine(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: K.outExpo,
        child: message == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_rounded, color: K.coral, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message!, style: KText.small(K.coral))),
                  ],
                ),
              ),
      );
}
