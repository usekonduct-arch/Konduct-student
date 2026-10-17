import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/l10n.dart';

/// Fingerprint or face in place of typing the PIN.
///
/// The backend still checks a real PIN on every payment that needs one; nothing about that
/// changes. When the person turns this on (and proves it's them with their fingerprint), the app
/// keeps their PIN in the phone's encrypted store (Android Keystore / iOS Keychain), and hands it
/// over only after a fingerprint or face check that a phone passcode can't stand in for. If the
/// server ever says the saved PIN is wrong (it was changed somewhere else), it's deleted at once,
/// so it can cost at most one try against the PIN lock.
class BiometricPin {
  BiometricPin._();
  static final instance = BiometricPin._();

  // Under `flutter test` there are no fingerprint or keystore plugins: always off.
  static final bool _silent = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  final _auth = LocalAuthentication();
  static const _store = FlutterSecureStorage(aOptions: AndroidOptions(storageNamespace: 'konduct_pin'));

  /// Whose PIN: set when someone signs in, cleared on sign-out.
  String? get uid => _uid;
  set uid(String? v) {
    if (v != _uid) _known = null;
    _uid = v;
  }

  String? _uid;

  /// Whether a PIN is saved, once read; kept in step by [enable] and [disable].
  bool? _known;

  /// A phone answers these in milliseconds; never let a stuck plugin hold up a payment.
  static const _patience = Duration(seconds: 3);

  /// Notified when the setting changes, so the settings switch and PIN sheet update.
  final changes = ValueNotifier<int>(0);

  String get _key => 'pin.$uid';

  /// The phone has a fingerprint or face enrolled that this app can use.
  Future<bool> available() async {
    if (kIsWeb || _silent) return false;
    try {
      if (!await _auth.isDeviceSupported().timeout(_patience) || !await _auth.canCheckBiometrics.timeout(_patience)) return false;
      return (await _auth.getAvailableBiometrics().timeout(_patience)).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// A PIN is saved for the signed-in person.
  Future<bool> enabled() async {
    if (uid == null || _silent || kIsWeb) return false;
    if (_known != null) return _known!;
    try {
      return _known = await _store.containsKey(key: _key).timeout(_patience);
    } catch (_) {
      return false;
    }
  }

  /// Asks for a fingerprint or face; true only if it matched.
  Future<bool> check(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } on LocalAuthException catch (e) {
      debugPrint('biometric check: ${e.code.name}');
      return false;
    } on PlatformException catch (e) {
      debugPrint('biometric check: ${e.code}');
      return false;
    }
  }

  /// Turns it on with [pin], after a fingerprint or face check.
  Future<bool> enable(String pin) async {
    if (uid == null || !await check(tr('Confirm it\'s you to use your fingerprint or face for payments'))) return false;
    try {
      await _store.write(key: _key, value: pin).timeout(_patience);
      _known = true;
      changes.value++;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    if (uid == null) return;
    try {
      await _store.delete(key: _key).timeout(_patience);
    } catch (_) {}
    _known = false;
    changes.value++;
  }

  /// The saved PIN after a successful fingerprint or face check; null if it's off, failed or was cancelled.
  Future<String?> unlock(String reason) async {
    if (!await enabled()) return null;
    if (!await check(reason)) return null;
    try {
      return await _store.read(key: _key).timeout(_patience);
    } catch (_) {
      return null;
    }
  }

  /// The last PIN handed out came from the saved one (not typed).
  bool lastWasSaved = false;

  /// After the server refused a PIN: if it was the saved one, it's out of date (changed on another
  /// phone, or reset by an agent), so forget it. True when that happened.
  Future<bool> rejected(String reason) async {
    if (reason != 'pin_wrong' || !lastWasSaved) return false;
    lastWasSaved = false;
    await disable();
    return true;
  }

  /// The person changed their PIN: keep the saved one in step, if it's on.
  Future<void> replace(String pin) async {
    if (!await enabled()) return;
    try {
      await _store.write(key: _key, value: pin);
    } catch (_) {}
  }
}
