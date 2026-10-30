import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_student/auth/auth_repository.dart';
import 'package:konduct_student/messages/messages_api.dart';
import 'package:konduct_student/messages/messages_ui.dart';
import 'package:konduct_student/messages/voice.dart';
import 'package:konduct_student/theme/tokens.dart';
import 'package:konduct_student/wallet/demo_rider_api.dart';
import 'package:konduct_student/wallet/screens/home_screen.dart';

import 'auth_flow_test.dart' show loadFonts, phoneSize, settle;

Future<void> openHome(WidgetTester t, DemoMessagesApi messages) async {
  phoneSize(t);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(Palette.rider, dark: false),
      home: HomeScreen(
        api: DemoRiderApi(messages: messages),
        session: const Session(uid: 'u1', email: 'ada@uniosun.edu.ng', role: 'rider', pinSet: true, name: 'Adaeze Okafor'),
        onSignOut: () {},
      ),
    ),
  );
  await settle(t, 1500);
}

Future<void> done(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await settle(t, 1500);
}

const _banner = Ad(
  id: 'ad1',
  placement: AdPlacement.carousel,
  imageUrl: 'https://example.com/a.jpg',
  title: 'Ride more, pay less',
  buttons: [AdButton('Top up', 'app:topup')],
);

void main() {
  setUpAll(loadFonts);

  test('money alerts are spoken with the amount', () {
    expect(Voice.sentenceFor('fare.received', {'amountKobo': '60000', 'riders': '3'}), 'Payment received. 600 naira, from 3 riders.');
    expect(Voice.sentenceFor('fare.received', {'amountKobo': '20000', 'riders': '1'}), 'Payment received. 200 naira.');
    expect(Voice.sentenceFor('fare.received', const {}), 'Payment received.');
    expect(Voice.sentenceFor('wallet.funded', {'amountKobo': '125050'}), 'Your wallet has been topped up with 1250 naira 50 kobo.');
    expect(Voice.sentenceFor('payout.paid', {'amountKobo': '340000'}), '3400 naira has been sent to your bank.');
    expect(Voice.sentenceFor('support.reply', const {}), isNull);
  });

  testWidgets('with no ads the carousel takes no space at all', (t) async {
    await openHome(t, DemoMessagesApi());
    expect(find.byType(AdCarousel), findsOneWidget);
    expect(find.descendant(of: find.byType(AdCarousel), matching: find.byType(PageView)), findsNothing);
    expect(t.getSize(find.byType(AdCarousel)).height, 0);
    await done(t);
  });

  testWidgets('a carousel ad shows, and its button opens the screen it names', (t) async {
    await openHome(t, DemoMessagesApi(ads: const [_banner]));
    expect(find.text('Ride more, pay less'), findsOneWidget);
    expect(t.getSize(find.descendant(of: find.byType(AdCarousel), matching: find.byType(AspectRatio))).aspectRatio, closeTo(2, 0.01));
    await t.tap(find.text('Top up').last);
    await settle(t, 900);
    expect(find.text('How much?'), findsOneWidget);
    await done(t);
  });

  testWidgets('an ad that has ended or not started yet stays hidden', (t) async {
    final now = DateTime.now();
    await openHome(
      t,
      DemoMessagesApi(
        ads: [
          Ad(
            id: 'old',
            placement: AdPlacement.carousel,
            imageUrl: 'https://example.com/a.jpg',
            title: 'Old offer',
            endsAt: now.subtract(const Duration(days: 1)),
          ),
          Ad(
            id: 'soon',
            placement: AdPlacement.carousel,
            imageUrl: 'https://example.com/b.jpg',
            title: 'Later offer',
            startsAt: now.add(const Duration(days: 1)),
          ),
        ],
      ),
    );
    expect(find.text('Old offer'), findsNothing);
    expect(find.text('Later offer'), findsNothing);
    await done(t);
  });

  testWidgets('a popup ad opens once a day, with its buttons', (t) async {
    final messages = DemoMessagesApi(
      ads: const [
        Ad(
          id: 'pop1',
          placement: AdPlacement.popup,
          imageUrl: 'https://example.com/p.jpg',
          title: 'Weekend promo',
          body: 'Half price rides on Saturday',
          buttons: [AdButton('Top up now', 'app:topup')],
        ),
      ],
    );
    await openHome(t, messages);
    await settle(t, 2500);
    expect(find.text('Weekend promo'), findsOneWidget);
    expect(find.text('Top up now'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Close').last);
    await settle(t, 3000);
    expect(find.text('Weekend promo'), findsNothing);
    expect(messages.seen.hasToday('ad:pop1'), isTrue);
    await done(t);
  });

  testWidgets('a popup message from staff opens over the app and counts as read', (t) async {
    final messages = DemoMessagesApi(
      notices: [Notice(id: 'n1', title: 'Service update', body: 'Buses run late tonight.', at: DateTime.now(), personal: true, popup: true)],
    );
    await openHome(t, messages);
    await settle(t, 2500);
    expect(find.text('Service update'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t, 600);
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget); // no unread count left
    await done(t);
  });

  testWidgets('the bell shows unread messages and opens the inbox and the message', (t) async {
    await openHome(t, DemoMessagesApi());
    expect(find.bySemanticsLabel('Notifications, 1 unread'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Notifications, 1 unread'));
    await settle(t, 900);
    expect(find.text('Notifications'), findsOneWidget);
    await t.tap(find.text('Welcome to Konduct'));
    await settle(t, 900);
    expect(find.text('Messages from the Konduct team show up here.'), findsOneWidget);
    await done(t);
  });

  testWidgets('a push that arrives while the app is open shows a banner', (t) async {
    final messages = DemoMessagesApi();
    await openHome(t, messages);
    messages.simulatePush(const PushEvent(title: '₦2,000 added', body: 'Your Konduct wallet is topped up.', kind: 'wallet.funded'));
    await settle(t, 600);
    expect(find.text('₦2,000 added'), findsOneWidget);
    await settle(t, 6500);
    expect(find.text('₦2,000 added'), findsNothing);
    await done(t);
  });
}
