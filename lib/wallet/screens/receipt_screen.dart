import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../messages/voice.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'rate_sheet.dart';
import 'wrapped_screen.dart';
import '../../support/support_api.dart';
import '../../support/support_screens.dart';

/// The receipt straight after paying: it celebrates, shows the code for the driver, and points a
/// rider who paid the wrong vehicle to support (payments can't be undone in the app).
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen._({
    required this.api,
    required this.txId,
    required this.reference,
    required this.totalKobo,
    required this.passengers,
    required this.offlineCode,
    required this.at,
    required this.routeName,
    required this.plate,
    required this.status,
    required this.justPaid,
    this.driverName,
    this.balanceKobo,
    this.tripRoute,
  });

  factory ReceiptScreen.paid({required RiderApi api, required PayResult result, required Quote quote}) => ReceiptScreen._(
    api: api,
    txId: result.txId,
    reference: result.reference,
    totalKobo: result.totalKobo,
    passengers: result.passengers,
    offlineCode: result.offlineCode,
    at: DateTime.now(),
    routeName: quote.route,
    plate: quote.plate,
    driverName: quote.driverFirstName,
    tripRoute: quote.tripRoute,
    status: 'completed',
    balanceKobo: result.balanceKobo,
    justPaid: true,
  );

  final RiderApi api;
  final String txId, reference, offlineCode, routeName, plate, status;
  final String? driverName;
  final int totalKobo, passengers;
  final int? balanceKobo;
  final DateTime at;
  final TripRoute? tripRoute;
  final bool justPaid;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> with SingleTickerProviderStateMixin {
  late final String _status = widget.status;
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.justPaid) {
      _pop.forward();
      // Said out loud, so the rider (and the driver beside them) hears that it went through.
      Voice.say(
        'Payment successful. ${Voice.amount(widget.totalKobo)} paid${widget.passengers > 1 ? ' for ${widget.passengers} riders' : ''}.',
        clip: 'sounds/voice_payment_success.wav',
      );
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reversed = _status == 'reversed' || _status == 'refunded';
    return PageFrame(
      trailing: SupportButton(api: widget.api.support, txId: widget.txId),
      kicker: widget.justPaid ? 'Paid' : 'Receipt',
      title: reversed ? (_status == 'refunded' ? 'Refunded.' : 'Payment undone.') : (widget.justPaid ? 'You\'re good to go.' : naira(widget.totalKobo)),
      bottom: widget.justPaid ? KButton(label: 'Done', onTap: () => Navigator.of(context).pop()) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.justPaid && !reversed)
            Center(
              child: AnimatedBuilder(
                animation: _pop,
                builder: (_, _) => CustomPaint(size: const Size.square(120), painter: _PaidPainter(_pop.value)),
              ),
            ),
          if (widget.justPaid && !reversed) const SizedBox(height: 10),
          if (!reversed && widget.offlineCode.isNotEmpty)
            Entrance(
              delay: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    Text('SHOW THE DRIVER THIS CODE', style: KText.kicker(K.muteDark)),
                    const SizedBox(height: 10),
                    FittedBox(child: Text(widget.offlineCode.split('').join(' '), style: KText.mono(K.yellow, size: 40))),
                    const SizedBox(height: 8),
                    Text('Only if their phone didn\'t sound the alert.', textAlign: TextAlign.center, style: KText.small(K.muteDark)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Entrance(
            delay: const Duration(milliseconds: 320),
            child: Panel(
              child: Column(
                children: [
                  _row(context, 'Amount', naira(widget.totalKobo), strike: reversed),
                  _row(context, 'Riders', widget.passengers == 1 ? 'Just you' : 'You + ${widget.passengers - 1}'),
                  if (widget.driverName != null) _row(context, 'Driver', widget.driverName!),
                  if (widget.plate.isNotEmpty) _row(context, 'Vehicle', widget.plate),
                  if (widget.routeName.isNotEmpty) _row(context, 'Route', widget.routeName),
                  if (widget.tripRoute != null) _row(context, 'Trip', '${widget.tripRoute!.label} · ~${widget.tripRoute!.etaMin} min'),
                  _row(context, 'When', whenText(widget.at)),
                  _row(context, 'Reference', widget.reference, copy: true),
                  if (widget.balanceKobo != null && !reversed) _row(context, 'Wallet now', naira(widget.balanceKobo!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!reversed && widget.justPaid) ...[
            RideShareCard(api: widget.api, trip: widget.tripRoute, at: widget.at),
            const SizedBox(height: 14),
            _WrongVehicle(api: widget.api, txId: widget.txId),
          ],
          if (!reversed) RideRatingCard(api: widget.api, txId: widget.txId),
          if (!reversed) FareReportLink(api: widget.api, txId: widget.txId),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v, {bool strike = false, bool copy = false}) {
    final p = Palette.of(context);
    final value = Text(
      v,
      textAlign: TextAlign.right,
      style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700, decoration: strike ? TextDecoration.lineThrough : null),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: KText.body(p.subtle)),
          const SizedBox(width: 16),
          Expanded(
            child: copy
                ? Pressable(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: v));
                      showSnack(context, 'Reference copied');
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(child: value),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 16, color: p.subtle),
                      ],
                    ),
                  )
                : value,
          ),
        ],
      ),
    );
  }
}

/// Payments can't be undone in the app (it was used to ride for free). A rider who paid the wrong
/// vehicle talks to support, who can refund it after checking.
class _WrongVehicle extends StatelessWidget {
  const _WrongVehicle({required this.api, required this.txId});
  final RiderApi api;
  final String txId;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Pressable(
        onTap: () => pushScreen(context, NewSupportScreen(api: api.support, txId: txId, category: SupportCategory.payment)),
        child: Panel(
          child: Row(
            children: [
              const Icon(Icons.support_agent_rounded, color: K.yellowDeep),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Paid the wrong vehicle?', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Payments can\'t be undone. Contact support and we\'ll check it.', style: KText.small(p.subtle)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.subtle),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Report a problem with this payment", or where the report stands once one is open.
class FareReportLink extends StatefulWidget {
  const FareReportLink({super.key, required this.api, required this.txId});
  final RiderApi api;
  final String txId;
  @override
  State<FareReportLink> createState() => _FareReportLinkState();
}

class _FareReportLinkState extends State<FareReportLink> {
  late final _dispute = widget.api.disputeState(widget.txId);

  Future<void> _report() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DisputeSheet(api: widget.api, txId: widget.txId),
    );
    if (done == true && mounted) showSnack(context, 'Reported. We\'ll look into it within 3 days.');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<String?>(
      stream: _dispute,
      builder: (_, s) {
        final state = s.data;
        if (state != null) {
          return Panel(
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: K.yellowDeep),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state == 'open' || state == 'in_review'
                        ? 'You reported this payment. We\'ll update you within 3 days.'
                        : 'Your report on this payment was closed.',
                    style: KText.small(p.text),
                  ),
                ),
              ],
            ),
          );
        }
        return Center(
          child: Pressable(
            onTap: _report,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Report a problem with this payment', style: KText.small(p.subtle).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        );
      },
    );
  }
}

/// Green disc that springs in and draws its tick.
class _PaidPainter extends CustomPainter {
  _PaidPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final pop = K.springy.transform((t / 0.5).clamp(0, 1));
    canvas.drawCircle(c, 58 * pop, Paint()..color = K.go.withValues(alpha: 0.2 * pop));
    canvas.drawCircle(c, 46 * pop, Paint()..color = K.go);
    final draw = ((t - 0.4) / 0.45).clamp(0.0, 1.0);
    if (draw == 0) return;
    final path = Path()
      ..moveTo(c.dx - 19, c.dy + 1)
      ..lineTo(c.dx - 5, c.dy + 15)
      ..lineTo(c.dx + 21, c.dy - 13);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * Curves.easeOut.transform(draw)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PaidPainter old) => old.t != t;
}

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({required this.api, required this.txId});
  final RiderApi api;
  final String txId;
  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  DisputeReason? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.openDispute(txId: widget.txId, reason: _reason!, note: _note.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: SingleChildScrollView(
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
              Text('What went wrong?', style: KText.h3(p.text)),
              const SizedBox(height: 12),
              for (final r in DisputeReason.values)
                Pressable(
                  scale: 0.98,
                  onTap: () => setState(() => _reason = r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _reason == r ? K.yellow.withValues(alpha: 0.2) : p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _reason == r ? K.yellowDeep : p.border, width: _reason == r ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(r.label, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (_reason == r) const Icon(Icons.check_circle_rounded, color: K.yellowDeep),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              TextField(
                controller: _note,
                maxLength: 500,
                maxLines: 3,
                minLines: 2,
                style: KText.body(p.text),
                decoration: InputDecoration(
                  hintText: 'Anything that helps us (optional)',
                  hintStyle: KText.body(p.subtle),
                  filled: true,
                  fillColor: p.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: p.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: K.yellowDeep, width: 2),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: KText.small(K.coral)),
                ),
              KButton(label: 'Send report', loading: _busy, onTap: _reason == null ? null : _send),
            ],
          ),
        ),
      ),
    );
  }
}
