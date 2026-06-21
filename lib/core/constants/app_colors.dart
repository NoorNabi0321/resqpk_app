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
