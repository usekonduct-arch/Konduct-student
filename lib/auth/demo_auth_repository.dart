import 'dart:async';

import 'auth_repository.dart';

/// Stand-in used without Firebase (`--dart-define=KONDUCT_DEMO=true`) so every screen can be
/// tried on a device. Any email signs up; `taken@konduct.app` plays an email already in use.
/// Signing in needs the password the account was created with in this session.
/// Student ID "DUP123" plays an ID that is already registered.
class DemoAuthRepository implements AuthRepository {
  final _ctrl = StreamController<Session?>.broadcast();
  final _accounts = <String, String>{};
  Session? _session;

  @override
  bool get isDemo => true;

  @override
  Stream<Session?> sessions() async* {
    yield _session;
    yield* _ctrl.stream;
  }

  void _emit(Session? s) => _ctrl.add(_session = s);

  Future<void> _lag([int ms = 800]) => Future.delayed(Duration(milliseconds: ms));

  @override
  Future<void> signUp(String email, String password) async {
    await _lag();
    if (email == 'taken@konduct.app' || _accounts.containsKey(email)) {
      throw const AuthException('email-already-in-use', 'There\'s already an account with this email. Sign in instead.');
    }
    _accounts[email] = password;
    _emit(Session(uid: 'demo-${email.hashCode}', email: email));
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _lag();
    if (_accounts[email] != password) throw const AuthException('invalid-credential', 'That email and password don\'t match an account.');
    _emit(Session(uid: 'demo-${email.hashCode}', email: email));
  }

  @override
  Future<void> sendPasswordReset(String email) => _lag(500);

  @override
  Future<void> registerRider({required String fullName, required String studentId}) async {
    await _lag(1100);
    if (studentId.toUpperCase() == 'DUP123') {
      throw const AuthException('already-exists', 'That student ID is already on another account. If it\'s yours, talk to a Konduct agent.');
    }
    final s = _session!;
    _emit(Session(uid: s.uid, email: s.email, role: 'rider', name: fullName));
  }

  @override
  Future<void> setPin(String pin) async {
    await _lag();
    final s = _session!;
    _emit(Session(uid: s.uid, email: s.email, role: s.role, name: s.name, pinSet: true));
  }

  @override
  Future<void> signOut() async => _emit(null);
}
