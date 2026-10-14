import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

const _minKobo = 20000; // ₦200, as the backend's RULES.minTopUpKobo
const _maxKobo = 5000000; // ₦50,000

/// Pick an amount, then pay on Bachs's page (card or bank transfer). The wallet is credited when
/// Bachs confirms the payment to the backend, not when the page closes.
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

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await widget.api.createTopUp(amountKobo: _kobo, idempotencyKey: _key);
      if (url.isNotEmpty) {
        final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
        if (!opened) throw const ApiException('no_browser', 'We couldn\'t open the payment page. Try again.');
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'We\'ll add ${naira(_kobo)} as soon as the payment goes through.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tooLow = _kobo > 0 && _kobo < _minKobo;
    final tooHigh = _kobo > _maxKobo;
    return PageFrame(
      kicker: 'Top up',
      title: 'How much?',
      scroll: false,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Keypad(onDigit: _type, onBackspace: () => _set(_digits.length <= 1 ? '0' : _digits.substring(0, _digits.length - 1)), enabled: !_busy),
          const SizedBox(height: 12),
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
