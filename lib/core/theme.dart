import 'package:flutter/material.dart';

/// Brand tokens. Yellow is the one accent; flag colours appear only in the ribbon and PL tag.
class Brand {
  static const ink = Color(0xFF111215); // text on yellow
  static const ink2 = Color(0xFF13151B);
  static const ink3 = Color(0xFF191C24);
  static const ink4 = Color(0xFF222631);
  static const yellow = Color(0xFFF5C43D);
  static const yellowDeep = Color(0xFFEBB72A);
  static const green = Color(0xFF055E40); // LT flag
  static const greenBright = Color(0xFF34D399);
  static const ltRed = Color(0xFFB41627); // LT flag
  static const plRed = Color(0xFFDC2626); // PL tag
  static const coral = Color(0xFFE2465B);
  static const white = Color(0xFFF4F6FA);
}

/// Semantic colours for one theme. Read with `context.c`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.raised2,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.accentLine,
    required this.onAccent,
    required this.good,
    required this.goodSoft,
    required this.bad,
    required this.badSoft,
    required this.warn,
    required this.warnSoft,
    required this.blue,
    required this.blueSoft,
    required this.sheet,
    required this.nav,
  });

  final Color bg, surface, raised, raised2, line, lineStrong, text, text2, text3;
  final Color accent, accentText, accentSoft, accentLine, onAccent;
  final Color good, goodSoft, bad, badSoft, warn, warnSoft, blue, blueSoft, sheet, nav;

  static const dark = Palette(
    bg: Color(0xFF0B0C0F),
    surface: Color(0xFF13151B),
    raised: Color(0xFF191C24),
    raised2: Color(0xFF222631),
    line: Color(0x14FFFFFF),
    lineStrong: Color(0x24FFFFFF),
    text: Color(0xFFF4F6FA),
    text2: Color(0xFF9AA2B2),
    text3: Color(0xFF687082),
    accent: Color(0xFFF5C43D),
    accentText: Color(0xFFF5C43D),
    accentSoft: Color(0x24F5C43D),
    accentLine: Color(0x47F5C43D),
    onAccent: Color(0xFF111215),
    good: Color(0xFF34D399),
    goodSoft: Color(0x2434D399),
    bad: Color(0xFFEF4444),
    badSoft: Color(0x26EF4444),
    warn: Color(0xFFF59E0B),
    warnSoft: Color(0x26F59E0B),
    blue: Color(0xFF60A5FA),
    blueSoft: Color(0x2460A5FA),
    sheet: Color(0xFF14171E),
    nav: Color(0xEB0D0F14),
  );

  static const light = Palette(
    bg: Color(0xFFF5F6F8),
    surface: Colors.white,
    raised: Color(0xFFEFEFF3),
    raised2: Color(0xFFE4E6EC),
    line: Color(0x140F172A),
    lineStrong: Color(0x260F172A),
    text: Color(0xFF0F172A),
    text2: Color(0xFF525B6D),
    text3: Color(0xFF838D9F),
    accent: Color(0xFFEAB308),
    accentText: Color(0xFFB45309),
    accentSoft: Color(0x26EAB308),
    accentLine: Color(0x4DCA8A04),
    onAccent: Color(0xFF111215),
    good: Color(0xFF059669),
    goodSoft: Color(0x1F059669),
    bad: Color(0xFFDC2626),
    badSoft: Color(0x1CDC2626),
    warn: Color(0xFFD97706),
    warnSoft: Color(0x1FD97706),
    blue: Color(0xFF2563EB),
    blueSoft: Color(0x1C2563EB),
    sheet: Colors.white,
    nav: Color(0xEBFFFFFF),
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

const display = 'Manrope';
const body = 'Inter';

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(brightness: b, useMaterial3: true, fontFamily: body);
  TextStyle d(double size, FontWeight w, {double h = 1.15, double ls = -0.3}) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: w, height: h, letterSpacing: ls, color: p.text);
  TextStyle t(double size, FontWeight w, {Color? color, double h = 1.35}) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: w, height: h, color: color ?? p.text);
  final text = TextTheme(
    displayLarge: d(38, FontWeight.w700, h: 1.0, ls: -1.2),
    displayMedium: d(30, FontWeight.w700, h: 1.05, ls: -0.9),
    headlineMedium: d(26, FontWeight.w700, ls: -0.73),
    headlineSmall: d(20, FontWeight.w700, ls: -0.4),
    titleLarge: d(17, FontWeight.w700, ls: -0.25),
    titleMedium: t(15, FontWeight.w600, h: 1.28),
    bodyLarge: t(15.5, FontWeight.w400, h: 1.42),
    bodyMedium: t(13.5, FontWeight.w400, color: p.text2, h: 1.38),
    bodySmall: t(12, FontWeight.w400, color: p.text3, h: 1.33),
    labelLarge: d(15.5, FontWeight.w700, h: 1.2, ls: -0.15),
    labelMedium: t(12.5, FontWeight.w600, color: p.text2, h: 1.2),
    labelSmall: t(11.5, FontWeight.w600, color: p.text2, h: 1.2),
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    textTheme: text,
    extensions: [p],
    colorScheme: ColorScheme.fromSeed(seedColor: Brand.yellow, brightness: b).copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      surface: p.surface,
      onSurface: p.text,
      error: p.bad,
    ),
    splashFactory: InkRipple.splashFactory,
    highlightColor: p.raised.withValues(alpha: .5),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 54,
      foregroundColor: p.text,
      titleTextStyle: d(16.5, FontWeight.w700, ls: -0.25),
      shape: Border(bottom: BorderSide(color: p.line)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.sheet, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      checkColor: WidgetStatePropertyAll(p.onAccent),
      side: BorderSide(color: p.lineStrong, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.text2),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.raised2),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.sheet,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: Colors.black.withValues(alpha: .58),
      showDragHandle: true,
      dragHandleColor: p.lineStrong,
      dragHandleSize: const Size(38, 4),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: p.lineStrong),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1C2029),
      contentTextStyle: t(13.5, FontWeight.w500, color: const Color(0xFFF8FAFC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0x1FFFFFFF))),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: p.accent, selectionHandleColor: p.accent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: t(14.5, FontWeight.w400, color: p.text3),
      labelStyle: t(14, FontWeight.w500, color: p.text2),
      prefixIconColor: p.text3,
      suffixIconColor: p.text3,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accentLine, width: 1.5)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accentText, textStyle: t(13, FontWeight.w600)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.nav,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => t(10.5, s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.accentText : p.text3, h: 1.1)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 23, color: s.contains(WidgetState.selected) ? p.accentText : p.text3)),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: p.accent, textColor: p.onAccent, textStyle: t(10, FontWeight.w700)),
  );
}
