import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_info.dart';
import '../messages/firebase_messages_api.dart';
import '../messages/messages_api.dart';
import '../support/firebase_support_api.dart';
import '../support/support_api.dart';
import 'models.dart';
import 'rider_api.dart';

class FirebaseRiderApi implements RiderApi {
  FirebaseRiderApi() : _functions = FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion);

  final _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  bool get isDemo => false;

  @override
  final SupportApi support = FirebaseSupportApi();

  @override
  final MessagesApi messages = FirebaseMessagesApi();

  @override
  Future<void> changePassword({required String current, required String next}) async {
    await reauthenticate(current);
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(next);
    } on FirebaseAuthException catch (e) {
      throw ApiException('password_change', switch (e.code) {
        'weak-password' => 'Choose a stronger password: at least 8 characters that are hard to guess.',
        'requires-recent-login' => 'For your safety, sign out, sign in again, then change your password.',
        'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
        'network-request-failed' => 'No connection. Check your data and try again.',
        _ => e.message ?? "Couldn't change your password. Try again.",
      });
    }
  }

  @override
  Future<void> sendPasswordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: FirebaseAuth.instance.currentUser!.email!);
    } on FirebaseAuthException catch (e) {
      throw ApiException('reset_failed', switch (e.code) {
        'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
        'network-request-failed' => 'No connection. Check your data and try again.',
        _ => "Couldn't send the reset link. Try again.",
      });
    }
  }

  @override
  Stream<RiderProfile?> profile() => _db.doc('users/$_uid').snapshots().map((s) {
    final d = s.data();
    if (d == null) return null;
    return RiderProfile(
      fullName: d['fullName'] as String? ?? '',
      studentId: d['studentId'] as String? ?? '',
      fundingCode: d['fundingCode'] as String? ?? '',
      kycTier: (d['kycTier'] as num?)?.toInt() ?? 1,
      status: d['status'] as String? ?? 'active',
    );
  });

  @override
  Stream<int?> balance() => _db.doc('wallets/rider_$_uid').snapshots().map((s) => (s.data()?['balanceKobo'] as num?)?.toInt());

  @override
  Stream<List<Activity>> activity({int limit = 30}) {
    final fares = _db
        .collection('transactions')
        .where('payerUid', isEqualTo: _uid)
        .orderBy('createdAtMs', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map((d) => _fare(d.id, d.data())).toList());
    final topUps = _db
        .collection('topups')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(_topUp).toList());
    final withdrawals = _db
        .collection('payouts')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(_withdrawal).toList());
    return _combineAll([
      fares,
      topUps,
      withdrawals,
    ]).map((lists) => (lists.expand((l) => l).toList()..sort((x, y) => y.at.compareTo(x.at))).take(limit).toList());
  }

  Activity _withdrawal(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Activity(
      id: d.id,
      kind: ActivityKind.withdrawal,
      amountKobo: (m['amountKobo'] as num?)?.toInt() ?? 0,
      at: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: m['status'] as String? ?? 'reserved',
      reference: m['accountLast4'] == null ? '' : '****${m['accountLast4']}',
    );
  }

  Activity _fare(String id, Map<String, dynamic> m) {
    final undo = (m['undoUntilMs'] as num?)?.toInt();
    final rateFrom = (m['rateFromMs'] as num?)?.toInt();
    return Activity(
      id: id,
      kind: ActivityKind.fare,
      amountKobo: (m['totalKobo'] as num?)?.toInt() ?? 0,
      at: DateTime.fromMillisecondsSinceEpoch((m['createdAtMs'] as num?)?.toInt() ?? 0),
      status: m['status'] as String? ?? 'completed',
      reference: m['reference'] as String? ?? '',
      routeName: m['routeName'] as String? ?? '',
      plate: m['plate'] as String? ?? '',
      passengers: (m['passengers'] as num?)?.toInt() ?? 1,
      offlineCode: m['offlineCode'] as String? ?? '',
      undoUntil: undo == null ? null : DateTime.fromMillisecondsSinceEpoch(undo),
      driverName: m['driverFirstName'] as String? ?? '',
      tripRoute: TripRoute.fromMap(m['tripRoute']),
      rateFrom: rateFrom == null ? null : DateTime.fromMillisecondsSinceEpoch(rateFrom),
      rating: (m['rating'] as num?)?.toInt(),
    );
  }

  @override
  Stream<Activity?> fare(String txId) =>
      _db.doc('transactions/$txId').snapshots().map((s) => s.data() == null ? null : _fare(s.id, s.data()!)).handleError((_) {});

  @override
  Future<void> rateDriver({required String txId, required int stars, String comment = ''}) =>
      _call('rateDriver', {'txId': txId, 'stars': stars, 'comment': comment});

  Activity _topUp(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final status = m['status'] as String? ?? 'open';
    return Activity(
      id: d.id,
      kind: ActivityKind.topUp,
      amountKobo: ((status == 'credited' ? m['creditedKobo'] : null) ?? m['amountKobo'] as num? ?? 0).toInt(),
      at: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: status,
      checkoutUrl: m['checkoutUrl'] as String?,
    );
  }

  @override
  Stream<bool> paymentsPaused() => _db.doc('config/switches').snapshots().map((s) => s.data()?['paymentsPaused'] == true).handleError((_) {});

  @override
  Stream<List<Park>> parks() =>
      _db.collection('parks').where('active', isEqualTo: true).snapshots().map((q) => q.docs.map(_park).toList()..sort((a, b) => a.name.compareTo(b.name)));

  Park _park(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final at = (m['busCountAtMs'] as num?)?.toInt();
    return Park(
      id: d.id,
      name: m['name'] as String? ?? '',
      location: m['location'] as String? ?? '',
      busCount: (m['busCount'] as num?)?.toInt() ?? 0,
      updatedAt: at == null ? null : DateTime.fromMillisecondsSinceEpoch(at),
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
    );
  }

  @override
  Stream<String?> disputeState(String txId) {
    // The rules only let the payer read a dispute that exists; "no dispute" comes back as permission-denied.
    final c = StreamController<String?>();
    final sub = _db.doc('disputes/$txId').snapshots().listen((s) => c.add(s.data()?['state'] as String?), onError: (_) => c.add(null));
    c.onCancel = sub.cancel;
    return c.stream;
  }

  @override
  Future<Quote> preview({String? qr, String? code, int passengers = 1}) async {
    final data = await _call('payPreview', {'qr': ?qr, 'code': ?code, 'passengers': passengers});
    return Quote.fromMap(data);
  }

  @override
  Future<PayResult> confirm({required String quoteId, required String idempotencyKey, String? pin, bool repeatConfirmed = false}) async {
    final data = await _call('payConfirm', {'quoteId': quoteId, 'idempotencyKey': idempotencyKey, 'pin': ?pin, 'repeatConfirmed': repeatConfirmed});
    return PayResult.fromMap(data);
  }

  @override
  Future<int> undo(String txId) async => ((await _call('payUndo', {'txId': txId}))['balanceKobo'] as num).toInt();

  @override
  Future<String> createTopUp({required int amountKobo, required String idempotencyKey}) async {
    final data = await _call('createTopUp', {'amountKobo': amountKobo, 'idempotencyKey': idempotencyKey});
    final url = data['checkoutUrl'] as String?;
    if (url == null) throw const ApiException('checkout_unavailable', 'We couldn\'t open the payment page. Try again in a moment.');
    return url;
  }

  @override
  Future<TopUpCheck> refreshTopUps() async {
    final data = await _call('refreshTopUps', {});
    return TopUpCheck(checked: (data['checked'] as num?)?.toInt() ?? 0, credited: (data['credited'] as num?)?.toInt() ?? 0);
  }

  @override
  Future<ReceiptProof> receiptProof({required ActivityKind kind, required String id}) async => ReceiptProof.fromMap(
    await _call('receiptProof', {
      'kind': switch (kind) {
        ActivityKind.fare => 'fare',
        ActivityKind.topUp => 'topup',
        ActivityKind.withdrawal => 'payout',
      },
      'id': id,
    }),
  );

  @override
  Future<void> openDispute({required String txId, required DisputeReason reason, String note = ''}) =>
      _call('openDispute', {'txId': txId, 'reason': reason.code, 'note': note});

  @override
  Future<void> changePin({required String oldPin, required String newPin}) => _call('changePin', {'oldPin': oldPin, 'newPin': newPin});

  @override
  Future<void> lockMyAccount() async {
    await _call('lockMyAccount', {});
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  @override
  Stream<BankAccounts> bankAccounts() {
    // users/{uid} names the approved account and any pending one; follow both documents.
    late StreamController<BankAccounts> c;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    final subs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    final docs = <String, BankAccount?>{};
    String? activeId, pendingId;
    void emit() => c.add(BankAccounts(active: activeId == null ? null : docs[activeId], pending: pendingId == null ? null : docs[pendingId]));

    void follow(String? id) {
      if (id == null || subs.containsKey(id)) return;
      subs[id] = _db.doc('payoutAccounts/$id').snapshots().listen((s) {
        docs[id] = s.exists ? _bankAccount(s.id, s.data()!) : null;
        emit();
      }, onError: (_) {});
    }

    c = StreamController<BankAccounts>(
      onListen: () {
        userSub = _db.doc('users/$_uid').snapshots().listen((u) {
          activeId = u.data()?['payoutAccountId'] as String?;
          pendingId = u.data()?['pendingPayoutAccountId'] as String?;
          follow(activeId);
          follow(pendingId);
          emit();
        }, onError: c.addError);
      },
      onCancel: () async {
        await userSub?.cancel();
        for (final s in subs.values) {
          await s.cancel();
        }
      },
    );
    return c.stream;
  }

  BankAccount _bankAccount(String id, Map<String, dynamic> m) {
    final hold = (m['holdUntilMs'] as num?)?.toInt();
    return BankAccount(
      id: id,
      bankCode: m['bankCode'] as String? ?? '',
      last4: m['accountLast4'] as String? ?? '',
      accountName: m['accountName'] as String? ?? '',
      status: m['status'] as String? ?? 'pending_approval',
      nameMatches: m['nameMatches'] == true,
      holdUntil: hold == null ? null : DateTime.fromMillisecondsSinceEpoch(hold),
    );
  }

  List<Bank>? _banks;

  @override
  Future<List<Bank>> banks() async {
    if (_banks != null) return _banks!;
    final data = await _call('payoutBanks', {});
    final list = (data['banks'] as List? ?? const []).whereType<Map>().map((b) => Bank('${b['code']}', '${b['name']}')).toList();
    if (list.isEmpty) throw const ApiException('banks_unavailable', "We couldn't load the list of banks. Try again in a moment.");
    return _banks = list;
  }

  @override
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin}) async {
    await reauthenticate(password);
    final data = await _call('riderSetPayoutAccount', {'bankCode': bankCode, 'accountNumber': accountNumber, 'pin': pin});
    return BankCheck(accountName: data['accountName'] as String? ?? '', nameMatches: data['nameMatches'] == true);
  }

  @override
  Future<void> withdraw({required int amountKobo, required String pin}) => _call('riderWithdraw', {'amountKobo': amountKobo, 'pin': pin});

  Future<Map<String, dynamic>> _call(String name, Map<String, Object?> data) async {
    try {
      final callable = AppConfig.backendUrl.isEmpty ? _functions.httpsCallable(name) : _functions.httpsCallableFromUrl('${AppConfig.backendUrl}/$name');
      final res = (await callable.call<Object?>(data)).data;
      return res is Map ? Map<String, dynamic>.from(res) : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : <String, dynamic>{};
      final reason = details['reason'] as String? ?? e.code;
      final message = switch (e.code) {
        'unavailable' || 'deadline-exceeded' when details['reason'] == null => 'No connection to Konduct. Check your data and try again.',
        'internal' when details['reason'] == null => 'Something went wrong on our side. Try again.',
        _ => e.message ?? 'Something went wrong. Try again.',
      };
      throw ApiException(reason, message, details: details);
    }
  }
}

/// The latest value of every stream, once each has produced one.
Stream<List<T>> _combineAll<T>(List<Stream<T>> streams) {
  late StreamController<List<T>> c;
  final subs = <StreamSubscription<T>>[];
  final latest = List<T?>.filled(streams.length, null);
  final seen = List<bool>.filled(streams.length, false);
  c = StreamController<List<T>>(
    onListen: () {
      for (var i = 0; i < streams.length; i++) {
        subs.add(
          streams[i].listen((v) {
            latest[i] = v;
            seen[i] = true;
            if (seen.every((x) => x)) c.add(latest.cast<T>());
          }, onError: c.addError),
        );
      }
    },
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
    },
  );
  return c.stream;
}

/// Confirms the password again, so the backend sees a sign-in from the last few minutes.
Future<void> reauthenticate(String password) async {
  final user = FirebaseAuth.instance.currentUser!;
  try {
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password));
    await user.getIdToken(true);
  } on FirebaseAuthException catch (e) {
    throw ApiException('wrong_password', switch (e.code) {
      'wrong-password' || 'invalid-credential' => "That password isn't right.",
      'too-many-requests' => 'Too many tries. Wait a few minutes, then try again.',
      'network-request-failed' => 'No connection. Check your data and try again.',
      _ => e.message ?? "Couldn't confirm your password.",
    });
  }
}
