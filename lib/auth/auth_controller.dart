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

  /// Email typed on the last sign-in attempt, to pre-fill after a sign-out.
  String? email;

  /// True when this session just finished sign-up, so "Welcome aboard" shows once before the wallet.
  bool justJoined = false;

  void _onSession(Session? s) {
    session = s;
    _gotSession = true;
    _recompute();
  }

  void _recompute() {
    final next = (!_gotSession || !_splashDone) ? Stage.booting : _stageFor(session);
    if (next != stage) {
      if (next == Stage.ready) justJoined = stage == Stage.pin;
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

  Future<void> signIn(String email, String password) {
    this.email = email;
    return repo.signIn(email, password);
  }

  Future<void> signUp(String email, String password) {
    this.email = email;
    return repo.signUp(email, password);
  }

  Future<void> sendPasswordReset(String email) => repo.sendPasswordReset(email);

  Future<void> registerRider(String fullName, String studentId) => repo.registerRider(fullName: fullName, studentId: studentId);

  Future<void> setPin(String pin) => repo.setPin(pin);

  /// Leaves "Welcome aboard" for the wallet.
  void enterWallet() {
    if (!justJoined) return;
    justJoined = false;
    notifyListeners();
  }

  Future<void> signOut() => repo.signOut();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
