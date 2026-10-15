import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../models.dart';
import '../rider_api.dart';
import '../wallet_ui.dart';
import '../../support/support_screens.dart';

/// Where withdrawals go. Adding or changing an account needs the password and PIN; a Konduct
/// staff member checks the bank's name for the account matches the rider before it's used.
class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key, required this.api});
  final RiderApi api;

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  late final _accounts = widget.api.bankAccounts();
  List<Bank> _banks = const [];

  @override
  void initState() {
    super.initState();
    widget.api.banks().then((b) => mounted ? setState(() => _banks = b) : null, onError: (_) {});
  }

  String _bankName(String code) => _banks.where((b) => b.code == code).firstOrNull?.name ?? 'Bank $code';

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return StreamBuilder<BankAccounts>(
      stream: _accounts,
      builder: (context, s) {
        final a = s.data;
        return PageFrame(
          trailing: SupportButton(api: widget.api.support),
          kicker: 'Withdrawals',
          title: 'Your bank account',
          bottom: a == null || a.pending != null
              ? null
              : KButton(
                  label: a.active == null ? 'Add a bank account' : 'Change bank account',
                  icon: Icons.account_balance_rounded,
                  onTap: () => pushScreen(context, AddBankScreen(api: widget.api)),
                ),
          child: !s.hasData
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: K.yellowDeep)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (a!.active == null && a.pending == null)
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.account_balance_rounded, color: K.yellowDeep, size: 32),
                            const SizedBox(height: 10),
                            Text('No bank account yet', style: KText.h3(p.text)),
                            const SizedBox(height: 6),
                            Text(
                              'Add an account in your own name to withdraw money from your wallet. Any Nigerian bank or fintech works.',
                              style: KText.body(p.subtle),
                            ),
                          ],
                        ),
                      ),
                    if (a.active != null) _AccountCard(account: a.active!, bank: _bankName(a.active!.bankCode)),
                    if (a.pending != null) ...[const SizedBox(height: 12), _AccountCard(account: a.pending!, bank: _bankName(a.pending!.bankCode))],
                    const SizedBox(height: 18),
                    Text('HOW IT KEEPS YOUR MONEY SAFE', style: KText.kicker(p.subtle)),
                    const SizedBox(height: 8),
                    _Point(Icons.badge_rounded, 'The account must be in the name you registered with.'),
                    _Point(Icons.verified_user_rounded, 'A Konduct team member checks every new account.'),
                    _Point(Icons.schedule_rounded, 'Your first withdrawal to a new account can go 24 hours after it\'s approved.'),
                  ],
                ),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.bank});
  final BankAccount account;
  final String bank;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (String label, Color tone) = account.waiting
        ? ('Being checked', K.yellowDeep)
        : account.onHold
        ? ('Ready ${untilText(account.holdUntil!)}', K.yellowDeep)
        : account.active
        ? ('Ready for withdrawals', K.green)
        : (account.status, p.subtle);
    return Panel(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.account_balance_rounded, color: K.yellow),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.accountName.isEmpty ? bank : account.accountName, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
                Text('$bank · ****${account.last4}', style: KText.small(p.subtle)),
                const SizedBox(height: 6),
                Tag(label, color: tone),
                if (account.waiting && !account.nameMatches) ...[
                  const SizedBox(height: 6),
                  Text('The name on this account doesn\'t match yours, so it may be refused.', style: KText.small(K.coral)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: p.subtle),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: KText.small(p.text))),
        ],
      ),
    );
  }
}

/// Bank, account number, then password and PIN.
class AddBankScreen extends StatefulWidget {
  const AddBankScreen({super.key, required this.api});
  final RiderApi api;
  @override
  State<AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends State<AddBankScreen> {
  final _number = TextEditingController();
  Bank? _bank;
  List<Bank>? _banks;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    try {
      final b = await widget.api.banks();
      if (mounted) setState(() => _banks = b);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  bool get _ready => _bank != null && _number.text.length == 10;

  Future<void> _pickBank() async {
    if (_banks == null) return _loadBanks();
    final b = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BankPicker(banks: _banks!),
    );
    if (b != null) setState(() => _bank = b);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PasswordSheet(),
    );
    if (password == null || !mounted) return;
    final pin = await askPin(context, title: 'Enter your PIN', message: 'To confirm it\'s you adding this account.');
    if (pin == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.setBankAccount(bankCode: _bank!.code, accountNumber: _number.text, password: password, pin: pin);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await showDialog<void>(
        context: context,
        builder: (context) {
          final p = Palette.of(context);
          return AlertDialog(
            backgroundColor: p.bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(r.nameMatches ? 'Account added' : 'Check the name', style: KText.h3(p.text)),
            content: Text(
              r.nameMatches
                  ? 'The bank says this account belongs to ${r.accountName}. A Konduct team member will approve it shortly, and you can withdraw 24 hours after that.'
                  : 'The bank says this account belongs to ${r.accountName}, which doesn\'t match your name. Withdrawals only go to your own account, so it will likely be refused.',
              style: KText.body(p.subtle),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK', style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          );
        },
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return PageFrame(
      kicker: 'Withdrawals',
      title: 'Add a bank account',
      bottom: KButton(label: 'Continue', loading: _busy, onTap: _ready ? _submit : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('BANK', style: KText.kicker(p.subtle)),
          const SizedBox(height: 8),
          Pressable(
            scale: 0.98,
            onTap: _busy ? null : _pickBank,
            child: Panel(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: p.subtle),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _bank?.name ?? (_banks == null ? 'Loading banks…' : 'Choose your bank'),
                      style: KText.body(_bank == null ? p.subtle : p.text).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, color: p.subtle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('ACCOUNT NUMBER', style: KText.kicker(p.subtle)),
          const SizedBox(height: 8),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            maxLength: 10,
            enabled: !_busy,
            onChanged: (_) => setState(() {}),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: KText.mono(p.text, size: 22).copyWith(letterSpacing: 3),
            decoration: InputDecoration(
              counterText: '',
              hintText: '0123456789',
              hintStyle: KText.mono(p.border, size: 22).copyWith(letterSpacing: 3),
              filled: true,
              fillColor: p.field,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: K.yellowDeep, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: p.border),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('10 digits. It must be an account in your own name.', style: KText.small(p.subtle)),
          ErrorLine(_error),
        ],
      ),
    );
  }
}

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.banks});
  final List<Bank> banks;
  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty ? widget.banks : widget.banks.where((b) => b.name.toLowerCase().contains(q)).toList();
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            style: KText.body(p.text),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, color: p.subtle),
              hintText: 'Search banks',
              hintStyle: KText.body(p.subtle),
              filled: true,
              fillColor: p.field,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: K.yellowDeep, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No bank matches "$_q".', style: KText.body(p.subtle)),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () => Navigator.of(context).pop(list[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                        child: Text(list[i].name, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _c = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Confirm your password', style: KText.h3(p.text)),
            const SizedBox(height: 4),
            Text('Changing where money goes needs your password, even when you\'re signed in.', style: KText.small(p.subtle)),
            const SizedBox(height: 16),
            TextField(
              controller: _c,
              autofocus: true,
              obscureText: !_show,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _c.text.isEmpty ? null : Navigator.of(context).pop(_c.text),
              autofillHints: const [AutofillHints.password],
              style: KText.body(p.text),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: KText.body(p.subtle),
                filled: true,
                fillColor: p.field,
                suffixIcon: IconButton(
                  icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: p.subtle),
                  onPressed: () => setState(() => _show = !_show),
                  tooltip: _show ? 'Hide password' : 'Show password',
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: p.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: K.yellowDeep, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            KButton(label: 'Confirm', onTap: _c.text.isEmpty ? null : () => Navigator.of(context).pop(_c.text)),
          ],
        ),
      ),
    );
  }
}
