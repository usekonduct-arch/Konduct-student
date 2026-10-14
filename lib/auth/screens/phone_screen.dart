import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../auth_repository.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.onSend, required this.onBack, required this.progress, this.initial, this.demo = false});
  final Future<void> Function(String e164) onSend;
  final VoidCallback onBack;
  final double progress;
  final String? initial;
  final bool demo;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _shake = GlobalKey<ShakeState>();
  late String _digits = widget.initial?.replaceFirst('+234', '') ?? '';
  bool _busy = false;
  String? _error;

  int get _max => _digits.startsWith('0') ? 11 : 10;
  String? get _e164 => toE164(_digits);

  void _type(String d) {
    if (_busy || _digits.length >= _max) return;
    setState(() {
      _digits += d;
      _error = null;
    });
  }

  void _back() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _send() async {
    final e164 = _e164;
    if (e164 == null) {
      setState(() => _error = 'Enter a Nigerian mobile number, like 0803 123 4567.');
      _shake.currentState?.shake();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onSend(e164);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _shake.currentState?.shake();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 0803 123 4567 or 803 123 4567, with gaps where they belong.
  List<String> _groups() {
    final local = _digits.startsWith('0') ? [4, 3, 4] : [3, 3, 4];
    final out = <String>[];
    var i = 0;
    for (final n in local) {
      if (i >= _digits.length) break;
      out.add(_digits.substring(i, (i + n).clamp(0, _digits.length)));
      i += n;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ready = _e164 != null;
    return FlowScaffold(
      kicker: 'Sign in',
      title: 'What\'s your phone number?',
      subtitle: const Text('We\'ll text you a 6-digit code to make sure it\'s you.'),
      progress: widget.progress,
      onBack: _busy ? null : widget.onBack,
      demo: widget.demo,
      bottom: Column(
        children: [
          Keypad(onDigit: _type, onBackspace: _back, enabled: !_busy),
          const SizedBox(height: 12),
          KButton(label: 'Send code', loading: _busy, onTap: ready ? _send : null),
          const SizedBox(height: 10),
          Text('By continuing you agree to Konduct\'s Terms and Privacy Policy.', textAlign: TextAlign.center, style: KText.small(p.subtle).copyWith(fontSize: 12)),
        ],
      ),
      child: Center(
        child: Shake(
          key: _shake,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 18, 16),
                decoration: BoxDecoration(
                  color: p.field,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _error != null ? K.coral : (ready ? K.go : p.border), width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
                      child: Text('🇳🇬 +234', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _digits.isEmpty
                            ? Text('803 123 4567', style: KText.title(p.subtle.withValues(alpha: 0.35)).copyWith(fontSize: 30))
                            : Row(
                                children: [
                                  for (final (gi, g) in _groups().indexed) ...[
                                    if (gi > 0) const SizedBox(width: 10),
                                    for (final (ci, ch) in g.split('').indexed)
                                      TweenAnimationBuilder<double>(
                                        key: ValueKey('$gi-$ci-$ch'),
                                        tween: Tween(begin: 0.4, end: 1),
                                        duration: const Duration(milliseconds: 380),
                                        curve: K.springy,
                                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                                        child: Text(ch, style: KText.title(p.text).copyWith(fontSize: 30, letterSpacing: 0)),
                                      ),
                                  ],
                                ],
                              ),
                      ),
                    ),
                    AnimatedScale(
                      scale: ready ? 1 : 0,
                      duration: const Duration(milliseconds: 380),
                      curve: K.springy,
                      child: const CircleAvatar(radius: 13, backgroundColor: K.go, child: Icon(Icons.check_rounded, size: 17, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              ErrorLine(_error),
            ],
          ),
        ),
      ),
    );
  }
}
