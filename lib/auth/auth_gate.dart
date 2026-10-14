import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'auth_controller.dart';
import 'screens/otp_screen.dart';
import 'screens/phone_screen.dart';
import 'screens/pin_screen.dart';
import 'screens/ready_screen.dart';
import 'screens/rider_profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';

/// Shows the screen for the current sign-up stage and animates between stages.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.auth});
  final AuthController auth;

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
        child: KeyedSubtree(key: ValueKey(auth.stage), child: _screen(context)),
      ),
    );
  }

  Widget _screen(BuildContext context) {
    final demo = auth.repo.isDemo;
    // Phone, code, profile, PIN.
    double step(int n) => n / (4);

    switch (auth.stage) {
      case Stage.booting:
        return const SplashScreen();
      case Stage.signedOut:
        return _SignedOutFlow(auth: auth, progress: step);
      case Stage.riderProfile:
        return RiderProfileScreen(
          progress: step(3),
          demo: demo,
          onSubmit: auth.registerRider,
          onSignOut: auth.signOut,
        );
      case Stage.pin:
        return PinScreen(
          progress: step(4),
          demo: demo,
          onSave: auth.setPin,
          onBack: auth.signOut,
        );
      case Stage.ready:
        return ReadyScreen(session: auth.session!, demo: demo, onSignOut: auth.signOut);
      case Stage.wrongApp:
        return BlockedScreen(
          title: 'This number belongs to a driver.',
          message: 'Drivers use the Konduct Driver app. Sign out and use a different number to ride.',
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

enum _Step { welcome, phone, code }

/// Welcome → phone → code, with direction-aware slides and system back support.
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
      _Step.welcome => WelcomeScreen(demo: demo, onStart: () => _go(_Step.phone)),
      _Step.phone => PhoneScreen(
          progress: widget.progress(1),
          demo: demo,
          initial: auth.phone,
          onBack: () => _go(_Step.welcome),
          onSend: (e164) async {
            await auth.sendCode(e164);
            // On Android the SMS may already have signed us in; the gate moves on by itself.
            if (mounted && auth.stage == Stage.signedOut) _go(_Step.code);
          },
        ),
      _Step.code => OtpScreen(
          progress: widget.progress(2),
          demo: demo,
          phone: auth.phone ?? '',
          onBack: () => _go(_Step.phone),
          onVerify: auth.verifyCode,
          onResend: () => auth.sendCode(auth.phone!, resend: true),
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
