import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/auth_repository.dart';
import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../../ui/web_screen.dart';
import '../../messages/messages_ui.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'activity_screen.dart';
import 'rate_sheet.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'top_up_screen.dart';
import 'transaction_screen.dart';
import 'withdraw_screen.dart';
import '../../support/support_screens.dart';

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
  late Stream<int?> _balance;
  late Stream<List<Activity>> _activity;
  late Stream<bool> _paused;
  late Stream<List<Park>> _parks;
  // A second listener for the "rate your ride" prompt (a stream can only be listened to once).
  late Stream<List<Activity>> _rateable;
  late final AppLifecycleListener _lifecycle;
  bool _hidden = false;
  // A top-up is still waiting for Bachs; checked again whenever the app comes back.
  bool _topUpWaiting = false;

  RiderApi get api => widget.api;

  @override
  void initState() {
    super.initState();
    _listen();
    _lifecycle = AppLifecycleListener(onResume: () => _topUpWaiting ? _refresh(quiet: true) : null);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Fresh subscriptions to everything on the page. Resubscribing also revives a listener the
  /// connection dropped.
  void _listen() {
    _balance = api.balance();
    _activity = api.activity(limit: 30);
    _paused = api.paymentsPaused();
    _parks = api.parks();
    _rateable = api.activity(limit: 10);
  }

  Future<void> _refresh({bool quiet = false}) async {
    await refreshWallet(context, api, quiet: quiet);
    if (mounted) setState(_listen);
  }

  void _scan() => pushScreen(context, ScanScreen(api: api));
  void _topUp() => pushScreen(context, TopUpScreen(api: api));
  void _withdraw() => pushScreen(context, WithdrawScreen(api: api));
  void _open(Activity a) => openActivity(context, api, a);

  /// Screens an ad or message can open with an app: link.
  late final AppActions _actions = {
    'topup': _topUp,
    'scan': _scan,
    'withdraw': _withdraw,
    'activity': () => pushScreen(context, ActivityScreen(api: api)),
    'account': () => pushScreen(context, SettingsScreen(api: api, session: widget.session, onSignOut: widget.onSignOut)),
  };

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final name = widget.session.firstName.isEmpty ? 'there' : widget.session.firstName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: MessagesHost(
        api: api.messages,
        actions: _actions,
        child: Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: K.ink,
              backgroundColor: K.yellow,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    // One box, not a lazy list: these sections must keep their stream subscriptions when scrolled away.
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              NoticeBell(api: api.messages, actions: _actions),
                              const SizedBox(width: 8),
                              SupportButton(api: api.support),
                              const SizedBox(width: 8),
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
                          StreamBuilder<List<Activity>>(
                            stream: _rateable,
                            builder: (_, s) => _RatePrompt(api: api, fares: s.data ?? const []),
                          ),
                          AdCarousel(api: api.messages, actions: _actions, padding: const EdgeInsets.only(top: 18)),
                          StreamBuilder<List<Park>>(
                            stream: _parks,
                            builder: (_, s) => (s.data ?? const []).isEmpty
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(top: 28),
                                    child: ParksStrip(parks: s.data!),
                                  ),
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
                          _topUpWaiting = items.any((a) => a.kind == ActivityKind.topUp && a.pending);
                          if (items.isEmpty) {
                            return _Note(
                              icon: Icons.directions_bus_rounded,
                              text: 'No rides yet. Top up, then scan the sticker on any Konduct shuttle or bike.',
                            );
                          }
                          return Column(
                            children: [for (final a in items.take(6)) ActivityTile(a: a, onTap: () => _open(a))],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

/// How many buses staff last counted at each park. Tapping a park with a map pin opens Maps.
class ParksStrip extends StatelessWidget {
  const ParksStrip({super.key, required this.parks});
  final List<Park> parks;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final total = parks.fold(0, (t, x) => t + x.busCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('BUSES AT THE PARKS', style: KText.kicker(p.subtle)),
            const Spacer(),
            Text(total == 1 ? '1 bus' : '$total buses', style: KText.small(p.subtle)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            // Two parks fill the row; more scroll sideways with the next one peeking in.
            final width = parks.length <= 2 ? (c.maxWidth - 10 * (parks.length - 1)) / parks.length : (c.maxWidth - 10) / 2.2;
            return SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: parks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(width: width, child: _ParkCard(parks[i])),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ParkCard extends StatelessWidget {
  const _ParkCard(this.park);
  final Park park;

  @override
  Widget build(BuildContext context) {
    void openMap() => openWeb(context, 'https://www.google.com/maps/search/?api=1&query=${park.lat},${park.lng}', title: park.name);
    final p = Palette.of(context);
    final now = DateTime.now();
    final stale = park.staleAt(now);
    final updated = park.updatedAt == null ? 'Not counted yet' : 'Updated ${_lower(whenText(park.updatedAt!, now: now))}';
    final card = Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${park.busCount}', style: KText.title(p.text).copyWith(fontSize: 34)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(park.busCount == 1 ? 'bus' : 'buses', style: KText.small(p.subtle)),
              ),
              const Spacer(),
              if (park.hasPin) Icon(Icons.map_rounded, size: 18, color: p.subtle),
            ],
          ),
          const Spacer(),
          Text(
            park.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800),
          ),
          Text(park.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.small(p.subtle)),
          const SizedBox(height: 4),
          Text(
            stale && park.updatedAt != null ? '$updated · may have changed' : updated,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.small(stale ? K.coral : p.subtle).copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
    return Semantics(
      label: '${park.name}, ${park.busCount} ${park.busCount == 1 ? 'bus' : 'buses'}. $updated.',
      button: park.hasPin,
      excludeSemantics: true,
      child: park.hasPin ? Pressable(scale: 0.97, onTap: openMap, child: card) : card,
    );
  }

  static String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}

/// "How was your ride?" for the latest ride whose estimated time has passed and isn't rated yet.
/// Rides older than a day aren't prompted for (they can still be rated from the receipt).
class _RatePrompt extends StatefulWidget {
  const _RatePrompt({required this.api, required this.fares});
  final RiderApi api;
  final List<Activity> fares;
  @override
  State<_RatePrompt> createState() => _RatePromptState();
}

class _RatePromptState extends State<_RatePrompt> {
  // A ride becomes rateable as time passes, not when data changes.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  final _dismissed = <String>{};

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final fare = widget.fares.where((a) => a.canRateAt(now) && now.difference(a.at) < const Duration(days: 1) && !_dismissed.contains(a.id)).firstOrNull;
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: fare == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Panel(
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, color: K.yellowDeep, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('How was your ride with ${fare.driverLabel}?', style: KText.body(K.ink).copyWith(fontWeight: FontWeight.w800)),
                          Text(fare.tripRoute?.label ?? whenText(fare.at), maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.small(K.mute)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: () => rateRide(context, widget.api, fare),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(20)),
                        child: Text('Rate', style: KText.body(K.ink).copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Not now',
                      onPressed: () => setState(() => _dismissed.add(fare.id)),
                      icon: const Icon(Icons.close_rounded, color: K.mute, size: 20),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Pull-to-refresh: asks the backend to re-check open top-ups with Bachs (its confirmation can be
/// late) and says what happened. [quiet] only speaks up when money was added.
Future<void> refreshWallet(BuildContext context, RiderApi api, {bool quiet = false}) async {
  try {
    final r = await api.refreshTopUps();
    if (!context.mounted) return;
    if (r.credited > 0) {
      HapticFeedback.mediumImpact();
      showSnack(context, r.credited == 1 ? 'Top-up confirmed. Your balance is updated.' : '${r.credited} top-ups confirmed. Your balance is updated.');
    } else if (!quiet) {
      showSnack(context, r.checked > 0 ? 'Still waiting for Bachs to confirm your top-up. We add it the moment they do.' : 'You\'re up to date.');
    }
  } on ApiException catch (e) {
    if (!quiet && context.mounted) showSnack(context, e.message);
  }
}
