import 'package:flutter/material.dart' hide Text;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/text.dart';
import '../../theme/tokens.dart';
import '../../ui/field.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';

/// Map groups, in the order students see them. Keys match PLACE_CATEGORIES in the backend, plus park.
const campusCategories = <String, (String, IconData)>{
  'park': ('Bus parks', Icons.directions_bus_rounded),
  'academic': ('Faculties & lecture halls', Icons.school_rounded),
  'office': ('Offices', Icons.business_rounded),
  'hostel': ('Hostels', Icons.bed_rounded),
  'food': ('Food', Icons.restaurant_rounded),
  'health': ('Health', Icons.local_hospital_rounded),
  'bank': ('Banks & ATMs', Icons.account_balance_rounded),
  'worship': ('Worship', Icons.church_rounded),
  'other': ('Other places', Icons.place_rounded),
};

(String, IconData) _category(String key) => campusCategories[key] ?? campusCategories['other']!;

/// Places matching what the student typed (name or note) in the chosen group.
List<CampusPlace> filterPlaces(List<CampusPlace> places, String query, String? category) {
  final q = query.trim().toLowerCase();
  return [
    for (final place in places)
      if ((category == null || place.category == category) && (place.name.toLowerCase().contains(q) || place.note.toLowerCase().contains(q))) place,
  ];
}

/// The campus guide for new students: every pinned place on a map, searchable, with walking directions.
class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key, required this.api});
  final RiderApi api;

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  late final _places = widget.api.campusPlaces();
  late final _parks = widget.api.parks();
  final _map = MapController();
  final _search = TextEditingController();
  String? _group;
  String? _pickedId;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _pick(CampusPlace place) {
    FocusScope.of(context).unfocus();
    setState(() => _pickedId = place.id);
    _map.move(LatLng(place.lat, place.lng), 17);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceSheet(place: place),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      kicker: 'Osun State University',
      title: 'Campus map',
      scroll: false,
      child: StreamBuilder<List<Park>>(
        stream: _parks,
        builder: (_, parksSnap) => StreamBuilder<List<CampusPlace>>(
          stream: _places,
          builder: (_, placesSnap) {
            if (placesSnap.hasError) return const _Note(icon: Icons.cloud_off_rounded, text: 'Couldn\'t load the map. Check your data or Wi-Fi, then try again.');
            if (!placesSnap.hasData) return const Center(child: CircularProgressIndicator(color: K.yellowDeep));
            final all = [...placesSnap.data!, for (final park in parksSnap.data ?? const <Park>[]) if (park.hasPin) CampusPlace.park(park)];
            if (all.isEmpty) return const _Note(icon: Icons.map_outlined, text: 'We\'re still adding places to the map. Check back soon.');
            return _body(all);
          },
        ),
      ),
    );
  }

  Widget _body(List<CampusPlace> all) {
    final p = Palette.of(context);
    final shown = filterPlaces(all, _search.text, _group);
    final groups = campusCategories.keys.where((k) => all.any((x) => x.category == k)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: [for (final place in all) LatLng(place.lat, place.lng)],
                  padding: const EdgeInsets.all(48),
                  maxZoom: 17,
                ),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'ng.com.konduct.app', maxZoom: 19),
                MarkerLayer(
                  markers: [
                    for (final place in shown)
                      Marker(
                        point: LatLng(place.lat, place.lng),
                        width: 44,
                        height: 44,
                        child: _Pin(place: place, picked: place.id == _pickedId, onTap: () => _pick(place)),
                      ),
                  ],
                ),
                const _Credit(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        KField(controller: _search, label: 'Search for a place', icon: Icons.search_rounded, capitalization: TextCapitalization.words),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _Chip(label: 'All', selected: _group == null, onTap: () => setState(() => _group = null)),
              for (final g in groups) _Chip(label: _category(g).$1, selected: _group == g, onTap: () => setState(() => _group = g)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 4,
          child: shown.isEmpty
              ? const Align(alignment: Alignment.topCenter, child: _Note(icon: Icons.search_off_rounded, text: 'No places match that search.'))
              : ListView.separated(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _PlaceRow(place: shown[i], onTap: () => _pick(shown[i])),
                ),
        ),
        const SizedBox(height: 8),
        Text('Pins are checked by the Konduct team. Walking directions open in your maps app.', style: KText.small(p.subtle).copyWith(fontSize: 12)),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.place, required this.picked, required this.onTap});
  final CampusPlace place;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: place.name,
    child: GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: picked ? 38 : 30,
          height: picked ? 38 : 30,
          decoration: BoxDecoration(
            color: picked ? K.ink : K.yellow,
            shape: BoxShape.circle,
            border: Border.all(color: picked ? K.yellow : K.ink, width: 2),
          ),
          child: Icon(_category(place.category).$2, size: picked ? 20 : 16, color: picked ? K.yellow : K.ink),
        ),
      ),
    ),
  );
}

/// OpenStreetMap's licence asks for this on the map itself.
class _Credit extends StatelessWidget {
  const _Credit();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication).catchError((_) => false),
      child: Container(
        color: Colors.white.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('© OpenStreetMap contributors', translate: false, style: KText.small(K.ink).copyWith(fontSize: 11)),
      ),
    ),
  );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.place, required this.onTap});
  final CampusPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (group, icon) = _category(place.category);
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: p.text),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, translate: false, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w700)),
                  Text(group, maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.small(p.subtle).copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceSheet extends StatelessWidget {
  const _PlaceSheet({required this.place});
  final CampusPlace place;

  void _directions() {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${place.lat},${place.lng}&travelmode=walking';
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank').catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 20 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_category(place.category).$1.toUpperCase(), style: KText.kicker(p.subtle)),
          const SizedBox(height: 6),
          Text(place.name, translate: false, style: KText.h3(p.text)),
          if (place.note.isNotEmpty) ...[const SizedBox(height: 6), Text(place.note, translate: false, style: KText.body(p.subtle))],
          const SizedBox(height: 18),
          KButton(label: 'Get walking directions', icon: Icons.directions_walk_rounded, onTap: _directions),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
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
            child: Text(label, style: KText.small(selected ? K.paper : p.text).copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
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
          Expanded(child: Text(text, style: KText.small(p.subtle))),
        ],
      ),
    );
  }
}
