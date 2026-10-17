import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../app/home_widget_sync.dart';
import '../../messages/messages_api.dart' show WebPush;
import '../../l10n/l10n.dart';
import '../../l10n/language_sheet.dart';
import '../../l10n/text.dart';
import '../../security/biometric.dart';
import '../../app/app_info.dart';
import '../../auth/auth_repository.dart';
import '../../auth/screens/pin_screen.dart' show isWeakPin;
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'bank_account_screen.dart';
import 'invite_screen.dart';
import '../../support/support_screens.dart';
import 'password_screen.dart';
import 'wrapped_screen.dart';

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
  late final _balance = widget.api.balance();
  final _bioAvailable = BiometricPin.instance.available();
  bool _bioOn = false;
  bool _widgetBalance = false;

  /// Web app only: notifications in this browser (the phones ask when the app starts).
  WebPush? _webPush;

  @override
  void initState() {
    super.initState();
    BiometricPin.instance.enabled().then((v) {
      if (mounted) setState(() => _bioOn = v);
    });
    HomeWidgetSync.showsBalance().then((v) {
      if (mounted) setState(() => _widgetBalance = v);
    });
    widget.api.messages.webPush().then((v) {
      if (mounted) setState(() => _webPush = v);
    });
  }

  Future<void> _setWebPush(bool on) async {
    if (!on) return showSnack(context, 'To turn them off, use your browser\'s settings for this site.');
    if (_webPush == WebPush.needsInstall) {
      return showSnack(context, 'On iPhone, add Konduct to your Home Screen first, then turn notifications on here.');
    }
    final now = await widget.api.messages.enableWebPush();
    if (!mounted) return;
    setState(() => _webPush = now);
    if (now == WebPush.on) showSnack(context, 'Notifications are on.');
    if (now == WebPush.blocked) showSnack(context, 'Notifications are blocked. Allow them for this site in your browser settings.');
  }

  /// Fingerprint payments: on needs the PIN once (kept in the phone's secure store) and a fingerprint.
  Future<void> _setBiometric(bool on) async {
    final bio = BiometricPin.instance;
    if (!on) {
      await bio.disable();
      if (mounted) setState(() => _bioOn = false);
      return;
    }
    final pin = await askPin(context, title: 'Enter your PIN', message: 'Once, so your fingerprint or face can stand in for it.');
    if (pin == null || !mounted) return;
    final ok = await bio.enable(pin);
    if (!mounted) return;
    setState(() => _bioOn = ok);
    showSnack(context, ok ? 'Done. Use your fingerprint or face when a payment asks for your PIN.' : 'Fingerprint payments weren\'t turned on.');
  }

  Future<void> _setWidgetBalance(bool on) async {
    setState(() => _widgetBalance = on);
    final kobo = await _balance.first.timeout(const Duration(seconds: 5), onTimeout: () => null).catchError((_) => null);
    await HomeWidgetSync.setShowsBalance(on, balanceText: kobo == null ? null : naira(kobo));
  }

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
      await BiometricPin.instance.replace(fresh);
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
              Text('APP', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              _action(
                context,
                Icons.translate_rounded,
                'Language',
                subtitle: L10nScope.watch(context).nativeName,
                onTap: () => pickLanguage(context),
              ),
              _action(
                context,
                Icons.card_giftcard_rounded,
                'Invite friends',
                subtitle: 'Share your code. You both get credit after their first ride.',
                onTap: () => pushScreen(context, InviteScreen(api: widget.api)),
              ),
              // The home-screen widget is Android's; the web app has notifications to switch on instead.
              if (!kIsWeb)
                _toggle(
                  context,
                  Icons.widgets_rounded,
                  'Balance on home-screen widget',
                  subtitle: 'Off: the widget only shows Scan to pay.',
                  value: _widgetBalance,
                  onChanged: _setWidgetBalance,
                ),
              if (_webPush != null)
                _toggle(
                  context,
                  Icons.notifications_rounded,
                  'Notifications',
                  subtitle: 'When you pay, top up or get a message.',
                  value: _webPush == WebPush.on,
                  onChanged: _setWebPush,
                ),
              const SizedBox(height: 14),
              Text('YOUR MONTHS', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              _action(
                context,
                Icons.auto_awesome_rounded,
                'Konduct Wrapped',
                subtitle: 'Your month in rides, to look back on and share',
                onTap: () => pushScreen(context, WrappedMonthsScreen(api: widget.api, firstName: widget.session.firstName)),
              ),
              const SizedBox(height: 14),
              Text('MONEY', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              _action(
                context,
                Icons.account_balance_rounded,
                'Bank account',
                subtitle: 'Where your withdrawals go',
                onTap: () => pushScreen(context, BankAccountScreen(api: widget.api)),
              ),
              const SizedBox(height: 14),
              Text('SECURITY', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              _action(
                context,
                Icons.password_rounded,
                'Change password',
                subtitle: 'The one you sign in with',
                onTap: () => pushScreen(context, PasswordScreen(api: widget.api, email: widget.session.email)),
              ),
              _action(context, Icons.pin_rounded, 'Change PIN', onTap: _changePin),
              FutureBuilder<bool>(
                future: _bioAvailable,
                builder: (_, a) => a.data == true
                    ? _toggle(
                        context,
                        Icons.fingerprint_rounded,
                        'Pay with fingerprint or face',
                        subtitle: 'Instead of typing your PIN.',
                        value: _bioOn,
                        onChanged: _setBiometric,
                      )
                    : const SizedBox.shrink(),
              ),
              _action(context, Icons.lock_person_rounded, 'Lock my account', subtitle: 'Phone stolen? Freeze your wallet now.', color: K.coral, onTap: _lock),
              const SizedBox(height: 14),
              Text('HELP', style: KText.kicker(p.subtle)),
              const SizedBox(height: 8),
              _action(
                context,
                Icons.support_agent_rounded,
                'Help & support',
                subtitle: 'Chat with Konduct staff, or make a complaint',
                onTap: () => pushScreen(context, SupportScreen(api: widget.api.support)),
              ),
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

  Widget _toggle(BuildContext context, IconData icon, String title, {String? subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MergeSemantics(
        child: Panel(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
          child: Row(
            children: [
              Icon(icon, color: p.text),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                    if (subtitle != null) Text(subtitle, style: KText.small(p.subtle)),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged, activeThumbColor: K.ink, activeTrackColor: K.yellow),
            ],
          ),
        ),
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
