import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/field.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../auth_repository.dart';
import '../password_ui.dart';

enum EmailMode { signIn, signUp }

/// Email + password, with a sliding Sign in / Create account switch.
/// Email addresses are not verified yet; that comes later with an emailed code.
class EmailScreen extends StatefulWidget {
  const EmailScreen({
    super.key,
    required this.onSubmit,
    required this.onForgot,
    required this.onBack,
    required this.progress,
    this.signUpHint,
    this.initialMode = EmailMode.signUp,
    this.demo = false,
  });

  final Future<void> Function(String email, String password, EmailMode mode) onSubmit;
  final Future<void> Function(String email) onForgot;
  final VoidCallback onBack;
  final double progress;
  final String? signUpHint;
  final EmailMode initialMode;
  final bool demo;

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  final _shake = GlobalKey<ShakeState>();
  late EmailMode _mode = widget.initialMode;
  bool _busy = false;
  String? _error;
  bool _emailBad = false;
  bool _passwordBad = false;

  static const minPassword = 8;

  @override
  void initState() {
    super.initState();
    _email.addListener(_edited);
    _password.addListener(_edited);
  }

  void _edited() => setState(() {
        _error = null;
        _emailBad = false;
        _passwordBad = false;
      });

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _signUp => _mode == EmailMode.signUp;
  bool get _ready => looksLikeEmail(_email.text) && _password.text.length >= (_signUp ? minPassword : 1);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!looksLikeEmail(_email.text)) return _fail('Enter a valid email address.', email: true);
    if (_signUp && _password.text.length < minPassword) return _fail('Use at least $minPassword characters for your password.', password: true);
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_email.text.trim().toLowerCase(), _password.text, _mode);
    } on AuthException catch (e) {
      if (mounted) _fail(e.message, email: e.code.contains('email'), password: e.code.contains('password') || e.code == 'invalid-credential');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fail(String message, {bool email = false, bool password = false}) {
    setState(() {
      _error = message;
      _emailBad = email;
      _passwordBad = password;
    });
    _shake.currentState?.shake();
  }

  Future<void> _forgot() => showForgotPassword(context, initialEmail: _email.text, send: widget.onForgot);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FlowScaffold(
      kicker: _signUp ? 'New here' : 'Welcome back',
      title: _signUp ? 'Create your account.' : 'Sign in to Konduct.',
      subtitle: Text(_signUp ? (widget.signUpHint ?? 'Just an email and a password to start.') : 'Use the email and password you signed up with.'),
      progress: widget.progress,
      onBack: _busy ? null : widget.onBack,
      demo: widget.demo,
      bottom: Column(
        children: [
          KButton(label: _signUp ? 'Create account' : 'Sign in', icon: Icons.arrow_forward_rounded, loading: _busy, onTap: _ready ? _submit : null),
          const SizedBox(height: 10),
          Text('By continuing you agree to Konduct\'s Terms and Privacy Policy.', textAlign: TextAlign.center, style: KText.small(p.subtle).copyWith(fontSize: 12)),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 24),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Entrance(delay: const Duration(milliseconds: 140), child: _ModeSwitch(mode: _mode, enabled: !_busy, onChanged: (m) => setState(() => _mode = m))),
              const SizedBox(height: 18),
              Shake(
                key: _shake,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Entrance(
                      delay: const Duration(milliseconds: 200),
                      child: KField(
                        controller: _email,
                        label: 'Email',
                        hint: 'you@example.com',
                        icon: Icons.alternate_email_rounded,
                        enabled: !_busy,
                        error: _emailBad,
                        keyboardType: TextInputType.emailAddress,
                        action: TextInputAction.next,
                        autofill: const [AutofillHints.email],
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Entrance(
                      delay: const Duration(milliseconds: 260),
                      child: KField(
                        controller: _password,
                        focusNode: _passwordFocus,
                        label: 'Password',
                        hint: _signUp ? 'At least $minPassword characters' : null,
                        icon: Icons.lock_rounded,
                        obscure: true,
                        enabled: !_busy,
                        error: _passwordBad,
                        action: TextInputAction.done,
                        autofill: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                        onSubmitted: (_) => _ready ? _submit() : null,
                      ),
                    ),
                  ],
                ),
              ),
              ErrorLine(_error),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: K.outExpo,
                child: _signUp
                    ? Padding(padding: const EdgeInsets.only(top: 14), child: _PasswordMeter(length: _password.text.length, min: minPassword))
                    : Align(
                        alignment: Alignment.centerRight,
                        child: Pressable(
                          onTap: _busy ? null : _forgot,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 14, 4, 8),
                            child: Text('Forgot password?', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-tab pill with a yellow thumb that slides between "Create account" and "Sign in".
class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged, this.enabled = true});
  final EmailMode mode;
  final ValueChanged<EmailMode> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget tab(EmailMode m, String label) => Expanded(
          child: Pressable(
            scale: 0.97,
            onTap: enabled && mode != m ? () => onChanged(m) : null,
            child: SizedBox(
              height: 46,
              child: Center(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: KText.body(mode == m ? K.ink : p.subtle).copyWith(fontWeight: FontWeight.w800),
                  child: Text(label),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: p.border)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 380),
            curve: K.springy,
            alignment: mode == EmailMode.signUp ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(height: 46, decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(999))),
            ),
          ),
          Row(children: [tab(EmailMode.signUp, 'Create account'), tab(EmailMode.signIn, 'Sign in')]),
        ],
      ),
    );
  }
}

/// Fills as the password grows; green once it's long enough.
class _PasswordMeter extends StatelessWidget {
  const _PasswordMeter({required this.length, required this.min});
  final int length, min;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ok = length >= min;
    final strong = length >= 12;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (length / 12).clamp(0, 1).toDouble()),
              duration: const Duration(milliseconds: 300),
              curve: K.outExpo,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: p.border, color: ok ? K.go : K.yellowDeep),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(strong ? 'Strong' : (ok ? 'Good' : '${(min - length).clamp(0, min)} more'), style: KText.small(ok ? K.go : p.subtle)),
      ],
    );
  }
}
