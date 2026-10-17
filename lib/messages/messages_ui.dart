import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../l10n/text.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';
import '../ui/web_screen.dart';
import 'messages_api.dart';
import 'voice.dart';

/// In-app screens an `app:<name>` link can open (for example "topup" → the top-up screen). A link
/// can carry one argument after a slash, `app:buses/<parkId>`, which the action receives ('' if none).
typedef AppActions = Map<String, void Function(String arg)>;

/// Follows a message or ad link: web pages open inside the app, app: links open a screen.
void openLink(BuildContext context, String? link, AppActions actions) {
  if (link == null || link.isEmpty) return;
  if (link.startsWith('https://')) {
    openWeb(context, link);
  } else if (link.startsWith('app:')) {
    final rest = link.substring(4);
    final slash = rest.indexOf('/');
    final name = slash < 0 ? rest : rest.substring(0, slash);
    actions[name]?.call(slash < 0 ? '' : rest.substring(slash + 1));
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return '${t.day} ${tr(_months[t.month - 1])}';
}

/// A picture from the web that never breaks the layout while loading or when it fails.
class _NetImage extends StatelessWidget {
  const _NetImage(this.url);
  final String url;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    // Kept on disk, so an ad seen once shows instantly on the next launch instead of downloading again.
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => ColoredBox(color: p.border.withValues(alpha: 0.4)),
      errorWidget: (_, _, _) => ColoredBox(
        color: p.border.withValues(alpha: 0.4),
        child: Center(child: Icon(Icons.image_not_supported_rounded, color: p.subtle)),
      ),
    );
  }
}

/// Bell with the number of unread messages. Opens the inbox.
class NoticeBell extends StatefulWidget {
  const NoticeBell({super.key, required this.api, required this.actions});
  final MessagesApi api;
  final AppActions actions;
  @override
  State<NoticeBell> createState() => _NoticeBellState();
}

class _NoticeBellState extends State<NoticeBell> {
  late final _notices = widget.api.notices();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<List<Notice>>(
      stream: _notices,
      builder: (context, s) {
        final unread = (s.data ?? const <Notice>[]).where((n) => !n.read).length;
        return Semantics(
          button: true,
          label: tr(unread == 0 ? 'Notifications' : 'Notifications, $unread unread'),
          excludeSemantics: true,
          child: Pressable(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InboxScreen(api: widget.api, actions: widget.actions),
              ),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.border),
                    ),
                    child: Center(child: Icon(Icons.notifications_rounded, color: p.text, size: 22)),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 19),
                        height: 19,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: K.coral,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: p.bg, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(unread > 9 ? '9+' : '$unread', style: KText.small(Colors.white).copyWith(fontSize: 10.5, height: 1)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A plain page with a back button and a title, matching the app's other screens.
class _Page extends StatelessWidget {
  const _Page({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: tr('Back'),
                        child: Pressable(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: p.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.border),
                            ),
                            child: Icon(Icons.arrow_back_rounded, color: p.text, size: 22),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ?action,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Text(title, style: KText.title(p.text)),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a kind of message looks: its icon, colour and the small label above the title.
class _Look {
  const _Look(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;

  static _Look of(Notice n) {
    final k = n.kind;
    if (k == 'fare.received') return const _Look(Icons.payments_rounded, K.go, 'Payment received');
    if (k == 'wallet.funded') return const _Look(Icons.account_balance_wallet_rounded, K.go, 'Wallet');
    if (k == 'payout.paid') return const _Look(Icons.account_balance_rounded, K.go, 'Payout');
    if (k == 'payout.failed') return const _Look(Icons.error_outline_rounded, K.coral, 'Payout');
    if (k == 'dispute.update') return const _Look(Icons.support_agent_rounded, K.yellowDeep, 'Your report');
    if (k == 'support.reply') return const _Look(Icons.chat_bubble_rounded, Color(0xFF1F6F99), 'Support');
    if (k.startsWith('security')) return const _Look(Icons.shield_rounded, K.coral, 'Security');
    if (n.personal) return const _Look(Icons.mark_email_unread_rounded, K.yellowDeep, 'Message for you');
    return const _Look(Icons.campaign_rounded, K.yellowDeep, 'From Konduct');
  }
}

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String _fullDate(DateTime t) =>
    '${tr(_days[t.weekday - 1])} ${t.day} ${tr(_monthsLong[t.month - 1])}${t.year == DateTime.now().year ? '' : ' ${t.year}'} · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Today", "This week" or "Earlier": the heading a message sits under in the inbox.
String _bucket(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (!t.isBefore(today)) return 'Today';
  if (t.isAfter(today.subtract(const Duration(days: 7)))) return 'This week';
  return 'Earlier';
}

/// The round icon in a message's colour.
class _Badge extends StatelessWidget {
  const _Badge(this.look, {this.size = 44});
  final _Look look;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: look.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(size * 0.32)),
    child: Icon(look.icon, color: look.color, size: size * 0.5),
  );
}

/// Every message from Konduct, newest first, under Today / This week / Earlier.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.api, required this.actions});
  final MessagesApi api;
  final AppActions actions;
  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final _notices = widget.api.notices();
  List<Notice> _last = const [];

  Future<void> _readAll() async {
    for (final n in _last.where((n) => !n.read)) {
      await widget.api.markRead(n);
    }
  }

  void _open(Notice n) {
    widget.api.markRead(n);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoticeScreen(notice: n, actions: widget.actions)));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<List<Notice>>(
      stream: _notices,
      builder: (context, s) {
        _last = s.data ?? const [];
        final unread = _last.where((n) => !n.read).length;
        final rows = <Widget>[];
        String? heading;
        for (final n in _last) {
          final b = _bucket(n.at);
          if (b != heading) {
            heading = b;
            rows.add(
              Padding(
                padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 18, bottom: 8),
                child: Text(b.toUpperCase(), style: KText.kicker(p.subtle)),
              ),
            );
          }
          rows.add(Padding(padding: const EdgeInsets.only(bottom: 10), child: _NoticeTile(notice: n, onTap: () => _open(n))));
        }
        return _Page(
          title: 'Notifications',
          action: unread > 0
              ? TextButton(
                  onPressed: _readAll,
                  child: Text('Mark all read', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline)),
                )
              : null,
          child: !s.hasData
              ? const Center(child: CircularProgressIndicator(color: K.yellowDeep))
              : _last.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                  child: Column(
                    children: [
                      _Badge(const _Look(Icons.notifications_none_rounded, K.yellowDeep, ''), size: 72),
                      const SizedBox(height: 16),
                      Text('All quiet', style: KText.h3(p.text)),
                      const SizedBox(height: 6),
                      Text('Payments, replies and news from the Konduct team show up here.', textAlign: TextAlign.center, style: KText.body(p.subtle)),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    if (unread > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text('$unread unread', style: KText.small(p.subtle)),
                      ),
                    ...rows,
                  ],
                ),
        );
      },
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});
  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final n = notice;
    final look = _Look.of(n);
    return Semantics(
      button: true,
      label: '${n.read ? '' : '${tr('Unread.')} '}${tr(look.label)}: ${n.title}. ${_ago(n.at)}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.98,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: n.read ? p.surface : look.color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: n.read ? p.border : look.color.withValues(alpha: 0.45)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(look),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(look.label.toUpperCase(), style: KText.kicker(look.color).copyWith(fontSize: 10)),
                        ),
                        Text(_ago(n.at), style: KText.small(p.subtle).copyWith(fontSize: 11.5)),
                        if (!n.read) ...[
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: K.coral, shape: BoxShape.circle)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KText.body(p.text).copyWith(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800),
                    ),
                    if (n.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.small(p.subtle)),
                    ],
                  ],
                ),
              ),
              if (n.imageUrl != null) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(width: 56, height: 56, child: _NetImage(n.imageUrl!)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One message in full: a coloured header with what kind of message it is and when it came,
/// the picture, the text, and its button.
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key, required this.notice, required this.actions});
  final Notice notice;
  final AppActions actions;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final n = notice;
    final look = _Look.of(n);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: tr('Back'),
                    child: Pressable(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.border)),
                        child: Icon(Icons.arrow_back_rounded, color: p.text, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Entrance(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [look.color.withValues(alpha: dark ? 0.28 : 0.2), look.color.withValues(alpha: dark ? 0.1 : 0.06)],
                    ),
                    border: Border.all(color: look.color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: look.color, borderRadius: BorderRadius.circular(17)),
                            child: Icon(look.icon, color: Colors.white, size: 27),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(look.label.toUpperCase(), style: KText.kicker(p.text)),
                                const SizedBox(height: 3),
                                Text(_ago(n.at), style: KText.small(p.subtle)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(n.title, style: KText.title(p.text).copyWith(fontSize: 28, height: 1.1)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 15, color: p.subtle),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_fullDate(n.at), style: KText.small(p.subtle))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (n.imageUrl != null) ...[
                const SizedBox(height: 16),
                Entrance(
                  delay: const Duration(milliseconds: 80),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(aspectRatio: 2, child: _NetImage(n.imageUrl!)),
                  ),
                ),
              ],
              if (n.body.isNotEmpty) ...[
                const SizedBox(height: 16),
                Entrance(
                  delay: const Duration(milliseconds: 120),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.border)),
                    child: SelectableText(n.body, style: KText.body(p.text).copyWith(fontSize: 16.5, height: 1.55)),
                  ),
                ),
              ],
              if (n.link != null) ...[
                const SizedBox(height: 20),
                KButton(label: n.linkLabel ?? 'Open', onTap: () => openLink(context, n.link, actions)),
              ],
              const SizedBox(height: 26),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const KMark(size: 22),
                  const SizedBox(width: 8),
                  Text(n.personal ? 'Sent to you by Konduct' : 'From the Konduct team', style: KText.small(p.subtle)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner ads (1200 × 600, 2:1) that slide by on their own. Shows nothing at all when there are
/// no live carousel ads, so the page closes up around it.
class AdCarousel extends StatefulWidget {
  const AdCarousel({super.key, required this.api, required this.actions, this.padding = EdgeInsets.zero});
  final MessagesApi api;
  final AppActions actions;

  /// Space around the carousel, applied only when it shows.
  final EdgeInsets padding;

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  late final _ads = widget.api.ads();
  final _pages = PageController();
  Timer? _auto;
  int _page = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_count < 2 || !_pages.hasClients) return;
      _pages.animateToPage((_page + 1) % _count, duration: const Duration(milliseconds: 550), curve: K.outExpo);
    });
  }

  final _fetched = <String>{};

  /// Starts every banner downloading now, so slides after the first are ready when they slide in.
  void _prefetch(BuildContext context, List<Ad> ads) {
    for (final ad in ads) {
      if (ad.imageUrl.isNotEmpty && _fetched.add(ad.imageUrl)) {
        precacheImage(CachedNetworkImageProvider(ad.imageUrl), context).catchError((_) {});
      }
    }
  }

  // Viewability (backend adstats.ts): a slide counts as seen once at least half of it has been on
  // screen for a full second, with the app in front and this screen on top. One count per visit:
  // the slide sliding in again is a new visit.
  Timer? _watch;
  List<Ad> _shown = const [];
  int _visitPage = -1;
  DateTime? _visibleSince;
  bool _counted = false;

  void _checkView() {
    if (!mounted || _shown.isEmpty) return;
    final page = _page.clamp(0, _shown.length - 1);
    if (page != _visitPage) {
      _visitPage = page;
      _visibleSince = null;
      _counted = false;
    }
    if (_counted) return;
    if (!_onScreen()) {
      _visibleSince = null;
      return;
    }
    final now = DateTime.now();
    _visibleSince ??= now;
    if (now.difference(_visibleSince!) >= const Duration(seconds: 1)) {
      _counted = true;
      widget.api.tracker.view('ad', _shown[page].id);
    }
  }

  /// The app is in front, this screen is the top one, and half the banner is inside the screen.
  bool _onScreen() {
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached || box.size.isEmpty) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final visible = rect.intersect(Offset.zero & MediaQuery.sizeOf(context));
    if (visible.isEmpty || visible.width <= 0 || visible.height <= 0) return false;
    return visible.width * visible.height >= 0.5 * rect.width * rect.height;
  }

  @override
  void dispose() {
    _auto?.cancel();
    _watch?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<List<Ad>>(
      stream: _ads,
      builder: (context, s) {
        final now = DateTime.now();
        final ads = (s.data ?? const <Ad>[]).where((a) => a.placement == AdPlacement.carousel && a.liveAt(now)).toList();
        _count = ads.length;
        if (ads.isEmpty) return const SizedBox.shrink();
        if (_page >= ads.length) _page = 0;
        _prefetch(context, ads);
        _shown = ads;
        _watch ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _checkView());
        return Padding(
          padding: widget.padding,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 2,
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: ads.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _Banner(ad: ads[i], actions: widget.actions, tracker: widget.api.tracker),
                  ),
                ),
              ),
              if (ads.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < ads.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(color: i == _page ? K.yellowDeep : p.border, borderRadius: BorderRadius.circular(3)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.ad, required this.actions, required this.tracker});
  final Ad ad;
  final AppActions actions;
  final AdTracker tracker;

  void _open(BuildContext context, String link) {
    tracker.tap('ad', ad.id);
    openLink(context, link, actions);
  }

  @override
  Widget build(BuildContext context) {
    final cta = ad.buttons.isEmpty ? null : ad.buttons.first;
    final hasText = ad.title.isNotEmpty || cta != null;
    return Semantics(
      label: tr(ad.title.isEmpty ? 'Advert' : 'Advert: ${ad.title}'),
      button: ad.link.isNotEmpty,
      child: GestureDetector(
        onTap: ad.link.isEmpty ? null : () => _open(context, ad.link),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _NetImage(ad.imageUrl),
            if (hasText)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xAA000000)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
            if (hasText)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        ad.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KText.h3(Colors.white).copyWith(fontSize: 18, shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
                      ),
                    ),
                    if (cta != null) ...[
                      const SizedBox(width: 10),
                      Pressable(
                        onTap: () => _open(context, cta.link),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(18)),
                          child: Text(cta.label, style: KText.small(K.ink).copyWith(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a home screen: opens popup messages and popup ads (once each), shows a banner when a
/// push arrives while the app is open, and follows pushes the person tapped.
class MessagesHost extends StatefulWidget {
  const MessagesHost({super.key, required this.api, required this.actions, required this.child, this.quietKinds = const {}});
  final MessagesApi api;
  final AppActions actions;
  final Widget child;

  /// Push kinds the app already announces itself (the driver's fare alert), so no banner.
  final Set<String> quietKinds;

  @override
  State<MessagesHost> createState() => _MessagesHostState();
}

class _MessagesHostState extends State<MessagesHost> {
  final _subs = <StreamSubscription<Object?>>[];
  List<Notice> _notices = const [];
  List<Ad> _ads = const [];
  Timer? _tick;
  bool _showing = false;
  OverlayEntry? _banner;
  Timer? _bannerTimer;

  MessagesApi get api => widget.api;

  @override
  void initState() {
    super.initState();
    api.seen.ready().then((_) {
      if (!mounted) return;
      _subs
        ..add(api.notices().listen((n) => _notices = n, onError: (_) {}))
        ..add(api.ads().listen((a) => _ads = a, onError: (_) {}))
        ..add(api.pushes().listen(_onPush));
      // Look for something to pop up once the home screen has settled, and again now and then
      // (a popup waits while another screen is open).
      _tick = Timer.periodic(const Duration(seconds: 2), (_) => _maybePopup());
    });
    api.startPush();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _tick?.cancel();
    _bannerTimer?.cancel();
    _banner?.remove();
    super.dispose();
  }

  bool get _inFront => mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _maybePopup() async {
    if (_showing || !_inFront) return;
    final notice = _notices.where((n) => n.popup && !n.read && !api.seen.has('pop:${n.key}')).firstOrNull;
    final now = DateTime.now();
    final ad = notice != null ? null : _ads.where((a) => a.placement == AdPlacement.popup && a.liveAt(now) && !api.seen.has('ad:${a.id}')).firstOrNull;
    if (notice == null && ad == null) return;
    _showing = true;
    HapticFeedback.lightImpact();
    try {
      if (notice != null) {
        await api.seen.add('pop:${notice.key}');
        await api.markRead(notice);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => _NoticePopup(notice: notice, actions: widget.actions),
        );
      } else {
        await api.seen.add('ad:${ad!.id}');
        if (!mounted) return;
        api.tracker.view('ad', ad.id);
        await showDialog<void>(
          context: context,
          builder: (_) => _AdPopup(ad: ad, actions: widget.actions, tracker: api.tracker),
        );
      }
    } finally {
      _showing = false;
    }
  }

  void _onPush(PushEvent e) {
    if (!mounted) return;
    if (e.tapped) {
      // Opened from the notification shade: go where it points, else to the inbox.
      if (e.link != null) {
        openLink(context, e.link, widget.actions);
      } else if (!widget.quietKinds.contains(e.kind)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InboxScreen(api: api, actions: widget.actions),
          ),
        );
      }
      return;
    }
    // In front: popups open by themselves from the inbox; everything else gets a banner.
    // Money alerts are always spoken (Voice): there is no system notification sound in front.
    Voice.announce(e.kind, e.data);
    if (e.popup || widget.quietKinds.contains(e.kind) || e.title.isEmpty) return;
    _showBanner(e);
  }

  void _showBanner(PushEvent e) {
    _bannerTimer?.cancel();
    _banner?.remove();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    late final OverlayEntry entry;
    void close() {
      if (_banner == entry) {
        entry.remove();
        _banner = null;
      }
    }

    entry = OverlayEntry(
      builder: (context) => _PushBanner(
        event: e,
        onTap: () {
          close();
          if (e.link != null) {
            openLink(this.context, e.link, widget.actions);
          } else {
            Navigator.of(this.context).push(
              MaterialPageRoute(
                builder: (_) => InboxScreen(api: api, actions: widget.actions),
              ),
            );
          }
        },
        onDismiss: close,
      ),
    );
    _banner = entry;
    overlay.insert(entry);
    HapticFeedback.mediumImpact();
    _bannerTimer = Timer(const Duration(seconds: 6), close);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PushBanner extends StatelessWidget {
  const _PushBanner({required this.event, required this.onTap, required this.onDismiss});
  final PushEvent event;
  final VoidCallback onTap, onDismiss;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: K.outExpo,
        builder: (_, v, child) => Transform.translate(
          offset: Offset(0, -80 * (1 - v)),
          child: Opacity(opacity: v, child: child),
        ),
        child: Dismissible(
          key: const ValueKey('push-banner'),
          direction: DismissDirection.up,
          onDismissed: (_) => onDismiss(),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: K.ink,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2A313C)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.notifications_active_rounded, color: K.ink, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (event.body.isNotEmpty) Text(event.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.small(K.muteDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({this.onImage = false});
  final bool onImage;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr('Close'),
    child: Pressable(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: onImage ? Colors.black.withValues(alpha: 0.45) : Palette.of(context).border, shape: BoxShape.circle),
        child: Icon(Icons.close_rounded, color: onImage ? Colors.white : Palette.of(context).text, size: 20),
      ),
    ),
  );
}

class _NoticePopup extends StatelessWidget {
  const _NoticePopup({required this.notice, required this.actions});
  final Notice notice;
  final AppActions actions;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final n = notice;
    return Dialog(
      backgroundColor: p.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (n.imageUrl != null)
              Stack(
                children: [
                  AspectRatio(aspectRatio: 2, child: _NetImage(n.imageUrl!)),
                  const Positioned(right: 10, top: 10, child: _CloseButton(onImage: true)),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(n.title, style: KText.h3(p.text))),
                      if (n.imageUrl == null) const _CloseButton(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(n.body, style: KText.body(p.subtle)),
                  const SizedBox(height: 20),
                  if (n.link != null) ...[
                    KButton(
                      label: n.linkLabel ?? 'Open',
                      onTap: () {
                        Navigator.of(context).pop();
                        openLink(context, n.link, actions);
                      },
                    ),
                    const SizedBox(height: 4),
                  ],
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(n.link == null ? 'OK' : 'Not now', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A popup ad: a 4:5 picture (1080 × 1350) with an optional title, text and up to two buttons.
class _AdPopup extends StatelessWidget {
  const _AdPopup({required this.ad, required this.actions, required this.tracker});
  final Ad ad;
  final AppActions actions;
  final AdTracker tracker;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    void go(String link) {
      tracker.tap('ad', ad.id);
      Navigator.of(context).pop();
      openLink(context, link, actions);
    }

    final hasText = ad.title.isNotEmpty || ad.body.isNotEmpty || ad.buttons.isNotEmpty;
    return Dialog(
      backgroundColor: p.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: ad.link.isEmpty ? null : () => go(ad.link),
                    child: AspectRatio(aspectRatio: 4 / 5, child: _NetImage(ad.imageUrl)),
                  ),
                  const Positioned(right: 10, top: 10, child: _CloseButton(onImage: true)),
                  Positioned(
                    left: 12,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(6)),
                      child: Text('AD', style: KText.kicker(Colors.white).copyWith(fontSize: 10)),
                    ),
                  ),
                ],
              ),
              if (hasText)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ad.title.isNotEmpty) Text(ad.title, style: KText.h3(p.text)),
                      if (ad.body.isNotEmpty) ...[const SizedBox(height: 6), Text(ad.body, style: KText.body(p.subtle))],
                      for (final (i, b) in ad.buttons.indexed) ...[
                        SizedBox(height: i == 0 ? 16 : 8),
                        KButton(label: b.label, dark: i > 0, onTap: () => go(b.link)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
