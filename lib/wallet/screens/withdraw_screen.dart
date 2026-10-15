import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import 'bank_account_screen.dart';
import '../../support/support_screens.dart';

/// Send money from the wallet to the rider's approved bank account. Konduct pays the bank fee.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key, required this.api});
  final RiderApi api;
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  late final _balance = widget.api.balance();
  late final _accounts = widget.api.bankAccounts();
  String _digits = '';
  bool _busy = false;
  String? _error;

  int get _kobo => (int.tryParse(_digits) ?? 0) * 100;

  void _set(String d) => setState(() {
    _digits = d;
    _error = null;
  });

  void _type(String d) {
    if (_digits.length >= 6 || (_digits.isEmpty && d == '0')) return;
    _set(_digits + d);
  }

  Future<void> _go(BankAccount to) async {
    final pin = await askPin(context, title: 'Enter your PIN', message: 'To send ${naira(_kobo)} to ****${to.last4}.');
    if (pin == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.withdraw(amountKobo: _kobo, pin: pin);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop();
      showSnack(context, '${naira(_kobo)} is on its way to ****${to.last4}. Banks usually take a few minutes.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<BankAccounts>(
      stream: _accounts,
      builder: (context, acc) => StreamBuilder<int?>(
        stream: _balance,
        builder: (context, bal) {
          final balance = bal.data ?? 0;
          final to = acc.data?.active;
          if (acc.hasData && (to == null || to.onHold)) return _NotReady(api: widget.api, accounts: acc.data!);
          final tooLow = _kobo > 0 && _kobo < minWithdrawKobo;
          final tooHigh = _kobo > balance;
          final ok = to != null && _kobo >= minWithdrawKobo && !tooHigh;
          return PageFrame(
            trailing: SupportButton(api: widget.api.support),
            kicker: 'Withdraw',
            title: 'How much?',
            scroll: false,
            bottom: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Keypad(onDigit: _type, onBackspace: () => _set(_digits.isEmpty ? '' : _digits.substring(0, _digits.length - 1)), enabled: !_busy),
                const SizedBox(height: 12),
                KButton(label: ok ? 'Withdraw ${naira(_kobo)}' : 'Withdraw', loading: _busy, onTap: ok ? () => _go(to) : null),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(naira(_kobo), style: KText.hero(ok ? p.text : p.subtle).copyWith(fontSize: 56)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    tooHigh
                        ? 'You have ${naira(balance)} in your wallet.'
                        : tooLow
                        ? 'The least you can withdraw is ${naira(minWithdrawKobo)}.'
                        : 'Available: ${naira(balance)} · no fee',
                    style: KText.small(tooHigh || tooLow ? K.coral : p.subtle),
                  ),
                ),
                const SizedBox(height: 14),
                if (balance >= minWithdrawKobo)
                  Center(
                    child: Pressable(
                      onTap: _busy ? null : () => _set('${balance ~/ 100}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: p.border),
                        ),
                        child: Text('Withdraw all', style: KText.small(p.text).copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ErrorLine(_error),
                const Spacer(),
                if (to != null)
                  Panel(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_rounded, color: p.subtle),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('To ${to.accountName} · ****${to.last4}', maxLines: 1, overflow: TextOverflow.ellipsis, style: KText.small(p.text)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// No approved account yet, or a new one still in its 24-hour hold.
class _NotReady extends StatelessWidget {
  const _NotReady({required this.api, required this.accounts});
  final RiderApi api;
  final BankAccounts accounts;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final hold = accounts.active?.onHold == true;
    final waiting = accounts.pending != null;
    final (String title, String text) = hold
        ? (
            'Almost ready',
            'Your new bank account can receive its first withdrawal ${untilText(accounts.active!.holdUntil!)}. This wait protects you if someone else got into your account.',
          )
        : waiting
        ? ('Being checked', 'A Konduct team member is checking your bank account. You can withdraw once it\'s approved and 24 hours have passed.')
        : ('Add your bank account', 'Withdrawals go to a bank account in your own name. Add one to get started.');
    return PageFrame(
      kicker: 'Withdraw',
      title: title,
      bottom: hold || waiting
          ? null
          : KButton(
              label: 'Add a bank account',
              icon: Icons.account_balance_rounded,
              onTap: () => pushScreen(context, AddBankScreen(api: api)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: KText.body(p.subtle)),
          const SizedBox(height: 18),
          Pressable(
            onTap: () => pushScreen(context, BankAccountScreen(api: api)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('See your bank account', style: KText.small(p.text).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        ],
      ),
    );
  }
}
