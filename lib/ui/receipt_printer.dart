import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import '../l10n/text.dart';
import '../theme/tokens.dart';
import 'kit.dart';
import 'share_file.dart';

/// The rubber stamp on a printed receipt.
enum SlipSeal {
  verified('VERIFIED', K.green),
  pending('PENDING', K.yellowDeep),
  voided('REVERSED', K.coral),
  unverified('UNVERIFIED', K.coral),
  none('', K.mute);

  const SlipSeal(this.text, this.color);
  final String text;
  final Color color;
}

class SlipLine {
  const SlipLine(this.label, this.value, {this.strong = false, this.strike = false});
  final String label, value;
  final bool strong, strike;
}

/// Everything a printed receipt says.
class Slip {
  const Slip({
    required this.heading,
    required this.amount,
    required this.when,
    this.place = '',
    this.lines = const [],
    this.totals = const [],
    this.status = '',
    this.seal = SlipSeal.none,
    this.verifyUrl,
    this.fingerprint,
    this.note,
    this.strikeAmount = false,
    this.footer = 'Thank you for riding',
  });

  final String heading, amount, when, place, status;
  final List<SlipLine> lines, totals;
  final SlipSeal seal;

  /// The public receipt check. Printed as a QR when set.
  final String? verifyUrl;

  /// The ledger entry's hash, shortened, so a printout can be matched by hand.
  final String? fingerprint;

  /// A line under the total, such as "Waiting for Bachs to confirm the payment".
  final String? note;
  final bool strikeAmount;

  /// The sign-off at the bottom of the slip.
  final String footer;
}

/// A little POS terminal that prints [slip] onto thermal paper: it "connects" while [slip]
/// loads, feeds the paper out line by line with the printer's buzz, tears it off and stamps it.
/// Tap the printer to print it again, or share the slip as an image or a PDF. With reduced
/// motion the receipt simply appears.
class ReceiptPrinter extends StatefulWidget {
  const ReceiptPrinter({super.key, required this.slip, this.onPrinted, this.fileName = 'konduct-receipt'});

  /// Must not throw: give back a receipt that says what couldn't be checked instead.
  final Future<Slip> slip;
  final VoidCallback? onPrinted;

  /// The shared file's name, without extension (for example "konduct-receipt-KD-4MX2Q9").
  final String fileName;

  @override
  State<ReceiptPrinter> createState() => _ReceiptPrinterState();
}

class _ReceiptPrinterState extends State<ReceiptPrinter> with TickerProviderStateMixin {
  /// Muting lasts until the app closes.
  static bool _muted = false;

  // Under `flutter test` there is no audio plugin to talk to.
  static final bool _silent = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static const _steps = 26;
  static const _step = Duration(milliseconds: 95); // matches the bursts in receipt_print.wav

  late final _feed = AnimationController(vsync: this, duration: _step * _steps);
  late final _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..repeat(reverse: true);
  AudioPlayer? _player;
  Slip? _slip;
  int _lastStep = -1;
  final _paperKey = GlobalKey();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _feed.addListener(_onFeed);
    _feed.addStatusListener((s) {
      if (s == AnimationStatus.completed) _tear();
    });
    // Sharing waits for the stamp to land, so the picture has it.
    _settle.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });
    _load();
  }

  @override
  void didUpdateWidget(ReceiptPrinter old) {
    super.didUpdateWidget(old);
    if (old.slip != widget.slip) _load();
  }

  @override
  void dispose() {
    _feed.dispose();
    _settle.dispose();
    _blink.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final asked = widget.slip;
    final started = DateTime.now();
    final slip = await asked;
    // Let the "connecting" light blink at least briefly, like a real terminal.
    final wait = const Duration(milliseconds: 650) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future.delayed(wait);
    if (!mounted || asked != widget.slip) return;
    setState(() => _slip = slip);
    _print();
  }

  void _print() {
    _lastStep = -1;
    _settle.value = 0;
    if (MediaQuery.of(context).disableAnimations) {
      _feed.value = 1;
      _settle.value = 1;
      widget.onPrinted?.call();
      return;
    }
    _feed.forward(from: 0);
    _play('sounds/receipt_print.wav');
  }

  void _onFeed() {
    final s = (_feed.value * _steps).floor();
    if (s == _lastStep) return;
    _lastStep = s;
    if (s.isEven && s < _steps) HapticFeedback.selectionClick();
  }

  void _tear() {
    _play('sounds/receipt_tear.wav');
    HapticFeedback.mediumImpact();
    _settle.forward(from: 0);
    widget.onPrinted?.call();
  }

  Future<void> _play(String asset) async {
    if (_muted || _silent) return;
    try {
      final p = _player ??= AudioPlayer();
      await p.setAudioContext(
        // Android: don't take audio focus from the rider's music. iOS: obey the silent switch.
        defaultTargetPlatform == TargetPlatform.iOS
            ? AudioContextConfig(respectSilence: true).build()
            : AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      await p.stop();
      await p.play(AssetSource(asset), volume: 0.75);
    } catch (_) {
      // Sound is a nicety; the receipt prints without it.
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    if (_muted) _player?.stop().catchError((_) {});
  }

  /// Image or PDF? Then renders the slip and opens the phone's share sheet (WhatsApp, Drive, email...).
  Future<void> _share() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ShareSheet(),
    );
    if (kind == null || !mounted) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    try {
      final pdf = kind == 'pdf';
      final shot = await _snapshot(background: pdf ? Colors.white : K.ink);
      final bytes = pdf ? await receiptPdf(shot.png, shot.width, shot.height, title: _slip?.heading ?? 'Receipt') : shot.png;
      final name = widget.fileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
      final file = await shareFile(bytes, name: '$name.${pdf ? 'pdf' : 'png'}', mimeType: pdf ? 'application/pdf' : 'image/png');
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          subject: 'Konduct receipt',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Couldn\'t share the receipt. Try again.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// The printed slip as a PNG, sharp (3x) and on a plain [background] with a margin, so the torn
  /// edges show.
  Future<({Uint8List png, int width, int height})> _snapshot({required Color background}) async {
    const ratio = 3.0;
    final boundary = _paperKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final paper = await boundary.toImage(pixelRatio: ratio);
    const margin = 24 * ratio;
    final w = paper.width + 2 * margin, h = paper.height + 2 * margin;
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = background)
      ..drawImage(paper, const Offset(margin, margin), Paint());
    final image = await recorder.endRecording().toImage(w.round(), h.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    paper.dispose();
    image.dispose();
    return (png: data!.buffer.asUint8List(), width: w.round(), height: h.round());
  }

  /// How far the paper is out of the slot: it moves in short jolts, one per printed line.
  double get _reveal {
    final t = _feed.value * _steps;
    final i = t.floor();
    final move = Curves.easeOut.transform(((t - i) / 0.74).clamp(0.0, 1.0));
    return ((i + move) / _steps).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final slip = _slip;
    final state = slip == null ? 'CONNECTING' : (_feed.isAnimating ? 'PRINTING' : 'READY');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Head(
          state: state,
          blink: _blink,
          busy: slip == null || _feed.isAnimating,
          muted: _muted,
          onMute: _toggleMute,
          onReprint: slip == null || _feed.isAnimating ? null : _print,
          onShare: slip == null || _feed.isAnimating || _settle.isAnimating || _sharing ? null : _share,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: slip == null
              ? const SizedBox(width: double.infinity)
              : ClipRect(
                  child: Stack(
                    children: [
                      // Room below the slip for it to drop into when it tears off.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_feed, _settle]),
                          builder: (_, child) {
                            // Torn off: the slip drops a few pixels free of the cutter, then sways still.
                            final drop = Curves.elasticOut.transform(_settle.value) * 6;
                            return FractionalTranslation(
                              translation: Offset(0, _reveal - 1),
                              child: Transform.translate(offset: Offset(0, drop), child: child),
                            );
                          },
                          child: RepaintBoundary(key: _paperKey, child: _Paper(slip: slip, stamp: _settle)),
                        ),
                      ),
                      // The dark mouth of the slot the paper comes out of.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: 14,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.state, required this.blink, required this.busy, required this.muted, required this.onMute, this.onReprint, this.onShare});
  final String state;
  final Animation<double> blink;
  final bool busy, muted;
  final VoidCallback onMute;
  final VoidCallback? onReprint, onShare;

  @override
  Widget build(BuildContext context) => Semantics(
    label: tr('Receipt printer, {state}', {'state': tr(state).toLowerCase()}),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B323D), K.ink]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 22, spreadRadius: -8, offset: const Offset(0, 12))],
        border: Border.all(color: const Color(0xFF39414D)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: blink,
                builder: (_, _) => Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: busy ? Color.lerp(K.yellow, const Color(0xFF5A4A10), blink.value) : K.go,
                    boxShadow: [BoxShadow(color: (busy ? K.yellow : K.go).withValues(alpha: 0.6), blurRadius: 8)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(child: Text('KONDUCT POS', maxLines: 1, overflow: TextOverflow.clip, softWrap: false, style: KText.kicker(K.muteDark).copyWith(fontSize: 10.5))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF9FD8A8).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(state, style: KText.kicker(const Color(0xFF9FD8A8)).copyWith(fontSize: 9.5, letterSpacing: 1.2)),
              ),
              const Spacer(),
              IconButton(
                tooltip: tr(muted ? 'Turn printer sound on' : 'Mute printer sound'),
                visualDensity: VisualDensity.compact,
                onPressed: onMute,
                icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: K.muteDark, size: 20),
              ),
              IconButton(
                tooltip: 'Print again',
                visualDensity: VisualDensity.compact,
                onPressed: onReprint,
                icon: Icon(Icons.print_rounded, color: onReprint == null ? K.mute : K.paper, size: 20),
              ),
              IconButton(
                tooltip: 'Share receipt',
                visualDensity: VisualDensity.compact,
                onPressed: onShare,
                icon: Icon(Icons.share_rounded, color: onShare == null ? K.mute : K.yellow, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The paper slot.
          Container(
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
              color: Color(0xFF040507),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ],
      ),
    ),
  );
}

const _thermal = Color(0xFFFFFEF7);
const _ink = Color(0xFF26282C);

class _Paper extends StatelessWidget {
  const _Paper({required this.slip, required this.stamp});
  final Slip slip;
  final Animation<double> stamp;

  TextStyle _mono({double size = 13, FontWeight weight = FontWeight.w500, Color color = _ink}) =>
      TextStyle(fontFamily: K.mono, fontSize: size, fontWeight: weight, color: color, height: 1.45);

  Widget _row(SlipLine l) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.label.toUpperCase(), style: _mono(size: 12, color: const Color(0xFF6A6D72))),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            l.value,
            textAlign: TextAlign.right,
            style: _mono(
              size: l.strong ? 14 : 13,
              weight: l.strong ? FontWeight.w700 : FontWeight.w500,
            ).copyWith(decoration: l.strike ? TextDecoration.lineThrough : null),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _TornEdges(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F1E7), _thermal, _thermal, Color(0xFFF7F5EC)],
            stops: [0, 0.05, 0.9, 1],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: KMark(size: 34)),
            const SizedBox(height: 8),
            Text(
              'KONDUCT',
              textAlign: TextAlign.center,
              style: _mono(size: 18, weight: FontWeight.w700).copyWith(letterSpacing: 5),
            ),
            if (slip.place.isNotEmpty)
              Text(
                slip.place.toUpperCase(),
                textAlign: TextAlign.center,
                style: _mono(size: 11, color: const Color(0xFF6A6D72)),
              ),
            const _Dashes(),
            Text(
              slip.heading.toUpperCase(),
              textAlign: TextAlign.center,
              style: _mono(size: 14, weight: FontWeight.w700).copyWith(letterSpacing: 1.5),
            ),
            Text(
              slip.when,
              textAlign: TextAlign.center,
              style: _mono(size: 12, color: const Color(0xFF6A6D72)),
            ),
            const _Dashes(),
            for (final l in slip.lines) _row(l),
            const _Dashes(),
            for (final l in slip.totals) _row(l),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TOTAL', style: _mono(size: 13, weight: FontWeight.w700)),
                const Spacer(),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      slip.amount,
                      style: _mono(size: 28, weight: FontWeight.w700).copyWith(decoration: slip.strikeAmount ? TextDecoration.lineThrough : null, height: 1.1),
                    ),
                  ),
                ),
              ],
            ),
            if (slip.status.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '*** ${slip.status.toUpperCase()} ***',
                textAlign: TextAlign.center,
                style: _mono(size: 13, weight: FontWeight.w700).copyWith(letterSpacing: 1),
              ),
            ],
            if (slip.seal != SlipSeal.none)
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Center(
                  child: _Stamp(seal: slip.seal, t: stamp),
                ),
              ),
            if (slip.note != null) ...[
              const SizedBox(height: 10),
              Text(
                slip.note!,
                textAlign: TextAlign.center,
                style: _mono(size: 12, color: const Color(0xFF6A6D72)),
              ),
            ],
            const _Dashes(),
            if (slip.verifyUrl != null) ...[
              Center(
                child: QrImageView(
                  data: slip.verifyUrl!,
                  size: 132,
                  padding: EdgeInsets.zero,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _ink),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _ink),
                  semanticsLabel: 'QR code to verify this receipt online',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SCAN TO VERIFY ONLINE',
                textAlign: TextAlign.center,
                style: _mono(size: 11, weight: FontWeight.w700).copyWith(letterSpacing: 1.5),
              ),
            ],
            if (slip.fingerprint != null)
              Text(
                'LEDGER ${slip.fingerprint!.toUpperCase()}',
                textAlign: TextAlign.center,
                style: _mono(size: 10, color: const Color(0xFF8A8D92)),
              ),
            if (slip.verifyUrl != null || slip.fingerprint != null) const _Dashes(),
            Text(
              slip.footer.toUpperCase(),
              textAlign: TextAlign.center,
              style: _mono(size: 12, weight: FontWeight.w700).copyWith(letterSpacing: 1.5),
            ),
            Text(
              '*  *  *',
              textAlign: TextAlign.center,
              style: _mono(size: 12, color: const Color(0xFF8A8D92)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A receipt image as a one-page PDF the width of a till roll (80 mm), as tall as the slip.
Future<Uint8List> receiptPdf(Uint8List png, int width, int height, {required String title}) {
  final pageWidth = 80 * PdfPageFormat.mm;
  final doc = pw.Document(title: 'Konduct receipt: $title', author: 'Konduct', creator: 'Konduct');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(pageWidth, pageWidth * height / width),
      build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
    ),
  );
  return doc.save();
}

/// "Share as an image or a PDF?" Returns 'image' or 'pdf'.
class _ShareSheet extends StatelessWidget {
  const _ShareSheet();

  Widget _option(BuildContext context, {required String value, required IconData icon, required String title, required String detail}) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        scale: 0.98,
        onTap: () => Navigator.of(context).pop(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: p.text),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                    Text(detail, style: KText.small(p.subtle)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3))),
          ),
          const SizedBox(height: 18),
          Text('Share this receipt', style: KText.h3(p.text)),
          const SizedBox(height: 14),
          _option(context, value: 'image', icon: Icons.image_rounded, title: 'As an image', detail: 'A picture for WhatsApp or your gallery'),
          _option(context, value: 'pdf', icon: Icons.picture_as_pdf_rounded, title: 'As a PDF', detail: 'For email, printing or your records'),
        ],
      ),
    );
  }
}

/// Thumps down onto the paper just after it tears off.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.seal, required this.t});
  final SlipSeal seal;
  final Animation<double> t;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: t,
    builder: (_, child) {
      final v = const Interval(0.3, 0.62, curve: Curves.easeIn).transform(t.value);
      return Opacity(
        opacity: v,
        child: Transform.rotate(
          angle: -0.21,
          child: Transform.scale(scale: 1.9 - 0.9 * v, child: child),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: seal.color.withValues(alpha: 0.85), width: 2.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        seal.text,
        style: TextStyle(fontFamily: K.mono, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2, color: seal.color.withValues(alpha: 0.85)),
      ),
    ),
  );
}

class _Dashes extends StatelessWidget {
  const _Dashes();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter()),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB9BBBE)
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset((x + 4).clamp(0, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

/// Zigzag top and bottom, where the slip was torn from the roll.
class _TornEdges extends CustomClipper<Path> {
  const _TornEdges();
  @override
  Path getClip(Size size) {
    const depth = 6.0;
    final teeth = (size.width / 14).floor().clamp(1, 200);
    final w = size.width / teeth;
    final p = Path()..moveTo(0, depth);
    for (var i = 0; i < teeth; i++) {
      p
        ..lineTo(i * w + w / 2, 0)
        ..lineTo((i + 1) * w, depth);
    }
    p.lineTo(size.width, size.height - depth);
    for (var i = teeth; i > 0; i--) {
      p
        ..lineTo(i * w - w / 2, size.height)
        ..lineTo((i - 1) * w, size.height - depth);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_TornEdges old) => false;
}
