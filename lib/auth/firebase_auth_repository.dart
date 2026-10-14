import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_info.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository() : _functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions;
  String? _verificationId;
  int? _resendToken;

  @override
  bool get isDemo => false;

  @override
  Stream<Session?> sessions() => _auth.idTokenChanges().asyncMap(_toSession);

  Future<Session?> _toSession(User? user) async {
    if (user == null) return null;
    final claims = (await user.getIdTokenResult()).claims ?? const {};
    return Session(
      uid: user.uid,
      phone: user.phoneNumber ?? '',
      role: claims['role'] as String?,
      pinSet: claims['pin'] == true,
      status: (claims['status'] as String?) ?? 'active',
      name: claims['name'] as String?,
    );
  }

  @override
  Future<void> sendCode(String e164, {bool resend = false}) {
    final done = Completer<void>();
    _auth.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 60),
      forceResendingToken: resend ? _resendToken : null,
      verificationCompleted: (credential) async {
        // Android read the SMS for us.
        await _auth.signInWithCredential(credential);
        if (!done.isCompleted) done.complete();
      },
      verificationFailed: (e) {
        if (!done.isCompleted) done.completeError(_mapAuth(e));
      },
      codeSent: (id, token) {
        _verificationId = id;
        _resendToken = token;
        if (!done.isCompleted) done.complete();
      },
      codeAutoRetrievalTimeout: (id) => _verificationId = id,
    );
    return done.future;
  }

  @override
  Future<void> verifyCode(String code) async {
    final id = _verificationId;
    if (id == null) throw const AuthException('no-session', 'Send yourself a new code first.');
    try {
      await _auth.signInWithCredential(PhoneAuthProvider.credential(verificationId: id, smsCode: code));
    } on FirebaseAuthException catch (e) {
      throw _mapAuth(e);
    }
  }

  @override
  Future<void> registerRider({required String fullName, required String studentId}) async {
    await _call('registerRider', {'fullName': fullName, 'studentId': studentId});
    await _auth.currentUser?.getIdToken(true);
  }

  @override
  Future<void> setPin(String pin) async {
    await _call('setTransactionPin', {'pin': pin});
    await _auth.currentUser?.getIdToken(true);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      return (await _functions.httpsCallable(name).call<Object?>(data)).data;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.code, e.message ?? 'Something went wrong. Try again.');
    }
  }

  AuthException _mapAuth(FirebaseAuthException e) => AuthException(e.code, switch (e.code) {
        'invalid-phone-number' => 'That number doesn\'t look right.',
        'invalid-verification-code' => 'That code isn\'t right. Check the SMS and try again.',
        'session-expired' || 'code-expired' => 'That code has expired. Send a new one.',
        'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
        'network-request-failed' => 'No connection. Check your data and try again.',
        'quota-exceeded' => 'We can\'t send codes right now. Try again shortly.',
        'user-disabled' => 'This account has been locked. Talk to a Konduct agent.',
        _ => e.message ?? 'Something went wrong. Try again.',
      });
}
