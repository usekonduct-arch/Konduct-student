/// What the app knows about the signed-in person. Everything except uid/phone comes from
/// custom claims that only the backend can set (SRS FR-AUTH-05), so it is readable offline.
class Session {
  const Session({required this.uid, required this.phone, this.role, this.pinSet = false, this.status = 'active', this.name});

  final String uid;
  final String phone;
  final String? role; // 'rider' | 'driver' | staff roles; null until the backend assigns one
  final bool pinSet;
  final String status; // 'active' | 'suspended'
  final String? name;

  String get firstName => (name ?? '').trim().split(' ').first;
}

class AuthException implements Exception {
  const AuthException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract class AuthRepository {
  /// True when running without a Firebase project (UI preview).
  bool get isDemo;

  /// Emits the current session on sign-in, sign-out and every token refresh.
  Stream<Session?> sessions();

  /// Sends an SMS code. Completes when the code is on its way; on Android the SMS may be
  /// read automatically, in which case [sessions] emits a signed-in session by itself.
  Future<void> sendCode(String e164, {bool resend = false});

  Future<void> verifyCode(String code);

  Future<void> registerRider({required String fullName, required String studentId});

  Future<void> setPin(String pin);

  Future<void> signOut();
}

/// Nigerian mobile numbers: accepts 0803..., 803..., 234803..., +234803...
String? toE164(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('234')) d = d.substring(3);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length != 10 || !RegExp(r'^[789][01]').hasMatch(d)) return null;
  return '+234$d';
}

String prettyPhone(String e164) {
  final d = e164.replaceFirst('+234', '');
  if (d.length != 10) return e164;
  return '+234 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
}
