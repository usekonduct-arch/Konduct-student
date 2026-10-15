import 'package:flutter/material.dart';

/// Brand tokens, shared with the landing page (konduct-landing/src/styles.css).
abstract final class K {
  static const ink = Color(0xFF0E1115);
  static const ink2 = Color(0xFF161B22);
  static const ink3 = Color(0xFF222934);
  static const paper = Color(0xFFF4F3EC);
  static const paper2 = Color(0xFFEAE8DC);
  static const line = Color(0xFFD8D6C8);
  static const mute = Color(0xFF5D636B);
  static const muteDark = Color(0xFFA3AAB3);
  static const yellow = Color(0xFFFFC700);
  static const yellowDeep = Color(0xFFE3AB00);
  static const green = Color(0xFF0B6B42);
  static const go = Color(0xFF19B86A);
  static const coral = Color(0xFFFF5A3C);
  static const sky = Color(0xFFBFE3F2);

  /// Letters the brand fonts don't have (Yoruba ẹ ọ ṣ with tone marks, Hausa ɓ ɗ ƙ ƴ, ₦) come from here.
  static const fallback = ['NotoSansLatin'];

  static const display = 'Bricolage';
  static const body = 'Figtree';
  static const mono = 'JetBrainsMono';

  static const springy = Cubic(0.34, 1.56, 0.64, 1);
  static const outExpo = Cubic(0.16, 1, 0.3, 1);
}

/// Colours that differ between the light rider app and the dark driver app.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({required this.bg, required this.surface, required this.text, required this.subtle, required this.border, required this.field});

  final Color bg, surface, text, subtle, border, field;

  static const rider = Palette(bg: K.paper, surface: Colors.white, text: K.ink, subtle: K.mute, border: K.line, field: Colors.white);
  static const driver = Palette(bg: K.ink, surface: K.ink2, text: K.paper, subtle: K.muteDark, border: Color(0xFF2A313C), field: K.ink2);

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith({Color? bg, Color? surface, Color? text, Color? subtle, Color? border, Color? field}) => Palette(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        text: text ?? this.text,
        subtle: subtle ?? this.subtle,
        border: border ?? this.border,
        field: field ?? this.field,
      );

  @override
  Palette lerp(Palette? other, double t) => other == null
      ? this
      : Palette(
          bg: Color.lerp(bg, other.bg, t)!,
          surface: Color.lerp(surface, other.surface, t)!,
          text: Color.lerp(text, other.text, t)!,
          subtle: Color.lerp(subtle, other.subtle, t)!,
          border: Color.lerp(border, other.border, t)!,
          field: Color.lerp(field, other.field, t)!,
        );
}

ThemeData buildTheme(Palette p, {required bool dark}) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: K.body,
    fontFamilyFallback: K.fallback,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: K.yellow,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: K.yellow,
      onPrimary: K.ink,
      surface: p.bg,
      onSurface: p.text,
      error: K.coral,
    ),
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: K.yellowDeep, selectionHandleColor: K.yellowDeep),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? K.paper : K.ink,
      contentTextStyle: TextStyle(fontFamily: K.body, fontWeight: FontWeight.w600, color: dark ? K.ink : K.paper),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

/// Type scale.
abstract final class KText {
  static TextStyle hero(Color c) => TextStyle(fontFamily: K.display, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w800, fontSize: 44, height: 0.95, letterSpacing: -1.8, color: c);
  static TextStyle title(Color c) => TextStyle(fontFamily: K.display, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w800, fontSize: 32, height: 1.0, letterSpacing: -1.2, color: c);
  static TextStyle h3(Color c) => TextStyle(fontFamily: K.display, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w700, fontSize: 21, height: 1.15, letterSpacing: -0.5, color: c);
  static TextStyle body(Color c) => TextStyle(fontFamily: K.body, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w500, fontSize: 16, height: 1.45, color: c);
  static TextStyle small(Color c) => TextStyle(fontFamily: K.body, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w600, fontSize: 13, height: 1.35, color: c);
  static TextStyle kicker(Color c) => TextStyle(fontFamily: K.mono, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w700, fontSize: 11.5, letterSpacing: 1.8, color: c);
  static TextStyle mono(Color c, {double size = 16}) => TextStyle(fontFamily: K.mono, fontFamilyFallback: K.fallback, fontWeight: FontWeight.w700, fontSize: size, color: c);
}
