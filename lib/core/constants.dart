// =============================================================================
// VCR Design System - Spacing & Layout (UI_SPEC.md Section 2.3, 2.4)
// =============================================================================

/// Spacing tokens (dp)
class Spacing {
  Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Border radius tokens (dp)
class Radii {
  Radii._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double full = 999;
}

/// Animation durations (milliseconds)
/// Named VcrDurations to avoid clash with Flutter's Durations class.
class VcrDurations {
  VcrDurations._();

  static const Duration pulse = Duration(milliseconds: 1500);
  static const Duration rotate = Duration(milliseconds: 1000);
  static const Duration fadeIn = Duration(milliseconds: 300);
  static const Duration slideUp = Duration(milliseconds: 200);
  static const Duration statusTransition = Duration(milliseconds: 300);
}

/// Network constants
class NetworkConstants {
  NetworkConstants._();

  static const int defaultPort = 9000;
  static const String mdnsServiceType = '_vcr._tcp';
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 5);
  static const int maxReconnectAttempts = 5;
  static const Duration mdnsTimeout = Duration(seconds: 10);
  static const Duration connectTimeout = Duration(seconds: 10);
}

/// Terminal constants
class TerminalConstants {
  TerminalConstants._();

  static const int maxHistorySize = 100;
}
