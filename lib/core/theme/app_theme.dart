import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Two themes, one palette.
///
/// Light is for everyone in an emergency: patients, bystanders, hospital staff.
/// Dark is for drivers, who work at night with the phone mounted in a vehicle.
/// Both draw from the same tokens, so an ambulance is the same blue on both.
///
/// Screens should stop hand-styling surfaces and read from the theme instead —
/// that is what makes a restyle a one-file change rather than a thirty-file one.
class ResqTheme {
  ResqTheme._();

  static ThemeData get light => _base(
        brightness: Brightness.light,
        canvas: Resq.canvas,
        surface: Resq.surface,
        outline: Resq.border,
        ink: Resq.ink,
        inkMuted: Resq.inkMuted,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        canvas: ResqDark.canvas,
        surface: ResqDark.surface,
        outline: ResqDark.border,
        ink: ResqDark.ink,
        inkMuted: ResqDark.inkMuted,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color canvas,
    required Color surface,
    required Color outline,
    required Color ink,
    required Color inkMuted,
  }) {
    final isLight = brightness == Brightness.light;
    final textTheme = GoogleFonts.interTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    ).apply(bodyColor: ink, displayColor: ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: brightness,
        // `critical` is the primary action colour only because the primary
        // action of this app is an emergency. Ordinary actions use `info`.
        primary: Resq.critical,
        onPrimary: Colors.white,
        secondary: Resq.info,
        onSecondary: Colors.white,
        error: Resq.critical,
        onError: Colors.white,
        surface: surface,
        onSurface: ink,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Resq.radiusCard),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Resq.radiusControl),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Resq.radiusControl),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Resq.radiusControl),
          borderSide: const BorderSide(color: Resq.info, width: 2),
        ),
        hintStyle: TextStyle(color: inkMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Resq.critical,
          foregroundColor: Colors.white,
          // Every tappable thing clears 48dp: this app is used one-handed, in a
          // hurry, sometimes in a moving vehicle.
          minimumSize: const Size.fromHeight(Resq.tapTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Resq.radiusControl)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(Resq.tapTarget),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Resq.radiusControl)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Resq.info,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? Resq.ink : ResqDark.surfaceRaised,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Resq.radiusControl)),
      ),
    );
  }
}
