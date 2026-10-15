import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/l10n.dart';
import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

/// Invite friends: this rider's referral code to share, what both of them get, and, for a new
/// rider, a box for the friend's code that brought them.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.api});
  final RiderApi api;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late Future<ReferralInfo> _info = widget.api.referral();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _clean => _code.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');

  Future<void> _apply() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final welcome = await widget.api.applyReferral(_clean);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showSnack(context, welcome > 0 ? tr('Code added. You get {amount} after your first ride.', {'amount': naira(welcome)}) : tr('Code added.'));
      setState(() => _info = widget.api.referral());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(ReferralInfo r) async {
    final text = r.enabled && r.welcomeKobo > 0
        ? tr('Pay for campus rides with a scan on Konduct. Use my code {code} when you join and get {amount} after your first ride.', {'code': r.code, 'amount': naira(r.welcomeKobo)})
        : tr('Pay for campus rides with a scan on Konduct. Use my code {code} when you join.', {'code': r.code});
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) showSnack(context, 'Copied. Paste it to your friends.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Invite friends',
      title: 'Ride together',
      child: FutureBuilder<ReferralInfo>(
        future: _info,
        builder: (context, snap) {
          if (snap.hasError) {
            return Panel(child: Text(snap.error is ApiException ? (snap.error as ApiException).message : 'Couldn\'t load your invite code. Check your connection and try again.', style: KText.body(p.subtle)));
          }
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: K.yellowDeep)));
          final r = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR CODE', style: KText.kicker(K.muteDark)),
                    const SizedBox(height: 8),
                    Semantics(
                      label: tr('Your referral code is {code}', {'code': r.code.split('').join(' ')}),
                      excludeSemantics: true,
                      child: Text(r.code, translate: false, style: KText.mono(K.yellow, size: 34).copyWith(letterSpacing: 6)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r.enabled && (r.bonusKobo > 0 || r.welcomeKobo > 0)
                          ? 'When a friend joins with your code and takes their first ride, you get ${naira(r.bonusKobo)} and they get ${naira(r.welcomeKobo)}.'
                          : 'Share it with friends. Rewards aren\'t running right now, but your code will count when they start again.',
                      style: KText.body(K.paper),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: KButton(label: 'Share', icon: Icons.share_rounded, onTap: () => _share(r))),
                        const SizedBox(width: 10),
                        RoundIconButton(
                          icon: Icons.copy_rounded,
                          dark: true,
                          tooltip: 'Copy code',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: r.code));
                            showSnack(context, 'Code copied');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Panel(
                child: Row(
                  children: [
                    _stat(context, '${r.joined}', r.joined == 1 ? 'friend joined' : 'friends joined'),
                    _stat(context, '${r.rewarded}', r.rewarded == 1 ? 'took a ride' : 'took rides'),
                    _stat(context, naira(r.earnedKobo), 'earned'),
                  ],
                ),
              ),
              if (r.canApply) ...[
                const SizedBox(height: 26),
                Text('GOT A FRIEND\'S CODE?', style: KText.kicker(p.subtle)),
                const SizedBox(height: 8),
                Text('Enter it before your first ride.', style: KText.small(p.subtle)),
                const SizedBox(height: 10),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  onChanged: (_) => setState(() {}),
                  style: KText.mono(p.text, size: 22).copyWith(letterSpacing: 4),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]'))],
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'AB12CD',
                    hintStyle: KText.mono(p.border, size: 22).copyWith(letterSpacing: 4),
                    filled: true,
                    fillColor: p.field,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: p.border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: K.yellowDeep, width: 2)),
                  ),
                ),
                ErrorLine(_error),
                const SizedBox(height: 12),
                KButton(label: 'Use this code', loading: _busy, onTap: _clean.length == 6 ? _apply : null),
              ] else if (r.usedCode) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: K.go, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('You joined with a friend\'s code.', style: KText.small(p.text))),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final p = Palette.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: KText.h3(p.text)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: KText.small(p.subtle)),
        ],
      ),
    );
  }
}
