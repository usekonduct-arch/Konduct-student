import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import 'kit.dart';
import 'share_card.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "October", or "October 2025" when it isn't this year.
String monthName(DateTime m) => '${_monthNames[m.month - 1]}${m.year == DateTime.now().year ? '' : ' ${m.year}'}';

/// One full-screen page of a Wrapped story.
class WrappedSlide {
  const WrappedSlide({required this.kicker, required this.big, required this.headline, this.sub, required this.background, required this.foreground, this.icon});
  final String kicker, big, headline;
  final String? sub;
  final Color background, foreground;
  final IconData? icon;
}

/// The colours slides take in turn: ink, yellow, green, coral, sky.
const wrappedColors = <(Color, Color)>[
  (K.ink, K.paper),
  (K.yellow, K.ink),
  (Color(0xFF0B6B42), K.paper),
  (K.coral, K.ink),
  (Color(0xFF1F6F99), K.paper),
];

/// A month's Wrapped, played like a story: tap the right side for the next page, the left to go
/// back, hold to pause. It moves on by itself every few seconds. The last page is the share card.
class WrappedStory extends StatefulWidget {
  const WrappedStory({super.key, required this.slides, required this.card, required this.caption, required this.fileName});
  final List<WrappedSlide> slides;

  /// The summary card shown last and shared as a picture.
  final Widget card;
  final String caption, fileName;

  @override
  State<WrappedStory> createState() => _WrappedStoryState();
}

class _WrappedStoryState extends State<WrappedStory> with SingleTickerProviderStateMixin {
  static const _dwell = Duration(milliseconds: 5500);
  late final _clock = AnimationController(vsync: this, duration: _dwell)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });
  int _i = 0;

  int get _pages => widget.slides.length + 1;
  bool get _onCard => _i == widget.slides.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    // The share card waits for the person; so does everything when animations are off.
    if (_onCard || MediaQuery.of(context).disableAnimations) {
      _clock.value = _onCard ? 1 : 0;
      return;
    }
    _clock.forward(from: 0);
  }

  void _next() {
    if (_i >= _pages - 1) return;
    HapticFeedback.selectionClick();
    setState(() => _i++);
    _start();
  }

  void _back() {
    if (_i == 0) return _start();
    setState(() => _i--);
    _start();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _onCard ? (K.paper, K.ink) : (widget.slides[_i].background, widget.slides[_i].foreground);
    final dark = bg.computeLuminance() < 0.4;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => d.localPosition.dx < MediaQuery.sizeOf(context).width / 3 ? _back() : _next(),
          onLongPressStart: (_) => _clock.stop(),
          onLongPressEnd: (_) => _onCard ? null : _clock.forward(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            color: bg,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
                    child: Row(
                      children: [
                        for (var j = 0; j < _pages; j++) ...[
                          if (j > 0) const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 3,
                                child: AnimatedBuilder(
                                  animation: _clock,
                                  builder: (_, _) => LinearProgressIndicator(
                                    value: j < _i ? 1 : (j == _i ? _clock.value : 0),
                                    backgroundColor: fg.withValues(alpha: 0.25),
                                    valueColor: AlwaysStoppedAnimation(fg),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(Icons.close_rounded, color: fg),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 420),
                      switchInCurve: K.outExpo,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: child),
                      ),
                      child: _onCard ? _CardPage(key: const ValueKey('card'), story: widget) : _SlidePage(key: ValueKey(_i), slide: widget.slides[_i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({super.key, required this.slide});
  final WrappedSlide slide;

  @override
  Widget build(BuildContext context) {
    final fg = slide.foreground;
    return Stack(
      children: [
        if (slide.icon != null)
          Positioned(
            right: -40,
            bottom: 40,
            child: Icon(slide.icon, size: 260, color: fg.withValues(alpha: 0.08)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(slide.kicker.toUpperCase(), style: KText.kicker(fg.withValues(alpha: 0.75))),
              const SizedBox(height: 18),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: K.springy,
                builder: (_, s, child) => Transform.scale(scale: s, alignment: Alignment.centerLeft, child: child),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(slide.big, style: KText.title(fg).copyWith(fontSize: 88, height: 1)),
                ),
              ),
              const SizedBox(height: 18),
              Text(slide.headline, style: KText.title(fg).copyWith(fontSize: 30, height: 1.12)),
              if (slide.sub != null) ...[const SizedBox(height: 14), Text(slide.sub!, style: KText.body(fg.withValues(alpha: 0.8)).copyWith(fontSize: 17))],
            ],
          ),
        ),
      ],
    );
  }
}

class _CardPage extends StatelessWidget {
  const _CardPage({super.key, required this.story});
  final WrappedStory story;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
    child: Column(
      children: [
        Expanded(
          child: FittedBox(
            child: ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox.fromSize(size: shareCardSize, child: story.card)),
          ),
        ),
        const SizedBox(height: 16),
        KButton(
          label: 'Share my Wrapped',
          icon: Icons.share_rounded,
          onTap: () => showShareCard(context, card: story.card, caption: story.caption, fileName: story.fileName, title: 'Share your Wrapped'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text('Done', style: KText.body(K.ink).copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
