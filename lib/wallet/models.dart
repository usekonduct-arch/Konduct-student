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
  });

  final String quoteId, driverFirstName, plate, vehicleType, route;
  final int fareKobo, passengers, totalKobo, balanceKobo;
  final bool insufficient, needsPin, recentlyPaidThisVehicle, stickerChangedRecently;
  final DateTime expiresAt;

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
  );
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
    required this.undoUntil,
  });

  final String txId, reference, offlineCode;
  final int totalKobo, passengers, balanceKobo;
  final DateTime undoUntil;

  factory PayResult.fromMap(Map<String, dynamic> m) => PayResult(
    txId: m['txId'] as String,
    reference: m['reference'] as String,
    totalKobo: (m['totalKobo'] as num).toInt(),
    passengers: (m['passengers'] as num).toInt(),
    balanceKobo: (m['balanceKobo'] as num).toInt(),
    offlineCode: m['offlineCode'] as String,
    undoUntil: DateTime.fromMillisecondsSinceEpoch((m['undoUntilMs'] as num).toInt()),
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
    this.undoUntil,
    this.checkoutUrl,
  });

  final String id;
  final ActivityKind kind;
  final int amountKobo;
  final DateTime at;

  /// Fares: completed | reversed | refunded. Top-ups: creating | open | credited | expired | failed_to_open | ...
  final String status;
  final String reference, routeName, plate, offlineCode;
  final int passengers;
  final DateTime? undoUntil;
  final String? checkoutUrl;

  bool get isFare => kind == ActivityKind.fare;
  bool get isWithdrawal => kind == ActivityKind.withdrawal;
  bool get reversed => status == 'reversed' || status == 'refunded' || (isWithdrawal && status == 'returned');
  bool get credited => status == 'credited';
  bool get pending =>
      (kind == ActivityKind.topUp && (status == 'open' || status == 'creating')) ||
      (isWithdrawal && const ['reserved', 'transferred', 'submitted', 'unknown'].contains(status));
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
