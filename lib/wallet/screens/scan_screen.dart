import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/connection.dart';
import '../../app/current.dart';
import '../../app/intents.dart';
import '../../l10n/l10n.dart';
import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../recent_vehicles.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'confirm_screen.dart';

/// What the rider pointed at: the sticker's QR text, or its 6-character code typed by hand.
class PaySource {
  const PaySource({this.qr, this.code});
  final String? qr, code;
}

/// Camera view with a scan frame. A Konduct sticker (K1.…) is priced by the server, then the
/// rider confirms on the next screen. Typing the sticker code works without the camera.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.api, this.demoCamera = false, this.code});
  final RiderApi api;

  /// A sticker code from a link (konduct://pay?code=…): priced straight away, no camera needed.
  final String? code;

  /// Tests and demo mode can skip the real camera.
  final bool demoCamera;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final MobileScannerController? _camera = (widget.api.isDemo || widget.demoCamera)
      ? null
      : MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.qrCode]);
  int _passengers = 1;
  bool _busy = false;
  String? _error;
  List<RecentVehicle> _recent = const [];

  @override
  void initState() {
    super.initState();
    if (Current.uid.isNotEmpty) {
      RecentVehicles.load(Current.uid).then((r) {
        if (mounted) setState(() => _recent = r);
      });
    }
    final code = widget.code;
    if (code != null && code.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _price(PaySource(code: code.toUpperCase())));
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null || _busy) return;
    // A link sticker (https://konduct.app/pay/AB12CD) opens the app from any camera; here it's just the code.
    final link = AppIntents.linkFor(Uri.tryParse(raw.trim()));
    if (link != null && link.startsWith('app:pay/')) {
      _price(PaySource(code: link.substring(8).toUpperCase()));
      return;
    }
    if (!raw.trim().startsWith('K1.')) {
      setState(() => _error = 'That isn\'t a Konduct code. Look for the yellow Konduct sticker.');
      return;
    }
    _price(PaySource(qr: raw.trim()));
  }

  Future<void> _price(PaySource src) async {
    if (_busy) return;
    if (Connection.instance.isOffline) {
      HapticFeedback.heavyImpact();
      return setState(() => _error = "You're offline. Turn on data or Wi-Fi to pay with Konduct, or pay the driver in cash.");
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _error = null;
    });
    await _camera?.stop();
    try {
      final quote = await widget.api.preview(qr: src.qr, code: src.code, passengers: _passengers);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 520),
          pageBuilder: (_, _, _) => ConfirmScreen(api: widget.api, source: src, quote: quote),
          transitionsBuilder: (_, a, _, c) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(CurvedAnimation(parent: a, curve: K.outExpo)),
              child: c,
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // Not enough seats for the whole group: offer the seats that are left on the next scan.
      final left = e.reason == 'not_enough_seats' ? (e.details['seatsLeft'] as num?)?.toInt() ?? 0 : 0;
      setState(() {
        _busy = false;
        if (left > 0) _passengers = left;
        _error = left > 0 ? '${e.message} Scan again to pay for $left.' : e.message;
      });
      await _camera?.start();
    }
  }

  Future<void> _typeCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CodeSheet(),
    );
    if (code != null) await _price(PaySource(code: code));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frame = (size.width * 0.68).clamp(200.0, 320.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_camera != null)
              MobileScanner(
                controller: _camera,
                onDetect: _onDetect,
                errorBuilder: (context, e) => _CameraProblem(
                  message: e.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Konduct needs the camera to scan stickers. Allow it in Settings, or type the code instead.'
                      : 'The camera didn\'t start. Type the code on the sticker instead.',
                ),
              )
            else
              _DemoCamera(onScan: () => _price(const PaySource(qr: 'K1.demo.1.sig'))),
            IgnorePointer(
              child: CustomPaint(painter: _FramePainter(frame, busy: _busy)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    RoundIconButton(icon: Icons.close_rounded, dark: true, tooltip: 'Close', onTap: () => Navigator.of(context).maybePop()),
                    const Spacer(),
                    if (widget.api.isDemo) const DemoBadge(),
                    if (_camera != null)
                      ValueListenableBuilder(
                        valueListenable: _camera,
                        builder: (_, state, _) => RoundIconButton(
                          icon: state.torchState == TorchState.on ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded,
                          dark: true,
                          tooltip: 'Torch',
                          onTap: _camera.toggleTorch,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment(0, -(frame / size.height) - 0.32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Scan the sticker', style: KText.title(Colors.white).copyWith(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text('It\'s on the door or behind the driver\'s seat.', textAlign: TextAlign.center, style: KText.small(Colors.white70)),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: K.ink,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: K.outExpo,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_rounded, color: K.coral, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!, style: KText.small(Colors.white))),
                                ],
                              ),
                            ),
                    ),
                    PassengerStepper(value: _passengers, onChanged: _busy ? null : (v) => setState(() => _passengers = v), dark: true),
                    if (_recent.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _RecentRow(recent: _recent, onPick: _busy ? null : (v) => _price(PaySource(qr: v.qr, code: v.qr == null ? v.code : null))),
                    ],
                    const SizedBox(height: 14),
                    Pressable(
                      onTap: _busy ? null : _typeCode,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white24),
                        ),
                        alignment: Alignment.center,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: K.yellow))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.keyboard_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Type the code instead', style: KText.body(Colors.white).copyWith(fontWeight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
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

/// "Who's riding?" You plus up to five friends (FR-GRP-01).
class PassengerStepper extends StatelessWidget {
  const PassengerStepper({super.key, required this.value, required this.onChanged, this.dark = false, this.max = 6});
  final int value, max;
  final ValueChanged<int>? onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fg = dark ? Colors.white : p.text;
    final sub = dark ? K.muteDark : p.subtle;
    Widget btn(IconData icon, int to, String label) {
      final on = onChanged != null && to >= 1 && to <= max;
      return Pressable(
        scale: 0.85,
        onTap: on ? () => onChanged!(to) : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: on ? 1 : 0.35,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: 0.1) : p.bg,
              shape: BoxShape.circle,
              border: Border.all(color: dark ? Colors.white24 : p.border),
            ),
            child: Icon(icon, color: fg, semanticLabel: tr(label)),
          ),
        ),
      );
    }

    final friends = value - 1;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WHO\'S RIDING', style: KText.kicker(sub)),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(friends == 0 ? 'Just me' : 'Me + $friends ${friends == 1 ? 'friend' : 'friends'}', key: ValueKey(value), style: KText.h3(fg)),
              ),
            ],
          ),
        ),
        btn(Icons.remove_rounded, value - 1, 'One fewer rider'),
        SizedBox(
          width: 40,
          child: Text('$value', textAlign: TextAlign.center, style: KText.mono(fg, size: 22)),
        ),
        btn(Icons.add_rounded, value + 1, 'One more rider'),
      ],
    );
  }
}

/// Dark scrim with a clear rounded square and yellow corners, like the app icon.
class _FramePainter extends CustomPainter {
  _FramePainter(this.side, {required this.busy});
  final double side;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: side, height: side), const Radius.circular(28));
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(r)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final arm = side * 0.18;
    final paint = Paint()
      ..color = busy ? K.go : K.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final rect = r.outerRect;
    for (final (x, y, sx, sy) in [
      (rect.left, rect.top, 1.0, 1.0),
      (rect.right, rect.top, -1.0, 1.0),
      (rect.left, rect.bottom, 1.0, -1.0),
      (rect.right, rect.bottom, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + sy * arm)
          ..lineTo(x, y + sy * 20)
          ..quadraticBezierTo(x, y, x + sx * 20, y)
          ..lineTo(x + sx * arm, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.side != side || old.busy != busy;
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: K.ink,
    child: Align(
      alignment: const Alignment(0, -0.1),
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, color: K.muteDark, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: KText.body(K.muteDark)),
          ],
        ),
      ),
    ),
  );
}

/// Demo mode has no camera: tap the frame to "scan" a sample shuttle.
class _DemoCamera extends StatelessWidget {
  const _DemoCamera({required this.onScan});
  final VoidCallback onScan;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onScan,
    child: Container(
      color: const Color(0xFF1B2028),
      alignment: const Alignment(0, -0.16),
      child: Text('Tap to scan a sample sticker', style: KText.small(Colors.white60)),
    ),
  );
}

/// Bottom sheet for the 6-character code printed under the QR.
class _CodeSheet extends StatefulWidget {
  const _CodeSheet();
  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String get _clean => _c.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ok = _clean.length == 6;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Type the sticker code', style: KText.h3(p.text)),
            const SizedBox(height: 4),
            Text('The 6 letters and numbers under the QR code.', style: KText.small(p.subtle)),
            const SizedBox(height: 16),
            TextField(
              controller: _c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 7,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => ok ? Navigator.of(context).pop(_clean) : null,
              style: KText.mono(p.text, size: 28).copyWith(letterSpacing: 6),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z -]'))],
              decoration: InputDecoration(
                counterText: '',
                hintText: 'A1B2C3',
                hintStyle: KText.mono(p.border, size: 28).copyWith(letterSpacing: 6),
                filled: true,
                fillColor: p.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: p.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: K.yellowDeep, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            KButton(label: 'Find vehicle', onTap: ok ? () => Navigator.of(context).pop(_clean) : null),
          ],
        ),
      ),
    );
  }
}

/// "Pay again": the last vehicles paid on this phone. The next screen shows the plate to check.
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.recent, required this.onPick});
  final List<RecentVehicle> recent;
  final ValueChanged<RecentVehicle>? onPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('PAY AGAIN', style: KText.kicker(K.muteDark)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final v in recent)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  label: tr('Pay {plate} again, driver {driver}', {'plate': v.plate, 'driver': v.driver}),
                  excludeSemantics: true,
                  child: Pressable(
                    onTap: onPick == null ? null : () => onPick!(v),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.plate, style: KText.mono(K.yellow, size: 13)),
                          const SizedBox(height: 2),
                          Text(v.driver, translate: false, maxLines: 1, style: KText.small(Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
