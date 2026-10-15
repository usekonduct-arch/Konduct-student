import 'package:flutter/widgets.dart' hide Text;
import 'package:flutter/widgets.dart' as w show Text;

import 'l10n.dart';

/// Flutter's [w.Text], translated. Files import Flutter with `hide Text` and get this one, so every
/// label in the app follows the language setting without each call site asking for it, and it
/// redraws when the language changes. English text with no translation shows as written.
///
/// Pass `translate: false` for text people typed (chat messages, names) so a message that happens
/// to match an app label isn't changed.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.translate = true,
  }) : textSpan = null;

  /// Rich text: each [TextSpan]'s text is translated on its own.
  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.translate = true,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;
  final bool translate;

  @override
  Widget build(BuildContext context) {
    // Depend on the language so this redraws when it changes, even when built const.
    L10nScope.watch(context);
    final label = semanticsLabel == null || !translate ? semanticsLabel : tr(semanticsLabel!);
    if (textSpan != null) {
      return w.Text.rich(
        translate ? _span(textSpan!) : textSpan!,
        key: key,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: label,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return w.Text(
      translate ? tr(data!) : data!,
      key: key,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: label,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  static InlineSpan _span(InlineSpan s) {
    if (s is! TextSpan) return s;
    return TextSpan(
      text: s.text == null ? null : tr(s.text!),
      children: s.children?.map(_span).toList(),
      style: s.style,
      recognizer: s.recognizer,
      mouseCursor: s.mouseCursor,
      onEnter: s.onEnter,
      onExit: s.onExit,
      semanticsLabel: s.semanticsLabel == null ? null : tr(s.semanticsLabel!),
      locale: s.locale,
      spellOut: s.spellOut,
    );
  }
}
