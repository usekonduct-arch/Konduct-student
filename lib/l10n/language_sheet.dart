import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../theme/tokens.dart';
import '../ui/kit.dart';
import 'l10n.dart';
import 'text.dart';

/// Picks the app's language. Each language is listed in its own name, so anyone can find theirs
/// whatever the app is set to now.
Future<void> pickLanguage(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => const _LanguageSheet(),
);

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = L10nScope.watch(context);
    return Container(
      decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(width: 44, height: 5, decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(3))),
          ),
          const SizedBox(height: 18),
          Text('Language', style: KText.h3(p.text)),
          const SizedBox(height: 4),
          Text('The app and your notifications will use it.', style: KText.small(p.subtle)),
          const SizedBox(height: 14),
          for (final l in Lang.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                button: true,
                selected: l == now,
                child: Pressable(
                  scale: 0.98,
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    await L10n.instance.set(l);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: l == now ? K.yellow.withValues(alpha: 0.2) : p.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: l == now ? K.yellowDeep : p.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Never translated: each name stays in its own language.
                              Text(l.nativeName, translate: false, style: KText.body(p.text).copyWith(fontWeight: FontWeight.w800)),
                              if (l.nativeName != l.englishName) Text(l.englishName, translate: false, style: KText.small(p.subtle)),
                            ],
                          ),
                        ),
                        if (l == now) const Icon(Icons.check_circle_rounded, color: K.yellowDeep),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Translations are new and still being checked. If something reads wrong, tell us from Help & support.',
            style: KText.small(p.subtle),
          ),
        ],
      ),
    );
  }
}
