import 'package:flutter/material.dart';

/// The single source of colour truth for ResQPK.
///
/// The same token names exist in the React app's Tailwind theme, with the same
/// values, so the mobile app, the public web pages and the hospital dashboard
/// read as one product. When a value changes here it changes there in the same
/// commit — see ResQPK_Plan_3_Frontend_Design.md §2.
///
/// The rule that does the most work: **`critical` is for emergencies only.**
/// Not for delete buttons, not for decoration. If red is everywhere it signals
/// nothing, which is how the first version ended up feeling flat.
class Resq {
  Resq._();

  // --- Surfaces (light — patient, public and hospital screens) -------------
  static const Color canvas = Color(0xFFF6F8FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE5E9F0);

  // --- Semantic colours: one meaning each ----------------------------------
  /// SOS and critical urgency. Nothing else.
  static const Color critical = Color(0xFFDC2626);
  static const Color criticalPressed = Color(0xFFB91C1C);
  static const Color criticalTint = Color(0xFFFEF2F2);

  /// Waiting, en route, needs a decision.
  static const Color decision = Color(0xFFD97706);
  static const Color decisionTint = Color(0xFFFFFBEB);

  /// Confirmed, online, arrived, low urgency.
  static const Color ready = Color(0xFF059669);
  static const Color readyTint = Color(0xFFECFDF5);

  /// Links, secondary actions, live tracking.
  static const Color info = Color(0xFF2563EB);
  static const Color infoTint = Color(0xFFEFF6FF);

  /// Brand navy — headers and the driver app's chrome.
  static const Color brand = Color(0xFF0B2545);
  static const Color brandSoft = Color(0xFF134074);

  // --- Text ramp on light surfaces -----------------------------------------
  static const Color ink = Color(0xFF111827);
  static const Color inkSoft = Color(0xFF4B5563);
  static const Color inkMuted = Color(0xFF6B7280);
  static const Color inkFaint = Color(0xFF9CA3AF);

  // --- Radii, spacing, elevation -------------------------------------------
  static const double radiusCard = 16;
  static const double radiusControl = 12;
  static const double radiusPill = 999;

  /// 4-point spacing scale. Page gutter is 16, card padding 14–16.
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  /// Minimum touch target. Anything smaller fails in a moving vehicle.
  static const double tapTarget = 48;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> raisedShadow = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

/// Dark surfaces, used by the driver app.
///
/// Drivers work at night with the phone mounted in a vehicle; a white screen at
/// 2am is genuinely dangerous. The accent colours above are unchanged — they are
/// legible on both grounds — so only the surfaces and the text ramp differ.
class ResqDark {
  ResqDark._();

  static const Color canvas = Color(0xFF0B1220);
  static const Color surface = Color(0xFF16202E);
  static const Color surfaceRaised = Color(0xFF1E2A3A);
  static const Color surfaceHigh = Color(0xFF243044);
  static const Color border = Color(0xFF2B3A4E);

  static const Color ink = Color(0xFFE6EDF5);
  static const Color inkMuted = Color(0xFF9FB0C3);
  static const Color inkFaint = Color(0xFF6B7A8C);

  /// Hairline over photography or a map at night.
  static const Color borderGlass = Color(0x1AFFFFFF);
  static const Color overlay = Color(0x0FFFFFFF);
}
