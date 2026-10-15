import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../auth_repository.dart';

/// Mirrors the backend's weak-PIN rule (functions/src/pin.ts): no repeats (1111) and no runs (1234, 9876).
bool isWeakPin(String pin) {
  if (pin.split('').toSet().length == 1) return true;
  final d = pin.codeUnits;
  bool run(int step) => [for (var i = 1; i < d.length; i++) d[i] - d[i - 1]].every((x) => x == step);
  return run(1) || run(-1);
}

/// FR-AUTH-06: a 4 or 6 digit transaction PIN, entered twice. The backend hashes it;
/// the plain PIN never touches the device's storage.
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.onSave, required this.onBack, required this.progress, this.header, this.demo = false});
  final Future<void> Function(String pin) onSave;
  final VoidCallback onBack;
  final double progress;
  final Widget? header;
  final bool demo;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _shake = GlobalKey<ShakeState>();
  int _len = 4;
  String _first = '';
  String _entry = '';
  bool _confirming = false;
  bool _busy = false;
  bool _bad = false;
  String? _error;

  void _type(String d) {
    if (_busy || _entry.length >= _len) return;
    setState(() {
      _entry += d;
      _bad = false;
      _error = null;
    });
    if (_entry.length == _len) Future.delayed(const Duration(milliseconds: 180), _complete);
  }

  void _back() {
    if (_busy || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _fail(String msg, {bool restart = false}) async {
    setState(() {
      _bad = true;
      _error = msg;
    });
    _shake.currentState?.shake();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _entry = '';
      _bad = false;
      if (restart) {
        _first = '';
        _confirming = false;
      }
    });
  }

  Future<void> _complete() async {
    if (!mounted) return;
    if (!_confirming) {
      if (isWeakPin(_entry)) return _fail('That one is too easy to guess. Avoid repeats and runs like 1234.');
      HapticFeedback.lightImpact();
      setState(() {
        _first = _entry;
        _entry = '';
        _confirming = true;
      });
      return;
    }
    if (_entry != _first) return _fail('Those didn\'t match. Let\'s start again.', restart: true);
    setState(() => _busy = true);
    try {
      await widget.onSave(_entry);
      HapticFeedback.mediumImpact();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        await _fail(e.message, restart: true);
      }
    }
  }

  void _toggleLength() {
    setState(() {
      _len = _len == 4 ? 6 : 4;
      _entry = '';
      _first = '';
      _confirming = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FlowScaffold(
      kicker: _confirming ? 'Confirm' : 'Last step',
      title: _confirming ? 'Enter it once more.' : 'Create your PIN.',
      subtitle: Text(_confirming ? 'Just to be sure you\'ll remember it.' : 'You\'ll use it for bigger payments and when you sign in on a new phone. Not your birthday, please.'),
      progress: widget.progress,
      onBack: _busy ? null : (_confirming ? () => setState(() {
            _confirming = false;
            _first = '';
            _entry = '';
          }) : widget.onBack),
      demo: widget.demo,
      bottom: Keypad(onDigit: _type, onBackspace: _back, enabled: !_busy),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.header != null) ...[widget.header!, const SizedBox(height: 26)],
          Shake(
            key: _shake,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              transitionBuilder: (c, a) => SlideTransition(
                position: Tween(begin: const Offset(0.3, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: K.outExpo)),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: KeyedSubtree(
                key: ValueKey('$_confirming$_len$_busy'),
                child: _busy ? const _Saving() : PinDots(length: _len, filled: _entry.length, error: _bad),
              ),
            ),
          ),
          ErrorLine(_error),
          const SizedBox(height: 18),
          if (!_confirming && !_busy)
            Pressable(
              onTap: _toggleLength,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_len == 4 ? 'Use 6 digits instead' : 'Use 4 digits instead', style: KText.small(p.subtle).copyWith(decoration: TextDecoration.underline)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Saving extends StatelessWidget {
  const _Saving();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: K.yellowDeep)),
          const SizedBox(width: 12),
          Text('Locking it in…', style: KText.body(Palette.of(context).subtle)),
        ],
      );
}
