import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/web_screen.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

/// Seats left as a word and a colour: plenty, filling up, full.
(String, Color) _seatState(int left) => switch (left) {
  0 => ('Full', K.coral),
  1 => ('1 seat left', K.yellowDeep),
  2 => ('2 seats left', K.yellowDeep),
  _ => ('$left seats left', K.go),
};

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Home: one card per park with the buses checked in there and their free seats. Tapping a card
/// (or "See all") opens the full board.
class BusBoardStrip extends StatelessWidget {
  const BusBoardStrip({super.key, required this.api, required this.parks, required this.buses});
  final RiderApi api;
  final List<Park> parks;
  final List<LiveBus> buses;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = DateTime.now();
    final onRoad = buses.where((b) => b.parkAt(now) == null).length;
    void open([String? parkId]) => pushScreen(context, BusesScreen(api: api, parkId: parkId));
    final cards = <Widget>[
      for (final park in parks) _ParkCard(park: park, buses: buses.where((b) => b.parkAt(now) == park.id).toList(), onTap: () => open(park.id)),
      if (onRoad > 0) _RoadCard(count: onRoad, onTap: () => open(BusesScreen.onRoad)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('BUSES NOW', style: KText.kicker(p.subtle)),
            const Spacer(),
            Pressable(
              onTap: open,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text('Buses & routes', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            // Two cards fill the row; more scroll sideways with the next one peeking in.
            final width = cards.length <= 2 ? (c.maxWidth - 10 * (cards.length - 1)) / cards.length : (c.maxWidth - 10) / 2.2;
            return SizedBox(
              height: 158,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: cards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SizedBox(width: width, child: cards[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ParkCard extends StatelessWidget {
  const _ParkCard({required this.park, required this.buses, required this.onTap});
  final Park park;
  final List<LiveBus> buses;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = DateTime.now();
    final free = buses.fold(0, (t, b) => t + b.seatsLeftAt(now));
    final heading = {for (final b in buses) ?b.trip?.to}.take(2).join(', ');
    // No bus has checked in on Konduct: fall back to what staff last counted, if it's recent.
    final staffCount = buses.isEmpty && park.busCount > 0 && !park.staleAt(now) ? park.busCount : null;
    final detail = buses.isNotEmpty
        ? [free == 0 ? 'All full' : '$free ${free == 1 ? 'seat' : 'seats'} free', if (heading.isNotEmpty) 'to $heading'].join(' · ')
        : staffCount != null
        ? 'Staff counted $staffCount · ${_lower(whenText(park.updatedAt!, now: now))}'
        : 'No buses checked in';
    final count = buses.length;
    return Semantics(
      button: true,
      label: '${park.name}: $count ${count == 1 ? 'bus' : 'buses'} checked in. $detail.',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.97,
        onTap: onTap,
        child: Panel(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$count', style: KText.title(p.text).copyWith(fontSize: 34)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(count == 1 ? 'bus' : 'buses', style: KText.small(p.subtle)),
                  ),
                  const Spacer(),
                  if (count > 0) _Dot(color: free == 0 ? K.coral : K.go),
                ],
              ),
              const Spacer(),
              Text(park.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: KText.small(p.subtle).copyWith(fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadCard extends StatelessWidget {
  const _RoadCard({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$count ${count == 1 ? 'bus' : 'buses'} on the road',
    excludeSemantics: true,
    child: Pressable(
      scale: 0.97,
      onTap: onTap,
      child: Panel(
        color: K.ink,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$count', style: KText.title(K.paper).copyWith(fontSize: 34)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(count == 1 ? 'bus' : 'buses', style: KText.small(K.muteDark)),
                ),
                const Spacer(),
                const Icon(Icons.directions_bus_rounded, color: K.yellow, size: 20),
              ],
            ),
            const Spacer(),
            Text('On the road', style: KText.body(K.paper).copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Where they\'re going and seats left', maxLines: 2, style: KText.small(K.muteDark).copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
  );
}

/// The full live board: every bus by park or on the road, then the fare routes.
class BusesScreen extends StatefulWidget {
  const BusesScreen({super.key, required this.api, this.parkId});
  final RiderApi api;

  /// Opens filtered to one park, or to [onRoad].
  final String? parkId;

  static const onRoad = '_road';

  @override
  State<BusesScreen> createState() => _BusesScreenState();
}

class _BusesScreenState extends State<BusesScreen> {
  late Stream<List<LiveBus>> _buses;
  late Stream<List<Park>> _parks;
  late Stream<List<FareRoute>> _routes;
  late String? _filter = widget.parkId;
  // Seats reset and check-ins lapse on their own; re-read the clock now and then.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _buses = widget.api.buses();
    _parks = widget.api.parks();
    _routes = widget.api.routes();
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(_listen);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Live',
      title: 'Buses & routes',
      onRefresh: _refresh,
      child: StreamBuilder<List<Park>>(
        stream: _parks,
        builder: (_, parksSnap) => StreamBuilder<List<LiveBus>>(
          stream: _buses,
          builder: (_, busesSnap) {
            if (busesSnap.hasError) return const _Note(icon: Icons.cloud_off_rounded, text: 'Couldn\'t load the buses. Pull down to try again.');
            if (!busesSnap.hasData) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: K.yellowDeep)));
            }
            final now = DateTime.now();
            final parks = parksSnap.data ?? const <Park>[];
            final all = busesSnap.data!;
            final onRoad = all.where((b) => b.parkAt(now) == null).toList();
            final shown = switch (_filter) {
              null => all,
              BusesScreen.onRoad => onRoad,
              final id => all.where((b) => b.parkAt(now) == id).toList(),
            };
            // At a park first, the emptiest bus first; then the ones on the road.
            shown.sort((a, b) {
              final atPark = (a.parkAt(now) == null ? 1 : 0).compareTo(b.parkAt(now) == null ? 1 : 0);
              return atPark != 0 ? atPark : b.seatsLeftAt(now).compareTo(a.seatsLeftAt(now));
            });
            final where = _filter == null ? null : (_filter == BusesScreen.onRoad ? 'on the road' : 'at ${parks.where((x) => x.id == _filter).firstOrNull?.name ?? 'this park'}');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _Chip(label: 'All', count: all.length, selected: _filter == null, onTap: () => setState(() => _filter = null)),
                      for (final park in parks)
                        _Chip(
                          label: park.name,
                          count: all.where((b) => b.parkAt(now) == park.id).length,
                          selected: _filter == park.id,
                          onTap: () => setState(() => _filter = park.id),
                        ),
                      _Chip(label: 'On the road', count: onRoad.length, selected: _filter == BusesScreen.onRoad, onTap: () => setState(() => _filter = BusesScreen.onRoad)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (parks.where((x) => x.id == _filter && x.hasPin).firstOrNull case final park?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Pressable(
                      onTap: () => openWeb(context, 'https://www.google.com/maps/search/?api=1&query=${park.lat},${park.lng}', title: park.name),
                      child: Row(
                        children: [
                          Icon(Icons.map_rounded, size: 18, color: p.text),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Directions to ${park.name}', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline))),
                          Text(park.location, style: KText.small(p.subtle)),
                        ],
                      ),
                    ),
                  ),
                if (shown.isEmpty)
                  _Note(icon: Icons.directions_bus_outlined, text: where == null ? 'No buses on Konduct right now.' : 'No buses $where right now.')
                else
                  for (final b in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: BusCard(bus: b, now: now)),
                const SizedBox(height: 4),
                Text(
                  'Seats left are counted from payments in the app, so riders paying cash aren\'t included. Everything here updates live.',
                  style: KText.small(p.subtle),
                ),
                const SizedBox(height: 28),
                Text('ROUTES & FARES', style: KText.kicker(p.subtle)),
                const SizedBox(height: 10),
                StreamBuilder<List<FareRoute>>(
                  stream: _routes,
                  builder: (_, r) {
                    final routes = r.data ?? const <FareRoute>[];
                    if (routes.isEmpty) return r.hasData ? const _Note(icon: Icons.alt_route_rounded, text: 'No routes yet.') : const SizedBox.shrink();
                    return Column(
                      children: [
                        for (final route in routes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RouteCard(route: route, buses: all.where((b) => b.fareRouteId == route.id).length),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.count, required this.selected, required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Pressable(
          scale: 0.95,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? K.ink : p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? K.ink : p.border),
            ),
            child: Text('$label · $count', style: KText.small(selected ? K.paper : p.text).copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

/// One bus: plate, driver, where it's going, seats left as a bar, where it is, the fare.
class BusCard extends StatelessWidget {
  const BusCard({super.key, required this.bus, required this.now});
  final LiveBus bus;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final taken = bus.takenAt(now);
    final left = bus.capacity - taken;
    final (seatText, seatColor) = _seatState(left);
    final park = bus.parkAt(now) == null ? null : bus.parkName;
    final status = park != null
        ? 'At $park${bus.parkSince == null ? '' : ' · arrived ${_lower(whenText(bus.parkSince!, now: now))}'}'
        : 'On the road';
    final trip = bus.trip;
    return Semantics(
      label: [
        '${bus.isBike ? 'Bike' : 'Bus'} ${bus.plate}',
        if (bus.driverName.isNotEmpty) 'driver ${bus.driverName}',
        trip == null ? 'route not set' : 'going ${trip.from} to ${trip.to}, about ${trip.etaMin} minutes',
        left == 0 ? 'full' : 'about $left of ${bus.capacity} seats free',
        status,
        if (bus.fareKobo > 0) 'fare ${naira(bus.fareKobo)}',
      ].join(', '),
      excludeSemantics: true,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(6)),
                  child: Text(bus.plate, style: KText.mono(K.ink, size: 12)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: bus.driverName.isEmpty ? (bus.isBike ? 'Bike' : 'Bus') : bus.driverName),
                        if (bus.rating != null) TextSpan(text: '  ★ ${bus.rating!.toStringAsFixed(1)}', style: KText.small(p.subtle)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(seatText, style: KText.body(seatColor).copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.place_rounded, size: 18, color: trip == null ? p.subtle : K.yellowDeep),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    trip?.label ?? 'Route not set yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.body(trip == null ? p.subtle : p.text).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trip != null) Text('~${trip.etaMin} min', style: KText.small(p.subtle)),
              ],
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < bus.capacity; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        height: 8,
                        decoration: BoxDecoration(
                          color: i < taken ? (left == 0 ? K.coral : K.yellow) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: i < taken ? Colors.transparent : p.border, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(park != null ? Icons.local_parking_rounded : Icons.directions_bus_rounded, size: 15, color: p.subtle),
                const SizedBox(width: 5),
                Expanded(child: Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.small(p.subtle))),
                if (bus.fareKobo > 0) Text(naira(bus.fareKobo), style: KText.mono(p.text, size: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.buses});
  final FareRoute route;
  final int buses;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(route.name, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800))),
              Text('${naira(route.fareKobo)} a rider', style: KText.mono(p.text, size: 13)),
            ],
          ),
          if (route.stops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 6,
              children: [
                for (var i = 0; i < route.stops.length; i++) ...[
                  if (i > 0) Icon(Icons.arrow_forward_rounded, size: 13, color: p.subtle),
                  Text(route.stops[i], style: KText.small(p.text)),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            buses == 0 ? 'No buses on this route right now' : '$buses ${buses == 1 ? 'bus' : 'buses'} on this route now',
            style: KText.small(buses == 0 ? p.subtle : K.green).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
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
          Expanded(child: Text(text, style: KText.small(p.text))),
        ],
      ),
    );
  }
}
