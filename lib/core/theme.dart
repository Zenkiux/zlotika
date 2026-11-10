import 'package:flutter/material.dart';

/// Brand tokens sampled from the approved Zlotika logo.
class Brand {
  static const ink = Color(0xFF0F1017); // logo background
  static const ink2 = Color(0xFF171923);
  static const ink3 = Color(0xFF20222E);
  static const ink4 = Color(0xFF2B2E3C);
  static const yellow = Color(0xFFFCC206); // LT flag
  static const green = Color(0xFF055E40); // LT flag
  static const greenBright = Color(0xFF2FC98C); // legible green on ink
  static const ltRed = Color(0xFFB41627); // LT flag
  static const plRed = Color(0xFFDD022A); // PL flag
  static const coral = Color(0xFFE2465B); // logo underline
  static const white = Color(0xFFF5F5F5);
}

/// Semantic colours for one theme. Read with `context.c`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.line,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.onAccent,
    required this.good,
    required this.goodSoft,
    required this.bad,
    required this.badSoft,
    required this.warnSoft,
    required this.warn,
  });

  final Color bg, surface, raised, line, text, text2, text3, accent, onAccent, good, goodSoft, bad, badSoft, warnSoft, warn;

  static const dark = Palette(
    bg: Brand.ink,
    surface: Brand.ink2,
    raised: Brand.ink3,
    line: Brand.ink4,
    text: Brand.white,
    text2: Color(0xFFB4B7C5),
    text3: Color(0xFF7E8293),
    accent: Brand.yellow,
    onAccent: Brand.ink,
    good: Brand.greenBright,
    goodSoft: Color(0xFF0E2C22),
    bad: Color(0xFFFF5A6E),
    badSoft: Color(0xFF34141B),
    warnSoft: Color(0xFF332A0B),
    warn: Brand.yellow,
  );

  static const light = Palette(
    bg: Color(0xFFF4F4F7),
    surface: Colors.white,
    raised: Color(0xFFECEDF2),
    line: Color(0xFFE1E2E9),
    text: Brand.ink,
    text2: Color(0xFF4D5162),
    text3: Color(0xFF7A7E8E),
    accent: Brand.yellow,
    onAccent: Brand.ink,
    good: Brand.green,
    goodSoft: Color(0xFFE2F2EB),
    bad: Brand.ltRed,
    badSoft: Color(0xFFFBE6E8),
    warnSoft: Color(0xFFFFF4CC),
    warn: Color(0xFF7A5B00),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < .5 ? this : (other as Palette);
}

extension PaletteX on BuildContext {
  Palette get c => Theme.of(this).extension<Palette>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}

const _display = 'Manrope';
const _body = 'Inter';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: _body);
  TextStyle d(double size, FontWeight w, {double h = 1.15, double ls = -0.3}) =>
      TextStyle(fontFamily: _display, fontSize: size, fontWeight: w, height: h, letterSpacing: ls, color: p.text);
  TextStyle t(double size, FontWeight w, {Color? color, double h = 1.4}) =>
      TextStyle(fontFamily: _body, fontSize: size, fontWeight: w, height: h, color: color ?? p.text);
  // Generous sizes on purpose: readable for every age group.
  final text = TextTheme(
    displayLarge: d(44, FontWeight.w800, h: 1.0, ls: -1.2),
    displayMedium: d(34, FontWeight.w800, h: 1.05, ls: -0.8),
    headlineMedium: d(28, FontWeight.w800, ls: -0.6),
    headlineSmall: d(23, FontWeight.w800, ls: -0.4),
    titleLarge: d(20, FontWeight.w700),
    titleMedium: t(17, FontWeight.w600),
    bodyLarge: t(17, FontWeight.w400),
    bodyMedium: t(15.5, FontWeight.w400, color: p.text2),
    bodySmall: t(13.5, FontWeight.w400, color: p.text3),
    labelLarge: t(17, FontWeight.w700, h: 1.2),
    labelMedium: t(14, FontWeight.w600, color: p.text2),
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: text,
    extensions: [p],
    colorScheme: ColorScheme.fromSeed(seedColor: Brand.yellow, brightness: b).copyWith(
      primary: Brand.yellow,
      onPrimary: Brand.ink,
      surface: p.surface,
      onSurface: p.text,
      error: p.bad,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: t(15, FontWeight.w600, color: p.bg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: t(17, FontWeight.w400, color: p.text3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Brand.yellow, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: Brand.yellow.withValues(alpha: b == Brightness.dark ? .18 : .35),
      height: 74,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => t(13, s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.text : p.text3)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 26, color: s.contains(WidgetState.selected) ? p.text : p.text3)),
    ),
  );
}
