import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../app/app_info.dart';
import '../../theme/tokens.dart';
import '../../ui/field.dart';
import '../../ui/flow_scaffold.dart';
import '../../ui/kit.dart';
import '../../ui/legal.dart';
import '../auth_repository.dart';

/// FR-AUTH-01: first and last name. Student IDs are no longer asked for at sign-up; staff can
/// add one from the console if it's ever needed.
class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, required this.onSubmit, required this.onSignOut, required this.progress, this.demo = false});
  final Future<void> Function(String fullName) onSubmit;
  final VoidCallback onSignOut;
  final double progress;
  final bool demo;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _lastFocus = FocusNode();
  final _shake = GlobalKey<ShakeState>();
  bool _agree = false;
  bool _busy = false;
  String? _error;

  static final _nameChars = [FilteringTextInputFormatter.allow(RegExp(r"[\p{L}'.\- ]", unicode: true)), LengthLimitingTextInputFormatter(40)];

  @override
  void initState() {
    super.initState();
    _first.addListener(() => setState(() {}));
    _last.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _lastFocus.dispose();
    super.dispose();
  }

  String _clean(TextEditingController c) => c.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get _valid => _clean(_first).length >= 2 && _clean(_last).length >= 2 && _agree;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit('${_clean(_first)} ${_clean(_last)}');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      _shake.currentState?.shake();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      kicker: 'Almost there',
      title: 'Tell us who\'s riding.',
      subtitle: const Text('Just your first and last name. It shows on your receipts and helps an agent find your account.'),
      progress: widget.progress,
      onBack: _busy ? null : widget.onSignOut,
      demo: widget.demo,
      bottom: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: KButton(label: 'Continue', loading: _busy, onTap: _valid ? _submit : null),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 26, bottom: 8),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Shake(
          key: _shake,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Entrance(delay: const Duration(milliseconds: 160), child: const _CampusCard()),
              const SizedBox(height: 14),
              Entrance(
                delay: const Duration(milliseconds: 220),
                child: KField(
                  controller: _first,
                  label: 'First name',
                  hint: 'Adaeze',
                  icon: Icons.person_rounded,
                  enabled: !_busy,
                  capitalization: TextCapitalization.words,
                  action: TextInputAction.next,
                  autofill: const [AutofillHints.givenName],
                  formatters: _nameChars,
                  onSubmitted: (_) => _lastFocus.requestFocus(),
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 280),
                child: KField(
                  controller: _last,
                  focusNode: _lastFocus,
                  label: 'Last name',
                  hint: 'Okafor',
                  icon: Icons.badge_rounded,
                  enabled: !_busy,
                  capitalization: TextCapitalization.words,
                  action: TextInputAction.done,
                  autofill: const [AutofillHints.familyName],
                  formatters: _nameChars,
                  error: _error != null,
                  onSubmitted: (_) => _valid ? _submit() : null,
                ),
              ),
              ErrorLine(_error),
              const SizedBox(height: 14),
              Entrance(
                delay: const Duration(milliseconds: 340),
                child: AgreeBox(
                  label: 'I agree to the Terms and Privacy Policy.',
                  value: _agree,
                  enabled: !_busy,
                  onChanged: (v) => setState(() => _agree = v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampusCard extends StatelessWidget {
  const _CampusCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: K.ink, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: K.yellow, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.school_rounded, color: K.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConfig.campusName, style: KText.h3(K.paper)),
                  Text(AppConfig.campusPlace, style: KText.small(K.muteDark)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: K.go.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
              child: Text('PILOT', style: KText.kicker(K.go).copyWith(fontSize: 10)),
            ),
          ],
        ),
      );
}
