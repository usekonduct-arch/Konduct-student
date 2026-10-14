import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// The Konduct text field: icon tile that lights up on focus, floating label, yellow focus ring,
/// red border on error, and an optional show/hide toggle for passwords.
class KField extends StatefulWidget {
  const KField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.enabled = true,
    this.capitalization = TextCapitalization.none,
    this.mono = false,
    this.error = false,
    this.obscure = false,
    this.keyboardType,
    this.action,
    this.autofill,
    this.formatters,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool enabled, mono, error, obscure;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final TextInputAction? action;
  final Iterable<String>? autofill;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<KField> createState() => _KFieldState();
}

class _KFieldState extends State<KField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  late bool _hidden = widget.obscure;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_changed);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final on = _focus.hasFocus;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      decoration: BoxDecoration(
        color: p.field,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.error ? K.coral : (on ? (dark ? K.yellow : K.ink) : p.border), width: on || widget.error ? 2 : 1.4),
        boxShadow: [if (on) BoxShadow(color: K.yellow.withValues(alpha: dark ? 0.18 : 0.35), blurRadius: 0, spreadRadius: 4)],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: on ? K.yellow : p.bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(widget.icon, size: 20, color: on ? K.ink : p.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              obscureText: _hidden,
              enableSuggestions: !widget.obscure,
              textCapitalization: widget.capitalization,
              keyboardType: widget.keyboardType,
              textInputAction: widget.action,
              autofillHints: widget.autofill,
              inputFormatters: widget.formatters,
              onSubmitted: widget.onSubmitted,
              autocorrect: false,
              style: widget.mono ? KText.mono(p.text, size: 17) : KText.body(p.text).copyWith(fontSize: 17, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                labelStyle: KText.small(p.subtle),
                floatingLabelStyle: KText.small(p.subtle),
                hintStyle: KText.body(p.subtle.withValues(alpha: 0.5)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (widget.obscure)
            IconButton(
              tooltip: _hidden ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(_hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, key: ValueKey(_hidden), color: p.subtle),
              ),
            ),
        ],
      ),
    );
  }
}
