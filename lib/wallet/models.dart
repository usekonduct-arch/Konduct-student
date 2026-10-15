/// Plain data the wallet screens show. Amounts are integer kobo, as on the backend (₦1 = 100 kobo).
library;

/// "₦1,250" or "₦1,250.50". Whole naira drop the kobo.
String naira(int kobo) {
  final negative = kobo < 0;
  final abs = kobo.abs();
  final whole = (abs ~/ 100).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final rest = abs % 100;
  return '${negative ? '-' : ''}₦$whole${rest == 0 ? '' : '.${rest.toString().padLeft(2, '0')}'}';
}

/// users/{uid}, the parts the rider app shows.
class RiderProfile {
  const RiderProfile({required this.fullName, required this.studentId, required this.fundingCode, required this.kycTier, required this.status});
  final String fullName, studentId, fundingCode, status;
  final int kycTier;
}

/// payPreview: the server's priced, single-use quote for one scan.
class Quote {
  const Quote({
    required this.quoteId,
    required this.driverFirstName,
    required this.plate,
    required this.vehicleType,
    required this.route,
    required this.fareKobo,
    required this.passengers,
    required this.totalKobo,
    required this.balanceKobo,
    required this.insufficient,
    required this.needsPin,
    required this.recentlyPaidThisVehicle,
    required this.stickerChangedRecently,
    required this.expiresAt,
    this.seatCapacity,
    this.seatsTaken = 0,
    this.tripRoute,
  });

  final String quoteId, driverFirstName, plate, vehicleType, route;
  final int fareKobo, passengers, totalKobo, balanceKobo;
  final bool insufficient, needsPin, recentlyPaidThisVehicle, stickerChangedRecently;
  final DateTime expiresAt;

  /// Seats on this bus, or null when it isn't a bus (bikes aren't counted).
  final int? seatCapacity;

  /// Seats already paid by scan on this bus's current trip, before this payment. Riders paying
  /// cash aren't counted, so what's left is an estimate.
  final int seatsTaken;

  /// Where the driver says this trip goes; null if they haven't set it.
  final TripRoute? tripRoute;

  /// Most riders this scan can pay for: the group limit, or the seats left on the bus.
  int get maxPassengers => seatCapacity == null ? maxGroup : (seatCapacity! - seatsTaken).clamp(1, maxGroup);

  /// Seats free once this payment goes through, by scan count; null when it isn't a bus.
  int? get seatsLeftAfter => seatCapacity == null ? null : (seatCapacity! - seatsTaken - passengers).clamp(0, seatCapacity!);

  /// The same quote with a different wallet balance.
  Quote withBalance(int balance) => Quote(
    quoteId: quoteId,
    driverFirstName: driverFirstName,
    plate: plate,
    vehicleType: vehicleType,
    route: route,
    fareKobo: fareKobo,
    passengers: passengers,
    totalKobo: totalKobo,
    balanceKobo: balance,
    insufficient: balance < totalKobo,
    needsPin: needsPin,
    recentlyPaidThisVehicle: recentlyPaidThisVehicle,
    stickerChangedRecently: stickerChangedRecently,
    expiresAt: expiresAt,
    seatCapacity: seatCapacity,
    seatsTaken: seatsTaken,
    tripRoute: tripRoute,
  );

  factory Quote.fromMap(Map<String, dynamic> m) => Quote(
    quoteId: m['quoteId'] as String,
    driverFirstName: m['driverFirstName'] as String? ?? 'Driver',
    plate: m['plate'] as String? ?? '',
    vehicleType: m['vehicleType'] as String? ?? 'shuttle',
    route: m['route'] as String? ?? '',
    fareKobo: (m['fareKobo'] as num).toInt(),
    passengers: (m['passengers'] as num).toInt(),
    totalKobo: (m['totalKobo'] as num).toInt(),
    balanceKobo: (m['balanceKobo'] as num).toInt(),
    insufficient: m['insufficient'] == true,
    needsPin: m['needsPin'] == true,
    recentlyPaidThisVehicle: m['recentlyPaidThisVehicle'] == true,
    stickerChangedRecently: m['stickerChangedRecently'] == true,
    expiresAt: DateTime.now().add(Duration(milliseconds: (m['expiresInMs'] as num?)?.toInt() ?? 120000)),
    seatCapacity: (m['seatCapacity'] as num?)?.toInt(),
    seatsTaken: (m['seatsTaken'] as num?)?.toInt() ?? 0,
    tripRoute: TripRoute.fromMap(m['tripRoute']),
  );
}

/// Where a bus is going on a trip, from one landmark to another, and about how long it takes.
class TripRoute {
  const TripRoute({required this.from, required this.to, required this.etaMin});
  final String from, to;
  final int etaMin;

  String get label => '$from → $to';

  static TripRoute? fromMap(Object? m) {
    if (m is! Map || m['from'] == null || m['to'] == null) return null;
    return TripRoute(from: '${m['from']}', to: '${m['to']}', etaMin: (m['etaMin'] as num?)?.toInt() ?? 0);
  }
}

/// Most riders on one scan, the payer included (backend RULES.maxPassengers).
const maxGroup = 6;

/// parks/{id}: a park and how many buses staff last counted there.
class Park {
  const Park({required this.id, required this.name, required this.location, required this.busCount, this.updatedAt, this.lat, this.lng});
  final String id, name, location;
  final int busCount;

  /// When staff last updated the count; null if they never have.
  final DateTime? updatedAt;
  final double? lat, lng;

  bool get hasPin => lat != null && lng != null;

  /// A count this old may no longer be true.
  bool staleAt(DateTime now) => updatedAt == null || now.difference(updatedAt!) > const Duration(hours: 2);
}

/// payConfirm's answer.
class PayResult {
  const PayResult({
    required this.txId,
    required this.reference,
    required this.totalKobo,
    required this.passengers,
    required this.balanceKobo,
    required this.offlineCode,
  });

  final String txId, reference, offlineCode;
  final int totalKobo, passengers, balanceKobo;

  factory PayResult.fromMap(Map<String, dynamic> m) => PayResult(
    txId: m['txId'] as String,
    reference: m['reference'] as String,
    totalKobo: (m['totalKobo'] as num).toInt(),
    passengers: (m['passengers'] as num).toInt(),
    balanceKobo: (m['balanceKobo'] as num).toInt(),
    offlineCode: m['offlineCode'] as String,
  );
}

enum ActivityKind { fare, topUp, withdrawal }

/// One line in the activity list: a fare (transactions/{id}) or a top-up (topups/{id}).
class Activity {
  const Activity({
    required this.id,
    required this.kind,
    required this.amountKobo,
    required this.at,
    required this.status,
    this.reference = '',
    this.routeName = '',
    this.plate = '',
    this.passengers = 1,
    this.offlineCode = '',
    this.checkoutUrl,
    this.driverName = '',
    this.tripRoute,
    this.rateFrom,
    this.rating,
  });

  final String id;
  final ActivityKind kind;
  final int amountKobo;
  final DateTime at;

  /// Fares: completed | reversed | refunded. Top-ups: creating | open | credited | expired | failed_to_open | ...
  final String status;
  final String reference, routeName, plate, offlineCode;
  final int passengers;
  final String? checkoutUrl;

  /// Fares: the driver's first name, the trip route, when the rider may rate the driver (the
  /// trip's estimated arrival) and the stars they gave, if any.
  final String driverName;
  final TripRoute? tripRoute;
  final DateTime? rateFrom;
  final int? rating;

  String get driverLabel => driverName.isEmpty ? 'your driver' : driverName;

  /// Riders rate a fare that went ahead, once, from its estimated arrival until a week after.
  bool canRateAt(DateTime now) =>
      isFare && status == 'completed' && rating == null && rateFrom != null && !now.isBefore(rateFrom!) && now.difference(at) < const Duration(days: 7);

  Activity copyWith({String? status, int? rating}) => Activity(
    id: id,
    kind: kind,
    amountKobo: amountKobo,
    at: at,
    status: status ?? this.status,
    reference: reference,
    routeName: routeName,
    plate: plate,
    passengers: passengers,
    offlineCode: offlineCode,
    checkoutUrl: checkoutUrl,
    driverName: driverName,
    tripRoute: tripRoute,
    rateFrom: rateFrom,
    rating: rating ?? this.rating,
  );

  bool get isFare => kind == ActivityKind.fare;
  bool get isWithdrawal => kind == ActivityKind.withdrawal;
  bool get reversed => status == 'reversed' || status == 'refunded' || (isWithdrawal && status == 'returned');
  bool get credited => status == 'credited';
  bool get pending =>
      (kind == ActivityKind.topUp && (status == 'open' || status == 'creating')) ||
      (isWithdrawal && const ['reserved', 'transferred', 'submitted', 'unknown'].contains(status));
}

/// receiptProof's answer: the ledger's word on one fare, top-up or withdrawal.
class ReceiptProof {
  const ReceiptProof({required this.verified, required this.posted, this.verifyUrl, this.hash, this.balanceAfterKobo, this.postedAt, this.reversed = false});

  /// The entry recomputes and sits in the wallet's hash chain.
  final bool verified;

  /// False while there is nothing on the ledger yet (a top-up still waiting for payment).
  final bool posted;

  /// The public receipt check (printed as a QR); null in demo mode.
  final String? verifyUrl;
  final String? hash;
  final int? balanceAfterKobo;
  final DateTime? postedAt;
  final bool reversed;

  /// What the receipt prints: the first 16 characters of the entry's hash.
  String? get fingerprint => hash == null || hash!.length < 16 ? hash : hash!.substring(0, 16);

  factory ReceiptProof.fromMap(Map<String, dynamic> m) => ReceiptProof(
    verified: m['verified'] == true,
    posted: m['posted'] == true,
    verifyUrl: m['verifyUrl'] as String?,
    hash: m['hash'] as String?,
    balanceAfterKobo: (m['balanceAfterKobo'] as num?)?.toInt(),
    postedAt: m['postedAtMs'] == null ? null : DateTime.fromMillisecondsSinceEpoch((m['postedAtMs'] as num).toInt()),
    reversed: m['reversed'] == true,
  );
}

/// refreshTopUps' answer: open top-ups re-checked with Bachs, and how many were just added.
class TopUpCheck {
  const TopUpCheck({required this.checked, required this.credited});
  final int checked, credited;
}

/// A Nigerian bank from Bachs's list.
class Bank {
  const Bank(this.code, this.name);
  final String code, name;
}

/// payoutAccounts/{id}: where withdrawals go. The full account number stays at Bachs.
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankCode,
    required this.last4,
    required this.accountName,
    required this.status,
    required this.nameMatches,
    this.holdUntil,
  });

  final String id, bankCode, last4, accountName;

  /// pending_approval | active | replaced | rejected
  final String status;
  final bool nameMatches;
  final DateTime? holdUntil;

  bool get active => status == 'active';
  bool get waiting => status == 'pending_approval';
  bool get onHold => active && holdUntil != null && DateTime.now().isBefore(holdUntil!);
}

/// The rider's approved account and, while a change is being checked, the new one.
class BankAccounts {
  const BankAccounts({this.active, this.pending});
  final BankAccount? active, pending;
}

/// riderSetPayoutAccount's answer: the name the bank has on the account.
class BankCheck {
  const BankCheck({required this.accountName, required this.nameMatches});
  final String accountName;
  final bool nameMatches;
}

/// Lowest withdrawal (backend RULES.minPayoutKobo).
const minWithdrawKobo = 50000;

/// Reasons a rider can give on a dispute (backend OpenDispute).
enum DisputeReason {
  wrongAmount('wrong_amount', 'I was charged the wrong amount'),
  chargedTwice('charged_twice', 'I was charged twice'),
  driverNoAlert('driver_no_alert', 'The driver didn\'t get the alert'),
  wrongVehicle('wrong_vehicle', 'I paid the wrong vehicle'),
  other('other', 'Something else');

  const DisputeReason(this.code, this.label);
  final String code, label;
}

/// An error the backend explained. [reason] is its stable code (for example "insufficient_funds").
class ApiException implements Exception {
  const ApiException(this.reason, this.message, {this.details = const {}});
  final String reason;
  final String message;
  final Map<String, dynamic> details;
  @override
  String toString() => message;
}
