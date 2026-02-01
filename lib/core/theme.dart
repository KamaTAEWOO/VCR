import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

// =============================================================================
// VCR Design System - Colors (UI_SPEC.md Section 2.1)
// =============================================================================

/// Background colors (GitHub Dark based)
class VcrColors {
  VcrColors._();

  // Background
  static const Color bgPrimary = Color(0xFF0D1117);
  static const Color bgSecondary = Color(0xFF161B22);
  static const Color bgTertiary = Color(0xFF21262D);
  static const Color bgSurface = Color(0xFF1C2128);

  // Text
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);

  // Semantic
  static const Color success = Color(0xFF3FB950);
  static const Color error = Color(0xFFF85149);
  static const Color warning = Color(0xFFD29922);
  static const Color info = Color(0xFF58A6FF);
  static const Color accent = Color(0xFFBC8CFF);

  // Agent state indicators
  static const Color stateIdle = Color(0xFF484F58);
  static const Color stateRunning = Color(0xFF3FB950);
  static const Color stateReloading = Color(0xFF58A6FF);
  static const Color stateBuilding = Color(0xFFD29922);
  static const Color stateError = Color(0xFFF85149);
  static const Color stateDisconnected = Color(0xFF484F58);
}

// =============================================================================
// VCR Design System - Typography (UI_SPEC.md Section 2.2)
// =============================================================================

class VcrTypography {
  VcrTypography._();

  static const String _monoFamily = 'monospace';

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: VcrColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: VcrColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: VcrColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: VcrColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: VcrColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: VcrColors.textPrimary,
  );

  // Terminal-specific styles (monospace required)
  static const TextStyle terminalText = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: VcrColors.textPrimary,
  );

  static const TextStyle terminalInput = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: VcrColors.textPrimary,
  );

  static const TextStyle terminalPrompt = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: VcrColors.accent,
  );
}

// =============================================================================
// xterm Terminal Theme (UI_SPEC_V2.md Section 6)
// =============================================================================

const TerminalTheme vcrTerminalTheme = TerminalTheme(
  cursor: VcrColors.accent,
  selection: Color(0x40BC8CFF),
  foreground: VcrColors.textPrimary,
  background: VcrColors.bgPrimary,
  black: Color(0xFF484F58),
  red: Color(0xFFF85149),
  green: Color(0xFF3FB950),
  yellow: Color(0xFFD29922),
  blue: Color(0xFF58A6FF),
  magenta: Color(0xFFBC8CFF),
  cyan: Color(0xFF76E3EA),
  white: Color(0xFFE6EDF3),
  brightBlack: Color(0xFF6E7681),
  brightRed: Color(0xFFFFA198),
  brightGreen: Color(0xFF56D364),
  brightYellow: Color(0xFFE3B341),
  brightBlue: Color(0xFF79C0FF),
  brightMagenta: Color(0xFFD2A8FF),
  brightCyan: Color(0xFFA5D6FF),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFD29922),
  searchHitBackgroundCurrent: Color(0xFFF85149),
  searchHitForeground: Color(0xFF0D1117),
);

const TerminalStyle vcrTerminalStyle = TerminalStyle(
  fontSize: 11,
  height: 1.2,
);

// =============================================================================
// VCR ThemeData (UI_SPEC.md Section 6)
// =============================================================================

final ThemeData vcrDarkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: VcrColors.bgPrimary,
  colorScheme: const ColorScheme.dark(
    primary: VcrColors.accent,
    secondary: VcrColors.info,
    error: VcrColors.error,
    surface: VcrColors.bgSurface,
  ),
  cardColor: VcrColors.bgSecondary,
  appBarTheme: const AppBarTheme(
    backgroundColor: VcrColors.bgSecondary,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: VcrColors.bgTertiary,
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: VcrColors.textMuted),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: VcrColors.accent,
      foregroundColor: VcrColors.bgPrimary,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: VcrColors.bgTertiary,
    contentTextStyle: const TextStyle(color: VcrColors.textPrimary),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  ),
  textTheme: const TextTheme(
    headlineLarge: VcrTypography.headlineLarge,
    headlineMedium: VcrTypography.headlineMedium,
    titleLarge: VcrTypography.titleLarge,
    bodyLarge: VcrTypography.bodyLarge,
    bodyMedium: VcrTypography.bodyMedium,
    labelMedium: VcrTypography.labelMedium,
  ),
);
