import 'package:flutter/widgets.dart';

/// Single source of truth for responsive breakpoints across the entire app.
///
/// Usage:
///   final isMobile = Responsive.isMobile(context);
///   final w = Responsive.breakpoint; // 850
class Responsive {
  Responsive._();

  /// Width below which the app switches to mobile layout (bottom nav, drawer, etc.)
  static const double breakpoint = 850.0;

  /// Uses [MediaQuery.sizeOf] (Flutter 3.7+) — only rebuilds when size changes,
  /// not on every MediaQuery property update.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;
}
