import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_repository.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'activity_screen.dart';
import 'receipt_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'top_up_screen.dart';
import 'withdraw_screen.dart';

/// The rider's home: balance, top up, scan to pay, recent activity.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.session, required this.onSignOut});
  final RiderApi api;
  final Session session;
  final VoidCallback onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final _balance = widget.api.balance();
  late final _activity = widget.api.activity(limit: 30);
  late final _paused = widget.api.paymentsPaused();
  bool _hidden = false;

  RiderApi get api => widget.api;

  void _scan() => pushScreen(context, ScanScreen(api: api));
  void _topUp() => pushScreen(context, TopUpScreen(api: api));
  void _withdraw() => pushScreen(context, WithdrawScreen(api: api));
  void _open(Activity a) {
    if (a.isFare) pushScreen(context, ReceiptScreen.fromActivity(api: api, activity: a));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final name = widget.session.firstName.isEmpty ? 'there' : widget.session.firstName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        const KMark(size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hi, $name', style: KText.h3(p.text)),
                              Text(_greeting(), style: KText.small(p.subtle)),
                            ],
                          ),
                        ),
                        if (api.isDemo) const Padding(padding: EdgeInsets.only(right: 10), child: DemoBadge()),
                        RoundIconButton(
                          icon: Icons.person_rounded,
                          tooltip: 'Account',
                          onTap: () => pushScreen(context, SettingsScreen(api: api, session: widget.session, onSignOut: widget.onSignOut)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<bool>(
                      stream: _paused,
                      builder: (_, s) => AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: s.data == true
                            ? const Padding(padding: EdgeInsets.only(bottom: 14), child: _PausedBanner())
                            : const SizedBox(width: double.infinity),
                      ),
                    ),
                    Entrance(
                      child: StreamBuilder<int?>(
                        stream: _balance,
                        builder: (_, s) => _BalanceCard(
                          kobo: s.data,
                          hidden: _hidden,
                          onToggle: () => setState(() => _hidden = !_hidden),
                          onTopUp: _topUp,
                          onWithdraw: _withdraw,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Entrance(
                      delay: const Duration(milliseconds: 80),
                      child: _ScanCard(onTap: _scan),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text('RECENT', style: KText.kicker(p.subtle)),
                        const Spacer(),
                        Pressable(
                          onTap: () => pushScreen(context, ActivityScreen(api: api)),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text('See all', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverToBoxAdapter(
                  child: StreamBuilder<List<Activity>>(
                    stream: _activity,
                    builder: (_, s) {
                      if (s.hasError) {
                        return _Note(icon: Icons.cloud_off_rounded, text: 'Couldn\'t load your activity. Check your connection and try again.');
                      }
                      if (!s.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: K.yellowDeep)),
                        );
                      }
                      final items = s.data!;
                      if (items.isEmpty) {
                        return _Note(icon: Icons.directions_bus_rounded, text: 'No rides yet. Top up, then scan the sticker on any Konduct shuttle or bike.');
                      }
                      return Column(
                        children: [for (final a in items.take(6)) ActivityTile(a: a, onTap: a.isFare ? () => _open(a) : null)],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning. Where to?';
    if (h < 17) return 'Good afternoon. Where to?';
    return 'Good evening. Ride safe.';
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.kobo, required this.hidden, required this.onToggle, required this.onTopUp, required this.onWithdraw});
  final int? kobo;
  final bool hidden;
  final VoidCallback onToggle, onTopUp, onWithdraw;

  @override
  Widget build(BuildContext context) {
    final text = kobo == null ? '₦ ···' : (hidden ? '₦ ••••' : naira(kobo!));
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
      decoration: BoxDecoration(
        color: K.ink,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: K.ink.withValues(alpha: 0.25), blurRadius: 30, spreadRadius: -12, offset: const Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('WALLET BALANCE', style: KText.kicker(K.muteDark)),
              const Spacer(),
              Pressable(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: K.muteDark,
                    size: 20,
                    semanticLabel: hidden ? 'Show balance' : 'Hide balance',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                child: c,
              ),
            ),
            child: FittedBox(
              key: ValueKey(text),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(text, style: KText.hero(K.paper).copyWith(fontSize: 46)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: onTopUp,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(25)),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, color: K.ink),
                        const SizedBox(width: 6),
                        Text('Top up', style: KText.body(K.ink).copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  onTap: onWithdraw,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: const Color(0xFF2A313C), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.north_east_rounded, color: K.paper, size: 20),
                        const SizedBox(width: 6),
                        Text('Withdraw', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
    scale: 0.97,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: K.yellow,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: K.yellow.withValues(alpha: 0.35), blurRadius: 26, spreadRadius: -10, offset: const Offset(0, 14))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.qr_code_scanner_rounded, color: K.yellow, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan to pay', style: KText.title(K.ink).copyWith(fontSize: 26)),
                const SizedBox(height: 4),
                Text('Point at the sticker on the shuttle or bike.', style: KText.small(K.ink.withValues(alpha: 0.7))),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: K.ink),
        ],
      ),
    ),
  );
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: K.coral.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: K.coral.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        const Icon(Icons.pause_circle_filled_rounded, color: K.coral),
        const SizedBox(width: 10),
        Expanded(child: Text('Konduct payments are paused for a moment. Please pay the driver in cash for now.', style: KText.small(K.ink))),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      child: Row(
        children: [
          Icon(icon, color: p.subtle),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: KText.small(p.subtle))),
        ],
      ),
    );
  }
}
