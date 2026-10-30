import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_student/theme/tokens.dart';
import 'package:konduct_student/wallet/demo_rider_api.dart';
import 'package:konduct_student/wallet/models.dart';
import 'package:konduct_student/wallet/screens/campus_map_screen.dart';

import 'auth_flow_test.dart' show phoneSize, settle;

/// A demo campus with no places on it.
class _EmptyCampus extends DemoRiderApi {
  @override
  Stream<List<CampusPlace>> campusPlaces() => Stream.value(const []);
  @override
  Stream<List<Park>> parks() => Stream.value(const []);
}

Future<void> open(WidgetTester t, DemoRiderApi api) async {
  phoneSize(t);
  await t.pumpWidget(MaterialApp(theme: buildTheme(Palette.rider, dark: false), home: CampusMapScreen(api: api)));
  await settle(t, 800);
}

void main() {
  const library = CampusPlace(id: 'a', name: 'University Library', category: 'academic', note: 'Behind the Senate building', lat: 7.76, lng: 4.6);
  const hostel = CampusPlace(id: 'b', name: 'Female hostel', category: 'hostel', lat: 7.77, lng: 4.61);

  test('search matches a name or a note, in any case, inside the chosen group', () {
    expect(filterPlaces([library, hostel], '', null), [library, hostel]);
    expect(filterPlaces([library, hostel], ' HOSTEL ', null), [hostel]);
    expect(filterPlaces([library, hostel], 'senate', null), [library]);
    expect(filterPlaces([library, hostel], '', 'hostel'), [hostel]);
    expect(filterPlaces([library, hostel], 'library', 'hostel'), isEmpty);
  });

  test('a park keeps its pin and joins the parks group', () {
    final place = CampusPlace.park(const Park(id: 'shasha', name: 'Shasha park', location: 'Shasha junction', busCount: 0, lat: 7.77, lng: 4.55));
    expect((place.id, place.category, place.note, place.lat), ('park_shasha', 'park', 'Shasha junction', 7.77));
  });

  testWidgets('with nothing pinned yet the screen says so instead of showing an empty map', (t) async {
    await open(t, _EmptyCampus());
    expect(find.textContaining('still adding places'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('places list, filter by search, and open with walking directions', (t) async {
    await open(t, DemoRiderApi());
    expect(find.text('Sample library'), findsOneWidget);
    expect(find.text('Sample hostel'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'hostel');
    await settle(t, 300);
    expect(find.text('Sample library'), findsNothing);
    await t.tap(find.text('Sample hostel'));
    await settle(t, 600);
    expect(find.text('Get walking directions'), findsOneWidget);
  });
}
