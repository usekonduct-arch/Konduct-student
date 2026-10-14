import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'receipt_screen.dart';
import 'scan_screen.dart';
import 'top_up_screen.dart';

/// Shows who the rider is about to pay (driver, plate, route, total) before any money moves.
/// The quote is the server's price; it lasts two minutes and pays once.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.api, required this.source, required this.quote});
  final RiderApi api;
  final PaySource source;
  final Quote quote;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late Quote _q = widget.quote;
  // One key per quote: a retry after a dropped connection returns the first result instead of paying twice.
  late String _key = newIdempotencyKey();
  bool _busy = false;
  bool _repricing = false;
  String? _error;
  Timer? _tick;

  RiderApi get api => widget.api;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _expired => DateTime.now().isAfter(_q.expiresAt);

  Future<void> _reprice({int? passengers}) async {
    setState(() {
      _repricing = true;
      _error = null;
    });
    try {
      final q = await api.preview(qr: widget.source.qr, code: widget.source.code, passengers: passengers ?? _q.passengers);
      if (!mounted) return;
      setState(() {
        _q = q;
        _key = newIdempotencyKey();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _repricing = false);
    }
  }

  Future<void> _pay() async {
    if (_expired) return _reprice();
    var repeat = false;
    if (_q.recentlyPaidThisVehicle) {
      final go = await _askRepeat();
      if (go != true) return;
      repeat = true;
    }
    String? pin;
    if (_q.needsPin) {
      if (!mounted) return;
      pin = await askPin(context, title: 'Enter your PIN', message: 'Payments of ₦500 and above need your PIN.');
      if (pin == null) return;
    }
    await _confirm(pin: pin, repeat: repeat);
  }

  Future<void> _confirm({String? pin, required bool repeat}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await api.confirm(quoteId: _q.quoteId, idempotencyKey: _key, pin: pin, repeatConfirmed: repeat);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, _, _) => ReceiptScreen.paid(api: api, result: r, quote: _q),
          transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      switch (e.reason) {
        case 'pin_wrong' || 'pin_required':
          final again = await askPin(context, title: 'Enter your PIN', error: e.message);
          if (again != null) await _confirm(pin: again, repeat: repeat);
        case 'repeat_scan':
          if (await _askRepeat() == true) await _confirm(pin: pin, repeat: true);
        case 'quote_expired' || 'quote_used' || 'fare_changed' || 'vehicle_changed':
          showSnack(context, e.message);
          await _reprice();
        case 'insufficient_funds':
          setState(() => _q = _withBalance((e.details['balanceKobo'] as num?)?.toInt() ?? _q.balanceKobo));
        default:
          HapticFeedback.heavyImpact();
          setState(() => _error = e.message);
      }
    }
  }

  Quote _withBalance(int balance) => Quote(
    quoteId: _q.quoteId,
    driverFirstName: _q.driverFirstName,
    plate: _q.plate,
    vehicleType: _q.vehicleType,
    route: _q.route,
    fareKobo: _q.fareKobo,
    passengers: _q.passengers,
    totalKobo: _q.totalKobo,
    balanceKobo: balance,
    insufficient: balance < _q.totalKobo,
    needsPin: _q.needsPin,
    recentlyPaidThisVehicle: _q.recentlyPaidThisVehicle,
    stickerChangedRecently: _q.stickerChangedRecently,
    expiresAt: _q.expiresAt,
  );

  Future<bool?> _askRepeat() => showDialog<bool>(
    context: context,
    builder: (context) {
      final p = Palette.of(context);
      return AlertDialog(
        backgroundColor: p.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('You paid this vehicle a few minutes ago', style: KText.h3(p.text)),
        content: Text('Are you paying for someone else now, or did you already pay for this ride?', style: KText.body(p.subtle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('I already paid', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Pay again', style: KText.body(K.yellowDeep).copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      );
    },
  );

  Future<void> _topUp() async {
    await pushScreen(context, TopUpScreen(api: api, suggestKobo: _q.totalKobo - _q.balanceKobo));
    if (mounted) await _reprice();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final left = _q.expiresAt.difference(DateTime.now());
    final bike = _q.vehicleType.toLowerCase().contains('bike');
    return PageFrame(
      kicker: 'Check before you pay',
      title: 'Pay ${_q.driverFirstName}?',
      bottom: _bottom(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Entrance(
            delay: const Duration(milliseconds: 100),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(16)),
                        child: Icon(bike ? Icons.two_wheeler_rounded : Icons.directions_bus_rounded, color: K.ink, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_q.driverFirstName, style: KText.h3(p.text)),
                            Text(bike ? 'Bike' : 'Shuttle', style: KText.small(p.subtle)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(8)),
                        child: Text(_q.plate, style: KText.mono(K.yellow, size: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(Icons.route_rounded, size: 18, color: p.subtle),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_q.route, style: KText.body(p.text))),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: p.border),
                  ),
                  PassengerStepper(
                    value: _q.passengers,
                    onChanged: _busy || _repricing ? null : (v) => _reprice(passengers: v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1, color: p.border),
                  ),
                  _line(context, 'Fare', '${naira(_q.fareKobo)} × ${_q.passengers}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Total', style: KText.h3(p.text)),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: _repricing
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: K.yellowDeep))
                            : Text(naira(_q.totalKobo), key: ValueKey(_q.totalKobo), style: KText.title(p.text).copyWith(fontSize: 30)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _line(context, 'Wallet after', _q.insufficient ? 'Not enough' : naira(_q.balanceKobo - _q.totalKobo), warn: _q.insufficient),
                ],
              ),
            ),
          ),
          if (_q.stickerChangedRecently) ...[
            const SizedBox(height: 12),
            _Warn(
              icon: Icons.warning_amber_rounded,
              text: 'This vehicle\'s sticker was replaced recently. Make sure the plate above matches the vehicle you\'re on.',
            ),
          ],
          if (_q.insufficient) ...[
            const SizedBox(height: 12),
            _Warn(
              icon: Icons.account_balance_wallet_rounded,
              text: 'You have ${naira(_q.balanceKobo)}. Top up at least ${naira(_q.totalKobo - _q.balanceKobo)} to pay this fare.',
            ),
          ],
          ErrorLine(_error),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _expired
                  ? 'This price expired. Tap below to refresh it.'
                  : 'Price held for ${left.inMinutes}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
              style: KText.small(p.subtle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom() {
    if (_q.insufficient) return KButton(label: 'Top up to pay', icon: Icons.add_rounded, onTap: _busy ? null : _topUp);
    if (_expired) return KButton(label: 'Refresh price', loading: _repricing, onTap: _reprice);
    return KButton(
      label: 'Pay ${naira(_q.totalKobo)}',
      icon: _q.needsPin ? Icons.lock_rounded : Icons.arrow_forward_rounded,
      loading: _busy,
      onTap: _repricing ? null : _pay,
    );
  }

  Widget _line(BuildContext context, String k, String v, {bool warn = false}) {
    final p = Palette.of(context);
    return Row(
      children: [
        Text(k, style: KText.body(p.subtle)),
        const Spacer(),
        Text(v, style: KText.mono(warn ? K.coral : p.text, size: 15)),
      ],
    );
  }
}

class _Warn extends StatelessWidget {
  const _Warn({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: K.yellow.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(18)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: K.ink, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: KText.small(K.ink))),
      ],
    ),
  );
}
