import 'dart:math';

import 'models.dart';

/// Everything the wallet screens read and do. Reads are live Firestore streams the security rules
/// limit to this rider; every change goes through a backend callable (the app never writes money).
abstract class RiderApi {
  bool get isDemo;

  Stream<RiderProfile?> profile();

  /// Wallet balance in kobo; null until the wallet document loads.
  Stream<int?> balance();

  /// Fares and top-ups, newest first.
  Stream<List<Activity>> activity({int limit = 30});

  /// config/switches: true while Konduct has paused payments.
  Stream<bool> paymentsPaused();

  /// The dispute state for one fare ("open", "resolved", ...), or null if none was opened.
  Stream<String?> disputeState(String txId);

  /// Prices one scan. Pass the sticker's QR text or the short code typed from it.
  Future<Quote> preview({String? qr, String? code, int passengers = 1});

  Future<PayResult> confirm({required String quoteId, required String idempotencyKey, String? pin, bool repeatConfirmed = false});

  /// Undo within 60 seconds. Returns the new balance.
  Future<int> undo(String txId);

  /// Opens a Bachs checkout. Returns its URL.
  Future<String> createTopUp({required int amountKobo, required String idempotencyKey});

  Future<void> openDispute({required String txId, required DisputeReason reason, String note = ''});

  Future<void> changePin({required String oldPin, required String newPin});

  /// Puts the account on hold at once (stolen phone). Only an agent can lift it.
  Future<void> lockMyAccount();
}

final _rand = Random.secure();
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A fresh key for one payment or top-up attempt. Retrying with the same key can't charge twice.
String newIdempotencyKey() => List.generate(24, (_) => _alphabet[_rand.nextInt(_alphabet.length)]).join();
