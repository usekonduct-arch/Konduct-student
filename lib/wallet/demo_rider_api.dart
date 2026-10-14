import 'dart:async';

import 'models.dart';
import 'rider_api.dart';

/// Stand-in used without Firebase (`--dart-define=KONDUCT_DEMO=true`). Starts with ₦1,500.
/// Any sticker code works and costs ₦200 a rider. Code `OFF000` plays a vehicle that's off duty.
/// A top-up "pays" itself two seconds after the checkout opens.
class DemoRiderApi implements RiderApi {
  DemoRiderApi({this.fullName = 'Adaeze Okafor', this.studentId = 'UNI/2023/04571'});

  final String fullName, studentId;
  int _balance = 150000;
  final _items = <Activity>[];
  final _disputes = <String, String>{};
  final _quotes = <String, Quote>{};
  final _results = <String, PayResult>{};
  final _changed = StreamController<void>.broadcast();
  var _n = 0;

  @override
  bool get isDemo => true;

  Future<void> _lag([int ms = 700]) => Future.delayed(Duration(milliseconds: ms));
  void _touch() => _changed.add(null);

  Stream<T> _live<T>(T Function() read) async* {
    yield read();
    yield* _changed.stream.map((_) => read());
  }

  @override
  Stream<RiderProfile?> profile() => _live(() => RiderProfile(fullName: fullName, studentId: studentId, fundingCode: 'KD7Q4M2P', kycTier: 1, status: 'active'));

  @override
  Stream<int?> balance() => _live(() => _balance);

  @override
  Stream<List<Activity>> activity({int limit = 30}) => _live(() => _items.take(limit).toList());

  @override
  Stream<bool> paymentsPaused() => Stream.value(false);

  @override
  Stream<String?> disputeState(String txId) => _live(() => _disputes[txId]);

  @override
  Future<Quote> preview({String? qr, String? code, int passengers = 1}) async {
    await _lag();
    if ((code ?? '').toUpperCase() == 'OFF000') {
      throw const ApiException('vehicle_inactive', 'This vehicle isn\'t taking Konduct payments right now. Please pay in cash.');
    }
    final total = 20000 * passengers;
    final recent = _items.any((a) => a.isFare && !a.reversed && DateTime.now().difference(a.at) < const Duration(minutes: 10));
    final q = Quote(
      quoteId: 'demo_quote_${++_n}_xxxxxxxx',
      driverFirstName: 'Tunde',
      plate: 'OS 482 KJA',
      vehicleType: 'shuttle',
      route: 'Main gate → Faculty of Science',
      fareKobo: 20000,
      passengers: passengers,
      totalKobo: total,
      balanceKobo: _balance,
      insufficient: _balance < total,
      needsPin: total >= 50000,
      recentlyPaidThisVehicle: recent,
      stickerChangedRecently: false,
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
    _quotes[q.quoteId] = q;
    return q;
  }

  @override
  Future<PayResult> confirm({required String quoteId, required String idempotencyKey, String? pin, bool repeatConfirmed = false}) async {
    await _lag(900);
    final earlier = _results[idempotencyKey];
    if (earlier != null) return earlier;
    final q = _quotes.remove(quoteId);
    if (q == null) throw const ApiException('quote_used', 'This scan was already used. Scan again to pay.');
    if (q.recentlyPaidThisVehicle && !repeatConfirmed) {
      _quotes[quoteId] = q;
      throw const ApiException('repeat_scan', 'You paid this vehicle a few minutes ago. Adding another passenger, or did you already pay?');
    }
    if (q.needsPin && pin != '2580') {
      _quotes[quoteId] = q;
      throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 2580)');
    }
    if (_balance < q.totalKobo) throw const ApiException('insufficient_funds', 'Not enough in your wallet. Top up and scan again.');
    _balance -= q.totalKobo;
    final r = PayResult(
      txId: 'fare_demo${++_n}xxxx',
      reference: 'KD-${(483920 + _n).toRadixString(36).toUpperCase()}',
      totalKobo: q.totalKobo,
      passengers: q.passengers,
      balanceKobo: _balance,
      offlineCode: 'Q7${_n}M4K'.substring(0, 6),
      undoUntil: DateTime.now().add(const Duration(seconds: 60)),
    );
    _results[idempotencyKey] = r;
    _items.insert(
      0,
      Activity(
        id: r.txId,
        kind: ActivityKind.fare,
        amountKobo: r.totalKobo,
        at: DateTime.now(),
        status: 'completed',
        reference: r.reference,
        routeName: q.route,
        plate: q.plate,
        passengers: q.passengers,
        offlineCode: r.offlineCode,
        undoUntil: r.undoUntil,
      ),
    );
    _touch();
    return r;
  }

  @override
  Future<int> undo(String txId) async {
    await _lag();
    final i = _items.indexWhere((a) => a.id == txId);
    if (i < 0) throw const ApiException('bad_tx', 'We couldn\'t find that payment.');
    final a = _items[i];
    if (a.undoUntil == null || DateTime.now().isAfter(a.undoUntil!)) {
      throw const ApiException('undo_expired', 'It\'s too late to undo. Open a dispute from the receipt instead.');
    }
    _balance += a.amountKobo;
    _items[i] = Activity(
      id: a.id,
      kind: a.kind,
      amountKobo: a.amountKobo,
      at: a.at,
      status: 'reversed',
      reference: a.reference,
      routeName: a.routeName,
      plate: a.plate,
      passengers: a.passengers,
      offlineCode: a.offlineCode,
    );
    _touch();
    return _balance;
  }

  @override
  Future<String> createTopUp({required int amountKobo, required String idempotencyKey}) async {
    await _lag();
    final id = 'tu_demo${++_n}';
    _items.insert(0, Activity(id: id, kind: ActivityKind.topUp, amountKobo: amountKobo, at: DateTime.now(), status: 'open'));
    _touch();
    Future.delayed(const Duration(seconds: 2), () {
      final i = _items.indexWhere((a) => a.id == id);
      if (i < 0) return;
      _balance += amountKobo;
      _items[i] = Activity(id: id, kind: ActivityKind.topUp, amountKobo: amountKobo, at: _items[i].at, status: 'credited');
      _touch();
    });
    // Nothing to open in demo mode; the screens treat an empty URL as "already paying".
    return '';
  }

  @override
  Future<void> openDispute({required String txId, required DisputeReason reason, String note = ''}) async {
    await _lag();
    if (_disputes.containsKey(txId)) throw const ApiException('dispute_exists', 'You\'ve already reported this payment. We\'ll update you.');
    _disputes[txId] = 'open';
    _touch();
  }

  @override
  Future<void> changePin({required String oldPin, required String newPin}) async {
    await _lag();
    if (oldPin != '2580') throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 2580)');
  }

  @override
  Future<void> lockMyAccount() => _lag();
}
