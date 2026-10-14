import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_info.dart';
import 'auth_repository.dart';

/// Where the person is in sign-up. Decided from the session alone, so a relaunch lands
/// on the right screen without a network round trip.
enum Stage { booting, signedOut, riderProfile, wrongApp, suspended, pin, ready }

class AuthController extends ChangeNotifier {
  AuthController(this.repo) {
    _sub = repo.sessions().listen(_onSession);
    // Hold the splash long enough for its animation, even when the session is instant.
    Future.delayed(const Duration(milliseconds: 1900), () {
      _splashDone = true;
      _recompute();
    });
  }

  final AuthRepository repo;
  late final StreamSubscription<Session?> _sub;

  Session? session;
  Stage stage = Stage.booting;
  bool _gotSession = false;
  bool _splashDone = false;

  /// Phone number the last code was sent to.
  String? phone;

  void _onSession(Session? s) {
    session = s;
    _gotSession = true;
    _recompute();
  }

  void _recompute() {
    final next = (!_gotSession || !_splashDone) ? Stage.booting : _stageFor(session);
    if (next != stage) {
      stage = next;
      notifyListeners();
    }
  }

  Stage _stageFor(Session? s) {
    if (s == null) return Stage.signedOut;
    if (s.status == 'suspended') return Stage.suspended;
    if (s.role == null) return Stage.riderProfile;
    if (s.role != AppInfo.role) return Stage.wrongApp;
    if (!s.pinSet) return Stage.pin;
    return Stage.ready;
  }

  Future<void> sendCode(String e164, {bool resend = false}) async {
    phone = e164;
    await repo.sendCode(e164, resend: resend);
  }

  Future<void> verifyCode(String code) => repo.verifyCode(code);

  Future<void> registerRider(String fullName, String studentId) => repo.registerRider(fullName: fullName, studentId: studentId);

  Future<void> setPin(String pin) => repo.setPin(pin);

  Future<void> signOut() => repo.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
