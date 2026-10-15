import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../auth/password_ui.dart';
import '../../theme/tokens.dart';
import '../../ui/field.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

/// Change the sign-in password: the current one first (Firebase wants a recent sign-in), then
/// the new one twice. Forgot the current one? Email a reset link instead.
class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key, required this.api, required this.email});
  final RiderApi api;
  final String email;
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_current.text.isEmpty) return setState(() => _error = 'Enter your current password.');
    final problem = newPasswordProblem(current: _current.text, next: _next.text, again: _again.text);
    if (problem != null) return setState(() => _error = problem);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      showSnack(context, 'Password changed. Use the new one next time you sign in.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    try {
      await widget.api.sendPasswordReset();
      if (mounted) showSnack(context, 'Reset link sent to ${widget.email}. Check your inbox and spam.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Security',
      title: 'Change password',
      bottom: KButton(label: 'Change password', loading: _busy, onTap: _save),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KField(
              controller: _current,
              label: 'Current password',
              icon: Icons.lock_rounded,
              obscure: true,
              autofill: const [AutofillHints.password],
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            KField(
              controller: _next,
              label: 'New password',
              icon: Icons.lock_reset_rounded,
              obscure: true,
              autofill: const [AutofillHints.newPassword],
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            KField(
              controller: _again,
              label: 'New password again',
              icon: Icons.lock_reset_rounded,
              obscure: true,
              autofill: const [AutofillHints.newPassword],
              action: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: KText.small(K.coral))),
            const SizedBox(height: 14),
            Text('At least 8 characters. Your PIN doesn\'t change. Other phones signed in to this account will need the new password.', style: KText.small(p.subtle)),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _forgot,
                child: Text('Forgot your current password? Email me a reset link', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
