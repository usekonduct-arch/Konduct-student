import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_info.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository() : _functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions;

  @override
  bool get isDemo => false;

  @override
  Stream<Session?> sessions() => _auth.idTokenChanges().asyncMap(_toSession);

  Future<Session?> _toSession(User? user) async {
    if (user == null) return null;
    final claims = (await user.getIdTokenResult()).claims ?? const {};
    return Session(
      uid: user.uid,
      email: user.email ?? '',
      role: claims['role'] as String?,
      pinSet: claims['pin'] == true,
      status: (claims['status'] as String?) ?? 'active',
      name: claims['name'] as String?,
    );
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  @override
  Future<void> signUp(String email, String password) => _guard(() => _auth.createUserWithEmailAndPassword(email: email, password: password));

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether an account exists for this email.
      if (e.code != 'user-not-found') throw _map(e);
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

  Future<void> _guard(Future<Object?> Function() f) async {
    try {
      await f();
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final callable = AppConfig.backendUrl.isEmpty
          ? _functions.httpsCallable(name)
          : _functions.httpsCallableFromUrl('${AppConfig.backendUrl}/$name');
      return (await callable.call<Object?>(data)).data;
    } on FirebaseFunctionsException catch (e) {
      throw AuthException(e.code, e.message ?? 'Something went wrong. Try again.');
    }
  }

  AuthException _map(FirebaseAuthException e) => AuthException(e.code, switch (e.code) {
        'invalid-email' => 'That email address doesn\'t look right.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'That email and password don\'t match an account.',
        'email-already-in-use' => 'There\'s already an account with this email. Sign in instead.',
        'weak-password' => 'Choose a stronger password: at least 8 characters.',
        'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
        'network-request-failed' => 'No connection. Check your data and try again.',
        'user-disabled' => 'This account has been locked. Talk to a Konduct agent.',
        'operation-not-allowed' => 'Email sign-in isn\'t switched on yet. Please try again later.',
        _ => e.message ?? 'Something went wrong. Try again.',
      });
}
