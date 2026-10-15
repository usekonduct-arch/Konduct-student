import '../security/biometric.dart';

/// Who is signed in on this phone right now, for things kept per person on the phone (recent
/// vehicles, the saved PIN). Set by the home screen; empty when signed out.
abstract final class Current {
  static String _uid = '';
  static String get uid => _uid;

  static set uid(String v) {
    _uid = v;
    BiometricPin.instance.uid = v.isEmpty ? null : v;
  }
}
