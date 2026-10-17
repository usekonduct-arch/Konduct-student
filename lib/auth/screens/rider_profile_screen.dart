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

/// FR-AUTH-01/02: name + student ID, one account per student ID per campus.
class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, required this.onSubmit, required this.onSignOut, required this.progress, this.demo = false});
  final Future<void> Function(String name, String studentId) onSubmit;
  final VoidCallback onSignOut;
  final double progress;
  final bool demo;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _shake = GlobalKey<ShakeState>();
  bool _agree = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _id.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _id.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().split(RegExp(r'\s+')).length >= 2 && _id.text.trim().length >= 4 && _agree;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_name.text.trim().replaceAll(RegExp(r'\s+'), ' '), _id.text.trim().toUpperCase());
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
      subtitle: const Text('Use the name and number on your student ID card. We check them so nobody can ride on your account.'),
      progress: widget.progress,
      onBack: _busy ? null : widget.onSignOut,
      demo: widget.demo,
      bottom: Column(
        children: [
          Entrance(
            delay: const Duration(milliseconds: 380),
            child: AgreeBox(
              label: 'I agree to the Terms and Privacy Policy, and to Konduct checking my student ID with ${AppConfig.campusName}.',
              value: _agree,
              enabled: !_busy,
              onChanged: (v) => setState(() => _agree = v),
            ),
          ),
          const SizedBox(height: 8),
          KButton(label: 'Continue', loading: _busy, onTap: _valid ? _submit : null),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 26),
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
                  controller: _name,
                  label: 'Full name',
                  hint: 'Adaeze Okafor',
                  icon: Icons.person_rounded,
                  enabled: !_busy,
                  capitalization: TextCapitalization.words,
                  action: TextInputAction.next,
                ),
              ),
              const SizedBox(height: 12),
              Entrance(
                delay: const Duration(milliseconds: 280),
                child: KField(
                  controller: _id,
                  label: 'Student ID / matric number',
                  hint: 'e.g. UNI/2023/04571',
                  icon: Icons.badge_rounded,
                  enabled: !_busy,
                  capitalization: TextCapitalization.characters,
                  mono: true,
                  error: _error != null,
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9/\-]')), LengthLimitingTextInputFormatter(24)],
                  onSubmitted: (_) => _valid ? _submit() : null,
                ),
              ),
              ErrorLine(_error),
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
