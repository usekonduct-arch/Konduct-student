import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../messages/messages_api.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/share_card.dart';
import '../../ui/wrapped.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

/// The most common value in [xs], with how many times it came up.
(T, int)? _top<T>(Iterable<T> xs) {
  final counts = <T, int>{};
  for (final x in xs) {
    counts[x] = (counts[x] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
  return (best.key, best.value);
}

String _minutes(int m) => m < 60 ? '${m}m' : '${m ~/ 60}h ${m % 60}m';

const _weekdays = ['Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'];

/// What kind of rider the hours say they are.
(String, String) _riderType(List<Activity> fares) {
  final hours = fares.map((f) => f.at.hour).toList();
  final early = hours.where((h) => h < 9).length, late = hours.where((h) => h >= 19).length;
  final rush = hours.where((h) => h >= 16 && h < 19).length;
  final n = hours.length;
  if (early >= n * 0.4) return ('Early bird', 'Most of your rides start before 9 am.');
  if (late >= n * 0.3) return ('Night owl', 'You keep Konduct busy after 7 pm.');
  if (rush >= n * 0.4) return ('Rush-hour hero', 'You ride when campus empties out, 4 to 7 pm.');
  return ('All-day rider', 'Morning, noon or evening, you\'re on the move.');
}

/// A rider's month as Wrapped slides and a summary card. [previous] is the month before, for "more than last month".
({List<WrappedSlide> slides, List<(String, String)> stats}) riderWrapped(DateTime month, List<Activity> fares, List<Activity> previous, String firstName) {
  final slides = <WrappedSlide>[];
  var c = 0;
  WrappedSlide slide({required String kicker, required String big, required String headline, String? sub, IconData? icon}) {
    final (bg, fg) = wrappedColors[c++ % wrappedColors.length];
    return WrappedSlide(kicker: kicker, big: big, headline: headline, sub: sub, background: bg, foreground: fg, icon: icon);
  }

  final name = monthName(month);
  slides.add(slide(kicker: 'Konduct Wrapped', big: name, headline: firstName.isEmpty ? 'Your month on Konduct.' : 'Your month on Konduct, $firstName.', sub: 'Tap to see it.', icon: Icons.auto_awesome_rounded));

  final rides = fares.length;
  final diff = rides - previous.length;
  slides.add(
    slide(
      kicker: 'You rode',
      big: '$rides',
      headline: rides == 1 ? 'ride with Konduct' : 'rides with Konduct',
      sub: previous.isEmpty ? 'Your first month riding with Konduct. Welcome aboard!' : (diff > 0 ? 'That\'s $diff more than last month.' : (diff == 0 ? 'Same as last month: steady.' : 'A quieter month than the last.')),
      icon: Icons.directions_bus_rounded,
    ),
  );

  final timed = fares.where((f) => f.tripRoute != null).toList();
  final minutes = timed.fold(0, (t, f) => t + f.tripRoute!.etaMin);
  if (minutes > 0) {
    slides.add(slide(kicker: 'On the road', big: _minutes(minutes), headline: 'riding around campus', sub: 'About ${(minutes / timed.length).round()} minutes a ride.', icon: Icons.schedule_rounded));
  }

  final route = _top(fares.map((f) => f.tripRoute?.label ?? (f.routeName.isEmpty ? null : f.routeName)).whereType<String>());
  if (route != null) slides.add(slide(kicker: 'Your top route', big: '${route.$2}×', headline: route.$1, sub: 'You know this road by heart.', icon: Icons.alt_route_rounded));

  final driver = _top(fares.map((f) => f.driverName).where((d) => d.isNotEmpty));
  if (driver != null && driver.$2 > 1) {
    slides.add(slide(kicker: 'Your favourite driver', big: driver.$1, headline: 'drove you ${driver.$2} times', sub: 'Rate them after your next ride.', icon: Icons.favorite_rounded));
  }

  final (type, why) = _riderType(fares);
  final day = _top(fares.map((f) => f.at.weekday));
  slides.add(slide(kicker: 'Your rider type', big: type, headline: why, sub: day == null ? null : '${_weekdays[day.$1 - 1]} were your busiest days.', icon: Icons.bolt_rounded));

  final friends = fares.fold(0, (t, f) => t + f.passengers - 1);
  if (friends > 0) {
    slides.add(slide(kicker: 'Squad goals', big: '$friends', headline: friends == 1 ? 'friend rode on you' : 'friends rode on you', sub: 'Paying for the group, the Konduct way.', icon: Icons.groups_rounded));
  }

  final spent = fares.fold(0, (t, f) => t + f.amountKobo);
  slides.add(slide(kicker: 'Cash you didn\'t need', big: naira(spent), headline: 'paid with a tap', sub: 'No change, no stress. ${naira(spent ~/ rides)} a ride on average.', icon: Icons.contactless_rounded));

  return (
    slides: slides,
    stats: [
      ('Rides', '$rides'),
      if (minutes > 0) ('On the road', _minutes(minutes)),
      if (route != null) ('Top route', route.$1),
      ('Rider type', type),
      if (driver != null && driver.$2 > 1) ('Favourite driver', driver.$1),
      if (friends > 0) ('Friends brought', '$friends'),
    ],
  );
}

/// Loads [month] (and the month before it) and plays the rider's Wrapped.
Future<void> openRiderWrapped(BuildContext context, RiderApi api, DateTime month, {required String firstName}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final results = await Future.wait([api.faresIn(month), api.faresIn(DateTime(month.year, month.month - 1))]);
    final brand = await api.messages.brand().first.timeout(const Duration(seconds: 4), onTimeout: () => const Brand());
    final sponsor = await api.messages.wrappedSponsor(month).timeout(const Duration(seconds: 4), onTimeout: () => null);
    // The share card is drawn off-screen into a picture: its logo has to be loaded first.
    if (sponsor != null && sponsor.logoUrl.isNotEmpty && navigator.mounted) {
      await precacheImage(CachedNetworkImageProvider(sponsor.logoUrl), navigator.context).catchError((_) {});
    }
    if (results[0].isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text('No rides in ${monthName(month)}, so no Wrapped yet.')));
      return;
    }
    final w = riderWrapped(month, results[0], results[1], firstName);
    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WrappedStory(
          slides: w.slides,
          sponsor: sponsor,
          tracker: api.messages.tracker,
          card: StoryCard(
            kicker: 'My ${monthName(month)} on Konduct',
            headline: 'Konduct\nWrapped',
            stats: w.stats,
            tags: brand.cardTags,
            style: StoryStyle.wrapped,
            sponsorName: sponsor?.name ?? '',
            sponsorLogoUrl: sponsor?.logoUrl ?? '',
          ),
          caption: brand.caption('My ${monthName(month)} on Konduct: ${results[0].length} rides, zero cash.'),
          fileName: 'konduct-wrapped-${month.year}-${month.month}',
        ),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Couldn\'t load your Wrapped. Check your connection and try again.')));
  }
}

/// Every month's Wrapped: this month so far, then the last five.
class WrappedMonthsScreen extends StatelessWidget {
  const WrappedMonthsScreen({super.key, required this.api, required this.firstName});
  final RiderApi api;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = DateTime.now();
    final months = [for (var i = 0; i < 6; i++) DateTime(now.year, now.month - i)];
    return PageFrame(
      kicker: 'Konduct Wrapped',
      title: 'Your months',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('A story of each month on Konduct: your rides, routes, favourite driver and more. Share it and tag us!', style: KText.body(p.subtle)),
          const SizedBox(height: 18),
          for (final (i, m) in months.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                scale: 0.98,
                onTap: () => openRiderWrapped(context, api, m, firstName: firstName),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: i == 1 ? K.ink : p.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: i == 1 ? K.ink : p.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: i == 1 ? K.yellow : K.yellowDeep),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(monthName(m), style: KText.body(i == 1 ? K.paper : p.text).copyWith(fontWeight: FontWeight.w800)),
                            Text(i == 0 ? 'So far this month' : (i == 1 ? 'Your latest Wrapped' : 'Look back'), style: KText.small(i == 1 ? K.muteDark : p.subtle)),
                          ],
                        ),
                      ),
                      Icon(Icons.play_arrow_rounded, color: i == 1 ? K.yellow : p.subtle),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// On the home screen for the first week of a month: last month's Wrapped is ready.
class WrappedBanner extends StatelessWidget {
  const WrappedBanner({super.key, required this.api, required this.firstName});
  final RiderApi api;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month - 1);
    return Pressable(
      scale: 0.98,
      onTap: () => openRiderWrapped(context, api, last, firstName: firstName),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [K.ink, Color(0xFF1F6F99)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: K.yellow, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your ${monthName(last)} Wrapped is here', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800)),
                  Text('Your rides, routes and favourite driver. Tap to play.', style: KText.small(K.muteDark)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill_rounded, color: K.yellow, size: 30),
          ],
        ),
      ),
    );
  }
}

/// After paying: share a picture that says you ride with Konduct, tagging Konduct's accounts.
class RideShareCard extends StatelessWidget {
  const RideShareCard({super.key, required this.api, this.trip, required this.at});
  final RiderApi api;
  final TripRoute? trip;
  final DateTime at;

  Future<void> _open(BuildContext context) async {
    final brand = await api.messages.brand().first.timeout(const Duration(seconds: 3), onTimeout: () => const Brand());
    if (!context.mounted) return;
    await showShareCard(
      context,
      title: 'Tell your friends',
      card: StoryCard(
        kicker: 'Just rode with Konduct',
        headline: trip == null ? 'No cash.\nNo change.\nJust ride.' : '${trip!.from}\n→ ${trip!.to}',
        lines: [if (trip != null) 'About ${trip!.etaMin} minutes, paid with a tap', whenText(at)],
        tags: brand.cardTags,
      ),
      caption: brand.caption(trip == null ? 'Just paid my bus fare with Konduct. No cash, no change.' : 'Just rode ${trip!.from} → ${trip!.to} and paid with Konduct. No cash, no change.'),
      fileName: 'konduct-ride',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      scale: 0.98,
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(color: K.yellow.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: K.yellowDeep.withValues(alpha: 0.5))),
        child: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: K.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tell your friends', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
                  Text('Share that you ride with Konduct and tag us', style: KText.small(p.subtle)),
                ],
              ),
            ),
            Icon(Icons.share_rounded, color: p.text),
          ],
        ),
      ),
    );
  }
}
