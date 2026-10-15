import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../../ui/web_screen.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import '../../support/support_screens.dart';

const _minKobo = 20000; // ₦200, as the backend's RULES.minTopUpKobo
const _maxKobo = 5000000; // ₦50,000

/// Pick an amount, then pay on Bachs's page (card or bank transfer), inside the app. The wallet
/// is credited when Bachs confirms the payment to the backend, not when the page closes; once
/// it does close we ask the backend to check with Bachs straight away instead of waiting.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key, required this.api, this.suggestKobo});
  final RiderApi api;

  /// The shortfall on a fare, to pre-fill.
  final int? suggestKobo;

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  late String _digits = _initial();
  // One key per amount, so a double tap or a retry opens the same checkout.
  String _key = newIdempotencyKey();
  bool _busy = false;
  bool _confirming = false;
  String? _error;

  String _initial() {
    final s = widget.suggestKobo;
    if (s == null || s <= 0) return '1000';
    final naira = ((s + 99) ~/ 100).clamp(_minKobo ~/ 100, _maxKobo ~/ 100);
    return '$naira';
  }

  int get _kobo => (int.tryParse(_digits) ?? 0) * 100;
  bool get _valid => _kobo >= _minKobo && _kobo <= _maxKobo;

  void _set(String d) => setState(() {
    _digits = d;
    _error = null;
    _key = newIdempotencyKey();
  });

  void _type(String d) {
    if (_digits.length >= 5) return;
    _set(_digits == '0' ? d : _digits + d);
  }

  /// Bachs sends the rider back to our return URL: ?topup=tu_...&outcome=success|cancel.
  static bool _isReturn(Uri u) => (u.queryParameters['topup'] ?? '').startsWith('tu_') && u.queryParameters.containsKey('outcome');

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await widget.api.createTopUp(amountKobo: _kobo, idempotencyKey: _key);
      if (!mounted) return;
      if (url.isEmpty) {
        // Demo mode: nothing to open, the "payment" goes through by itself.
        Navigator.of(context).pop();
        showSnack(context, 'We\'ll add ${naira(_kobo)} as soon as the payment goes through.');
        return;
      }
      final back = await openWeb(context, url, title: 'Pay ${naira(_kobo)}', closeWhen: _isReturn);
      if (!mounted) return;
      if (back?.queryParameters['outcome'] == 'cancel') {
        Navigator.of(context).pop();
        showSnack(context, 'Payment cancelled. You weren\'t charged.');
        return;
      }
      setState(() => _confirming = true);
      final added = await _confirm();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (added) HapticFeedback.mediumImpact();
      showSnack(context, added ? '${naira(_kobo)} added to your wallet.' : 'We\'ll add ${naira(_kobo)} as soon as Bachs confirms. Pull down on Home to check.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  /// Bachs can take a few seconds to mark a payment paid; ask a few times before giving up.
  Future<bool> _confirm() async {
    for (final wait in const [0, 2, 3, 4]) {
      if (wait > 0) await Future.delayed(Duration(seconds: wait));
      try {
        final r = await widget.api.refreshTopUps();
        if (r.credited > 0) return true;
        if (r.checked == 0) return true; // the webhook got there first
      } on ApiException {
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tooLow = _kobo > 0 && _kobo < _minKobo;
    final tooHigh = _kobo > _maxKobo;
    return PageFrame(
      trailing: SupportButton(api: widget.api.support),
      kicker: 'Top up',
      title: 'How much?',
      scroll: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Keypad(onDigit: _type, onBackspace: () => _set(_digits.length <= 1 ? '0' : _digits.substring(0, _digits.length - 1)), enabled: !_busy),
          const SizedBox(height: 12),
          if (_confirming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Confirming your payment with Bachs…', textAlign: TextAlign.center, style: KText.small(p.subtle)),
            ),
          KButton(label: _valid ? 'Pay ${naira(_kobo)}' : 'Pay', loading: _busy, onTap: _valid ? _go : null),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: Text(naira(_kobo), key: ValueKey(_digits), style: KText.hero(_valid ? p.text : p.subtle).copyWith(fontSize: 56)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              tooLow
                  ? 'The least you can add is ${naira(_minKobo)}.'
                  : (tooHigh ? 'The most at once is ${naira(_maxKobo)}.' : 'Card or bank transfer, on a secure Bachs page.'),
              style: KText.small(tooLow || tooHigh ? K.coral : p.subtle),
            ),
          ),
          ErrorLine(_error),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in const [500, 1000, 2000, 5000])
                Pressable(
                  onTap: _busy ? null : () => _set('$n'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _digits == '$n' ? K.yellow : p.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _digits == '$n' ? K.yellow : p.border),
                    ),
                    child: Text(naira(n * 100), style: KText.small(p.text).copyWith(fontWeight: FontWeight.w800)),
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (widget.api.isDemo) const Center(child: DemoBadge()),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
