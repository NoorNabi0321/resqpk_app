import 'package:flutter/material.dart';

/// The single source of colour truth for ResQPK.
///
/// Derived from the logo: its orange and green are the brand. The same token
/// names exist in the React app's Tailwind theme so the mobile app, the public
/// web pages and the hospital dashboard read as one product.
///
/// The rule that does the most work: **`brand` is ResQPK, `critical` is an
/// emergency.** The SOS button and critical urgency use `critical`; buttons,
/// tabs, links and highlights use `brand`. If the emergency colour is also the
/// decoration colour, nothing on the screen means anything.
class Resq {
  Resq._();

  // --- Surfaces: warm, because cool greys look dirty against cream ---------
  static const Color canvas = Color(0xFFF7F0E6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEFE5D8);
  static const Color border = Color(0xFFE5D9C9);

  // --- Brand: the logo's orange and green ----------------------------------
  static const Color brand = Color(0xFFF4551E);

  /// White text on `brand` fails contrast, so anything with a white label uses
  /// this instead. Two tokens rather than one accidental accessibility bug.
  static const Color brandInk = Color(0xFFC2410C);
  static const Color brandTint = Color(0xFFFFEDE4);

  /// The brand colour for text on a dark ground, such as the onboarding scrim.
  ///
  /// `brand` measures 2.9:1 against that scrim, under the 3:1 large text needs;
  /// lifted like this it is 3.8:1 and still plainly the same orange. The pair
  /// mirrors `brandInk`: one brand colour for light grounds, one for dark.
  static const Color brandOnDark = Color(0xFFFF7A55);

  // --- Emergency: deliberately redder than brand so the two never blur -----
  static const Color critical = Color(0xFFD62828);
  static const Color criticalPressed = Color(0xFFA81E1E);
  static const Color criticalTint = Color(0xFFFDECEC);

  /// Confirmed, online, arrived, low urgency — the logo's green.
  static const Color ready = Color(0xFF0FA37A);
  static const Color readyTint = Color(0xFFE6F7EF);

  /// Waiting, en route, needs a decision.
  static const Color decision = Color(0xFFE08A1E);
  static const Color decisionTint = Color(0xFFFDF3E2);

  /// Links, live tracking, map routes.
  static const Color info = Color(0xFF2563EB);
  static const Color infoTint = Color(0xFFEFF6FF);

  /// Navigation bar, headers, driver chrome.
  static const Color navy = Color(0xFF252A5B);

  // --- Warm text ramp -------------------------------------------------------
  static const Color ink = Color(0xFF1C1917);
  static const Color inkSoft = Color(0xFF57534E);
  static const Color inkMuted = Color(0xFF78716C);
  static const Color inkFaint = Color(0xFFA8A29E);

  // --- Shape, spacing, elevation -------------------------------------------
  static const double radiusCard = 16;
  static const double radiusControl = 12;
  static const double radiusPill = 999;

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
    BoxShadow(color: Color(0x0F1C1917), blurRadius: 3, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> raisedShadow = [
    BoxShadow(color: Color(0x1A1C1917), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

/// Dark surfaces, used by the driver app.
///
/// Drivers work at night with the phone mounted in a vehicle; a white screen at
/// 2am is genuinely dangerous. The accent colours above are unchanged — they
/// read on both grounds — so only surfaces and the text ramp differ.
class ResqDark {
  ResqDark._();

  static const Color canvas = Color(0xFF14162E);
  static const Color surface = Color(0xFF1E2145);
  static const Color surfaceRaised = Color(0xFF282C55);
  static const Color surfaceHigh = Color(0xFF32376B);
  static const Color border = Color(0xFF363B6E);

  static const Color ink = Color(0xFFECEAF6);
  static const Color inkMuted = Color(0xFFA6A8C8);
  static const Color inkFaint = Color(0xFF6F72A0);

  /// Hairline over a map at night.
  static const Color borderGlass = Color(0x1AFFFFFF);
  static const Color overlay = Color(0x0FFFFFFF);
}
