import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../auth/auth_repository.dart';
import '../../auth/screens/pin_screen.dart' show isWeakPin;
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

/// Profile, funding code, PIN, account lock and sign out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api, required this.session, required this.onSignOut});
  final RiderApi api;
  final Session session;
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _profile = widget.api.profile();

  Future<void> _changePin() async {
    final old = await askPin(context, title: 'Your current PIN');
    if (old == null || !mounted) return;
    String? error;
    String? fresh;
    while (true) {
      fresh = await askPin(context, title: 'Choose a new PIN', message: '4 or 6 digits. Avoid repeats and runs like 1234.', error: error);
      if (fresh == null || !mounted) return;
      if (isWeakPin(fresh)) {
        error = 'That one is too easy to guess.';
        continue;
      }
      final again = await askPin(context, title: 'Enter the new PIN again');
      if (again == null || !mounted) return;
      if (again != fresh) {
        error = 'Those didn\'t match. Try again.';
        continue;
      }
      break;
    }
    try {
      await widget.api.changePin(oldPin: old, newPin: fresh);
      if (mounted) showSnack(context, 'PIN changed.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _lock() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final p = Palette.of(context);
        return AlertDialog(
          backgroundColor: p.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Lock your account?', style: KText.h3(p.text)),
          content: Text(
            'Use this if your phone or password was stolen. Nobody can pay from your wallet until a Konduct agent unlocks it with you in person.',
            style: KText.body(p.subtle),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Lock it', style: KText.body(K.coral).copyWith(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (ok != true) return;
    try {
      await widget.api.lockMyAccount();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Account',
      title: widget.session.name ?? 'Your account',
      child: StreamBuilder<RiderProfile?>(
        stream: _profile,
        builder: (_, s) {
          final prof = s.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                child: Column(
                  children: [
                    _info(context, Icons.alternate_email_rounded, 'Email', widget.session.email),
                    _info(context, Icons.badge_rounded, 'Student ID', prof?.studentId ?? '…'),
                    _info(context, Icons.school_rounded, 'Campus', AppConfig.campusName),
                    _info(context, Icons.verified_user_rounded, 'Limits', prof == null ? '…' : 'Tier ${prof.kycTier}'),
                  ],
                ),
              ),
              if (prof != null && prof.fundingCode.isNotEmpty) ...[
                const SizedBox(height: 14),
                Pressable(
                  scale: 0.98,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: prof.fundingCode));
                    showSnack(context, 'Funding code copied');
                  },
                  child: Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('YOUR FUNDING CODE', style: KText.kicker(p.subtle)),
                              const SizedBox(height: 6),
                              Text(prof.fundingCode, style: KText.mono(p.text, size: 22).copyWith(letterSpacing: 2)),
                              const SizedBox(height: 4),
                              Text('Konduct agents use this code to find your wallet. Tap to copy.', style: KText.small(p.subtle)),
                            ],
                          ),
                        ),
                        Icon(Icons.copy_rounded, color: p.subtle),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text('SECURITY', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              _action(context, Icons.pin_rounded, 'Change PIN', onTap: _changePin),
              _action(context, Icons.lock_person_rounded, 'Lock my account', subtitle: 'Phone stolen? Freeze your wallet now.', color: K.coral, onTap: _lock),
              const SizedBox(height: 22),
              _action(
                context,
                Icons.logout_rounded,
                'Sign out',
                onTap: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  widget.onSignOut();
                },
              ),
              const SizedBox(height: 20),
              Center(child: Text('Konduct · ${AppConfig.campusPlace}', style: KText.small(p.subtle))),
            ],
          );
        },
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String k, String v) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.subtle),
          const SizedBox(width: 12),
          Text(k, style: KText.body(p.subtle)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title, {String? subtitle, Color? color, required VoidCallback onTap}) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        scale: 0.98,
        onTap: onTap,
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color ?? p.text),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KText.body(color ?? p.text).copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null) Text(subtitle, style: KText.small(p.subtle)),
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
