import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/text.dart';
import '../theme/tokens.dart';
import 'kit.dart';
import 'share_file.dart';

/// Story cards are drawn at this size and saved at 3x: 1080 × 1920, Instagram's story size.
const shareCardSize = Size(360, 640);

/// Shows [card] in a sheet with the caption, then shares it as a picture through the phone's share
/// sheet. The caption goes along as text and is copied too, because Instagram drops shared text.
Future<void> showShareCard(BuildContext context, {required Widget card, required String caption, required String fileName, String title = 'Share it'}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareCardSheet(card: card, caption: caption, fileName: fileName, title: title),
    );

class _ShareCardSheet extends StatefulWidget {
  const _ShareCardSheet({required this.card, required this.caption, required this.fileName, required this.title});
  final Widget card;
  final String caption, fileName, title;
  @override
  State<_ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<_ShareCardSheet> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      image.dispose();
      final name = widget.fileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
      final file = await shareFile(png, name: '$name.png', mimeType: 'image/png');
      await Clipboard.setData(ClipboardData(text: widget.caption));
      await SharePlus.instance.share(ShareParams(files: [file], text: widget.caption));
      if (mounted) Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Caption copied. Paste it in your post so we see it!')));
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Couldn\'t share right now. Try again.')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 14),
          Text(widget.title, style: KText.h3(p.text)),
          const SizedBox(height: 12),
          SizedBox(
            height: (height * 0.46).clamp(260.0, 460.0),
            child: FittedBox(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: RepaintBoundary(key: _key, child: SizedBox.fromSize(size: shareCardSize, child: widget.card)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
            child: Text(widget.caption, maxLines: 3, overflow: TextOverflow.ellipsis, style: KText.small(p.text)),
          ),
          const SizedBox(height: 12),
          KButton(label: 'Share', icon: Icons.share_rounded, loading: _busy, onTap: _busy ? null : _share),
        ],
      ),
    );
  }
}

/// The look of a share card: the illustrated scene behind it and the colours on top.
enum StoryStyle {
  /// Sky, the main gate and a Korope on the road: "I just rode with Konduct".
  ride('assets/share/share-ride.webp', K.ink, Color(0xFF143E94), Color(0xFF1E56C8), false),

  /// Konduct yellow, confetti and cheering students: a rider's Wrapped.
  wrapped('assets/share/share-wrapped.webp', K.ink, K.ink, Color(0xFF1E56C8), false),

  /// The campus at night with the bus lights on: a driver's Wrapped.
  driver('assets/share/share-driver.webp', K.paper, K.yellow, K.yellow, true);

  const StoryStyle(this.art, this.text, this.kicker, this.accent, this.dark);
  final String art;
  final Color text, kicker, accent;
  final bool dark;
}

/// A story-sized card (1080 × 1920 when shared) drawn over one of the brand illustrations, in the
/// style of Konduct's Instagram posts: logo, a kicker, a big headline, details or stat tiles, and
/// a footer with Konduct's tags.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.kicker,
    required this.headline,
    this.lines = const [],
    this.stats = const [],
    this.tags = '',
    this.style = StoryStyle.ride,
    this.sponsorName = '',
    this.sponsorLogoUrl = '',
  });
  final String kicker, headline, tags;

  /// A sponsor's "Brought to you by" badge (a sponsored Wrapped); empty for none. Precache the
  /// logo before sharing, so it is in the picture.
  final String sponsorName, sponsorLogoUrl;

  /// Smaller lines under the headline (a route's time, a date), shown as chips.
  final List<String> lines;

  /// Label → value pairs shown as tiles (a Wrapped summary).
  final List<(String, String)> stats;
  final StoryStyle style;

  // Its own Material: shared off-screen, there's no app around it to style the text.
  @override
  Widget build(BuildContext context) => Material(type: MaterialType.transparency, child: _card());

  Widget _card() {
    final s = style;
    final parts = headline.split('\n');
    return SizedBox.fromSize(
      size: shareCardSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(s.art, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KMark(size: 28, inverted: s == StoryStyle.wrapped),
                    const SizedBox(width: 8),
                    Text('konduct', style: KText.h3(s.text).copyWith(fontSize: 20, letterSpacing: -0.6)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: s.dark ? K.yellow : K.ink, borderRadius: BorderRadius.circular(99)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: s.dark ? K.ink : K.yellow, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('TAP · PAY · RIDE', style: KText.kicker(s.dark ? K.ink : K.yellow).copyWith(fontSize: 8.5, letterSpacing: 1.6)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(kicker.toUpperCase(), style: KText.kicker(s.kicker).copyWith(fontSize: 10.5, letterSpacing: 2.2)),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      for (final (i, p) in parts.indexed) TextSpan(text: i == 0 ? p : '\n$p', style: TextStyle(color: i == 0 ? s.text : s.accent)),
                    ],
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: KText.title(s.text).copyWith(fontSize: stats.isEmpty ? 46 : 44, height: 0.98, letterSpacing: -1.6),
                ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final l in lines)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(99)),
                          child: Text(l, style: KText.small(K.ink).copyWith(fontWeight: FontWeight.w700, fontSize: 11.5)),
                        ),
                    ],
                  ),
                ],
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (label, value) in stats.take(6))
                        Container(
                          width: 156,
                          padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                          decoration: BoxDecoration(
                            color: s.dark ? K.ink.withValues(alpha: 0.78) : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: s.dark ? const Color(0xFF2A313C) : K.ink.withValues(alpha: 0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.kicker(s.dark ? K.muteDark : K.mute).copyWith(fontSize: 8.5, letterSpacing: 1.4)),
                              const SizedBox(height: 3),
                              Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.h3(s.dark ? K.paper : K.ink).copyWith(fontSize: value.length > 14 ? 15 : 17, height: 1.15)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const Spacer(),
                if (sponsorName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: K.ink.withValues(alpha: 0.08))),
                    child: Row(
                      children: [
                        Text('BROUGHT TO YOU BY', style: KText.kicker(K.mute).copyWith(fontSize: 8.5, letterSpacing: 1.4)),
                        const SizedBox(width: 10),
                        if (sponsorLogoUrl.isNotEmpty) ...[
                          SizedBox(width: 30, height: 30, child: Image(image: CachedNetworkImageProvider(sponsorLogoUrl), fit: BoxFit.contain)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: Text(sponsorName, maxLines: 1, overflow: TextOverflow.ellipsis, translate: false, style: KText.h3(K.ink).copyWith(fontSize: 14))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF2A313C))),
                  child: Row(
                    children: [
                      const KMark(size: 20),
                      const SizedBox(width: 8),
                      Text('Tap. Pay. Ride.', style: KText.body(K.yellow).copyWith(fontWeight: FontWeight.w800, fontSize: 13.5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(tags, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: KText.small(K.paper).copyWith(fontSize: 10.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
