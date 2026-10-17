import 'package:flutter/material.dart' hide Text;

import '../app/app_info.dart';
import '../l10n/text.dart';
import '../theme/tokens.dart';
import 'kit.dart';
import 'web_screen.dart';

/// The Terms, Privacy Policy and Account Deletion Policy live on the website
/// (konduct-landing/src/content/legal.ts); these open them inside the app.
/// The same file is in konduct_student and konduct_driver.
const _docs = [
  ('Terms of Service', '/terms'),
  ('Privacy Policy', '/privacy'),
  ('Account deletion', '/delete-account'),
];

/// Three tappable links, so people can read before they agree.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.center = false});
  final bool center;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      spacing: 4,
      runSpacing: 2,
      children: [
        for (final (label, path) in _docs)
          Pressable(
            scale: 0.96,
            onTap: () => openWeb(context, '${AppConfig.siteUrl}$path', title: label),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: KText.small(p.text).copyWith(decoration: TextDecoration.underline, decorationColor: K.yellowDeep, decorationThickness: 2)),
                  const SizedBox(width: 3),
                  Icon(Icons.open_in_new_rounded, size: 13, color: p.subtle),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A required "I agree" box with the documents linked underneath.
class AgreeBox extends StatelessWidget {
  const AgreeBox({super.key, required this.label, required this.value, required this.onChanged, this.enabled = true});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          checked: value,
          button: true,
          child: Pressable(
            scale: 0.98,
            onTap: enabled ? () => onChanged(!value) : null,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: K.springy,
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: value ? K.ink : p.field,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: value ? K.ink : p.border, width: 2),
                    ),
                    child: AnimatedScale(
                      scale: value ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: K.springy,
                      child: const Icon(Icons.check_rounded, size: 18, color: K.yellow),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: KText.small(p.subtle))),
                ],
              ),
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.only(left: 32), child: LegalLinks()),
      ],
    );
  }
}
