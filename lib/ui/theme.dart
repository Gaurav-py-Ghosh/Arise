import 'package:flutter/material.dart';

/// The System window palette and theme. Dark only.
class Sys {
  const Sys._();

  static const bg = Color(0xFF05070D);
  static const panel = Color(0xFF0A111E);
  static const panelHi = Color(0xFF101B2E);
  static const line = Color(0xFF1C2B44);
  static const accent = Color(0xFF3DA9FF);
  static const accentHi = Color(0xFF9ADBFF);
  static const text = Color(0xFFD6E4F5);
  static const dim = Color(0xFF6F819B);
  static const danger = Color(0xFFFF4D5E);
  static const gold = Color(0xFFFFC857);
  static const ok = Color(0xFF3DFFB0);

  static const font = 'monospace';

  /// Horizontal page gutter and the gap between panels.
  static const gutter = 16.0;
  static const gap = 12.0;

  static const cut = BorderRadius.all(Radius.circular(8));
  static const cutSmall = BorderRadius.all(Radius.circular(5));

  static BeveledRectangleBorder shape(Color side,
          {double width = 1, BorderRadius radius = cut}) =>
      BeveledRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: side, width: width),
      );

  /// `// LABEL` section headers.
  static const label = TextStyle(
    fontFamily: font,
    fontSize: 11,
    letterSpacing: 2,
    color: dim,
  );

  static const title = TextStyle(
    fontFamily: font,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 5,
    color: accentHi,
  );

  static const body = TextStyle(
    fontFamily: font,
    fontSize: 13.5,
    height: 1.45,
    color: text,
  );

  static const small = TextStyle(
    fontFamily: font,
    fontSize: 11.5,
    color: dim,
  );

  static ThemeData theme() {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: line),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: font,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      // InkSparkle is shader based; the plain ripple is enough.
      splashFactory: InkRipple.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        onPrimary: bg,
        secondary: accentHi,
        onSecondary: bg,
        error: danger,
        surface: panel,
        onSurface: text,
        surfaceContainerHighest: panelHi,
        outline: line,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: font,
        bodyColor: text,
        displayColor: text,
      ),
      iconTheme: const IconThemeData(color: dim, size: 20),
      dividerColor: line,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
        selectionHandleColor: accent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: bg,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent),
        ),
        hintStyle: TextStyle(fontFamily: font, color: dim, fontSize: 13),
        labelStyle: TextStyle(fontFamily: font, color: dim, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: BeveledRectangleBorder(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          side: BorderSide(color: accent.withValues(alpha: 0.5)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : dim),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? accent.withValues(alpha: 0.25)
                : panelHi),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : line),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panelHi,
        surfaceTintColor: Colors.transparent,
        shape: shape(line),
        textStyle: const TextStyle(fontFamily: font, color: text, fontSize: 13),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: panelHi,
        headerForegroundColor: accentHi,
        shape: shape(line),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelHi,
        contentTextStyle: const TextStyle(fontFamily: font, color: text),
        shape: shape(accent),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(fontFamily: font, color: text, fontSize: 11),
        decoration: BoxDecoration(color: panelHi),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}

/// No stretch overscroll (it runs a shader) and no glow: lists simply stop.
class SysScroll extends MaterialScrollBehavior {
  const SysScroll();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}
