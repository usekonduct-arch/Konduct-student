import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app/app_info.dart';
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
        .map((q) => q.docs.map(_fare).toList());
    final topUps = _db
        .collection('topups')
        .where('uid', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(_topUp).toList());
    return _combine(fares, topUps, (a, b) => ([...a, ...b]..sort((x, y) => y.at.compareTo(x.at))).take(limit).toList());
  }

  Activity _fare(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    final undo = (m['undoUntilMs'] as num?)?.toInt();
    return Activity(
      id: d.id,
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
    );
  }

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
  Future<void> openDispute({required String txId, required DisputeReason reason, String note = ''}) =>
      _call('openDispute', {'txId': txId, 'reason': reason.code, 'note': note});

  @override
  Future<void> changePin({required String oldPin, required String newPin}) => _call('changePin', {'oldPin': oldPin, 'newPin': newPin});

  @override
  Future<void> lockMyAccount() async {
    await _call('lockMyAccount', {});
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

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

/// Emits [combine] of the latest values once both streams have produced one.
Stream<R> _combine<A, B, R>(Stream<A> a, Stream<B> b, R Function(A, B) combine) {
  late StreamController<R> c;
  StreamSubscription<A>? sa;
  StreamSubscription<B>? sb;
  A? la;
  B? lb;
  var hasA = false, hasB = false;
  void emit() {
    if (hasA && hasB) c.add(combine(la as A, lb as B));
  }

  c = StreamController<R>(
    onListen: () {
      sa = a.listen((v) {
        la = v;
        hasA = true;
        emit();
      }, onError: c.addError);
      sb = b.listen((v) {
        lb = v;
        hasB = true;
        emit();
      }, onError: c.addError);
    },
    onCancel: () async {
      await sa?.cancel();
      await sb?.cancel();
    },
  );
  return c.stream;
}
