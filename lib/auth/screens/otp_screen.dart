import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../auth_repository.dart';
import '../demo_auth_repository.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, required this.onVerify, required this.onResend, required this.onBack, required this.progress, this.demo = false});
  final String phone;
  final Future<void> Function(String code) onVerify;
  final Future<void> Function() onResend;
  final VoidCallback onBack;
  final double progress;
  final bool demo;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _len = 6;
  static const _wait = 30;
  final _shake = GlobalKey<ShakeState>();
  String _code = '';
  SlotState _state = SlotState.idle;
  String? _error;
  int _left = _wait;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _left = _wait);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) t.cancel();
      if (mounted) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _type(String d) {
    if (_state == SlotState.busy || _code.length >= _len) return;
    setState(() {
      _code += d;
      _state = SlotState.idle;
      _error = null;
    });
    if (_code.length == _len) _verify();
  }

  void _back() {
    if (_state == SlotState.busy || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _verify() async {
    setState(() => _state = SlotState.busy);
    try {
      await widget.onVerify(_code);
      if (mounted) setState(() => _state = SlotState.ok);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _state = SlotState.error;
        _error = e.message;
      });
      _shake.currentState?.shake();
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _code = '');
    }
  }

  Future<void> _resend() async {
    try {
      await widget.onResend();
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New code on its way.')));
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FlowScaffold(
      kicker: 'Check your messages',
      title: 'Enter the code',
      subtitle: Text.rich(TextSpan(children: [
        const TextSpan(text: 'Sent by SMS to '),
        TextSpan(text: prettyPhone(widget.phone), style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
        const TextSpan(text: '.'),
      ])),
      progress: widget.progress,
      onBack: _state == SlotState.busy ? null : widget.onBack,
      demo: widget.demo,
      bottom: Column(
        children: [
          Keypad(onDigit: _type, onBackspace: _back, enabled: _state != SlotState.busy && _state != SlotState.ok),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shake(key: _shake, child: CodeSlots(length: _len, value: _code, state: _state)),
          ErrorLine(_error),
          const SizedBox(height: 18),
          if (widget.demo)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Demo mode: the code is ${DemoAuthRepository.code}', style: KText.small(p.subtle)),
            ),
          _ResendButton(secondsLeft: _left, onTap: _resend),
        ],
      ),
    );
  }
}

class _ResendButton extends StatelessWidget {
  const _ResendButton({required this.secondsLeft, required this.onTap});
  final int secondsLeft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final waiting = secondsLeft > 0;
    return Pressable(
      onTap: waiting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: waiting ? Colors.transparent : p.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: waiting ? Colors.transparent : p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (waiting) ...[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(value: secondsLeft / 30, strokeWidth: 2.6, color: K.yellowDeep, backgroundColor: p.border),
              ),
              const SizedBox(width: 10),
              Text('Resend code in 0:${secondsLeft.toString().padLeft(2, '0')}', style: KText.small(p.subtle)),
            ] else ...[
              Icon(Icons.refresh_rounded, size: 18, color: p.text),
              const SizedBox(width: 8),
              Text('Send a new code', style: KText.small(p.text)),
            ],
          ],
        ),
      ),
    );
  }
}
