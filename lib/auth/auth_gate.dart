import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../wallet/rider_api.dart';
import '../wallet/screens/home_screen.dart';
import 'auth_controller.dart';
import 'screens/email_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/ready_screen.dart';
import 'screens/rider_profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

/// Shows the screen for the current sign-up stage and animates between stages.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth, required this.api});
  final AuthController auth;
  final RiderApi api;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 650),
        switchInCurve: K.outExpo,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
        ),
        child: KeyedSubtree(key: ValueKey((auth.stage, auth.justJoined)), child: _screen(context)),
      ),
    );
  }

  Widget _screen(BuildContext context) {
    final demo = auth.repo.isDemo;
    // Account, profile, PIN.
    double step(int n) => n / 3;

    switch (auth.stage) {
      case Stage.booting:
        return const SplashScreen();
      case Stage.signedOut:
        return _SignedOutFlow(auth: auth, progress: step);
      case Stage.riderProfile:
        return RiderProfileScreen(
          progress: step(2),
          demo: demo,
          onSubmit: auth.registerRider,
          onSignOut: auth.signOut,
        );
      case Stage.pin:
        return PinScreen(
          progress: step(3),
          demo: demo,
          onSave: auth.setPin,
          onBack: auth.signOut,
        );
      case Stage.ready:
        if (auth.justJoined) return ReadyScreen(session: auth.session!, demo: demo, onContinue: auth.enterWallet);
        return HomeScreen(key: ValueKey(auth.session!.uid), api: api, session: auth.session!, onSignOut: auth.signOut);
      case Stage.wrongApp:
        return BlockedScreen(
          title: 'This is a driver account.',
          message: 'Drivers use the Konduct Driver app. Sign out and create a separate account with another email to ride.',
          onSignOut: auth.signOut,
        );
      case Stage.suspended:
        return BlockedScreen(
          title: 'Your account is on hold.',
          message: 'For your safety this account has been paused. Talk to a Konduct agent at the park or contact support to unlock it.',
          onSignOut: auth.signOut,
        );
    }
  }
}

enum _Step { welcome, account }

/// Welcome → email and password, with direction-aware slides and system back support.
class _SignedOutFlow extends StatefulWidget {
  const _SignedOutFlow({required this.auth, required this.progress});
  final AuthController auth;
  final double Function(int) progress;
  @override
  State<_SignedOutFlow> createState() => _SignedOutFlowState();
}

class _SignedOutFlowState extends State<_SignedOutFlow> {
  _Step _step = _Step.welcome;
  bool _forward = true;

  void _go(_Step s) => setState(() {
        _forward = s.index > _step.index;
        _step = s;
      });

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final demo = auth.repo.isDemo;
    final child = switch (_step) {
      _Step.welcome => WelcomeScreen(demo: demo, onStart: () => _go(_Step.account)),
      _Step.account => EmailScreen(
          progress: widget.progress(1),
          demo: demo,
          signUpHint: 'Just an email and a password. You\'ll add your name and student ID next.',
          initialMode: EmailMode.signUp,
          onBack: () => _go(_Step.welcome),
          onForgot: auth.sendPasswordReset,
          // On success the session changes and the gate moves on by itself.
          onSubmit: (email, password, mode) => mode == EmailMode.signUp ? auth.signUp(email, password) : auth.signIn(email, password),
        ),
    };

    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Step.values[_step.index - 1]);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        switchInCurve: K.outExpo,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (c, a) {
          final incoming = c.key == ValueKey(_step);
          final dir = (_forward ? 1.0 : -1.0) * (incoming ? 1 : -1);
          return SlideTransition(
            position: Tween(begin: Offset(0.35 * dir, 0), end: Offset.zero).animate(a),
            child: FadeTransition(opacity: a, child: c),
          );
        },
        child: KeyedSubtree(key: ValueKey(_step), child: child),
      ),
    );
  }
}
