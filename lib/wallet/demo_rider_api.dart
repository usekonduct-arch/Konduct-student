import 'dart:async';

import '../support/demo_support_api.dart';
import '../support/support_api.dart';
import 'models.dart';
import 'rider_api.dart';

/// Stand-in used without Firebase (`--dart-define=KONDUCT_DEMO=true`). Starts with ₦1,500.
/// Any sticker code works and costs ₦200 a rider. Code `OFF000` plays a vehicle that's off duty.
/// The demo bus seats 7 and already has 2 riders paid by scan; undo gives seats back. Its trip
/// goes Shasha park → Main gate (about 12 minutes). An earlier ride is waiting to be rated.
/// A top-up "pays" itself two seconds after the checkout opens.
/// Bank accounts: any 10-digit number resolves to the rider's own name and is "approved" two
/// seconds later, with no hold. Password `ride-the-bus-1`, PIN `2580`.
class DemoRiderApi implements RiderApi {
  DemoRiderApi({this.fullName = 'Adaeze Okafor', this.studentId = 'UNI/2023/04571'}) {
    final earlier = DateTime.now().subtract(const Duration(minutes: 40));
    _items.add(
      Activity(
        id: 'fare_demo0earlier',
        kind: ActivityKind.fare,
        amountKobo: 20000,
        at: earlier,
        status: 'completed',
        reference: 'KD-4MX2Q9',
        routeName: 'Hostels → Main gate',
        plate: 'OS 117 EDE',
        offlineCode: 'H3K9QP',
        driverName: 'Kemi',
        tripRoute: const TripRoute(from: 'Hostels', to: 'Main gate', etaMin: 9),
        rateFrom: earlier.add(const Duration(minutes: 9)),
      ),
    );
  }

  static const _trip = TripRoute(from: 'Shasha park', to: 'Main gate', etaMin: 12);

  final String fullName, studentId;
  int _balance = 150000;
  final _items = <Activity>[];
  final _disputes = <String, String>{};
  final _quotes = <String, Quote>{};
  final _results = <String, PayResult>{};
  final _changed = StreamController<void>.broadcast();
  var _n = 0;
  static const _busSeats = 7;
  var _seatsTaken = 2;

  @override
  bool get isDemo => true;

  @override
  final SupportApi support = DemoSupportApi();

  @override
  Future<void> changePassword({required String current, required String next}) async {
    await _lag();
    if (current != 'ride-the-bus-1') throw const ApiException('wrong_password', "That password isn't right. (Demo: ride-the-bus-1)");
  }

  @override
  Future<void> sendPasswordReset() => _lag(500);

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
  Stream<List<Park>> parks() {
    final now = DateTime.now();
    return Stream.value([
      Park(id: 'main-campus', name: 'Main Campus park', location: 'Beside the main gate', busCount: 2, updatedAt: now.subtract(const Duration(minutes: 25))),
      Park(
        id: 'shasha',
        name: 'Shasha park',
        location: 'Shasha junction, Osogbo',
        busCount: 4,
        updatedAt: now.subtract(const Duration(minutes: 6)),
        lat: 7.7712,
        lng: 4.5567,
      ),
    ]);
  }

  @override
  Stream<String?> disputeState(String txId) => _live(() => _disputes[txId]);

  @override
  Future<Quote> preview({String? qr, String? code, int passengers = 1}) async {
    await _lag();
    if ((code ?? '').toUpperCase() == 'OFF000') {
      throw const ApiException('vehicle_inactive', 'This vehicle isn\'t taking Konduct payments right now. Please pay in cash.');
    }
    final left = _busSeats - _seatsTaken;
    if (left <= 0) {
      throw const ApiException('bus_full', 'This bus is full on Konduct: all 7 seats are paid. If riders just got off, ask the driver to tap "New trip".');
    }
    if (passengers > left) {
      throw ApiException('not_enough_seats', left == 1 ? 'Only 1 seat is left on this bus.' : 'Only $left seats are left on this bus.', details: {'seatsLeft': left});
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
      seatCapacity: _busSeats,
      seatsTaken: _seatsTaken,
      tripRoute: _trip,
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
    if (_seatsTaken + q.passengers > _busSeats) {
      throw const ApiException('bus_full', 'This bus is full on Konduct: all 7 seats are paid. If riders just got off, ask the driver to tap "New trip".');
    }
    _seatsTaken += q.passengers;
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
        driverName: q.driverFirstName,
        tripRoute: _trip,
        rateFrom: DateTime.now().add(Duration(minutes: _trip.etaMin)),
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
    _seatsTaken = (_seatsTaken - a.passengers).clamp(0, _busSeats);
    _items[i] = a.copyWith(status: 'reversed');
    _touch();
    return _balance;
  }

  @override
  Stream<Activity?> fare(String txId) => _live(() => _items.where((a) => a.id == txId).firstOrNull);

  @override
  Future<void> rateDriver({required String txId, required int stars, String comment = ''}) async {
    await _lag();
    final i = _items.indexWhere((a) => a.id == txId);
    if (i < 0) throw const ApiException('bad_tx', 'We couldn\'t find that ride.');
    final a = _items[i];
    if (a.rating != null) throw const ApiException('already_rated', 'You\'ve already rated this ride. Thanks!');
    if (!a.canRateAt(DateTime.now())) throw const ApiException('too_early', 'You can rate this ride once you\'ve arrived.');
    _items[i] = a.copyWith(rating: stars);
    _touch();
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
  Future<TopUpCheck> refreshTopUps() async {
    await _lag(500);
    return TopUpCheck(checked: _items.where((a) => a.kind == ActivityKind.topUp && a.pending).length, credited: 0);
  }

  @override
  Future<ReceiptProof> receiptProof({required ActivityKind kind, required String id}) async {
    await _lag(400);
    final a = _items.where((x) => x.id == id).firstOrNull;
    if (a == null || (a.kind == ActivityKind.topUp && !a.credited)) return const ReceiptProof(verified: false, posted: false);
    // A made-up but stable fingerprint; there is no public receipt page in demo mode.
    final hash = id.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff).toRadixString(16).padLeft(8, '0') * 8;
    return ReceiptProof(verified: true, posted: true, hash: hash, postedAt: a.at, reversed: a.reversed);
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

  BankAccount? _active, _pending;

  @override
  Stream<BankAccounts> bankAccounts() => _live(() => BankAccounts(active: _active, pending: _pending));

  @override
  Future<List<Bank>> banks() async {
    await _lag(300);
    return const [
      Bank('044', 'Access Bank'),
      Bank('058', 'Guaranty Trust Bank'),
      Bank('50515', 'Moniepoint MFB'),
      Bank('999992', 'OPay'),
      Bank('100033', 'PalmPay'),
      Bank('101', 'Providus Bank'),
      Bank('232', 'Sterling Bank'),
      Bank('033', 'United Bank for Africa'),
      Bank('057', 'Zenith Bank'),
    ];
  }

  @override
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin}) async {
    await _lag();
    if (password != 'ride-the-bus-1') throw const ApiException('wrong_password', "That password isn't right. (Demo: ride-the-bus-1)");
    if (pin != '2580') throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 2580)');
    final name = fullName.toUpperCase();
    _pending = BankAccount(
      id: 'pa_demo${++_n}',
      bankCode: bankCode,
      last4: accountNumber.substring(6),
      accountName: name,
      status: 'pending_approval',
      nameMatches: true,
    );
    _touch();
    Future.delayed(const Duration(seconds: 2), () {
      final p = _pending;
      if (p == null) return;
      _active = BankAccount(id: p.id, bankCode: p.bankCode, last4: p.last4, accountName: p.accountName, status: 'active', nameMatches: true);
      _pending = null;
      _touch();
    });
    return BankCheck(accountName: name, nameMatches: true);
  }

  @override
  Future<void> withdraw({required int amountKobo, required String pin}) async {
    await _lag();
    if (pin != '2580') throw const ApiException('pin_wrong', 'Wrong PIN. (Demo PIN: 2580)');
    if (_active == null) throw const ApiException('no_payout_account', 'Add a bank account first.');
    if (amountKobo > _balance) throw const ApiException('insufficient_funds', "That's more than you have in your wallet.");
    _balance -= amountKobo;
    final id = 'po_demo${++_n}';
    _items.insert(
      0,
      Activity(id: id, kind: ActivityKind.withdrawal, amountKobo: amountKobo, at: DateTime.now(), status: 'submitted', reference: '****${_active!.last4}'),
    );
    _touch();
    Future.delayed(const Duration(seconds: 2), () {
      final i = _items.indexWhere((a) => a.id == id);
      if (i < 0) return;
      final a = _items[i];
      _items[i] = Activity(id: a.id, kind: a.kind, amountKobo: a.amountKobo, at: a.at, status: 'paid', reference: a.reference);
      _touch();
    });
  }
}
