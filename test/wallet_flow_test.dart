import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_student/auth/auth_repository.dart';
import 'package:konduct_student/theme/tokens.dart';
import 'package:konduct_student/ui/kit.dart';
import 'package:konduct_student/wallet/demo_rider_api.dart';
import 'package:konduct_student/wallet/models.dart';
import 'package:konduct_student/wallet/screens/home_screen.dart';
import 'package:konduct_student/wallet/wallet_ui.dart';

import 'auth_flow_test.dart' show keypad, loadFonts, phoneSize, settle;

Future<DemoRiderApi> openHome(WidgetTester t) async {
  phoneSize(t);
  final api = DemoRiderApi();
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(Palette.rider, dark: false),
      home: HomeScreen(
        api: api,
        session: const Session(uid: 'u1', email: 'ada@uniosun.edu.ng', role: 'rider', pinSet: true, name: 'Adaeze Okafor'),
        onSignOut: () {},
      ),
    ),
  );
  await settle(t, 1500);
  return api;
}

/// Home → scan → (optional extra riders) → confirm screen.
Future<void> scanSample(WidgetTester t, {int riders = 1}) async {
  await t.tap(find.text('Scan to pay'));
  await settle(t, 900);
  for (var i = 1; i < riders; i++) {
    await t.tap(find.bySemanticsLabel('One more rider'));
    await settle(t, 200);
  }
  await t.tap(find.text('Tap to scan a sample sticker'));
  await settle(t, 1600);
}

Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await settle(t, 1500);
}

void main() {
  setUpAll(loadFonts);

  test('naira formatting', () {
    expect(naira(0), '₦0');
    expect(naira(20000), '₦200');
    expect(naira(150000), '₦1,500');
    expect(naira(123456789), '₦1,234,567.89');
    expect(naira(-5050), '-₦50.50');
  });

  test('times read like a person would say them', () {
    final now = DateTime(2026, 10, 14, 15, 0);
    expect(whenText(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
    expect(whenText(now.subtract(const Duration(minutes: 4)), now: now), '4 min ago');
    expect(whenText(DateTime(2026, 10, 14, 9, 5), now: now), 'Today, 09:05');
    expect(whenText(DateTime(2026, 10, 13, 18, 30), now: now), 'Yesterday, 18:30');
    expect(whenText(DateTime(2026, 9, 2, 7, 0), now: now), '2 Sep, 07:00');
  });

  testWidgets('a rider scans, pays and sees the balance drop', (t) async {
    await openHome(t);
    expect(find.text('₦1,500'), findsOneWidget);

    await scanSample(t);
    expect(find.text('Pay Tunde?'), findsOneWidget);
    expect(find.text('OS 482 KJA'), findsOneWidget);
    await t.tap(find.text('Pay ₦200'));
    await settle(t, 2000);

    expect(find.text('You\'re good to go.'), findsOneWidget);
    expect(find.text('SHOW THE DRIVER THIS CODE'), findsOneWidget);
    await t.tap(find.text('Done'));
    await settle(t, 1200);
    expect(find.text('₦1,300'), findsOneWidget);
    expect(find.text('Main gate → Faculty of Science'), findsOneWidget); // in Recent
    await done(t);
  });

  testWidgets('paying for friends over ₦500 asks for the PIN', (t) async {
    await openHome(t);
    await scanSample(t, riders: 3);
    expect(find.text('Me + 2 friends'), findsOneWidget);
    await t.tap(find.text('Pay ₦600'));
    await settle(t, 900);
    expect(find.text('Enter your PIN'), findsOneWidget);

    await keypad(t, '1357');
    await t.tap(find.text('Confirm'));
    await settle(t, 1600);
    expect(find.textContaining('Wrong PIN'), findsOneWidget); // asked again, with the reason

    for (var i = 0; i < 4; i++) {
      await t.tap(find.descendant(of: find.byType(Keypad), matching: find.byIcon(Icons.backspace_outlined)));
      await t.pump(const Duration(milliseconds: 60));
    }
    await keypad(t, '2580');
    await t.tap(find.text('Confirm'));
    await settle(t, 2000);
    expect(find.text('You\'re good to go.'), findsOneWidget);
    expect(find.text('You + 2'), findsOneWidget);
    await done(t);
  });

  testWidgets('a wrong-vehicle payment can be undone within a minute', (t) async {
    await openHome(t);
    await scanSample(t);
    await t.tap(find.text('Pay ₦200'));
    await settle(t, 2000);

    await t.tap(find.textContaining('Wrong vehicle? Undo'));
    await settle(t, 600);
    await t.tap(find.text('Undo'));
    await settle(t, 1500);
    expect(find.text('Payment undone.'), findsOneWidget);

    await t.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle(t, 1200);
    expect(find.text('₦1,500'), findsOneWidget);
    await done(t);
  });

  testWidgets('a second scan of the same vehicle asks before charging', (t) async {
    await openHome(t);
    await scanSample(t);
    await t.tap(find.text('Pay ₦200'));
    await settle(t, 2000);
    await t.tap(find.text('Done'));
    await settle(t, 1200);

    await scanSample(t);
    await t.tap(find.text('Pay ₦200'));
    await settle(t, 800);
    expect(find.text('You paid this vehicle a few minutes ago'), findsOneWidget);
    await t.tap(find.text('I already paid'));
    await settle(t, 800);
    expect(find.text('Pay Tunde?'), findsOneWidget); // nothing charged
    await t.tap(find.byIcon(Icons.arrow_back_rounded));
    await settle(t, 1200);
    expect(find.text('₦1,300'), findsOneWidget);
    await done(t);
  });

  testWidgets('a top-up shows as waiting, then lands in the balance', (t) async {
    await openHome(t);
    await t.tap(find.text('Top up'));
    await settle(t, 900);
    expect(find.text('How much?'), findsOneWidget);
    await t.tap(find.text('₦2,000'));
    await settle(t, 300);
    await t.tap(find.text('Pay ₦2,000'));
    await settle(t, 1200);

    expect(find.textContaining('Waiting for payment'), findsOneWidget);
    await settle(t, 2500);
    expect(find.text('₦3,500'), findsOneWidget);
    expect(find.text('+₦2,000'), findsOneWidget);
    await done(t);
  });
}
