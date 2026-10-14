import 'dart:async';

import 'auth_repository.dart';

/// Stand-in used while no Firebase project is configured, so every screen can be
/// tried on a device. Code is always 123456. Student ID "DUP123" plays a duplicate;
/// in the driver app a number ending in 0000 plays a driver no agent has onboarded.
class DemoAuthRepository implements AuthRepository {
  static const code = '123456';

  final _ctrl = StreamController<Session?>.broadcast();
  Session? _session;
  String? _phone;

  @override
  bool get isDemo => true;

  @override
  Stream<Session?> sessions() async* {
    yield _session;
    yield* _ctrl.stream;
  }

  void _emit(Session? s) => _ctrl.add(_session = s);

  Future<void> _lag([int ms = 900]) => Future.delayed(Duration(milliseconds: ms));

  @override
  Future<void> sendCode(String e164, {bool resend = false}) async {
    await _lag();
    _phone = e164;
  }

  @override
  Future<void> verifyCode(String c) async {
    await _lag(700);
    if (c != code) throw const AuthException('invalid-verification-code', 'That code isn\'t right. (Demo code: 123456)');
    _emit(Session(uid: 'demo', phone: _phone ?? ''));
  }

  @override
  Future<void> registerRider({required String fullName, required String studentId}) async {
    await _lag(1100);
    if (studentId.toUpperCase() == 'DUP123') {
      throw const AuthException('already-exists', 'That student ID is already on another account. If it\'s yours, talk to a Konduct agent.');
    }
    final s = _session!;
    _emit(Session(uid: s.uid, phone: s.phone, role: 'rider', name: fullName));
  }

  @override
  Future<DriverInvite?> claimDriver() async {
    await _lag(1200);
    if ((_phone ?? '').endsWith('0000')) return null;
    const invite = DriverInvite(fullName: 'Tunde Adebayo', plate: 'OS 452 KJA', vehicleType: 'Shuttle', route: 'Main Gate ⇄ Faculty');
    final s = _session!;
    _emit(Session(uid: s.uid, phone: s.phone, role: 'driver', name: invite.fullName));
    return invite;
  }

  @override
  Future<void> setPin(String pin) async {
    await _lag();
    final s = _session!;
    _emit(Session(uid: s.uid, phone: s.phone, role: s.role, name: s.name, pinSet: true));
  }

  @override
  Future<void> signOut() async => _emit(null);
}
