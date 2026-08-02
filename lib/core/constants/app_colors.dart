import 'package:flutter/material.dart';

/// ResQPK dark-first color system.
class AppColors {
  AppColors._();

  // Background
  static const Color background = Color(0xFF0A0E1A); // deep navy
  static const Color surfaceOne = Color(0xFF111827);
  static const Color surfaceTwo = Color(0xFF1C2333);
  static const Color surfaceThree = Color(0xFF243044);
  static const Color glassOverlay = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)

  // Accent
  static const Color sosRed = Color(0xFFFF2D3B);
  static const Color sosGlow = Color(0x59FF2D3B); // rgba(255,45,59,0.35)
  static const Color confirmedGreen = Color(0xFF00D68F);
  static const Color warningAmber = Color(0xFFFFB930);
  static const Color infoBlue = Color(0xFF3B82F6);

  // Text
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFF4B5563);

  // Border
  static const Color borderGlass = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
}

/// Light palette for the patient home screen. The rest of the app stays on the
/// dark system above; this is scoped to the screens that follow the new
/// light reference design.
class AppLight {
  AppLight._();

  static const Color background = Color(0xFFF4F6FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE8ECF3);

  // Deep navy used by the location banner.
  static const Color navy = Color(0xFF152238);
  static const Color navyDeep = Color(0xFF0D1626);

  static const Color red = Color(0xFFE8202F);
  static const Color redSoft = Color(0xFFFF4757);
  static const Color green = Color(0xFF16A34A);
  static const Color greenTint = Color(0xFFE7F8EE);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueTint = Color(0xFFEAF1FE);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberTint = Color(0xFFFEF4E2);
  static const Color tealTint = Color(0xFFE6F7F5);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF94A3B8);
}
