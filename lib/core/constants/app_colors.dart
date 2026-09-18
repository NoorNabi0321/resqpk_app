import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Legacy colour names, now backed by the shared tokens in `core/theme/tokens.dart`.
///
/// Kept because 26 screens reference them; new work should use `Resq` and
/// `ResqDark` directly. The values are the unified palette, so the three
/// different reds and two different greens the app had collapse into one each.
///
/// This class is the dark set, used by the driver app.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color background = ResqDark.canvas;
  static const Color surfaceOne = ResqDark.surface;
  static const Color surfaceTwo = ResqDark.surfaceRaised;
  static const Color surfaceThree = ResqDark.surfaceHigh;
  static const Color glassOverlay = ResqDark.overlay;
  static const Color borderGlass = ResqDark.borderGlass;

  // Accents — identical to the light set, because they read on both grounds.
  static const Color sosRed = Resq.critical;
  static const Color sosGlow = Color(0x59DC2626);
  static const Color confirmedGreen = Resq.ready;
  static const Color warningAmber = Resq.decision;
  static const Color infoBlue = Resq.info;

  // Text on dark
  static const Color textPrimary = ResqDark.ink;
  static const Color textSecondary = ResqDark.inkMuted;
  static const Color textDisabled = ResqDark.inkFaint;
}

/// The light set, used by patient-facing screens.
class AppLight {
  AppLight._();

  static const Color background = Resq.canvas;
  static const Color card = Resq.surface;
  static const Color cardAlt = Resq.surfaceAlt;
  static const Color border = Resq.border;

  static const Color navy = Resq.brand;
  static const Color navyDeep = Color(0xFF071A33);

  static const Color red = Resq.critical;
  static const Color redSoft = Color(0xFFEF4444);
  static const Color green = Resq.ready;
  static const Color greenTint = Resq.readyTint;
  static const Color blue = Resq.info;
  static const Color blueTint = Resq.infoTint;
  static const Color amber = Resq.decision;
  static const Color amberTint = Resq.decisionTint;
  static const Color tealTint = Color(0xFFE6F7F5);

  static const Color textPrimary = Resq.ink;
  static const Color textSecondary = Resq.inkMuted;
  static const Color textFaint = Resq.inkFaint;
}
