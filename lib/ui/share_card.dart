import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/tokens.dart';
import 'kit.dart';

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
      final dir = await getTemporaryDirectory();
      final name = widget.fileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(png, flush: true);
      await Clipboard.setData(ClipboardData(text: widget.caption));
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/png')], text: widget.caption));
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

/// The dark story card: Konduct mark, a big line, details, and the tags at the bottom.
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.kicker, required this.headline, this.lines = const [], this.stats = const [], this.tags = '', this.accent = K.yellow});
  final String kicker, headline, tags;

  /// Smaller lines under the headline (a route, a date).
  final List<String> lines;

  /// Label → value pairs shown as a grid of tiles (a Wrapped summary).
  final List<(String, String)> stats;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    color: K.ink,
    padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
    child: Stack(
      children: [
        // A big faint ring in the corner, the brand's yellow.
        Positioned(
          right: -90,
          top: -70,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent.withValues(alpha: 0.18), width: 34)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const KMark(size: 34),
                const SizedBox(width: 10),
                Text('konduct', style: KText.h3(K.paper).copyWith(fontSize: 20)),
              ],
            ),
            const Spacer(),
            Text(kicker.toUpperCase(), style: KText.kicker(accent)),
            const SizedBox(height: 10),
            Text(headline, style: KText.title(K.paper).copyWith(fontSize: 38, height: 1.05)),
            for (final l in lines) ...[const SizedBox(height: 8), Text(l, style: KText.body(K.muteDark).copyWith(fontSize: 16))],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (label, value) in stats)
                    Container(
                      width: 148,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(color: K.ink2, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2A313C))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.kicker(K.muteDark).copyWith(fontSize: 9.5)),
                          const SizedBox(height: 4),
                          Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.h3(K.paper).copyWith(fontSize: 18, height: 1.15)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const Spacer(),
            Container(height: 1, color: const Color(0xFF2A313C)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Tap. Pay. Ride.', style: KText.body(accent).copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                Flexible(child: Text(tags, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: KText.small(K.muteDark))),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
