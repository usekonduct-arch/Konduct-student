import 'dart:math';

import '../messages/messages_api.dart';
import '../support/support_api.dart';
import 'models.dart';

/// Everything the wallet screens read and do. Reads are live Firestore streams the security rules
/// limit to this rider; every change goes through a backend callable (the app never writes money).
abstract class RiderApi {
  bool get isDemo;

  /// Chat with Konduct staff.
  SupportApi get support;

  /// Notifications, ads and push.
  MessagesApi get messages;

  /// Changes the sign-in password after confirming the current one.
  Future<void> changePassword({required String current, required String next});

  /// Emails a password reset link to the signed-in address.
  Future<void> sendPasswordReset();

  Stream<RiderProfile?> profile();

  /// Wallet balance in kobo; null until the wallet document loads.
  Stream<int?> balance();

  /// Fares and top-ups, newest first.
  Stream<List<Activity>> activity({int limit = 30});

  /// config/switches: true while Konduct has paused payments.
  Stream<bool> paymentsPaused();

  /// Parks shown in the app and how many buses are there, by name.
  Stream<List<Park>> parks();

  /// The dispute state for one fare ("open", "resolved", ...), or null if none was opened.
  Stream<String?> disputeState(String txId);

  /// Prices one scan. Pass the sticker's QR text or the short code typed from it.
  Future<Quote> preview({String? qr, String? code, int passengers = 1});

  Future<PayResult> confirm({required String quoteId, required String idempotencyKey, String? pin, bool repeatConfirmed = false});

  /// One fare, live (for its rating); null if it can't be read.
  Stream<Activity?> fare(String txId);

  /// 1 to 5 stars for the driver, once the trip's estimated time has passed.
  Future<void> rateDriver({required String txId, required int stars, String comment = ''});

  /// Opens a Bachs checkout. Returns its URL.
  Future<String> createTopUp({required int amountKobo, required String idempotencyKey});

  /// Asks the backend to re-check open top-ups with Bachs, in case its confirmation is late.
  Future<TopUpCheck> refreshTopUps();

  /// The ledger's proof for one of this rider's fares, top-ups or withdrawals.
  Future<ReceiptProof> receiptProof({required ActivityKind kind, required String id});

  Future<void> openDispute({required String txId, required DisputeReason reason, String note = ''});

  Future<void> changePin({required String oldPin, required String newPin});

  /// Puts the account on hold at once (stolen phone). Only an agent can lift it.
  Future<void> lockMyAccount();

  /// Where withdrawals go: the approved account, and any new one waiting for a staff check.
  Stream<BankAccounts> bankAccounts();

  /// Nigerian banks for the picker.
  Future<List<Bank>> banks();

  /// Adds or changes the withdrawal account. Confirms the password first (the backend wants a
  /// sign-in from the last few minutes), then the PIN. A staff member approves the account.
  Future<BankCheck> setBankAccount({required String bankCode, required String accountNumber, required String password, required String pin});

  /// Sends [amountKobo] to the approved bank account.
  Future<void> withdraw({required int amountKobo, required String pin});
}

final _rand = Random.secure();
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A fresh key for one payment or top-up attempt. Retrying with the same key can't charge twice.
String newIdempotencyKey() => List.generate(24, (_) => _alphabet[_rand.nextInt(_alphabet.length)]).join();
