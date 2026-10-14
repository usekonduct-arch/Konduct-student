import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:konduct_student/app/bootstrap.dart';
import 'package:konduct_student/auth/auth_controller.dart';
import 'package:konduct_student/auth/auth_repository.dart';
import 'package:konduct_student/auth/demo_auth_repository.dart';
import 'package:konduct_student/auth/screens/pin_screen.dart';
import 'package:konduct_student/ui/kit.dart';

Future<void> settle(WidgetTester t, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> keypad(WidgetTester t, String digits) async {
  for (final d in digits.split('')) {
    await t.tap(find.descendant(of: find.byType(Keypad), matching: find.text(d)));
    await t.pump(const Duration(milliseconds: 60));
  }
}

/// Load the bundled fonts so text measures like it does on a phone (the test
/// default font draws every glyph as a 1em square).
Future<void> loadFonts() async {
  final families = {
    'Bricolage': ['BricolageGrotesque-500', 'BricolageGrotesque-700', 'BricolageGrotesque-800'],
    'Figtree': ['Figtree-400', 'Figtree-500', 'Figtree-600', 'Figtree-700', 'Figtree-800'],
    'JetBrainsMono': ['JetBrainsMono-500', 'JetBrainsMono-700'],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(File('assets/fonts/$f.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }
}

void phoneSize(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

/// From the welcome screen: open the account screen, pick a tab, fill both fields, submit.
Future<void> account(WidgetTester t, {required String email, required String password, bool signUp = true}) async {
  await t.tap(find.text('Get started'));
  await settle(t);
  if (!signUp) {
    await t.tap(find.text('Sign in').first);
    await settle(t, 600);
  }
  await t.enterText(find.byType(TextField).at(0), email);
  await t.enterText(find.byType(TextField).at(1), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, 400);
  await t.tap(find.text(signUp ? 'Create account' : 'Sign in').last);
  await settle(t, 1600);
}

void main() {
  setUpAll(loadFonts);

  test('email shape check', () {
    expect(looksLikeEmail('ada@uniosun.edu.ng'), isTrue);
    expect(looksLikeEmail(' ada.okafor+ride@gmail.com '), isTrue);
    for (final bad in ['ada', 'ada@', '@uniosun.edu.ng', 'ada@uniosun', 'ada okafor@gmail.com', '']) {
      expect(looksLikeEmail(bad), isFalse, reason: bad);
    }
  });

  test('weak PINs are refused', () {
    for (final p in ['1111', '1234', '9876', '123456', '000000']) {
      expect(isWeakPin(p), isTrue, reason: p);
    }
    for (final p in ['2580', '1379', '204816']) {
      expect(isWeakPin(p), isFalse, reason: p);
    }
  });

  testWidgets('a student signs up end to end in demo mode', (t) async {
    phoneSize(t);
    final auth = AuthController(DemoAuthRepository());
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    expect(auth.stage, Stage.signedOut);

    await account(t, email: 'ada@uniosun.edu.ng', password: 'ride-the-bus-1');
    expect(auth.stage, Stage.riderProfile);

    await t.enterText(find.byType(TextField).at(0), 'Adaeze Okafor');
    await t.enterText(find.byType(TextField).at(1), 'UNI/2023/04571');
    await t.tap(find.textContaining('I agree'));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 600);
    await t.tap(find.text('Continue'));
    await settle(t, 2200);
    expect(auth.stage, Stage.pin);

    await keypad(t, '2580');
    await settle(t, 800);
    expect(find.text('Enter it once more.'), findsOneWidget);
    await keypad(t, '2580');
    await settle(t, 2400);
    expect(auth.stage, Stage.ready);
    expect(find.textContaining('Welcome aboard'), findsOneWidget);
    expect(find.text('ada@uniosun.edu.ng'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a short password is caught before anything is sent', (t) async {
    phoneSize(t);
    final auth = AuthController(DemoAuthRepository());
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    await t.tap(find.text('Get started'));
    await settle(t);
    await t.enterText(find.byType(TextField).at(0), 'ada@uniosun.edu.ng');
    await t.enterText(find.byType(TextField).at(1), 'short');
    await settle(t, 400);
    expect(find.text('3 more'), findsOneWidget); // the meter counts down to 8 characters
    await t.tap(find.text('Create account').last);
    await settle(t, 800);
    expect(auth.stage, Stage.signedOut); // the button stays disabled below 8 characters

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a wrong password and a taken email are explained, not crashed', (t) async {
    phoneSize(t);
    final repo = DemoAuthRepository();
    final auth = AuthController(repo);
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);

    await account(t, email: 'taken@konduct.app', password: 'whatever-123');
    expect(auth.stage, Stage.signedOut);
    expect(find.textContaining('already an account'), findsOneWidget);

    await t.tap(find.text('Sign in').first);
    await settle(t, 600);
    await t.enterText(find.byType(TextField).at(1), 'wrong-password');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 400);
    await t.tap(find.text('Sign in').last);
    await settle(t, 1600);
    expect(auth.stage, Stage.signedOut);
    expect(find.textContaining('don\'t match'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });

  testWidgets('a duplicate student ID is refused with a message', (t) async {
    phoneSize(t);
    final repo = DemoAuthRepository();
    final auth = AuthController(repo);
    await t.pumpWidget(KonductApp(auth: auth));
    await settle(t, 2600);
    await t.runAsync(() => repo.signUp('ade@uniosun.edu.ng', 'ride-the-bus-1'));
    await settle(t, 1500);

    await t.enterText(find.byType(TextField).at(0), 'Ade Bello');
    await t.enterText(find.byType(TextField).at(1), 'DUP123');
    await t.tap(find.textContaining('I agree'));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t, 600);
    await t.tap(find.text('Continue'));
    await settle(t, 2000);
    expect(auth.stage, Stage.riderProfile);
    expect(find.textContaining('already on another account'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await settle(t, 1500);
  });
}
