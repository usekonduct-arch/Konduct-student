import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/receipt_printer.dart';
import '../../ui/web_screen.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'rate_sheet.dart';
import 'receipt_screen.dart';
import '../../support/support_screens.dart';

/// Opens a line from the activity list: its full receipt.
void openActivity(BuildContext context, RiderApi api, Activity a) => pushScreen(context, TransactionScreen(api: api, activity: a));

/// The full breakdown of one fare, top-up or withdrawal, printed like a POS slip and checked
/// against the ledger. It reprints by itself if the record changes (a top-up gets confirmed).
class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key, required this.api, required this.activity});
  final RiderApi api;
  final Activity activity;

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  late Activity _a = widget.activity;
  late Future<Slip> _slip = _load();
  ReceiptProof? _proof;
  StreamSubscription<List<Activity>>? _live;
  bool _printed = false;
  bool _checking = false;

  RiderApi get api => widget.api;

  @override
  void initState() {
    super.initState();
    _live = api.activity(limit: 100).listen((list) {
      final now = list.where((x) => x.id == _a.id && x.kind == _a.kind).firstOrNull;
      if (now == null || (now.status == _a.status && now.amountKobo == _a.amountKobo)) return;
      setState(() {
        _a = now;
        _printed = false;
        _slip = _load();
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  Future<Slip> _load() async {
    ReceiptProof? proof;
    String? problem;
    try {
      proof = await api.receiptProof(kind: _a.kind, id: _a.id).timeout(const Duration(seconds: 10));
    } on ApiException catch (e) {
      problem = e.message;
    } catch (_) {
      problem = 'No connection to Konduct, so this copy isn\'t verified yet.';
    }
    if (mounted) setState(() => _proof = proof);
    return slipFor(_a, proof, problem);
  }

  Future<void> _checkPayment() async {
    setState(() => _checking = true);
    try {
      final r = await api.refreshTopUps();
      if (!mounted) return;
      showSnack(
        context,
        r.credited > 0 ? 'Payment confirmed. Your wallet is topped up.' : 'Bachs hasn\'t confirmed this payment yet. We\'ll add it the moment they do.',
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final url = _proof?.verifyUrl;
    final waiting = _a.kind == ActivityKind.topUp && _a.pending;
    return PageFrame(
      trailing: SupportButton(api: api.support, txId: _a.isFare ? _a.id : null),
      kicker: 'Receipt',
      title: _title(_a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ReceiptPrinter(
            slip: _slip,
            fileName: 'konduct-receipt-${_a.reference.isNotEmpty ? _a.reference : _a.id}',
            onPrinted: () => setState(() => _printed = true),
          ),
          const SizedBox(height: 18),
          AnimatedOpacity(
            opacity: _printed ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: !_printed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (waiting) ...[
                    KButton(label: 'Check payment now', icon: Icons.refresh_rounded, loading: _checking, onTap: _checkPayment),
                    const SizedBox(height: 10),
                  ],
                  if (url != null)
                    KButton(
                      label: 'Verify online',
                      icon: Icons.verified_rounded,
                      dark: true,
                      onTap: () => openWeb(context, url, title: 'Receipt check'),
                    ),
                  if (_reference(_a).isNotEmpty)
                    Center(
                      child: Pressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: _reference(_a)));
                          showSnack(context, 'Reference copied');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 16, color: p.subtle),
                              const SizedBox(width: 6),
                              Text('Copy reference ${_reference(_a)}', style: KText.small(p.subtle)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_a.isFare && !_a.reversed) ...[const SizedBox(height: 4), RideRatingCard(api: api, txId: _a.id), FareReportLink(api: api, txId: _a.id)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _title(Activity a) => switch (a.kind) {
  ActivityKind.fare => a.reversed ? (a.status == 'refunded' ? 'Fare refunded' : 'Fare undone') : 'Ride fare',
  ActivityKind.topUp => a.pending ? 'Top-up pending' : 'Wallet top-up',
  ActivityKind.withdrawal => 'Withdrawal',
};

/// What the rider quotes to support: the fare's reference, or a short form of the record's id.
String _reference(Activity a) => a.isFare && a.reference.isNotEmpty ? a.reference : _shortId(a.id);

String _shortId(String id) {
  final bare = id.replaceFirst(RegExp(r'^(tu_|po_|fare_)'), '');
  return (bare.length > 10 ? bare.substring(bare.length - 10) : bare).toUpperCase();
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Wed 15 Oct 2026 · 14:05:09"
String receiptTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_days[t.weekday - 1]} ${t.day} ${_months[t.month - 1]} ${t.year} · ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

/// The printed receipt for one line of activity, with what the ledger says about it.
Slip slipFor(Activity a, ReceiptProof? proof, String? problem) {
  final SlipSeal seal;
  if (a.reversed) {
    seal = SlipSeal.voided;
  } else if (proof?.verified == true) {
    seal = SlipSeal.verified;
  } else if (a.pending) {
    seal = SlipSeal.pending;
  } else if (problem != null) {
    seal = SlipSeal.unverified;
  } else {
    seal = SlipSeal.none;
  }
  final after = proof?.balanceAfterKobo;
  final common = (
    place: '${AppConfig.campusName} · ${AppConfig.campusPlace}',
    when: receiptTime(a.at),
    verifyUrl: a.reversed ? null : proof?.verifyUrl,
    fingerprint: proof?.fingerprint,
  );
  switch (a.kind) {
    case ActivityKind.fare:
      final each = a.passengers <= 0 ? a.amountKobo : a.amountKobo ~/ a.passengers;
      return Slip(
        heading: 'Ride fare',
        amount: naira(a.amountKobo),
        strikeAmount: a.reversed,
        when: common.when,
        place: common.place,
        lines: [
          SlipLine('Ref', a.reference.isEmpty ? _shortId(a.id) : a.reference, strong: true),
          if (a.plate.isNotEmpty) SlipLine('Vehicle', a.plate),
          if (a.driverName.isNotEmpty) SlipLine('Driver', a.driverName),
          if (a.routeName.isNotEmpty) SlipLine('Route', a.routeName),
          if (a.tripRoute != null) SlipLine('Trip', '${a.tripRoute!.label} · ~${a.tripRoute!.etaMin} min'),
          SlipLine('Riders', a.passengers == 1 ? 'Just you' : 'You + ${a.passengers - 1}'),
          if (a.offlineCode.isNotEmpty && !a.reversed) SlipLine('Offline code', a.offlineCode.split('').join(' ')),
          if (a.rating != null) SlipLine('Your rating', '${'★' * a.rating!}${'☆' * (5 - a.rating!)}'),
        ],
        totals: [SlipLine('Fare', '${a.passengers} × ${naira(each)}'), if (after != null && !a.reversed) SlipLine('Wallet after', naira(after))],
        status: a.reversed ? (a.status == 'refunded' ? 'Refunded to wallet' : 'Undone, money returned') : 'Paid by wallet',
        seal: seal,
        verifyUrl: common.verifyUrl,
        fingerprint: common.fingerprint,
        note: problem,
      );
    case ActivityKind.topUp:
      final status = switch (a.status) {
        'credited' => 'Added to wallet',
        'open' || 'creating' => 'Waiting for payment',
        'expired' => 'Expired, not charged',
        'failed_to_open' => 'Didn\'t open, not charged',
        _ => a.status,
      };
      return Slip(
        heading: 'Wallet top-up',
        amount: naira(a.amountKobo),
        strikeAmount: !a.credited && !a.pending,
        when: common.when,
        place: common.place,
        lines: [SlipLine('Ref', _shortId(a.id), strong: true), const SlipLine('Method', 'Card / bank transfer'), const SlipLine('Processor', 'Bachs')],
        totals: [if (after != null) SlipLine('Wallet after', naira(after))],
        status: status,
        seal: seal,
        verifyUrl: common.verifyUrl,
        fingerprint: common.fingerprint,
        note: a.pending ? 'We add it the moment Bachs confirms. Pull down on Home, or tap "Check payment now".' : problem,
      );
    case ActivityKind.withdrawal:
      final status = a.pending ? 'On its way to your bank' : (a.reversed ? 'Returned to wallet' : 'Paid to your bank');
      return Slip(
        heading: 'Withdrawal',
        amount: naira(a.amountKobo),
        strikeAmount: a.reversed,
        when: common.when,
        place: common.place,
        lines: [
          SlipLine('Ref', _shortId(a.id), strong: true),
          if (a.reference.isNotEmpty) SlipLine('To account', a.reference),
          const SlipLine('Processor', 'Bachs'),
        ],
        totals: [if (after != null && !a.reversed) SlipLine('Wallet after', naira(after))],
        status: status,
        seal: seal,
        verifyUrl: common.verifyUrl,
        fingerprint: common.fingerprint,
        note: problem,
      );
  }
}
