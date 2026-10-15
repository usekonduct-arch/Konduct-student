import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/tokens.dart';
import '../ui/field.dart';
import '../ui/kit.dart';
import 'auth_repository.dart';

/// "Forgot password?": asks for the email, sends Firebase's reset link, then says what happens
/// next. The answer is the same whether or not the email has an account, so nobody can use this
/// to find out who's on Konduct.
Future<void> showForgotPassword(BuildContext context, {String initialEmail = '', required Future<void> Function(String email) send}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotSheet(initialEmail: initialEmail.trim(), send: send),
    );

class _ForgotSheet extends StatefulWidget {
  const _ForgotSheet({required this.initialEmail, required this.send});
  final String initialEmail;
  final Future<void> Function(String email) send;
  @override
  State<_ForgotSheet> createState() => _ForgotSheetState();
}

class _ForgotSheetState extends State<_ForgotSheet> {
  static const _cooldown = 60;
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!looksLikeEmail(email)) return setState(() => _error = 'Enter the email you sign in with.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.send(email);
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _sent = true;
        _wait = _cooldown;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _wait--);
        if (_wait <= 0) t.cancel();
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final email = _email.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 18),
              if (!_sent) ...[
                Text('Reset your password', style: KText.h3(p.text)),
                const SizedBox(height: 6),
                Text('We\'ll email you a link to choose a new one.', style: KText.body(p.subtle)),
                const SizedBox(height: 18),
                KField(
                  controller: _email,
                  label: 'Email',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofill: const [AutofillHints.email],
                  action: TextInputAction.send,
                  error: _error != null,
                  onSubmitted: (_) => _send(),
                ),
              ] else ...[
                const Icon(Icons.mark_email_read_rounded, size: 44, color: K.yellowDeep),
                const SizedBox(height: 12),
                Text('Check your email', style: KText.h3(p.text)),
                const SizedBox(height: 8),
                Text(
                  'If $email has a Konduct account, a reset link is on its way. Open it, choose a new password, then come back and sign in with it.',
                  style: KText.body(p.subtle),
                ),
                const SizedBox(height: 8),
                Text('No email after a few minutes? Check spam or junk, and make sure the address is right.', style: KText.small(p.subtle)),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: KText.small(K.coral)),
                ),
              const SizedBox(height: 18),
              if (!_sent)
                KButton(label: 'Send reset link', loading: _busy, onTap: _send)
              else ...[
                KButton(label: 'Back to sign in', onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _wait > 0 || _busy ? null : _send,
                    child: Text(
                      _wait > 0 ? 'Send again in ${_wait}s' : 'Send it again',
                      style: KText.small(_wait > 0 ? p.subtle : p.text).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _sent = false;
                      _error = null;
                    }),
                    child: Text('Use a different email', style: KText.small(p.subtle).copyWith(decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Checks for a new password. Null when it's fine.
String? newPasswordProblem({required String current, required String next, required String again, int min = 8}) {
  if (next.length < min) return 'Use at least $min characters.';
  if (next == current) return 'Pick a password different from the current one.';
  if (RegExp(r'^(.)\1+$').hasMatch(next)) return 'That\'s too easy to guess.';
  if (next != again) return 'The two new passwords don\'t match.';
  return null;
}
